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
PLAN="${GSE_VOCAB_P2_PLAN:-$TRACK_DIR/plan.md}"
FIX="${GSE_VOCAB_P2_FIXTURE_DIR:-$ROOT/english/cefr-vocabulary/fixtures/gse-vocab}"

# Mid-Red uses this temporary plan mutation to prove that completed work needs
# commit evidence. It never changes the tracked plan or fixture pack.
if [[ "${GSE_VOCAB_P2_NEGATIVE:-}" == "completed-without-sha" ]]; then
  NEGATIVE_TMP_ROOT="${TMPDIR:-}"
  if [[ -z "$NEGATIVE_TMP_ROOT" && -d /dev/shm && -w /dev/shm ]]; then
    NEGATIVE_TMP_ROOT=/dev/shm
  elif [[ -z "$NEGATIVE_TMP_ROOT" ]]; then
    NEGATIVE_TMP_ROOT=/tmp
  fi
  NEGATIVE_PLAN="$(mktemp "$NEGATIVE_TMP_ROOT/gse-vocab-p2-plan.XXXXXX")"
  trap 'rm -f -- "$NEGATIVE_PLAN"' EXIT
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
    r"(^## Phase 2: Tests And Fixtures\s*$)(.*?)(?=^## Phase 3:|\Z)",
    text,
    re.MULTILINE | re.DOTALL | re.IGNORECASE,
)
if phase is None:
    raise SystemExit("Phase 2 section is missing from the temporary plan")

task_pattern = re.compile(r"^([ \t]*- )[\[\]~xb ]+\s+(.+)$", re.MULTILINE)
task_number = 0


def rewrite(match):
    global task_number
    task_number += 1
    description = re.sub(
        r"\s+-\s+commit:\s*[0-9a-f]{7,40}\b[.,]?",
        "",
        match.group(2),
        flags=re.IGNORECASE,
    ).rstrip()
    if task_number > 1:
        description += " - commit: 9ef2832"
    return f"{match.group(1)}[x] {description}"


rewritten_phase = task_pattern.sub(rewrite, phase.group(0))
if task_number == 0:
    raise SystemExit("Phase 2 has no task markers in the temporary plan")
path.write_text(text[: phase.start()] + rewritten_phase + text[phase.end() :], encoding="utf-8")
PY
  PLAN="$NEGATIVE_PLAN"
elif [[ -n "${GSE_VOCAB_P2_NEGATIVE:-}" ]]; then
  printf 'unknown GSE_VOCAB_P2_NEGATIVE mode: %s\n' "$GSE_VOCAB_P2_NEGATIVE" >&2
  exit 2
fi

probe() {
  local check="$1"
  python3 - "$FIX" "$check" "$PLAN" <<'PY'
import hashlib
import json
import re
import sys
from pathlib import Path

fixture_root = Path(sys.argv[1])
check = sys.argv[2]
errors = []
allowed_bands = {"PRE-A1", "A1", "A2", "B1", "B2", "C1", "C2"}
pos_aliases = {
    "phrasal verb": "phrasal verb",
    "phrase": "phrase",
}


def add_error(message):
    errors.append(message)


def load_json(name):
    path = fixture_root / name
    if not path.is_file():
        add_error(f"missing fixture file: {path}")
        return None
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        add_error(f"invalid JSON in {path}: {exc}")
        return None
    if not isinstance(value, dict):
        add_error(f"fixture root must be an object: {path}")
        return None
    return value


def need(condition, message):
    if not condition:
        add_error(message)


def band(raw):
    if not isinstance(raw, str):
        return None
    value = raw.strip().lstrip("<").strip()
    value = re.sub(r"\s*\([^)]*\)\s*\*?$", "", value)
    value = value.rstrip("*").strip().upper()
    return value if value in allowed_bands else None


def normalized_pos(values):
    if not isinstance(values, list):
        return []
    result = []
    for value in values:
        if not isinstance(value, str) or not value.strip():
            return []
        lowered = value.strip().casefold()
        result.append(pos_aliases.get(lowered, lowered))
    return sorted(set(result))


def manifest_and_files():
    manifest = load_json("manifest.json")
    if manifest is None:
        return None
    need(manifest.get("schemaVersion") == 1, "manifest schemaVersion must be 1")
    need(manifest.get("fixturePack") == "gse-vocabulary-phase2", "manifest fixturePack is wrong")
    exports = manifest.get("sourceExports")
    need(isinstance(exports, dict), "manifest sourceExports must be an object")
    expected_exports = {
        "GL": {
            "file": "gse-vocabulary-gl-10-67-2026-08-11.json",
            "sha256": "e63298d796eecc1d9ed68cd5bde28d01912cfe3312a1381d2b074cdbe9b90800",
        },
        "YL": {
            "file": "gse-vocabulary-yl-10-59-2026-08-11.json",
            "sha256": "6b8c895055ea6c24c8f29b9e2999676444ffe3507a61725a9595f6eab784ab30",
        },
    }
    for audience, expected in expected_exports.items():
        value = exports.get(audience) if isinstance(exports, dict) else None
        need(isinstance(value, dict), f"manifest source export {audience} must be an object")
        if isinstance(value, dict):
            need(value.get("file") == expected["file"], f"manifest {audience} source file is wrong")
            need(value.get("sha256") == expected["sha256"], f"manifest {audience} source hash is not the pinned export hash")
            digest = value.get("sha256")
            need(isinstance(digest, str) and re.fullmatch(r"[0-9a-f]{64}", digest) is not None, f"manifest {audience} SHA-256 is not a full hex digest")
            need(value.get("audience") == audience, f"manifest source audience does not match {audience}")
    expected_counts = manifest.get("expectedCounts")
    required_counts = {
        "GL items": 11586,
        "YL items": 3024,
        "starred GL gse": 70,
        "YL temporaryGse": 129,
    }
    need(isinstance(expected_counts, dict), "manifest expectedCounts must be an object")
    if isinstance(expected_counts, dict):
        for label, expected in required_counts.items():
            need(expected_counts.get(label) == expected, f"manifest count {label} must be {expected}")
        print(f"GL items: {expected_counts.get('GL items')}")
        print(f"YL items: {expected_counts.get('YL items')}")
        print(f"starred GL gse: {expected_counts.get('starred GL gse')}")
        print(f"YL temporaryGse: {expected_counts.get('YL temporaryGse')}")
    files = manifest.get("fixtures")
    required_files = {
        "records": "records.json",
        "mapping": "mapping-cases.json",
        "mutation": "mutation-cases.json",
        "determinism": "determinism.json",
        "negative": "negative-cases.json",
    }
    need(isinstance(files, dict), "manifest fixtures must be an object")
    if isinstance(files, dict):
        for key, filename in required_files.items():
            need(files.get(key) == filename, f"manifest fixture path for {key} is wrong")
            path = fixture_root / filename
            need(path.is_file(), f"manifest fixture file is absent for {key}: {path}")
    return manifest


def source_hashes(manifest):
    exports = manifest.get("sourceExports") if isinstance(manifest, dict) else {}
    return {
        audience: (exports.get(audience) or {}).get("sha256")
        for audience in ("GL", "YL")
    }


def records_by_id(records_doc):
    rows = records_doc.get("records") if isinstance(records_doc, dict) else None
    need(isinstance(rows, list) and rows, "records fixture must contain a non-empty records list")
    result = {}
    if not isinstance(rows, list):
        return result
    for row in rows:
        if not isinstance(row, dict):
            add_error("record fixture row must be an object")
            continue
        case_id = row.get("caseId")
        need(isinstance(case_id, str) and case_id.strip(), "record fixture row needs a caseId")
        if isinstance(case_id, str) and case_id in result:
            add_error(f"duplicate record fixture caseId: {case_id}")
        elif isinstance(case_id, str):
            result[case_id] = row
    return result


def entry_shape(entry, label, hashes):
    need(isinstance(entry, dict), f"{label} must be an object")
    if not isinstance(entry, dict):
        return
    for field in ("itemId", "expression", "audience", "gse", "cefr", "sourceExportSha256"):
        need(isinstance(entry.get(field), str) and entry.get(field).strip(), f"{label} lacks source field {field}")
    audience = entry.get("audience")
    need(audience in ("GL", "YL"), f"{label} audience must be GL or YL")
    if audience in hashes:
        need(entry.get("sourceExportSha256") == hashes[audience], f"{label} source hash does not match its audience")
    categories = entry.get("grammaticalCategories")
    need(isinstance(categories, list) and all(isinstance(value, str) and value.strip() for value in categories), f"{label} grammaticalCategories must be a non-empty string list")


def mapping_cases(mapping_doc, hashes):
    rows = mapping_doc.get("cases") if isinstance(mapping_doc, dict) else None
    need(isinstance(rows, list) and rows, "mapping fixture must contain a non-empty cases list")
    result = {}
    if not isinstance(rows, list):
        return result
    for case in rows:
        if not isinstance(case, dict):
            add_error("mapping fixture case must be an object")
            continue
        case_id = case.get("caseId")
        need(isinstance(case_id, str) and case_id.strip(), "mapping fixture case needs a caseId")
        if isinstance(case_id, str):
            need(case_id not in result, f"duplicate mapping caseId: {case_id}")
            result[case_id] = case
        node = case.get("node")
        if node is not None:
            need(isinstance(node, dict), f"mapping case {case_id} node must be an object or null")
            if isinstance(node, dict):
                for field in ("nodeId", "normalizedForm", "audience"):
                    need(isinstance(node.get(field), str) and node.get(field).strip(), f"mapping case {case_id} node lacks {field}")
                need(node.get("audience") in ("GL", "YL"), f"mapping case {case_id} node audience is invalid")
                need(isinstance(node.get("partsOfSpeech"), list) and node.get("partsOfSpeech"), f"mapping case {case_id} node needs partsOfSpeech")
        entries = case.get("entries")
        need(isinstance(entries, list), f"mapping case {case_id} entries must be a list")
        if isinstance(entries, list):
            for index, entry in enumerate(entries):
                entry_shape(entry, f"mapping case {case_id} entry {index}", hashes)
        expected = case.get("expected")
        need(isinstance(expected, dict), f"mapping case {case_id} needs expected semantics")
    return result


def mutation_source_shape(source, label, hashes):
    entry_shape(source, label, hashes)
    if not isinstance(source, dict):
        return
    need(isinstance(source.get("definition"), str) and source.get("definition").strip(), f"{label} needs a source definition")
    need(isinstance(source.get("example"), str) and source.get("example").strip(), f"{label} needs a source example")


def node_by_id(graph):
    nodes = graph.get("nodes") if isinstance(graph, dict) else None
    need(isinstance(nodes, list), "graph fixture nodes must be a list")
    result = {}
    if isinstance(nodes, list):
        for node in nodes:
            need(isinstance(node, dict), "graph fixture node must be an object")
            if isinstance(node, dict):
                node_id = node.get("id")
                need(isinstance(node_id, str) and node_id.strip(), "graph fixture node needs an id")
                if isinstance(node_id, str):
                    result[node_id] = node
    return result


def graph_version(graph):
    if not isinstance(graph, dict):
        return None
    if isinstance(graph.get("schemaVersion"), str):
        return graph.get("schemaVersion")
    for node in graph.get("nodes") or []:
        if not isinstance(node, dict):
            continue
        metadata = node.get("metadata")
        if isinstance(metadata, dict) and isinstance(metadata.get("schemaVersion"), str):
            return metadata.get("schemaVersion")
    return None


def canonical_bytes(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def byte_delta(left, right):
    return sum(a != b for a, b in zip(left, right)) + abs(len(left) - len(right))


def gse_metadata(node):
    metadata = node.get("metadata") if isinstance(node, dict) else None
    return (metadata or {}).get("gse") if isinstance(metadata, dict) else None


def valid_record(record):
    return (
        isinstance(record, dict)
        and isinstance(record.get("itemId"), str)
        and bool(record.get("itemId").strip())
        and isinstance(record.get("expression"), str)
        and bool(record.get("expression").strip())
        and record.get("audience") in ("GL", "YL")
        and isinstance(record.get("grammaticalCategories"), list)
    )


def valid_mutation(mutation, source):
    metadata = mutation.get("metadata") if isinstance(mutation, dict) else None
    gse = (metadata or {}).get("gse") if isinstance(metadata, dict) else None
    if not isinstance(gse, dict):
        return False
    if not isinstance(gse.get("itemId"), str) or not gse.get("itemId").strip():
        return False
    if gse.get("audience") not in ("GL", "YL"):
        return False
    for optional in ("definition", "example", "cefrBand"):
        if optional in gse and optional not in source:
            return False
    return True


def check_manifest():
    manifest_and_files()


def check_record_layouts():
    manifest = manifest_and_files()
    records_doc = load_json("records.json")
    if manifest is None or records_doc is None:
        return
    hashes = source_hashes(manifest)
    records = records_by_id(records_doc)
    need(set(records) >= {"gl-standard-layout", "gl-starred-gse", "yl-standard-layout", "yl-temporary-gse"}, "records fixture lacks required GL/YL case IDs")
    for case_id, row in records.items():
        record = row.get("record") if isinstance(row, dict) else None
        audience = row.get("audience") if isinstance(row, dict) else None
        need(audience in ("GL", "YL"), f"record case {case_id} audience is invalid")
        need(row.get("sourceExportSha256") == hashes.get(audience), f"record case {case_id} source hash does not match audience")
        need(isinstance(record, dict), f"record case {case_id} record must be an object")
        if not isinstance(record, dict):
            continue
        for field in ("itemId", "expression", "audience", "cefr", "gse", "grammaticalCategories"):
            need(field in record, f"record case {case_id} lacks {field}")
        need(record.get("audience") == audience, f"record case {case_id} wrapper and source audience differ")
        for field in ("itemId", "expression", "cefr", "gse"):
            need(isinstance(record.get(field), str) and record.get(field).strip(), f"record case {case_id} source field {field} must be a non-empty string")
        need(isinstance(record.get("grammaticalCategories"), list) and record.get("grammaticalCategories"), f"record case {case_id} has no grammatical category list")
        if audience == "GL":
            need("expression_bre" not in record, f"GL record case {case_id} contains YL-only expression_bre")
            need("temporaryGse" not in record, f"GL record case {case_id} contains YL-only temporaryGse")
            need(isinstance(record.get("cefr"), str) and re.fullmatch(r"<(?:(?:PRE-)?A1|A2|B1|B2|C1|C2) \([0-9]+-[0-9]+\)\*?", record.get("cefr")), f"GL record case {case_id} must use the long CEFR form")
        if audience == "YL":
            need(isinstance(record.get("expression_bre"), str), f"YL record case {case_id} lacks expression_bre")
            need(isinstance(record.get("temporaryGse"), bool), f"YL record case {case_id} temporaryGse must be boolean")
            need(isinstance(record.get("cefr"), str) and re.fullmatch(r"<(?:(?:PRE-)?A1|A2|B1|B2|C1|C2)\*?", record.get("cefr")), f"YL record case {case_id} must use the short CEFR form")
        expected = row.get("expected")
        need(isinstance(expected, dict), f"record case {case_id} lacks expected semantics")
        if isinstance(expected, dict):
            need(expected.get("normalizedCefr") == band(record.get("cefr")), f"record case {case_id} CEFR expectation does not normalize its source value")


def check_special_values():
    manifest = manifest_and_files()
    records_doc = load_json("records.json")
    if manifest is None or records_doc is None:
        return
    records = records_by_id(records_doc)
    starred = records.get("gl-starred-gse") or {}
    starred_record = starred.get("record") if isinstance(starred, dict) else None
    starred_expected = starred.get("expected") if isinstance(starred, dict) else None
    need(isinstance(starred_record, dict), "starred GL fixture record is missing")
    if isinstance(starred_record, dict):
        need(isinstance(starred_record.get("gse"), str) and re.fullmatch(r"[0-9]+\*", starred_record.get("gse")), "starred GL fixture gse must preserve a numeric value with an asterisk")
        need(starred_record.get("audience") == "GL", "starred fixture must be a GL record")
    need(isinstance(starred_expected, dict), "starred GL fixture lacks expected preservation")
    if isinstance(starred_expected, dict) and isinstance(starred_record, dict):
        need(starred_expected.get("sourceValuePreserved") is True, "starred GL fixture does not require source-value preservation")
        need(starred_expected.get("gseRawValue") == starred_record.get("gse"), "starred GL expected raw value differs from source gse")
        need(starred_expected.get("starred") is True, "starred GL expected marker is not true")
    temporary = records.get("yl-temporary-gse") or {}
    temporary_record = temporary.get("record") if isinstance(temporary, dict) else None
    temporary_expected = temporary.get("expected") if isinstance(temporary, dict) else None
    need(isinstance(temporary_record, dict), "temporaryGse YL fixture record is missing")
    if isinstance(temporary_record, dict):
        need(temporary_record.get("audience") == "YL", "temporaryGse fixture must be a YL record")
        need(temporary_record.get("temporaryGse") is True, "temporaryGse fixture must preserve true")
    need(isinstance(temporary_expected, dict), "temporaryGse YL fixture lacks expected preservation")
    if isinstance(temporary_expected, dict):
        need(temporary_expected.get("sourceFieldPreserved") is True, "temporaryGse fixture does not require source-field preservation")
        need(temporary_expected.get("temporaryGse") is True, "temporaryGse expected preservation is not true")
    counts = manifest.get("expectedCounts") or {}
    print(f"starred GL gse: {counts.get('starred GL gse')}")
    print(f"YL temporaryGse: {counts.get('YL temporaryGse')}")


def check_yl_short_cefr():
    manifest = manifest_and_files()
    records_doc = load_json("records.json")
    if manifest is None or records_doc is None:
        return
    records = records_by_id(records_doc)
    yl_rows = [row for row in records.values() if row.get("audience") == "YL"]
    need(yl_rows, "records fixture has no YL rows for short CEFR validation")
    for row in yl_rows:
        record = row.get("record") or {}
        raw = record.get("cefr")
        need(isinstance(raw, str) and "(" not in raw and band(raw) is not None, f"YL record {row.get('caseId')} does not preserve a normalizable short CEFR value")
        expected = row.get("expected") or {}
        need(expected.get("normalizedCefr") == band(raw), f"YL record {row.get('caseId')} short CEFR expected band is wrong")


def check_mapping_shape_and_multi_pos():
    manifest = manifest_and_files()
    mapping_doc = load_json("mapping-cases.json")
    if manifest is None or mapping_doc is None:
        return
    cases = mapping_cases(mapping_doc, source_hashes(manifest))
    need(set(cases) >= {"multi-pos-expression", "ambiguous-binding", "unmapped-core-node", "unmatched-gse-entry", "cambridge-gse-level-conflict", "same-form-different-pos-falsifier"}, "mapping fixture lacks one or more required case IDs")
    case = cases.get("multi-pos-expression") or {}
    node = case.get("node") or {}
    entries = case.get("entries") or []
    expected = case.get("expected") or {}
    need(len(node.get("partsOfSpeech") or []) >= 2, "multi-POS node must contain at least two POS values")
    need(len(entries) == 1, "multi-POS fixture must have one exact candidate")
    if entries:
        entry = entries[0]
        need(normalized_pos(node.get("partsOfSpeech")) == normalized_pos(entry.get("grammaticalCategories")), "multi-POS node and entry POS sets do not match")
        need(node.get("normalizedForm", "").casefold() == entry.get("expression", "").casefold(), "multi-POS node and entry forms do not match")
        need(expected.get("outcome") == "mapped", "multi-POS fixture must expect mapped outcome")
        need(expected.get("itemId") == entry.get("itemId"), "multi-POS fixture expected itemId does not cite its candidate")


def check_queue_cases():
    manifest = manifest_and_files()
    mapping_doc = load_json("mapping-cases.json")
    if manifest is None or mapping_doc is None:
        return
    cases = mapping_cases(mapping_doc, source_hashes(manifest))
    ambiguous = cases.get("ambiguous-binding") or {}
    entries = ambiguous.get("entries") or []
    identity = {(entry.get("expression", "").casefold(), entry.get("audience"), tuple(normalized_pos(entry.get("grammaticalCategories")))) for entry in entries}
    node = ambiguous.get("node") or {}
    node_identity = (node.get("normalizedForm", "").casefold(), node.get("audience"), tuple(normalized_pos(node.get("partsOfSpeech"))))
    need(len(entries) >= 2, "ambiguous fixture needs at least two candidates")
    need(len({entry.get("itemId") for entry in entries}) == len(entries), "ambiguous fixture candidates need distinct itemIds")
    need(len(identity) == 1, "ambiguous candidates must share the same exact form, POS, and audience")
    need(identity == {node_identity}, "ambiguous candidates do not match the node's exact form, POS, and audience")
    ambiguous_expected = ambiguous.get("expected") or {}
    need(ambiguous_expected.get("outcome") == "ambiguous", "ambiguous fixture outcome is not ambiguous")
    need(ambiguous_expected.get("queue") == "ambiguous-node-to-entry.jsonl", "ambiguous fixture queue is wrong")
    need(set(ambiguous_expected.get("candidateItemIds") or []) == {entry.get("itemId") for entry in entries}, "ambiguous queue candidates do not match the entries")
    unmapped = cases.get("unmapped-core-node") or {}
    unmapped_expected = unmapped.get("expected") or {}
    need(isinstance(unmapped.get("node"), dict), "unmapped case must include a core node")
    need(unmapped.get("entries") == [], "unmapped case must contain no GSE candidates")
    need(unmapped_expected.get("outcome") == "unmapped", "unmapped case outcome is wrong")
    need(unmapped_expected.get("queue") == "unmapped-node-to-entry.jsonl", "unmapped case queue is wrong")
    unmatched = cases.get("unmatched-gse-entry") or {}
    unmatched_expected = unmatched.get("expected") or {}
    need(unmatched.get("node") is None, "unmatched GSE entry case must have no matching node")
    need(len(unmatched.get("entries") or []) == 1, "unmatched GSE entry case needs one source entry")
    need(unmatched_expected.get("outcome") == "unmatched-gse-entry", "unmatched GSE entry outcome is wrong")
    need(unmatched_expected.get("queue") == "unmatched-gse-entry.jsonl", "unmatched GSE entry queue is wrong")


def check_conflict_case():
    manifest = manifest_and_files()
    mapping_doc = load_json("mapping-cases.json")
    if manifest is None or mapping_doc is None:
        return
    cases = mapping_cases(mapping_doc, source_hashes(manifest))
    case = cases.get("cambridge-gse-level-conflict") or {}
    node = case.get("node") or {}
    entries = case.get("entries") or []
    expected = case.get("expected") or {}
    need(len(entries) == 1, "conflict fixture must have one exact GSE entry")
    if entries:
        source_band = band(entries[0].get("cefr"))
        cambridge_band = band(node.get("cambridgeCefr"))
        need(source_band is not None and cambridge_band is not None, "conflict fixture needs two normalizable CEFR bands")
        need(source_band != cambridge_band, "conflict fixture does not disagree across Cambridge and GSE bands")
        need(expected.get("outcome") == "mapped", "conflict fixture must still map the exact entry")
        need(expected.get("conflict") is True, "conflict fixture must expect a conflict")
        need(expected.get("preserveCambridge") is True, "conflict fixture must preserve Cambridge data")
        need(expected.get("gseCefrBand") == source_band, "conflict fixture expected GSE band is wrong")
        report = expected.get("conflictReport")
        need(isinstance(report, dict), "conflict fixture needs a conflict report row expectation")
        if isinstance(report, dict):
            for field in ("nodeId", "itemId", "cambridgeCefr", "gseCefrBand", "reason"):
                need(field in report, f"conflict report expectation lacks {field}")
            need(report.get("nodeId") == node.get("nodeId"), "conflict report nodeId does not cite the node")
            need(report.get("itemId") == entries[0].get("itemId"), "conflict report itemId does not cite the entry")
            need(report.get("reason") == "cambridge-gse-cefr-disagreement", "conflict report reason is wrong")


def check_falsifier():
    manifest = manifest_and_files()
    mapping_doc = load_json("mapping-cases.json")
    if manifest is None or mapping_doc is None:
        return
    cases = mapping_cases(mapping_doc, source_hashes(manifest))
    case = cases.get("same-form-different-pos-falsifier") or {}
    node = case.get("node") or {}
    entries = case.get("entries") or []
    expected = case.get("expected") or {}
    need(len(entries) >= 2, "form-only falsifier needs at least two entries")
    need(len({entry.get("itemId") for entry in entries}) == len(entries), "form-only falsifier entries need distinct itemIds")
    forms = {entry.get("expression", "").casefold() for entry in entries}
    audiences = {entry.get("audience") for entry in entries}
    poses = {tuple(normalized_pos(entry.get("grammaticalCategories"))) for entry in entries}
    need(len(forms) == 1, "form-only falsifier entries must share one form")
    need(len(audiences) == 1 and node.get("audience") in audiences, "form-only falsifier entries and node must share one audience")
    need(len(poses) >= 2, "form-only falsifier must contain different POS entries")
    first = entries[0]
    exact = [entry for entry in entries if normalized_pos(entry.get("grammaticalCategories")) == normalized_pos(node.get("partsOfSpeech"))]
    need(len(exact) == 1, "form-only falsifier must have one POS-exact entry")
    if exact:
        need(expected.get("itemId") == exact[0].get("itemId"), "form-only falsifier expected itemId does not use the POS-exact entry")
        need(expected.get("naiveFormOnlyItemId") == first.get("itemId"), "form-only falsifier does not identify the first form-only candidate")
        need(expected.get("naiveFormOnlyItemId") != expected.get("itemId"), "form-only falsifier first candidate is not wrong")
        need(expected.get("formOnlyWouldChooseWrong") is True, "form-only falsifier does not assert the wrong naive choice")
        need(expected.get("outcome") == "mapped", "form-only falsifier must expect exact POS mapping")


def check_mutation_schema():
    manifest = manifest_and_files()
    mutation_doc = load_json("mutation-cases.json")
    if manifest is None or mutation_doc is None:
        return
    rows = mutation_doc.get("cases")
    need(isinstance(rows, list) and rows, "mutation fixture must contain a non-empty cases list")
    cases = {row.get("caseId"): row for row in rows if isinstance(row, dict)} if isinstance(rows, list) else {}
    need(set(cases) >= {"mapped-node-source-backed-fields", "conflict-retains-cambridge", "unmapped-node-no-inferred-data", "byte-diff-report-actual-mutation"}, "mutation fixture lacks a required case ID")
    hashes = source_hashes(manifest)
    mapped = cases.get("mapped-node-source-backed-fields") or {}
    source = mapped.get("sourceEntry") or {}
    mutation_expected = (mapped.get("expected") or {}).get("nodeMetadataGse")
    mutation_source_shape(source, "mapped mutation sourceEntry", hashes)
    need(isinstance(mutation_expected, dict), "mapped mutation case needs nodeMetadataGse expectation")
    if isinstance(mutation_expected, dict):
        for field in ("itemId", "audience", "gseScore", "starred", "cefrBand", "definition", "example", "sourceCitation"):
            need(field in mutation_expected, f"mapped mutation expectation lacks {field}")
        need(mutation_expected.get("itemId") == source.get("itemId"), "mapped mutation itemId is not source-backed")
        need(mutation_expected.get("audience") == source.get("audience"), "mapped mutation audience is not source-backed")
        need(mutation_expected.get("gseScore") == source.get("gse"), "mapped mutation gseScore does not preserve the raw source value")
        need(mutation_expected.get("cefrBand") == band(source.get("cefr")), "mapped mutation CEFR band is not normalized from source")
        need(mutation_expected.get("definition") == source.get("definition"), "mapped mutation definition is not source-backed")
        need(mutation_expected.get("example") == source.get("example"), "mapped mutation example is not source-backed")
        if "starred" in source:
            need(mutation_expected.get("starred") == source.get("starred"), "mapped mutation starred marker is not source-backed")
        if "temporaryGse" in source:
            need(mutation_expected.get("temporaryGse") == source.get("temporaryGse"), "mapped mutation temporaryGse flag is not source-backed")
        citation = mutation_expected.get("sourceCitation")
        need(isinstance(citation, dict) and citation.get("itemId") == source.get("itemId") and citation.get("exportSha256") == source.get("sourceExportSha256"), "mapped mutation citation does not identify the source entry and export")
    conflict = cases.get("conflict-retains-cambridge") or {}
    conflict_node = conflict.get("nodeBefore") or {}
    conflict_source = conflict.get("sourceEntry") or {}
    conflict_expected = conflict.get("expected") or {}
    mutation_source_shape(conflict_source, "conflict mutation sourceEntry", hashes)
    need(band(conflict_source.get("cefr")) != band(conflict_node.get("metadata", {}).get("cefr")), "mutation conflict case does not disagree across levels")
    need(conflict_expected.get("preserveCambridge") is True, "mutation conflict case does not preserve Cambridge metadata")
    need(conflict_expected.get("conflict") is True, "mutation conflict case does not expect a conflict report")
    unmapped = cases.get("unmapped-node-no-inferred-data") or {}
    unmapped_before = unmapped.get("nodeBefore") or {}
    unmapped_expected = unmapped.get("expected") or {}
    need("gse" not in (unmapped_before.get("metadata") or {}), "unmapped mutation node must begin without GSE data")
    need(unmapped_expected.get("metadataGseAbsent") is True, "unmapped mutation case must prohibit inferred GSE data")


def check_byte_diff():
    manifest = manifest_and_files()
    mutation_doc = load_json("mutation-cases.json")
    if manifest is None or mutation_doc is None:
        return
    rows = mutation_doc.get("cases") or []
    case = next((row for row in rows if isinstance(row, dict) and row.get("caseId") == "byte-diff-report-actual-mutation"), None)
    need(case is not None, "byte-diff mutation case is missing")
    if case is None:
        return
    prior = case.get("priorGraph")
    current = case.get("newGraph")
    expected = case.get("expected") or {}
    need(isinstance(prior, dict) and isinstance(current, dict), "byte-diff case needs priorGraph and newGraph objects")
    if not isinstance(prior, dict) or not isinstance(current, dict):
        return
    prior_nodes = node_by_id(prior)
    current_nodes = node_by_id(current)
    prior_bytes = canonical_bytes(prior)
    current_bytes = canonical_bytes(current)
    changed = sorted(node_id for node_id in set(prior_nodes) | set(current_nodes) if canonical_bytes(prior_nodes.get(node_id, {})) != canonical_bytes(current_nodes.get(node_id, {})))
    levels_added = 0
    levels_corrected = 0
    conflicts = 0
    for node_id in set(prior_nodes) | set(current_nodes):
        old_gse = gse_metadata(prior_nodes.get(node_id, {})) or {}
        new_gse = gse_metadata(current_nodes.get(node_id, {})) or {}
        old_band = old_gse.get("cefrBand")
        new_band = new_gse.get("cefrBand")
        if old_band is None and new_band is not None:
            levels_added += 1
        if old_band is not None and new_band is not None and old_band != new_band:
            levels_corrected += 1
        cambridge = (current_nodes.get(node_id, {}).get("metadata") or {}).get("cefr")
        if cambridge is not None and new_band is not None and band(cambridge) != band(new_band):
            conflicts += 1
    nodes_mapped = sum(bool((gse_metadata(node) or {}).get("itemId")) for node in current_nodes.values())
    queue_rows = case.get("queueRows") or {}
    actual_counts = {
        "Nodes mapped": nodes_mapped,
        "Levels added": levels_added,
        "Levels corrected": levels_corrected,
        "Conflicts": conflicts,
        "Unmapped GSE entries queued": len(queue_rows.get("unmappedGseEntriesQueued") or []),
        "GSE entries with no matching node": len(queue_rows.get("gseEntriesWithNoMatchingNode") or []),
    }
    prior_version = graph_version(prior)
    current_version = graph_version(current)
    need(prior_version != current_version, "byte-diff case does not bump the core schema version")
    need(re.fullmatch(r"gse-vocab-[0-9]{8}-r[0-9]{2}", str(current_version)), "new core schema version has the required versioned form")
    need(expected.get("priorSha256") == hashlib.sha256(prior_bytes).hexdigest(), "byte-diff prior SHA-256 does not match priorGraph bytes")
    need(expected.get("newSha256") == hashlib.sha256(current_bytes).hexdigest(), "byte-diff new SHA-256 does not match newGraph bytes")
    need(expected.get("bytesChanged") == byte_delta(prior_bytes, current_bytes), "byte-diff bytesChanged does not match the actual byte mutation")
    need(expected.get("bytesChanged", 0) > 0, "byte-diff case must contain an actual byte mutation")
    need(expected.get("changedNodeIds") == changed, "byte-diff changedNodeIds do not match actual node mutations")
    diff_counts = expected.get("diffCounts") or {}
    for label, value in actual_counts.items():
        need(isinstance(diff_counts.get(label), int) and not isinstance(diff_counts.get(label), bool), f"byte-diff count {label} must be a labelled integer")
        need(diff_counts.get(label) == value, f"byte-diff count {label} does not match the actual mutation fixture")
    print(f"Nodes mapped: {actual_counts['Nodes mapped']}")
    print(f"Levels added: {actual_counts['Levels added']}")
    print(f"Levels corrected: {actual_counts['Levels corrected']}")
    print(f"Conflicts: {actual_counts['Conflicts']}")
    print(f"Unmapped GSE entries queued: {actual_counts['Unmapped GSE entries queued']}")
    print(f"GSE entries with no matching node: {actual_counts['GSE entries with no matching node']}")


def check_negative_cases():
    negative_doc = load_json("negative-cases.json")
    if negative_doc is None:
        return
    rows = negative_doc.get("cases")
    need(isinstance(rows, list) and rows, "negative fixture must contain a non-empty cases list")
    cases = {row.get("caseId"): row for row in rows if isinstance(row, dict)} if isinstance(rows, list) else {}
    need(set(cases) >= {"malformed-record-missing-item-id", "mutation-without-item-citation", "mutation-infers-absent-definition"}, "negative fixture lacks a required malformed or mutation probe")
    malformed = cases.get("malformed-record-missing-item-id") or {}
    malformed_expected = malformed.get("expected") or {}
    need(malformed_expected.get("accepted") is False, "malformed record probe must expect rejection")
    need(valid_record(malformed.get("record")) is False, "malformed record probe is accepted by the fixture schema")
    missing_citation = cases.get("mutation-without-item-citation") or {}
    missing_expected = missing_citation.get("expected") or {}
    need(missing_expected.get("accepted") is False, "missing citation mutation probe must expect rejection")
    need(valid_mutation(missing_citation.get("mutation") or {}, missing_citation.get("sourceEntry") or {}) is False, "missing citation mutation probe is accepted by the fixture schema")
    invented = cases.get("mutation-infers-absent-definition") or {}
    invented_expected = invented.get("expected") or {}
    source = invented.get("sourceEntry") or {}
    mutation = invented.get("mutation") or {}
    need(invented_expected.get("accepted") is False, "inferred-field mutation probe must expect rejection")
    need("definition" not in source and "definition" in (mutation.get("metadata", {}).get("gse", {})), "inferred-field mutation probe does not describe an absent source field and invented mutation field")
    need(valid_mutation(mutation, source) is False, "inferred-field mutation probe is accepted by the fixture schema")


def check_determinism():
    determinism = load_json("determinism.json")
    if determinism is None:
        return
    rows = determinism.get("expectations")
    need(isinstance(rows, list), "determinism fixture expectations must be a list")
    cases = {row.get("caseId"): row for row in rows if isinstance(row, dict)} if isinstance(rows, list) else {}
    need(set(cases) >= {"extractor-two-run-byte-identical", "core-mutation-two-run-byte-identical", "yle-same-procedure-before-after-baseline-isolation"}, "determinism fixture lacks a required expectation")
    for case_id in ("extractor-two-run-byte-identical", "core-mutation-two-run-byte-identical"):
        case = cases.get(case_id) or {}
        labels = case.get("runLabels")
        expected = case.get("expected") or {}
        need(isinstance(labels, list) and len(labels) == 2 and len(set(labels)) == 2, f"{case_id} needs two distinct run labels")
        need(case.get("procedure") in ("extract", "core-mutation"), f"{case_id} procedure is not explicit")
        need(expected.get("byteIdentical") is True, f"{case_id} must expect byte-identical output")
        need(isinstance(case.get("outputArtifact"), str) and case.get("outputArtifact").strip(), f"{case_id} lacks a tracked output artifact")
    yle = cases.get("yle-same-procedure-before-after-baseline-isolation") or {}
    yle_expected = yle.get("expected") or {}
    need(yle.get("sameProcedure") is True, "YLE expectation must use the same procedure before and after mutation")
    need(yle.get("runLabels") == ["before", "after"], "YLE expectation must label before and after runs")
    need(yle.get("mutationAppliedBetweenRuns") is True, "YLE expectation must place the GSE mutation between runs")
    need(yle.get("comparisonTarget") == "temporary-before-vs-after", "YLE comparison target must be temporary before versus after output")
    need(yle_expected.get("beforeAfterByteIdentical") is True, "YLE expectation must require byte-identical before and after output")
    need(yle_expected.get("frozenBaselineUnchanged") is True, "YLE expectation must preserve the frozen baseline")
    need(yle_expected.get("frozenBaselineIsComparisonTarget") is False, "YLE expectation must not compare against the frozen release artifact")
    need(isinstance(yle.get("frozenBaselineArtifact"), str) and yle.get("frozenBaselineArtifact").strip(), "YLE expectation lacks the frozen baseline artifact path")


def check_plan_gate():
    plan_path = Path(sys.argv[3]) if len(sys.argv) > 3 else None
    if plan_path is None or not plan_path.is_file():
        add_error(f"missing active plan: {plan_path}")
        return
    text = plan_path.read_text(encoding="utf-8")
    phase_one = re.search(
        r"^## Phase 1:.*?(?=^## Phase 2:|\Z)",
        text,
        re.IGNORECASE | re.MULTILINE | re.DOTALL,
    )
    need(phase_one is not None, "Phase 1 plan section is missing")
    if phase_one:
        need(
            re.search(
                r"^\s*- \[b\] Task: Complete Phase 1 review gate.*deferred:both-owners",
                phase_one.group(0),
                re.IGNORECASE | re.MULTILINE,
            )
            is not None,
            "Phase 1 human gate is not preserved as [b] deferred:both-owners",
        )
    need(re.search(r"^\s*-\s+\[ \]", text, re.MULTILINE) is None, "plan contains a deprecated [ ] marker")

    phase = re.search(
        r"^## Phase 2: Tests And Fixtures\s*$\n?(.*?)(?=^## Phase 3:|\Z)",
        text,
        re.IGNORECASE | re.MULTILINE | re.DOTALL,
    )
    need(phase is not None, "Phase 2 plan section is missing")
    if not phase:
        return

    phase_text = phase.group(1)
    task_rows = re.findall(r"^\s*- \[([~xb ])\] (.+)$", phase_text, re.MULTILINE)
    need(bool(task_rows), "Phase 2 has no task or subtask markers")
    if not task_rows:
        return

    invalid_rows = [
        (status, description)
        for status, description in task_rows
        if status not in ("~", "x")
    ]
    for status, description in invalid_rows:
        add_error(f"Phase 2 task uses unsupported marker [{status}]: {description}")

    commit_pattern = re.compile(r"\bcommit(?:s)?\s*:\s*[0-9a-f]{7,40}\b", re.IGNORECASE)
    missing_sha = [description for status, description in task_rows if status == "x" and commit_pattern.search(description) is None]
    for description in missing_sha:
        add_error(f"completed Phase 2 task lacks commit SHA evidence: {description}")

    statuses = [status for status, _description in task_rows]
    if all(status == "~" for status in statuses):
        print("Phase 2 plan state is valid Red: every task and subtask is [~]")
        return
    if all(status == "x" for status in statuses):
        if not missing_sha:
            print("Phase 2 plan state is valid Green: every task and subtask is [x] with commit SHA evidence")
        return

    remediation = [
        (status, description)
        for status, description in task_rows
        if re.search(r"\bbounded[ -]remediation\b", description, re.IGNORECASE)
    ]
    if not remediation:
        add_error("mixed Phase 2 markers require an explicit bounded remediation task")
        return
    remediation_statuses = {status for status, _description in remediation}
    if len(remediation_statuses) != 1:
        add_error("bounded remediation tasks must use one consistent marker state")

    evidence_heading = re.search(
        r"^\*\*[^\n]*bounded[ -]remediation[^\n]*\*\*:?\s*$",
        phase_text,
        re.IGNORECASE | re.MULTILINE,
    )
    command_evidence = re.search(r"^\s*-\s*(?:Red\s+)?command:\s*.+$", phase_text, re.IGNORECASE | re.MULTILINE)
    result_evidence = re.search(
        r"^\s*-\s*result:\s*exit\s*`?(\d+)`?.*$",
        phase_text,
        re.IGNORECASE | re.MULTILINE,
    )
    if evidence_heading is None or command_evidence is None or result_evidence is None:
        add_error("mixed Phase 2 markers require bounded-remediation evidence with a command and exit result")
        return

    result_code = int(result_evidence.group(1))
    if remediation_statuses == {"~"} and result_code == 0:
        add_error("bounded remediation marked [~] requires a failing exit result")
    if remediation_statuses == {"x"} and result_code != 0:
        add_error("bounded remediation marked [x] requires a successful exit result")
    if not errors:
        print("Phase 2 plan state is valid mixed remediation: bounded task evidence matches its marker")


checks = {
    "manifest": check_manifest,
    "record-layouts": check_record_layouts,
    "special-values": check_special_values,
    "yl-short-cefr": check_yl_short_cefr,
    "mapping-shape": check_mapping_shape_and_multi_pos,
    "queue-cases": check_queue_cases,
    "conflict": check_conflict_case,
    "falsifier": check_falsifier,
    "mutation-schema": check_mutation_schema,
    "byte-diff": check_byte_diff,
    "negative": check_negative_cases,
    "determinism": check_determinism,
    "plan-gate": check_plan_gate,
}

if check not in checks:
    add_error(f"unknown fixture probe: {check}")
else:
    try:
        checks[check]()
    except (AttributeError, KeyError, TypeError, ValueError) as exc:
        add_error(f"fixture probe raised a schema error instead of reporting a contract failure: {exc}")

if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
print(f"fixture probe passed: {check}")
PY
}

echo "=== manifest registers the complete Phase 2 fixture pack and labelled source counts ==="
if probe manifest; then
  pass "fixture manifest registers records, mapping, mutation, determinism, negative probes, and labelled GL/YL source counts"
else
  fail "fixture manifest or required fixture files are missing or invalid"
fi

echo "=== GL and YL records obey distinct source layouts ==="
if probe record-layouts; then
  pass "GL long-CEFR and YL expression_bre/short-CEFR record layouts are valid"
else
  fail "GL or YL record layout semantics are missing"
fi

echo "=== starred GSE and temporaryGse source values are represented and preserved ==="
if probe special-values; then
  pass "the starred GL gse and YL temporaryGse fixture records preserve their raw source values"
else
  fail "starred gse or temporaryGse preservation semantics are missing"
fi

echo "=== YL short CEFR values normalize without a long-form parser dependency ==="
if probe yl-short-cefr; then
  pass "every YL fixture CEFR value uses the short source form and has an expected normalized band"
else
  fail "YL short CEFR fixture semantics are missing"
fi

echo "=== multi-POS mapping fixture binds exact form and POS sets ==="
if probe mapping-shape; then
  pass "multi-POS mapping has one exact candidate with matching form and normalized POS sets"
else
  fail "mapping fixture schema or multi-POS relationship is missing"
fi

echo "=== ambiguous, unmapped, and unmatched queue fixtures carry semantic outcomes ==="
if probe queue-cases; then
  pass "ambiguous, unmapped-node, and GSE-without-node cases describe their durable queues"
else
  fail "queue fixture cases are missing or do not describe their semantic relationships"
fi

echo "=== Cambridge and GSE level conflict fixture retains both values ==="
if probe conflict; then
  pass "level conflict fixture records disagreement, preserved Cambridge data, GSE data, and report identity"
else
  fail "Cambridge-vs-GSE conflict fixture is missing or permits silent overwrite"
fi

echo "=== same-form different-POS fixture rejects naive form-only binding ==="
if probe falsifier; then
  pass "the falsifier proves form-only selection chooses a different, wrong POS entry"
else
  fail "required same-form different-POS falsifier is missing or weak"
fi

echo "=== mutation fixture carries source-backed fields and no-inference expectations ==="
if probe mutation-schema; then
  pass "mutation fixtures require itemId citation, source fields, versioned output, conflict visibility, and no inferred data"
else
  fail "core mutation fixture schema or source-backed relationship is missing"
fi

echo "=== byte-diff fixture report matches the actual graph mutation ==="
if probe byte-diff; then
  pass "byte hashes, changed node IDs, bytes changed, and labelled mutation counts match fixture graph bytes"
else
  fail "byte-diff fixture does not reconcile its report with the actual mutation"
fi

echo "=== malformed record and mutation probes fail closed ==="
if probe negative; then
  pass "malformed source records, missing item citations, and invented optional fields are rejected by the fixture contract"
else
  fail "malformed-input or mutation rejection probes are missing or vacuous"
fi

echo "=== extraction, core mutation, and YLE before-after determinism expectations are explicit ==="
if probe determinism; then
  pass "two-run byte equality and same-procedure YLE baseline isolation expectations are explicit"
else
  fail "determinism or YLE baseline-isolation fixture expectations are missing"
fi

echo "=== Phase 1 human gate and Phase 2 plan-state markers obey the contract ==="
if probe plan-gate; then
  pass "Phase 1 remains [b] deferred:both-owners and Phase 2 Red, Green, or bounded-remediation state is valid"
else
  fail "plan markers do not preserve the Phase 1 human gate or a valid Phase 2 state"
fi

echo "=== results ==="
printf '%s\n' "${RESULTS[@]}"
echo "=== Total: $((PASS_COUNT + FAIL_COUNT)) checks (PASS=$PASS_COUNT, FAIL=$FAIL_COUNT) ==="
exit "$FAILED"
