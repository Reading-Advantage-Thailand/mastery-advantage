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
TRACK_ID="gse_vocabulary_core_enrichment_20260811"
track_dir_resolve() {
  local track_id="$1"
  if [[ -d "$ROOT/measure/archive/$track_id" ]]; then
    printf '%s\n' "$ROOT/measure/archive/$track_id"
  else
    printf '%s\n' "$ROOT/measure/tracks/$track_id"
  fi
}
TRACK_DIR="$(track_dir_resolve "$TRACK_ID")"
PLAN="${GSE_VOCAB_P3_PLAN:-$TRACK_DIR/plan.md}"
FIXTURE_DIR="${GSE_VOCAB_P3_FIXTURE_DIR:-$ROOT/english/cefr-vocabulary/fixtures/gse-vocab}"
CONTRACT="$TRACK_DIR/phase3-execution-contract.md"
ENTRYPOINT="$ROOT/english/cefr-vocabulary/scripts/gse-vocabulary-core.js"
FROZEN_YLE="$ROOT/english/cefr-vocabulary/cefr-vocabulary-knowledge-space.json"

if ! TEMP_ROOT="$(mktemp -d "/tmp/opencode/gse-vocab-p3.XXXXXX")"; then
  echo "=== temporary probe storage ==="
  fail "temporary probe storage could not be created"
  printf '%s\n' "${RESULTS[@]}"
  echo "=== Total: $((PASS_COUNT + FAIL_COUNT)) checks (PASS=$PASS_COUNT, FAIL=$FAIL_COUNT) ==="
  exit "$FAILED"
fi

cleanup() {
  rm -rf -- "$TEMP_ROOT"
  if [[ -n "${NEGATIVE_PLAN:-}" ]]; then
    rm -f -- "$NEGATIVE_PLAN"
  fi
}
trap cleanup EXIT HUP INT TERM

if [[ "${GSE_VOCAB_P3_NEGATIVE:-}" == "completed-without-sha" ]]; then
  NEGATIVE_TMP_ROOT="${TMPDIR:-}"
  if [[ -z "$NEGATIVE_TMP_ROOT" && -d /dev/shm && -w /dev/shm ]]; then
    NEGATIVE_TMP_ROOT=/dev/shm
  elif [[ -z "$NEGATIVE_TMP_ROOT" ]]; then
    NEGATIVE_TMP_ROOT=/tmp
  fi
  NEGATIVE_PLAN="$(mktemp "$NEGATIVE_TMP_ROOT/gse-vocab-p3-plan.XXXXXX")"
  if ! cp -- "$PLAN" "$NEGATIVE_PLAN"; then
    printf 'could not copy plan for the completed-without-sha probe: %s\n' "$PLAN" >&2
    exit 2
  fi
  python3 - "$NEGATIVE_PLAN" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
phase = re.search(
    r"(^## Phase 3: Extraction, Mapping, And Core Mutation\s*$)(.*?)(?=^## Phase 4:|\Z)",
    text,
    re.MULTILINE | re.DOTALL | re.IGNORECASE,
)
if phase is None:
    raise SystemExit("Phase 3 section is missing from the temporary plan")

task_pattern = re.compile(r"^([ \t]*)- \[([~xb ])\] (.+)$", re.MULTILINE)
top_level_number = 0


def rewrite(match):
    global top_level_number
    indent, _status, description = match.groups()
    description = re.sub(
        r"\s+-\s+commit:\s*[0-9a-f]{7,40}\b[.,]?",
        "",
        description,
        flags=re.IGNORECASE,
    ).rstrip()
    if not indent:
        top_level_number += 1
        if top_level_number > 1:
            description += " - commit: 9ef2832"
    return f"{indent}- [x] {description}"


rewritten_phase = task_pattern.sub(rewrite, phase.group(0))
if top_level_number == 0:
    raise SystemExit("Phase 3 has no top-level tasks in the temporary plan")
path.write_text(text[: phase.start()] + rewritten_phase + text[phase.end() :], encoding="utf-8")
PY
  PLAN="$NEGATIVE_PLAN"
elif [[ -n "${GSE_VOCAB_P3_NEGATIVE:-}" ]]; then
  printf 'unknown GSE_VOCAB_P3_NEGATIVE mode: %s\n' "$GSE_VOCAB_P3_NEGATIVE" >&2
  exit 2
fi

probe() {
  local check="$1"
  python3 - "$ROOT" "$FIXTURE_DIR" "$ENTRYPOINT" "$FROZEN_YLE" "$TEMP_ROOT" "$TRACK_DIR" "$PLAN" "$check" <<'PY'
import hashlib
import json
import re
import shutil
import subprocess
import sys
import unicodedata
from pathlib import Path

repo_root, fixture_arg, entrypoint_arg, frozen_arg, temp_arg, track_dir_arg, plan_arg, check = sys.argv[1:]
repo_root = Path(repo_root).resolve()
fixture_root = Path(fixture_arg).resolve()
entrypoint = Path(entrypoint_arg).resolve()
frozen_path = Path(frozen_arg).resolve()
temp_root = Path(temp_arg).resolve() / check
track_dir = Path(track_dir_arg).resolve()
plan_path = Path(plan_arg).resolve()
temp_root.mkdir(parents=True, exist_ok=True)

ALLOWED_BANDS = {"PRE-A1", "A1", "A2", "B1", "B2", "C1", "C2"}
QUEUE_NAMES = (
    "ambiguous-node-to-entry.jsonl",
    "unmapped-node-to-entry.jsonl",
    "unmatched-gse-entry.jsonl",
    "invalid-cefr-source-data.jsonl",
)
COUNT_LABELS = (
    "Nodes mapped",
    "Levels added",
    "Levels corrected",
    "Conflicts",
    "Unmapped GSE entries queued",
    "GSE entries with no matching node",
)
SOURCE_IDS = {
    "GL": "gse-vocabulary-gl-10-67-2026-08-11",
    "YL": "gse-vocabulary-yl-10-59-2026-08-11",
}
POS_ALIASES = {"phrase": "phrase", "phrasal verb": "phrasal verb"}


class ProbeError(RuntimeError):
    pass


def need(condition, message):
    if not condition:
        raise ProbeError(message)


def load_json(path):
    path = Path(path)
    need(path.is_file(), f"missing JSON output: {path}")
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ProbeError(f"invalid JSON at {path}: {exc}") from exc


def canonical_bytes(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(canonical_bytes(value))


def copy_fixture(label):
    destination = temp_root / f"fixture-{label}"
    if destination.exists():
        shutil.rmtree(destination)
    shutil.copytree(fixture_root, destination)
    return destination


def normalized_form(value):
    return unicodedata.normalize("NFKC", str(value)).strip().casefold()


def normalized_pos(values):
    need(isinstance(values, list), "POS values must be a list")
    result = []
    for value in values:
        need(isinstance(value, str) and value.strip(), "POS values must be non-empty strings")
        lowered = value.strip().casefold()
        result.append(POS_ALIASES.get(lowered, lowered))
    return sorted(set(result))


def cefr_band(value):
    if not isinstance(value, str):
        return None
    result = value.strip().lstrip("<").strip()
    if "(" in result:
        result = result.split("(", 1)[0].strip()
    result = result.rstrip("*").strip().upper()
    return result if result in ALLOWED_BANDS else None


def source_entries():
    records_doc = load_json(fixture_root / "records.json")
    mapping_doc = load_json(fixture_root / "mapping-cases.json")
    mutation_doc = load_json(fixture_root / "mutation-cases.json")
    result = {}
    for row in records_doc.get("records", []):
        record = row.get("record", {})
        if isinstance(record, dict) and isinstance(record.get("itemId"), str):
            result.setdefault(record["itemId"], {}).update(record)
    for case in mapping_doc.get("cases", []):
        for entry in case.get("entries", []):
            if isinstance(entry, dict) and isinstance(entry.get("itemId"), str):
                result.setdefault(entry["itemId"], {}).update(entry)
    for case in mutation_doc.get("cases", []):
        entry = case.get("sourceEntry")
        if isinstance(entry, dict) and isinstance(entry.get("itemId"), str):
            result.setdefault(entry["itemId"], {}).update(entry)
    return result


def mutation_case():
    mutation_doc = load_json(fixture_root / "mutation-cases.json")
    for case_row in mutation_doc.get("cases", []):
        if case_row.get("caseId") == "byte-diff-report-actual-mutation":
            return case_row
    raise ProbeError("byte-diff fixture case is missing")


def source_for(item_id):
    source = source_entries().get(item_id)
    need(isinstance(source, dict), f"fixture source entry is missing for itemId {item_id}")
    return source


def graph_source_for(node_id, item_id):
    if node_id == "fixture:core:afternoon":
        mutation_doc = load_json(fixture_root / "mutation-cases.json")
        for case in mutation_doc.get("cases", []):
            if case.get("caseId") == "mapped-node-source-backed-fields":
                return case.get("sourceEntry")
    if node_id == "fixture:core:you":
        mapping_doc = load_json(fixture_root / "mapping-cases.json")
        for case in mapping_doc.get("cases", []):
            if case.get("caseId") != "ambiguous-binding":
                continue
            for entry in case.get("entries", []):
                if entry.get("itemId") == item_id:
                    return entry
    return source_for(item_id)


def expected_citation(source):
    audience = source.get("audience")
    return {
        "sourceId": SOURCE_IDS.get(audience),
        "itemId": source.get("itemId"),
        "exportSha256": source.get("sourceExportSha256"),
    }


def expected_source_for_case(case_id, item_id):
    mapping_doc = load_json(fixture_root / "mapping-cases.json")
    for case in mapping_doc.get("cases", []):
        if case.get("caseId") != case_id:
            continue
        for entry in case.get("entries", []):
            if entry.get("itemId") == item_id:
                return entry
    return source_for(item_id)


def validate_source_backed_gse(gse, source, label, require_optional_fields=True):
    need(isinstance(gse, dict), f"{label} GSE metadata must be an object")
    allowed = {
        "itemId", "audience", "gseScore", "starred", "temporaryGse",
        "cefrBand", "definition", "example", "sourceCitation",
    }
    extras = sorted(set(gse) - allowed)
    need(not extras, f"{label} has unsupported or inferred GSE fields: {extras}")
    need(gse.get("itemId") == source.get("itemId"), f"{label} itemId is not source-backed")
    need(gse.get("audience") == source.get("audience"), f"{label} audience is not source-backed")
    citation = gse.get("sourceCitation")
    need(isinstance(citation, dict), f"{label} sourceCitation is missing")
    need(citation == expected_citation(source), f"{label} sourceCitation is incomplete or mismatched")

    raw_gse = source.get("gse")
    if raw_gse is None:
        need("gseScore" not in gse, f"{label} invented a missing GSE score")
        need("starred" not in gse, f"{label} invented a starred marker")
    else:
        need(gse.get("gseScore") == raw_gse, f"{label} changed the raw GSE value")
        need(isinstance(gse.get("starred"), bool), f"{label} gseScore lacks boolean starred")
        need(gse.get("starred") is raw_gse.endswith("*"), f"{label} starred value does not match raw GSE")

    if "temporaryGse" in source:
        need(gse.get("temporaryGse") is source.get("temporaryGse"), f"{label} changed temporaryGse")
    else:
        need("temporaryGse" not in gse, f"{label} invented temporaryGse")

    expected_band = cefr_band(source.get("cefr")) if "cefr" in source else None
    if expected_band is None:
        need("cefrBand" not in gse, f"{label} invented or retained an invalid or absent CEFR band")
    else:
        need(gse.get("cefrBand") == expected_band, f"{label} CEFR band is not source-backed")

    for field in ("definition", "example"):
        if field in source:
            if require_optional_fields:
                need(gse.get(field) == source[field], f"{label} {field} is not source-backed")
            elif field in gse:
                need(gse.get(field) == source[field], f"{label} {field} is not source-backed")
        else:
            need(field not in gse, f"{label} invented a {field}")


def output_paths(run):
    output = run["output"]
    return {
        "gl": output / "extraction/gl.json",
        "yl": output / "extraction/yl.json",
        "mapping": output / "mapping/mappings.json",
        "graph": output / "graph/new-graph.json",
        "diff": run["diff"],
        "quality": run["quality"],
        "conflict": run["conflict"],
    }


def make_run(label, fixture=fixture_root, yle_output=False):
    run_root = temp_root / f"run-{label}"
    if run_root.exists():
        shutil.rmtree(run_root)
    run_root.mkdir(parents=True)
    prior = run_root / "prior-graph.json"
    write_json(prior, mutation_case()["priorGraph"])
    queue_root = run_root / "english/cefr-vocabulary/review/gse-vocab/queues"
    queue_root.mkdir(parents=True)
    queues = {name: queue_root / name for name in QUEUE_NAMES}
    for path in queues.values():
        path.touch()
    run = {
        "root": run_root,
        "fixture": Path(fixture),
        "output": run_root / "output",
        "prior": prior,
        "queues": queues,
        "diff": run_root / "reports/byte-diff.json",
        "quality": run_root / "reports/mapping-quality.json",
        "conflict": run_root / "reports/cambridge-gse-cefr-conflicts.jsonl",
        "yle": run_root / "yle-output.json",
    }
    args = [
        "node", str(entrypoint),
        "--fixture-dir", str(Path(fixture).resolve()),
        "--prior-graph", str(prior),
        "--output-dir", str(run["output"]),
    ]
    for name in QUEUE_NAMES:
        args.extend(["--queue-file", f"{name}={queues[name]}"])
    args.extend([
        "--byte-diff-report", str(run["diff"]),
        "--mapping-quality-report", str(run["quality"]),
        "--conflict-report", str(run["conflict"]),
        "--frozen-yle", str(frozen_path),
    ])
    if yle_output:
        args.extend(["--yle-output", str(run["yle"])])
    run["args"] = args
    return run


def run_cli(run):
    if not entrypoint.is_file():
        return subprocess.CompletedProcess(run["args"], 127, "", f"missing Phase 3 implementation: {entrypoint}")
    return subprocess.run(
        run["args"],
        cwd=repo_root,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        timeout=120,
        check=False,
    )


def require_success(result, label):
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip().replace("\n", " ")
        raise ProbeError(f"{label} failed with exit {result.returncode}: {detail[:320]}")


def require_rejection(result, label, tokens):
    detail = f"{result.stdout}\n{result.stderr}".lower()
    need(result.returncode != 0, f"{label} was accepted")
    need(any(token.casefold() in detail for token in tokens), f"{label} failed without a field-specific diagnostic")


def load_mapping(run):
    return load_json(output_paths(run)["mapping"])


def mapping_cases_by_id(document):
    rows = document.get("cases") if isinstance(document, dict) else None
    need(isinstance(rows, list), "mapping output cases must be a list")
    return {row.get("caseId"): row for row in rows if isinstance(row, dict)}


def load_graph(run):
    graph = load_json(output_paths(run)["graph"])
    need(isinstance(graph, dict) and isinstance(graph.get("nodes"), list), "new graph must contain a nodes list")
    return graph


def graph_nodes(graph):
    result = {}
    for node in graph.get("nodes", []):
        need(isinstance(node, dict) and isinstance(node.get("id"), str), "graph node must have a string id")
        result[node["id"]] = node
    return result


def validate_graph_mapped_nodes(graph):
    nodes = graph_nodes(graph)
    for node_id, node in nodes.items():
        metadata = node.get("metadata") or {}
        gse = metadata.get("gse")
        if gse is None:
            continue
        need(isinstance(gse, dict), f"graph node {node_id} GSE metadata must be an object")
        need(isinstance(gse.get("itemId"), str) and gse.get("itemId"), f"graph node {node_id} lacks itemId")
        validate_source_backed_gse(
            gse,
            graph_source_for(node_id, gse["itemId"]),
            f"graph node {node_id}",
            require_optional_fields=True,
        )
    absent = nodes.get("fixture:core:absent")
    if absent is not None:
        need("gse" not in (absent.get("metadata") or {}), "unmapped node received inferred GSE data")


def compare_files(left, right, label):
    left = Path(left)
    right = Path(right)
    need(left.is_file() and right.is_file(), f"{label} output is missing")
    need(left.read_bytes() == right.read_bytes(), f"{label} is not byte-identical across runs")


def byte_delta(left, right):
    return sum(a != b for a, b in zip(left, right)) + abs(len(left) - len(right))


def version(graph):
    if isinstance(graph.get("schemaVersion"), str):
        return graph["schemaVersion"]
    for node in graph.get("nodes", []):
        value = (node.get("metadata") or {}).get("schemaVersion")
        if isinstance(value, str):
            return value
    return None


def diff_counts(prior, current, queue_rows):
    prior_nodes = graph_nodes(prior)
    current_nodes = graph_nodes(current)
    changed = sorted(
        node_id
        for node_id in set(prior_nodes) | set(current_nodes)
        if canonical_bytes(prior_nodes.get(node_id, {})) != canonical_bytes(current_nodes.get(node_id, {}))
    )
    added = 0
    corrected = 0
    conflicts = 0
    for node_id in set(prior_nodes) | set(current_nodes):
        old_gse = (prior_nodes.get(node_id, {}).get("metadata") or {}).get("gse") or {}
        new_gse = (current_nodes.get(node_id, {}).get("metadata") or {}).get("gse") or {}
        old_band = old_gse.get("cefrBand")
        new_band = new_gse.get("cefrBand")
        if old_band is None and new_band is not None:
            added += 1
        if old_band is not None and new_band is not None and old_band != new_band:
            corrected += 1
        cambridge = (current_nodes.get(node_id, {}).get("metadata") or {}).get("cefr")
        if cambridge is not None and new_band is not None and cefr_band(cambridge) != cefr_band(new_band):
            conflicts += 1
    mapped = sum(bool(((node.get("metadata") or {}).get("gse") or {}).get("itemId")) for node in current_nodes.values())
    return {
        "changedNodeIds": changed,
        "Nodes mapped": mapped,
        "Levels added": added,
        "Levels corrected": corrected,
        "Conflicts": conflicts,
        "Unmapped GSE entries queued": len(queue_rows.get("unmappedGseEntriesQueued") or []),
        "GSE entries with no matching node": len(queue_rows.get("gseEntriesWithNoMatchingNode") or []),
    }


def read_jsonl(path):
    path = Path(path)
    need(path.is_file(), f"queue or report file is missing: {path}")
    rows = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.strip():
            rows.append(json.loads(line))
    return rows


def check_contract():
    contract_path = track_dir / "phase3-execution-contract.md"
    text = contract_path.read_text(encoding="utf-8") if contract_path.is_file() else ""
    need("--fixture-dir" in text and "--queue-file" in text, "Phase 3 execution contract lacks the live command interface")
    need("extraction/gl.json" in text and "graph/new-graph.json" in text, "Phase 3 execution contract lacks output paths")
    need("mapping-quality-report" in text and "frozen YLE artifact remains unchanged" in text, "Phase 3 execution contract lacks report and freeze rules")


def check_plan_state():
    need(plan_path.is_file(), f"missing track plan: {plan_path}")
    text = plan_path.read_text(encoding="utf-8")
    match = re.search(
        r"^## Phase 3: Extraction, Mapping, And Core Mutation\s*$\n?(.*?)(?=^## Phase 4:|\Z)",
        text,
        re.IGNORECASE | re.MULTILINE | re.DOTALL,
    )
    need(match is not None, "exact Phase 3 heading is missing")
    phase = match.group(1)
    task_rows = re.findall(r"^([ \t]*)- \[([~xb ])\] (.+)$", phase, re.MULTILINE)
    need(task_rows, "Phase 3 has no task markers")
    invalid_rows = [row for row in task_rows if row[1] not in ("~", "x")]
    if invalid_rows:
        raise ProbeError(f"Phase 3 contains unsupported marker [{invalid_rows[0][1]}]")
    statuses = [status for _indent, status, _description in task_rows]
    if all(status == "~" for status in statuses):
        return
    if all(status == "x" for status in statuses):
        top_level = [
            description
            for indent, _status, description in task_rows
            if not indent
        ]
        need(top_level, "Phase 3 has no completed top-level tasks")
        commit_pattern = re.compile(r"\bcommit(?:s)?\s*:\s*[0-9a-f]{7,40}\b", re.IGNORECASE)
        missing_sha = [description for description in top_level if commit_pattern.search(description) is None]
        if missing_sha:
            raise ProbeError(f"completed Phase 3 task lacks commit SHA evidence: {missing_sha[0]}")
        return
    need(False, "Phase 3 markers must be all [~] Red or all [x] Green")


def check_extraction():
    first = make_run("extract-first")
    second = make_run("extract-second")
    require_success(run_cli(first), "first extractor run")
    require_success(run_cli(second), "second extractor run")
    paths_first = output_paths(first)
    paths_second = output_paths(second)
    compare_files(paths_first["gl"], paths_second["gl"], "GL extraction")
    compare_files(paths_first["yl"], paths_second["yl"], "YL extraction")
    records = load_json(fixture_root / "records.json").get("records", [])
    by_item = {}
    for row in records:
        record = row.get("record", {})
        by_item[record.get("itemId")] = record
    for audience in ("GL", "YL"):
        output = load_json(paths_first["gl"] if audience == "GL" else paths_first["yl"])
        need(output.get("audience") == audience, f"{audience} extraction has the wrong audience")
        output_rows = {row.get("itemId"): row for row in output.get("records", []) if isinstance(row, dict)}
        expected_rows = [row for row in by_item.values() if row.get("audience") == audience]
        for source in expected_rows:
            actual = output_rows.get(source.get("itemId"))
            need(isinstance(actual, dict), f"{audience} extraction omitted {source.get('itemId')}")
            for field in ("itemId", "expression", "audience", "gse", "grammaticalCategories"):
                need(actual.get(field) == source.get(field), f"{audience} extraction changed raw {field}")
            if "cefr" in source:
                need(actual.get("cefr") == source.get("cefr"), f"{audience} extraction changed raw cefr")
            if "expression_bre" in source:
                need(actual.get("expression_bre") == source.get("expression_bre"), f"{audience} extraction changed expression_bre")
            if "temporaryGse" in source:
                need(actual.get("temporaryGse") is source.get("temporaryGse"), f"{audience} extraction changed temporaryGse")
            if isinstance(source.get("gse"), str) and source["gse"].endswith("*"):
                need(actual.get("gse") == source["gse"] and actual.get("starred") is True, "starred GL gse lost its raw marker")


def check_mapping():
    run = make_run("mapping")
    require_success(run_cli(run), "mapping run")
    document = load_mapping(run)
    cases = mapping_cases_by_id(document)
    source_doc = load_json(fixture_root / "mapping-cases.json")
    source_cases = {row.get("caseId"): row for row in source_doc.get("cases", [])}
    for case_id in ("multi-pos-expression", "cambridge-gse-level-conflict", "same-form-different-pos-falsifier", "absent-optional-cefr"):
        expected_case = source_cases[case_id]
        actual = cases.get(case_id)
        need(isinstance(actual, dict), f"mapping output omitted {case_id}")
        node = expected_case.get("node") or {}
        entries = expected_case.get("entries") or []
        entry = entries[0] if entries else None
        need(actual.get("outcome") == expected_case.get("expected", {}).get("outcome", "mapped"), f"mapping outcome is wrong for {case_id}")
        need(actual.get("nodeId") == node.get("nodeId"), f"mapping nodeId is wrong for {case_id}")
        need(actual.get("normalizedForm") == normalized_form(node.get("normalizedForm")), f"mapping form is wrong for {case_id}")
        need(actual.get("normalizedPartsOfSpeech") == normalized_pos(node.get("partsOfSpeech")), f"mapping POS set is wrong for {case_id}")
        selected_item_id = expected_case.get("expected", {}).get("itemId", entry.get("itemId"))
        need(actual.get("itemId") == selected_item_id, f"mapping itemId is wrong for {case_id}")
        selected_entry = next((candidate for candidate in entries if candidate.get("itemId") == selected_item_id), entry)
        need(actual.get("audience") == node.get("audience") == selected_entry.get("audience"), f"mapping audience parity is wrong for {case_id}")
        need(actual.get("normalizedForm") == normalized_form(selected_entry.get("expression")), f"mapping form does not equal the selected entry for {case_id}")
        need(actual.get("normalizedPartsOfSpeech") == normalized_pos(selected_entry.get("grammaticalCategories")), f"mapping POS set does not equal the selected entry for {case_id}")
        validate_source_backed_gse(actual.get("nodeMetadataGse"), selected_entry, f"mapping case {case_id}", require_optional_fields=False)

    temporary_fixture = copy_fixture("cross-audience")
    mapping_path = temporary_fixture / "mapping-cases.json"
    mapping_doc = load_json(mapping_path)
    for row in mapping_doc.get("cases", []):
        if row.get("caseId") == "multi-pos-expression":
            row["node"]["audience"] = "YL"
            break
    write_json(mapping_path, mapping_doc)
    negative = make_run("cross-audience", temporary_fixture)
    result = run_cli(negative)
    require_rejection(result, "cross-audience multi-POS mapping", ("audience", "exact"))


def check_citations_and_no_inference():
    run = make_run("citations")
    require_success(run_cli(run), "citation run")
    mapping = load_mapping(run)
    source_doc = load_json(fixture_root / "mapping-cases.json")
    source_cases = {row.get("caseId"): row for row in source_doc.get("cases", [])}
    for row in mapping.get("cases", []):
        gse = row.get("nodeMetadataGse")
        if isinstance(gse, dict):
            expected_case = source_cases.get(row.get("caseId"), {})
            expected_entry = next((candidate for candidate in expected_case.get("entries", []) if candidate.get("itemId") == row.get("itemId")), None)
            validate_source_backed_gse(
                gse,
                expected_entry or expected_source_for_case(row.get("caseId"), row.get("itemId")),
                f"mapped output {row.get('caseId')}",
                require_optional_fields=False,
            )
        elif row.get("outcome") in ("mapped", "invalid-cefr-source-data"):
            raise ProbeError(f"mapped output {row.get('caseId')} lacks GSE metadata")
        else:
            need("nodeMetadataGse" not in row, f"unmapped output {row.get('caseId')} contains inferred GSE metadata")
    graph = load_graph(run)
    validate_graph_mapped_nodes(graph)
    invalid = next(row for row in mapping.get("cases", []) if row.get("caseId") == "invalid-cefr-source-data")
    absent = next(row for row in mapping.get("cases", []) if row.get("caseId") == "absent-optional-cefr")
    need("cefrBand" not in invalid.get("nodeMetadataGse", {}), "invalid CEFR output invented a band")
    need("cefrBand" not in absent.get("nodeMetadataGse", {}), "absent optional CEFR output invented a band")
    need("definition" not in absent.get("nodeMetadataGse", {}), "absent source definition was invented")
    need("example" not in absent.get("nodeMetadataGse", {}), "absent source example was invented")
    mutation_doc = load_json(fixture_root / "mutation-cases.json")
    mapped_mutation = next(row for row in mutation_doc.get("cases", []) if row.get("caseId") == "mapped-node-source-backed-fields")
    validate_source_backed_gse(
        mapped_mutation.get("expected", {}).get("nodeMetadataGse"),
        mapped_mutation.get("sourceEntry"),
        "mapped mutation fixture",
    )


def check_queues():
    run = make_run("queues")
    require_success(run_cli(run), "queue run")
    mapping = load_mapping(run)
    mapping_cases = mapping_cases_by_id(mapping)
    need(mapping_cases.get("ambiguous-binding", {}).get("outcome") == "ambiguous", "ambiguous mapping outcome is missing")
    need(mapping_cases.get("unmapped-core-node", {}).get("outcome") == "unmapped", "unmapped mapping outcome is missing")
    need(mapping_cases.get("unmatched-gse-entry", {}).get("outcome") == "unmatched-gse-entry", "unmatched mapping outcome is missing")
    need(mapping_cases.get("invalid-cefr-source-data", {}).get("outcome") == "invalid-cefr-source-data", "invalid CEFR mapping outcome is missing")
    need(mapping_cases.get("absent-optional-cefr", {}).get("outcome") == "mapped", "absent optional CEFR mapping outcome is not mapped")
    invalid_case = mapping_cases.get("invalid-cefr-source-data", {})
    invalid_gse = invalid_case.get("nodeMetadataGse") or {}
    need("cefrBand" not in invalid_gse, "invalid CEFR mapping output contains a band")
    absent_case = mapping_cases.get("absent-optional-cefr", {})
    need("cefrBand" not in (absent_case.get("nodeMetadataGse") or {}), "absent optional CEFR mapping output contains a band")
    for case_id in ("ambiguous-binding", "unmapped-core-node", "unmatched-gse-entry"):
        need("nodeMetadataGse" not in mapping_cases.get(case_id, {}), f"{case_id} received inferred GSE metadata")
    queue_files = mapping.get("queueFiles")
    need(set(queue_files or []) == set(QUEUE_NAMES), "mapping output does not name all four queue files")
    need(all("english/cefr-vocabulary/review/gse-vocab/queues" in str(path) for path in run["queues"].values()), "queue paths are not track-local")
    rows = {name: read_jsonl(path) for name, path in run["queues"].items()}
    ambiguous = next((row for row in rows["ambiguous-node-to-entry.jsonl"] if row.get("reason") == "multiple-exact-candidates"), None)
    need(isinstance(ambiguous, dict), "ambiguous case lacks a durable queue row")
    need(set(ambiguous) == {"nodeId", "normalizedForm", "audience", "normalizedPartsOfSpeech", "candidateItemIds", "reason", "sourceExportSha256"}, "ambiguous queue row has the wrong fields")
    need(ambiguous.get("nodeId") == "fixture:core:you" and ambiguous.get("normalizedForm") == "you" and ambiguous.get("audience") == "GL", "ambiguous queue row loses node identity")
    need(ambiguous.get("normalizedPartsOfSpeech") == ["pronoun"] and len(ambiguous.get("candidateItemIds", [])) == 2, "ambiguous queue row loses candidate identity")
    unmapped = next((row for row in rows["unmapped-node-to-entry.jsonl"] if row.get("reason") == "no-exact-candidate"), None)
    need(isinstance(unmapped, dict), "unmapped case lacks a durable queue row")
    need(set(unmapped) == {"nodeId", "normalizedForm", "audience", "normalizedPartsOfSpeech", "reason", "sourceExportSha256"}, "unmapped queue row has the wrong fields")
    need(unmapped.get("nodeId") == "fixture:core:absent" and unmapped.get("normalizedForm") == "fixture-absent", "unmapped queue row loses node identity")
    unmatched = next((row for row in rows["unmatched-gse-entry.jsonl"] if row.get("reason") == "no-exact-node"), None)
    need(isinstance(unmatched, dict), "unmatched case lacks a durable queue row")
    need(set(unmatched) == {"itemId", "expression", "audience", "normalizedGrammaticalCategories", "reason", "sourceExportSha256"}, "unmatched queue row has the wrong fields")
    need(unmatched.get("itemId") == "ue5509a518e6b3efa.72421137.1585960e44b.18a6" and unmatched.get("expression") == "to", "unmatched queue row loses source identity")
    invalid_rows = rows["invalid-cefr-source-data.jsonl"]
    need(any(row.get("reason") == "invalid-cefr-band" and set(row) == {"nodeId", "itemId", "audience", "rawCefr", "reason", "sourceExportSha256"} for row in invalid_rows), "invalid CEFR case lacks its complete durable row")
    invalid_row = next(row for row in invalid_rows if row.get("reason") == "invalid-cefr-band")
    need(invalid_row.get("nodeId") == "fixture:core:uncle-invalid-cefr", "invalid CEFR queue row loses node identity")
    need(invalid_row.get("itemId") == "ua8444abd28d0e715.-5299d1a3.145b71d3748.-2882", "invalid CEFR queue row loses item identity")
    need(invalid_row.get("rawCefr") == "A2+ (36-42)", "invalid CEFR queue row does not preserve raw CEFR")
    need(not any(row.get("itemId") == "synthetic:absent-optional-cefr" for row in invalid_rows), "absent optional CEFR created an invalid-data queue row")


def check_conflict():
    run = make_run("conflict")
    require_success(run_cli(run), "conflict run")
    graph = load_graph(run)
    nodes = graph_nodes(graph)
    node = nodes.get("fixture:core:you")
    need(isinstance(node, dict), "conflict graph node is missing")
    metadata = node.get("metadata") or {}
    need(metadata.get("cefr") == "<A1", "Cambridge CEFR evidence was overwritten")
    need((metadata.get("gse") or {}).get("cefrBand") == "A2", "GSE conflict band is missing")
    report_rows = read_jsonl(run["conflict"])
    need(any(
        row.get("nodeId") == "fixture:core:you"
        and row.get("itemId") == "ua8444abd28d0e715.-5299d1a3.145b71d3748.46f8"
        and row.get("audience") == "GL"
        and row.get("cambridgeCefr") == "<A1"
        and row.get("cambridgeCefrAlignments") == ["A1"]
        and row.get("gseCefrBand") == "A2"
        and row.get("reason") == "cambridge-gse-cefr-disagreement"
        and row.get("sourceExportSha256") == "e63298d796eecc1d9ed68cd5bde28d01912cfe3312a1381d2b074cdbe9b90800"
        for row in report_rows
    ), "Cambridge-GSE conflict report lacks both values")


def check_diff_and_graph_rules():
    run = make_run("diff")
    require_success(run_cli(run), "byte-diff run")
    mutation = mutation_case()
    prior = mutation["priorGraph"]
    current = load_graph(run)
    expected = mutation["expected"]
    report = load_json(run["diff"])
    graph_path = output_paths(run)["graph"]
    actual_prior_bytes = canonical_bytes(prior)
    actual_new_bytes = canonical_bytes(current)
    need(graph_path.read_bytes() == actual_new_bytes, "new graph file is not canonical JSON")
    need(hashlib.sha256(actual_prior_bytes).hexdigest() == expected["priorSha256"], "fixture prior graph hash is not canonical")
    need(hashlib.sha256(actual_new_bytes).hexdigest() == expected["newSha256"], "new graph bytes do not match the source-backed fixture mutation")
    need(report.get("priorSha256") == hashlib.sha256(actual_prior_bytes).hexdigest(), "byte-diff report prior SHA does not match actual bytes")
    need(report.get("newSha256") == hashlib.sha256(actual_new_bytes).hexdigest(), "byte-diff report new SHA does not match actual bytes")
    need(report.get("bytesChanged") == byte_delta(actual_prior_bytes, actual_new_bytes), "byte-diff report byte count is wrong")
    need(report.get("changedNodeIds") == expected["changedNodeIds"], "byte-diff changed node IDs are wrong")
    queue_rows = {
        "unmappedGseEntriesQueued": read_jsonl(run["queues"]["unmapped-node-to-entry.jsonl"]),
        "gseEntriesWithNoMatchingNode": read_jsonl(run["queues"]["unmatched-gse-entry.jsonl"]),
    }
    counts = diff_counts(prior, current, queue_rows)
    need(report.get("diffCounts") == {label: counts[label] for label in COUNT_LABELS}, "byte-diff labelled counts do not match actual mutation")
    need(version(current) != version(prior), "new core graph version did not change")
    need(re.fullmatch(r"gse-vocab-[0-9]{8}-r[0-9]{2}", str(version(current))), "new core graph version has the wrong format")
    need(not any(edge.get("type") == "prerequisite_for" for edge in current.get("edges", [])), "new graph contains a prerequisite_for edge")
    need(not any(edge.get("type") == "prerequisite_for" for edge in prior.get("edges", [])), "prior graph contains a prerequisite_for edge")
    validate_graph_mapped_nodes(current)


def check_mutation_determinism():
    first = make_run("mutation-first")
    second = make_run("mutation-second")
    require_success(run_cli(first), "first mutation run")
    require_success(run_cli(second), "second mutation run")
    first_paths = output_paths(first)
    second_paths = output_paths(second)
    for label in ("gl", "yl", "mapping", "graph", "diff", "quality", "conflict"):
        compare_files(first_paths[label], second_paths[label], f"{label} mutation output")
    for name in QUEUE_NAMES:
        compare_files(first["queues"][name], second["queues"][name], f"{name} queue")


def check_yle_isolation():
    need(frozen_path.is_file(), "tracked frozen YLE artifact is missing")
    tracked = subprocess.run(
        ["git", "-C", str(repo_root), "ls-files", "--error-unmatch", "--", "english/cefr-vocabulary/cefr-vocabulary-knowledge-space.json"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    need(tracked.returncode == 0 and tracked.stdout.strip() == "english/cefr-vocabulary/cefr-vocabulary-knowledge-space.json", "frozen YLE artifact is not git-tracked")
    frozen_before = hashlib.sha256(frozen_path.read_bytes()).hexdigest()
    before_fixture = copy_fixture("yle-before")
    after_fixture = copy_fixture("yle-after")
    records_path = after_fixture / "records.json"
    records_doc = load_json(records_path)
    records_doc["records"][1]["record"]["gse"] = "20*"
    write_json(records_path, records_doc)
    need(before_fixture.joinpath("records.json").read_bytes() != after_fixture.joinpath("records.json").read_bytes(), "YLE proof did not apply a GSE fixture mutation")
    before = make_run("yle-before", before_fixture, yle_output=True)
    after = make_run("yle-after", after_fixture, yle_output=True)
    before["args"].extend(["--run-label", "before", "--mutation-applied-between-runs"])
    after["args"].extend(["--run-label", "after", "--mutation-applied-between-runs"])
    require_success(run_cli(before), "YLE before run")
    require_success(run_cli(after), "YLE after run")
    compare_files(before["yle"], after["yle"], "same-procedure temporary YLE output")
    need(before["yle"].stat().st_size > 0, "YLE before artifact is empty")
    need(after["yle"].stat().st_size > 0, "YLE after artifact is empty")
    frozen_after = hashlib.sha256(frozen_path.read_bytes()).hexdigest()
    need(frozen_before == frozen_after, "tracked frozen YLE artifact changed during the proof")


def check_queue_isolation():
    clean = make_run("queue-clean")
    poisoned = make_run("queue-poisoned")
    require_success(run_cli(clean), "clean queue run")
    foreign = poisoned["root"] / "english/cefr-vocabulary/review/gse-vocab/queues/foreign.jsonl"
    foreign.write_text('{"reason":"foreign-queue-poison"}\n', encoding="utf-8")
    require_success(run_cli(poisoned), "explicit queue run")
    clean_paths = output_paths(clean)
    poisoned_paths = output_paths(poisoned)
    for label in ("mapping", "graph", "diff", "quality", "conflict"):
        compare_files(clean_paths[label], poisoned_paths[label], f"{label} with foreign queue")
    for name in QUEUE_NAMES:
        compare_files(clean["queues"][name], poisoned["queues"][name], f"{name} with foreign queue")
    for path in (poisoned_paths["mapping"], poisoned_paths["diff"], poisoned_paths["quality"], poisoned_paths["conflict"]):
        need(b"foreign-queue-poison" not in Path(path).read_bytes(), f"foreign queue changed {path.name}")


def check_quality_report():
    run = make_run("quality")
    require_success(run_cli(run), "mapping quality run")
    quality = load_json(run["quality"])
    diff = load_json(run["diff"])
    need(set(quality.get("counts", {})) == set(COUNT_LABELS), "mapping quality report lacks a required labelled count")
    for label in COUNT_LABELS:
        value = quality["counts"].get(label)
        need(isinstance(value, int) and not isinstance(value, bool), f"mapping quality count {label} is not an integer")
        need(value == diff.get("diffCounts", {}).get(label), f"mapping quality count {label} differs from byte diff")
    need(set(quality.get("queueFiles", [])) == set(QUEUE_NAMES), "mapping quality report does not name the four queue files")


def validate_output(path, fixture):
    args = ["node", str(entrypoint), "--validate-output", str(path), "--fixture-dir", str(fixture)]
    if not entrypoint.is_file():
        return subprocess.CompletedProcess(args, 127, "", f"missing Phase 3 implementation: {entrypoint}")
    return subprocess.run(
        args,
        cwd=repo_root,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        timeout=120,
        check=False,
    )


def check_rejection():
    malformed_fixture = copy_fixture("malformed-input")
    negative = load_json(fixture_root / "negative-cases.json")
    malformed = next(row for row in negative["cases"] if row.get("caseId") == "malformed-record-missing-item-id")
    records_path = malformed_fixture / "records.json"
    records = load_json(records_path)
    records["records"][0]["record"] = malformed["record"]
    write_json(records_path, records)
    malformed_run = make_run("malformed-input", malformed_fixture)
    malformed_result = run_cli(malformed_run)
    if entrypoint.is_file():
        require_rejection(malformed_result, "malformed source record", ("itemId",))
    else:
        need(malformed_result.returncode == 127, "missing Phase 3 implementation did not fail the malformed-input probe")

    valid_run = make_run("malformed-output")
    require_success(run_cli(valid_run), "output validation setup")
    graph = load_graph(valid_run)
    nodes = graph_nodes(graph)
    nodes["fixture:core:afternoon"]["metadata"]["gse"].pop("itemId", None)
    missing_item = temp_root / "malformed-output-no-item-id.json"
    write_json(missing_item, graph)
    require_rejection(validate_output(missing_item, fixture_root), "output without itemId", ("itemid", "sourcecitation"))

    graph = load_graph(valid_run)
    nodes = graph_nodes(graph)
    nodes["fixture:core:afternoon"]["metadata"]["gse"].pop("sourceCitation", None)
    missing_citation = temp_root / "malformed-output-no-citation.json"
    write_json(missing_citation, graph)
    require_rejection(validate_output(missing_citation, fixture_root), "output without source citation", ("sourcecitation", "citation"))

    graph = load_graph(valid_run)
    nodes = graph_nodes(graph)
    nodes["fixture:core:you"]["metadata"]["gse"]["definition"] = "invented fixture text"
    inferred_text = temp_root / "malformed-output-inferred-text.json"
    write_json(inferred_text, graph)
    require_rejection(validate_output(inferred_text, fixture_root), "output with invented definition", ("definition", "source"))

    graph = load_graph(valid_run)
    nodes = graph_nodes(graph)
    absent_node = nodes.setdefault("fixture:core:absent", {"id": "fixture:core:absent", "metadata": {}})
    absent_node.setdefault("metadata", {})["gse"] = {
        "itemId": "ua8444abd28d0e715.-5299d1a3.145b71d3748.46f2",
        "audience": "GL",
        "gseScore": "11",
        "starred": False,
        "sourceCitation": expected_citation(source_for("ua8444abd28d0e715.-5299d1a3.145b71d3748.46f2")),
    }
    inferred_score = temp_root / "malformed-output-inferred-score.json"
    write_json(inferred_score, graph)
    require_rejection(validate_output(inferred_score, fixture_root), "output with inferred unmapped score", ("unmapped", "node", "mapping"))


checks = {
    "contract": check_contract,
    "plan-state": check_plan_state,
    "extraction": check_extraction,
    "mapping": check_mapping,
    "citations": check_citations_and_no_inference,
    "queues": check_queues,
    "conflict": check_conflict,
    "diff": check_diff_and_graph_rules,
    "mutation-determinism": check_mutation_determinism,
    "yle-isolation": check_yle_isolation,
    "queue-isolation": check_queue_isolation,
    "quality": check_quality_report,
    "rejection": check_rejection,
}

if check not in checks:
    raise SystemExit(f"unknown Phase 3 probe: {check}")
try:
    checks[check]()
except (OSError, StopIteration, KeyError, TypeError, ValueError, ProbeError) as exc:
    print(str(exc), file=sys.stderr)
    raise SystemExit(1)
print(f"Phase 3 probe passed: {check}")
PY
}

echo "=== Phase 3 execution contract defines a live test interface ==="
if probe contract; then
  pass "Phase 3 execution contract defines the live command and output paths"
else
  fail "Phase 3 execution contract is missing a testable live interface"
fi

echo "=== GL and YL extraction is deterministic and preserves raw source markers ==="
if probe extraction; then
  pass "consecutive GL and YL extraction outputs are byte-identical and source markers remain raw"
else
  fail "deterministic GL/YL extraction or raw marker preservation is missing"
fi

echo "=== Phase 3 plan markers obey the Red and Green state contract ==="
if probe plan-state; then
  pass "Phase 3 uses a complete Red or Green marker state with required SHA evidence"
else
  fail "Phase 3 plan markers do not describe a complete Red or Green state"
fi

echo "=== mapping requires exact form, normalized POS set, audience parity, and cross-audience rejection ==="
if probe mapping; then
  pass "mapped cases use exact form, POS set, audience, and reject cross-audience multi-POS input"
else
  fail "mapping identity or the cross-audience falsifier failed"
fi

echo "=== mapped graph nodes carry complete citations and no inferred fields ==="
if probe citations; then
  pass "mapped nodes carry source citations and absent source fields remain absent"
else
  fail "mapped node citations or no-inference validation failed"
fi

echo "=== durable queues cover ambiguous, unmapped, unmatched, and invalid CEFR cases ==="
if probe queues; then
  pass "all four track-local queues persist required rows and absent optional CEFR creates no row"
else
  fail "durable queue behavior or optional CEFR handling is missing"
fi

echo "=== Cambridge and GSE conflict evidence remains visible ==="
if probe conflict; then
  pass "conflict output keeps Cambridge data and records the GSE disagreement"
else
  fail "Cambridge-GSE conflict evidence is missing or overwritten"
fi

echo "=== byte diff, version bump, source-backed newGraph validation, and graph edge rules are live ==="
if probe diff; then
  pass "byte diff matches canonical graph bytes, the version changes, and prerequisite_for stays absent"
else
  fail "core mutation, byte diff, source-backed newGraph validation, or graph edge rules are missing"
fi

echo "=== two core mutation runs are byte-identical ==="
if probe mutation-determinism; then
  pass "two core mutation runs produce byte-identical graph, reports, and queues"
else
  fail "core mutation output is not deterministic"
fi

echo "=== same-procedure YLE isolation preserves the tracked frozen artifact ==="
if probe yle-isolation; then
  pass "temporary before and after YLE outputs match and the frozen artifact stays unchanged"
else
  fail "same-procedure YLE isolation or frozen-artifact preservation is missing"
fi

echo "=== explicit queue inputs isolate reports from foreign queues ==="
if probe queue-isolation; then
  pass "explicit queue files prevent foreign queue influence"
else
  fail "foreign queue input changes a report or queue result"
fi

echo "=== mapping quality report carries six labelled integer counts ==="
if probe quality; then
  pass "mapping quality counts match the byte-diff counts and name each queue"
else
  fail "mapping quality report counts or queue labels are missing"
fi

echo "=== malformed input and output without item citations are rejected ==="
if probe rejection; then
  pass "malformed source and citation-free output fail with field-specific diagnostics"
else
  fail "malformed input or citation-free output was accepted"
fi

echo "=== results ==="
printf '%s\n' "${RESULTS[@]}"
echo "=== Total: $((PASS_COUNT + FAIL_COUNT)) checks (PASS=$PASS_COUNT, FAIL=$FAIL_COUNT) ==="
exit "$FAILED"
