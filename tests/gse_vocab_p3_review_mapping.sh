#!/usr/bin/env bash
set -uo pipefail

FAILED=0
PASS_COUNT=0
FAIL_COUNT=0
RESULTS=()

pass() {
  RESULTS+=("PASS: $1")
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  RESULTS+=("FAIL: $1")
  FAIL_COUNT=$((FAIL_COUNT + 1))
  FAILED=1
}

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="$ROOT/english/cefr-vocabulary/fixtures/gse-vocab"
ENTRYPOINT="$ROOT/english/cefr-vocabulary/scripts/gse-vocabulary-core.js"
FROZEN_YLE="$ROOT/english/cefr-vocabulary/cefr-vocabulary-knowledge-space.json"
RUN_ROOT="$(mktemp -d "/tmp/opencode/gse-vocab-p3-review.XXXXXX")" || exit 2

cleanup() {
  rm -rf -- "$RUN_ROOT"
}
trap cleanup EXIT HUP INT TERM

probe() {
  local name="$1"
  python3 - "$ROOT" "$FIXTURE_DIR" "$ENTRYPOINT" "$FROZEN_YLE" "$RUN_ROOT" "$name" <<'PY'
import json
import shutil
import subprocess
import sys
from pathlib import Path


repo_root, fixture_source, entrypoint, frozen_source, run_root, probe_name = sys.argv[1:]
repo_root = Path(repo_root).resolve()
fixture_source = Path(fixture_source).resolve()
entrypoint = Path(entrypoint).resolve()
frozen_source = Path(frozen_source).resolve()
run_root = Path(run_root).resolve()

QUEUE_NAMES = (
    "ambiguous-node-to-entry.jsonl",
    "unmapped-node-to-entry.jsonl",
    "unmatched-gse-entry.jsonl",
    "invalid-cefr-source-data.jsonl",
)


class ProbeError(RuntimeError):
    pass


def need(condition, message):
    if not condition:
        raise ProbeError(message)


def read_json(path):
    path = Path(path)
    need(path.is_file(), f"missing JSON file: {path}")
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ProbeError(f"invalid JSON file {path}: {exc}") from exc


def write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )


def case_by_id(document, case_id):
    for case in document.get("cases", []):
        if case.get("caseId") == case_id:
            return case
    raise ProbeError(f"missing fixture case: {case_id}")


def setup_run(label):
    root = run_root / label
    fixture = root / "fixture"
    shutil.copytree(fixture_source, fixture)
    mutation = read_json(fixture / "mutation-cases.json")
    mutation_case = case_by_id(mutation, "byte-diff-report-actual-mutation")
    prior_graph = root / "prior-graph.json"
    write_json(prior_graph, mutation_case["priorGraph"])
    frozen_yle = root / "frozen-yle.json"
    shutil.copy2(frozen_source, frozen_yle)
    output = root / "output"
    queue_root = root / "english/cefr-vocabulary/review/gse-vocab/queues"
    queue_root.mkdir(parents=True, exist_ok=True)
    queues = {name: queue_root / name for name in QUEUE_NAMES}
    for queue in queues.values():
        queue.touch()
    reports = root / "reports"
    paths = {
        "mapping": output / "mapping/mappings.json",
        "conflict": reports / "cambridge-gse-cefr-conflicts.jsonl",
        "ambiguous": queues["ambiguous-node-to-entry.jsonl"],
    }
    args = [
        "node",
        str(entrypoint),
        "--fixture-dir",
        str(fixture),
        "--prior-graph",
        str(prior_graph),
        "--output-dir",
        str(output),
    ]
    for name in QUEUE_NAMES:
        args.extend(["--queue-file", f"{name}={queues[name]}"])
    args.extend(
        [
            "--byte-diff-report",
            str(reports / "byte-diff.json"),
            "--mapping-quality-report",
            str(reports / "mapping-quality.json"),
            "--conflict-report",
            str(paths["conflict"]),
            "--frozen-yle",
            str(frozen_yle),
        ]
    )
    return root, fixture, paths, args


def run_cli(args):
    result = subprocess.run(
        args,
        cwd=repo_root,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        timeout=120,
        check=False,
    )
    need(result.returncode == 0, f"CLI failed with exit {result.returncode}: {(result.stderr or result.stdout).strip()}")


def mapping_case(path, case_id):
    document = read_json(path)
    for case in document.get("cases", []):
        if case.get("caseId") == case_id:
            return case
    raise ProbeError(f"mapping output omitted case: {case_id}")


def jsonl(path):
    return [json.loads(line) for line in Path(path).read_text(encoding="utf-8").splitlines() if line.strip()]


def wrong_pos_probe():
    _root, fixture, paths, args = setup_run("wrong-pos")
    mapping_path = fixture / "mapping-cases.json"
    document = read_json(mapping_path)
    case = case_by_id(document, "same-form-different-pos-falsifier")
    entries = case["entries"]
    noun = next(entry for entry in entries if entry.get("grammaticalCategories") == ["noun"])
    verb = next(entry for entry in entries if entry.get("grammaticalCategories") == ["verb"])
    need(case["expected"]["itemId"] == verb["itemId"], "falsifier fixture does not identify its verb")
    case["expected"]["itemId"] = noun["itemId"]
    write_json(mapping_path, document)
    run_cli(args)
    actual = mapping_case(paths["mapping"], "same-form-different-pos-falsifier")
    need(actual.get("outcome") == "mapped", "wrong-POS falsifier did not map")
    need(actual.get("normalizedForm") == "make", "wrong-POS mapping changed the form")
    need(actual.get("normalizedPartsOfSpeech") == ["verb"], "wrong-POS mapping ignored the verb POS")
    need(actual.get("audience") == "GL", "wrong-POS mapping ignored the audience")
    need(actual.get("itemId") == verb["itemId"], "wrong-POS mapping trusted the noun expected itemId")
    need((actual.get("nodeMetadataGse") or {}).get("itemId") == verb["itemId"], "wrong-POS GSE data is not verb-backed")


def one_candidate_probe():
    _root, fixture, paths, args = setup_run("one-candidate")
    mapping_path = fixture / "mapping-cases.json"
    document = read_json(mapping_path)
    case = case_by_id(document, "ambiguous-binding")
    candidate = case["entries"][0]
    case["entries"] = [candidate]
    case["expected"] = {
        "outcome": "mapped",
        "itemId": candidate["itemId"],
    }
    write_json(mapping_path, document)
    run_cli(args)
    actual = mapping_case(paths["mapping"], "ambiguous-binding")
    need(actual.get("outcome") == "mapped", "one-candidate case did not map")
    need(actual.get("itemId") == candidate["itemId"], "one-candidate case mapped the wrong item")
    need((actual.get("nodeMetadataGse") or {}).get("itemId") == candidate["itemId"], "one-candidate GSE data is missing")
    need(not jsonl(paths["ambiguous"]), "one-candidate case wrote an ambiguous queue row")


def conflict_band_probe():
    _root, fixture, paths, args = setup_run("tampered-conflict-band")
    mapping_path = fixture / "mapping-cases.json"
    document = read_json(mapping_path)
    case = case_by_id(document, "cambridge-gse-level-conflict")
    source_entry = case["entries"][0]
    need(source_entry.get("cefr", "").startswith("A2"), "conflict fixture source band is not A2")
    case["expected"]["conflictReport"]["gseCefrBand"] = "C2"
    write_json(mapping_path, document)
    run_cli(args)
    rows = jsonl(paths["conflict"])
    matching = [row for row in rows if row.get("itemId") == source_entry["itemId"]]
    need(len(matching) == 1, "tampered conflict report omitted the source item")
    need(matching[0].get("gseCefrBand") == "A2", "conflict report did not use the source A2 band")


probes = {
    "wrong-POS expected item bypass": wrong_pos_probe,
    "one-candidate ambiguous outcome": one_candidate_probe,
    "tampered conflict band": conflict_band_probe,
}

if probe_name not in probes:
    raise SystemExit(f"unknown probe: {probe_name}")

try:
    probes[probe_name]()
except (OSError, StopIteration, KeyError, TypeError, ValueError, ProbeError) as exc:
    print(str(exc), file=sys.stderr)
    raise SystemExit(1)
PY
}

echo "=== wrong-POS expected item bypass ==="
if probe "wrong-POS expected item bypass"; then
  pass "wrong-POS mapping uses form, POS, and audience"
else
  fail "wrong-POS mapping trusted the tampered expected item"
fi

echo "=== one-candidate ambiguous outcome ==="
if probe "one-candidate ambiguous outcome"; then
  pass "one exact candidate maps without an ambiguous queue row"
else
  fail "one exact candidate still produced an ambiguous outcome"
fi

echo "=== tampered conflict band ==="
if probe "tampered conflict band"; then
  pass "conflict output uses the source A2 band"
else
  fail "conflict output trusted the tampered expected band"
fi

echo "=== results ==="
printf '%s\n' "${RESULTS[@]}"
echo "=== Total: $((PASS_COUNT + FAIL_COUNT)) checks (PASS=$PASS_COUNT, FAIL=$FAIL_COUNT) ==="
exit "$FAILED"
