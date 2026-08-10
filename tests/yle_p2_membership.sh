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
TRACK_ID="lexical_graph_core_release_20260610"
track_dir_resolve() {
  local track_id="$1"
  if [[ -d "$ROOT/measure/archive/$track_id" ]]; then
    printf '%s\n' "$ROOT/measure/archive/$track_id"
  else
    printf '%s\n' "$ROOT/measure/tracks/$track_id"
  fi
}
TRACK_DIR="$(track_dir_resolve "$TRACK_ID")"
PLAN="${PLAN_OVERRIDE:-$TRACK_DIR/plan.md}"
SOURCE_ID="cambridge-yle-word-list-2025"
SOURCE_URL="https://www.cambridgeenglish.org/Images/739104-starters-movers-flyers-word-list-2025.pdf"
SOURCE_SHA="6f7a0ad1e277bd10ae8b3bcccfb76c058f611a607c6c9947601abbd7e16a99fa"
SOURCE_PDF="$ROOT/english/cefr-vocabulary/source-pdfs/cambridge-yle-word-list-2025.pdf"
SOURCE_SUMS="$ROOT/english/cefr-vocabulary/source-pdfs/SHA256SUMS"
SOURCE_INFO="$ROOT/english/cefr-vocabulary/source-pdfs/pdfinfo.txt"
SOURCES="$ROOT/english/cefr-vocabulary/SOURCES.md"
INVENTORY="$ROOT/english/cefr-vocabulary/data/cambridge-vocabulary-inventory.json"
GRAPH="$ROOT/english/cefr-vocabulary/cefr-vocabulary-knowledge-space.json"
REVIEW_DIR="$ROOT/english/cefr-vocabulary/review/yle-2025"
FIXTURE_DIR="$ROOT/english/cefr-vocabulary/fixtures/yle-audit"
REPORT="$ROOT/english/cefr-vocabulary/reports/yle-membership-audit.json"
DECISIONS="$REVIEW_DIR/membership-decisions.jsonl"
EXCEPTIONS="$REVIEW_DIR/membership-exceptions.jsonl"
COLLISIONS="$REVIEW_DIR/collision-queue.jsonl"
GRAMMATICAL="$REVIEW_DIR/grammatical-list-decision.json"
APPROVAL="$REVIEW_DIR/phase2-approval.md"
THEMATIC="$FIXTURE_DIR/thematic-memberships.jsonl"

STARTERS_FIXTURE="$FIXTURE_DIR/starters-sample.jsonl"
MOVERS_FIXTURE="$FIXTURE_DIR/movers-sample.jsonl"
FLYERS_FIXTURE="$FIXTURE_DIR/flyers-sample.jsonl"

# This is deliberately a source-to-graph contract.  The JSONL rows must carry
# only source locations (not PDF excerpts); the local ignored PDF is read at
# test time to check those locations.  A fixture made by copying inventory
# rows without official-list locations therefore cannot satisfy the gate.

echo "=== local official YLE source identity and PDF metadata ==="
source_identity_errors="$(python3 - "$SOURCE_PDF" "$SOURCE_SUMS" "$SOURCE_INFO" "$SOURCES" "$SOURCE_ID" "$SOURCE_URL" "$SOURCE_SHA" <<'PY' 2>&1
import hashlib
import re
import shutil
import subprocess
import sys
from pathlib import Path

pdf_arg, sums_arg, info_arg, sources_arg, source_id, source_url, source_sha = sys.argv[1:]
pdf_path, sums_path, info_path, sources_path = map(Path, (pdf_arg, sums_arg, info_arg, sources_arg))
errors = []
if not pdf_path.is_file():
    errors.append(f"missing local source PDF: {pdf_path}")
else:
    digest = hashlib.sha256(pdf_path.read_bytes()).hexdigest()
    if digest != str(source_sha):
        errors.append(f"YLE source SHA-256 mismatch: expected {source_sha}, found {digest}")
    if shutil.which("pdftotext") is None:
        errors.append("pdftotext is unavailable; source comparison cannot run locally")
    else:
        probe = subprocess.run(
            ["pdftotext", "-layout", "-f", "1", "-l", "1", str(pdf_path), "-"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        if probe.returncode != 0:
            errors.append(f"pdftotext failed for local source: {probe.stderr.strip()}")
if not sums_path.is_file() or str(source_sha) not in sums_path.read_text(encoding="utf-8"):
    errors.append("SHA256SUMS lacks the registered YLE SHA-256")
info = info_path.read_text(encoding="utf-8") if info_path.is_file() else ""
for required in ("Title:           Starters, Movers and Flyers word lists", "Pages:           44"):
    if required not in info:
        errors.append(f"pdfinfo.txt lacks YLE metadata: {required}")
sources = sources_path.read_text(encoding="utf-8") if sources_path.is_file() else ""
for required in (str(source_id), str(source_url), str(source_sha)):
    if required not in sources:
        errors.append(f"SOURCES.md lacks registered YLE source field: {required}")
if errors:
    print("; ".join(errors))
    raise SystemExit(1)
PY
)"
if [[ -n "$source_identity_errors" ]]; then
  fail "$source_identity_errors"
else
  pass "local PDF hash, registry identity, and metadata are available without network access"
fi

echo "=== Phase 2 plan marker guard is non-vacuous and has no legacy [ ] tasks ==="
phase_marker_errors="$(python3 - "$PLAN" <<'PY' 2>&1
import re
import sys
from pathlib import Path

plan_path = Path(sys.argv[1])
if not plan_path.is_file():
    print(f"missing plan: {plan_path}")
    raise SystemExit(1)
text = plan_path.read_text(encoding="utf-8")
phase_matches = list(re.finditer(r"^## Phase 2: YLE List Fidelity Audit[ \t]*$", text, re.MULTILINE))
next_matches = list(re.finditer(r"^## Phase 3: Relationship And Progression Review[ \t]*$", text, re.MULTILINE))
if len(phase_matches) != 1 or len(next_matches) != 1 or next_matches[0].start() <= phase_matches[0].end():
    print("Phase 2/Phase 3 boundaries are not uniquely resolvable")
    raise SystemExit(1)
phase = text[phase_matches[0].end():next_matches[0].start()]
legacy = re.findall(r"^[ \t]*-[ \t]*\[ \][ \t]", phase, re.MULTILINE)
markers = re.findall(r"^[ \t]*-[ \t]*\[([^]]+)\][ \t]", phase, re.MULTILINE)
invalid = sorted({marker for marker in markers if marker not in {"x", "~", "b"}})
completed = len(re.findall(r"^- \[x\][ \t]+Task:", phase, re.MULTILINE))
in_progress = len(re.findall(r"^- \[~\][ \t]+Task:", phase, re.MULTILINE))
blocked = len(re.findall(r"^- \[b\][ \t]+Task:", phase, re.MULTILINE))
errors = []
if legacy:
    errors.append(f"legacy [ ] task markers: {len(legacy)}")
if invalid:
    errors.append(f"unrecognized Phase 2 markers: {invalid}")
if completed == 0:
    errors.append(f"INCOMPLETE: Phase 2 completed task count: {completed}")
if not markers:
    errors.append("Phase 2 has no task markers")
print(f"Phase 2 completed task count: {completed}")
print(f"Phase 2 in-progress task count: {in_progress}")
print(f"Phase 2 human-gate task count: {blocked}")
if errors:
    print("; ".join(errors))
    raise SystemExit(1)
PY
)"
if [[ -n "$phase_marker_errors" ]]; then
  fail "$phase_marker_errors"
else
  pass "Phase 2 has substantive completed work and uses only [x]/[~]/[b] markers"
fi

echo "=== full source-row fixtures exist with official locations and identity fields ==="
fixture_errors="$(python3 - "$INVENTORY" "$GRAPH" "$SOURCE_PDF" "$STARTERS_FIXTURE" "$MOVERS_FIXTURE" "$FLYERS_FIXTURE" "$DECISIONS" <<'PY' 2>&1
import json
import re
import subprocess
import sys
import unicodedata
from collections import defaultdict
from pathlib import Path

inventory_path, graph_path, pdf_path, starters_path, movers_path, flyers_path, decisions_path = map(Path, sys.argv[1:])
source_id = "cambridge-yle-word-list-2025"
exam_by_stage = {
    "starters": "pre-a1-starters",
    "movers": "a1-movers",
    "flyers": "a2-flyers",
}
fixture_paths = {
    "starters": starters_path,
    "movers": movers_path,
    "flyers": flyers_path,
}
errors = []

def load_jsonl(path):
    if not path.is_file():
        errors.append(f"missing fixture or decision file: {path}")
        return []
    rows = []
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError as exc:
            errors.append(f"{path}:{line_number} is not valid JSON: {exc}")
    return rows

try:
    inventory = json.loads(inventory_path.read_text(encoding="utf-8"))
    graph = json.loads(graph_path.read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError) as exc:
    print(f"cannot load tracked inventory/graph: {exc}")
    raise SystemExit(1)
decision_rows = load_jsonl(decisions_path)
decision_ids = {row.get("decision_id") for row in decision_rows if isinstance(row, dict)}
yle_inventory = [row for row in inventory if source_id in row.get("sourceRefs", [])]
yle_nodes = [row for row in graph.get("nodes", []) if row.get("kind") == "skill" and source_id in row.get("sourceRefs", [])]
yle_ids = {row.get("id") for row in yle_nodes}
expected_counts = {
    stage: sum(exam_by_stage[stage] in row.get("exams", []) for row in yle_inventory)
    for stage in exam_by_stage
}
expected_direct_rows = sum(expected_counts.values())
expected_unique_skills = len(yle_inventory)
print(f"Current YLE skill count: {expected_unique_skills}")
print(f"Expected direct source membership rows: {expected_direct_rows}")

all_rows = []
row_ids = set()
for stage, path in fixture_paths.items():
    rows = load_jsonl(path)
    count = len(rows)
    print(f"{stage.capitalize()} fixture row count: {count}")
    if count != expected_counts[stage]:
        errors.append(f"{stage} fixture must cover every direct source row: expected {expected_counts[stage]}, found {count}")
    for row in rows:
        if not isinstance(row, dict):
            errors.append(f"{stage} fixture contains a non-object row")
            continue
        all_rows.append((stage, row))
        row_id = row.get("source_row_id")
        if not isinstance(row_id, str) or not row_id.strip():
            errors.append(f"{stage} row lacks source_row_id")
        elif row_id in row_ids:
            errors.append(f"duplicate source_row_id: {row_id}")
        else:
            row_ids.add(row_id)
        if row.get("source_ref") != source_id:
            errors.append(f"{stage} row {row_id} has wrong source_ref")
        location = row.get("source_location")
        if not isinstance(location, dict):
            errors.append(f"{stage} row {row_id} lacks structured source_location")
        else:
            if not isinstance(location.get("pdf_page"), int) or not 4 <= location["pdf_page"] <= 30:
                errors.append(f"{stage} row {row_id} needs a YLE alphabetic-list PDF page from 4 through 30")
            if not isinstance(location.get("pdf"), str) or not location["pdf"].endswith("source-pdfs/cambridge-yle-word-list-2025.pdf"):
                errors.append(f"{stage} row {row_id} does not reference the local YLE PDF path")
            if not isinstance(location.get("section"), str) or not re.search(r"alphabetic|a-z|wordlist", location["section"], re.IGNORECASE):
                errors.append(f"{stage} row {row_id} lacks an alphabetic YLE source section")
        headword = row.get("source_headword")
        pos = row.get("source_parts_of_speech")
        forms = row.get("source_forms")
        if not isinstance(headword, str) or not headword.strip():
            errors.append(f"{stage} row {row_id} lacks source_headword")
        if not isinstance(pos, list) or not pos or not all(isinstance(value, str) and value.strip() for value in pos):
            errors.append(f"{stage} row {row_id} lacks canonical source_parts_of_speech")
        if not isinstance(forms, list) or not forms or not all(isinstance(value, str) and value.strip() for value in forms):
            errors.append(f"{stage} row {row_id} lacks source_forms for lexical/variant matching")
        if row.get("stage") != stage or row.get("expected_exam") != exam_by_stage[stage]:
            errors.append(f"{stage} row {row_id} does not declare direct {stage} membership")
        if not isinstance(row.get("is_mwe"), bool) or not isinstance(row.get("is_variant"), bool):
            errors.append(f"{stage} row {row_id} must classify MWE and variant handling explicitly")
        if isinstance(headword, str):
            without_parenthetical = re.sub(r"\([^)]*\)", "", headword).strip()
            expected_mwe = len(without_parenthetical.split()) > 1
            expected_variant = bool(re.search(r"[()/]", headword))
            if row.get("is_mwe") != expected_mwe:
                errors.append(f"{stage} row {row_id} has incorrect is_mwe classification")
            if row.get("is_variant") != expected_variant:
                errors.append(f"{stage} row {row_id} has incorrect is_variant classification")
        status = row.get("status")
        graph_id = row.get("graph_skill_id")
        row_decisions = row.get("decision_ids")
        if status not in {"matched", "omission"}:
            errors.append(f"{stage} row {row_id} has unsupported audit status: {status}")
        if not isinstance(row_decisions, list):
            errors.append(f"{stage} row {row_id} lacks decision_ids list")
        else:
            for decision_id in row_decisions:
                if decision_id not in decision_ids:
                    errors.append(f"{stage} row {row_id} references missing decision_id: {decision_id}")
        if status == "matched":
            if not isinstance(graph_id, str) or graph_id not in yle_ids:
                errors.append(f"{stage} row {row_id} must map to a current YLE graph skill")
        elif status == "omission":
            if graph_id is not None:
                errors.append(f"{stage} omission row {row_id} must not invent a graph_skill_id")
            if not isinstance(row_decisions, list) or not row_decisions:
                errors.append(f"{stage} omission row {row_id} requires a durable decision_id")
        for key in ("source_excerpt", "source_text", "pdf_text", "pdf_contents"):
            if key in row:
                errors.append(f"{stage} row {row_id} commits publisher PDF content through {key}")

if len(all_rows) != expected_direct_rows:
    errors.append(f"full fixture population must contain {expected_direct_rows} direct source rows, found {len(all_rows)}")

# Verify source locations against the ignored local PDF, not against the inventory.
def normalize(value):
    return re.sub(r"\s+", " ", unicodedata.normalize("NFKC", value).casefold().replace("\u2019", "'").replace("\u2013", "-").replace("\u2014", "-")).strip()

if all_rows and pdf_path.is_file():
    probe = subprocess.run(["pdftotext", "-layout", str(pdf_path), "-"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if probe.returncode != 0:
        errors.append(f"pdftotext failed while checking source locations: {probe.stderr.strip()}")
    else:
        pages = probe.stdout.split("\f")
        for stage, row in all_rows:
            location = row.get("source_location", {})
            page_number = location.get("pdf_page") if isinstance(location, dict) else None
            if not isinstance(page_number, int) or page_number < 1 or page_number > len(pages):
                continue
            headword = row.get("source_headword")
            if not isinstance(headword, str):
                continue
            base = re.sub(r"\([^)]*\)", "", headword).strip()
            candidates = [normalize(base), normalize(headword)]
            first = re.split(r"\s+", base, maxsplit=1)[0] if base else ""
            if first:
                candidates.append(normalize(first))
            page_text = normalize(pages[page_number - 1])
            if not any(candidate and candidate in page_text for candidate in candidates):
                errors.append(f"{stage} row {row.get('source_row_id')} source_headword is not found on cited local PDF page {page_number}")

# Compare every mapped source row with graph identity and direct contains membership.
nodes_by_id = {node.get("id"): node for node in yle_nodes}
exam_ids = {"pre-a1-starters", "a1-movers", "a2-flyers"}
exam_node_ids = {f"english.vocabulary.exam.{exam}" : exam for exam in exam_ids}
contains = defaultdict(set)
for edge in graph.get("edges", []):
    if edge.get("type") == "contains" and edge.get("sourceId") in exam_node_ids and edge.get("targetId") in yle_ids:
        contains[edge.get("targetId")].add(exam_node_ids[edge.get("sourceId")])
expected_by_graph = defaultdict(set)
matched_ids = set()
for stage, row in all_rows:
    if row.get("status") != "matched":
        continue
    graph_id = row.get("graph_skill_id")
    expected_by_graph[graph_id].add(row.get("expected_exam"))
    matched_ids.add(graph_id)
    node = nodes_by_id.get(graph_id)
    row_decisions = row.get("decision_ids") if isinstance(row.get("decision_ids"), list) else []
    if node is None:
        continue
    metadata = node.get("metadata", {})
    actual_exams = set(metadata.get("examAlignments", [])) & exam_ids
    edge_exams = contains.get(graph_id, set())
    if row.get("expected_exam") not in actual_exams or row.get("expected_exam") not in edge_exams:
        if not row_decisions:
            errors.append(f"source row {row.get('source_row_id')} has silent direct-membership mismatch for {graph_id}")
    graph_headword = metadata.get("lexicalForm")
    if isinstance(row.get("source_headword"), str) and isinstance(graph_headword, str):
        if normalize(row["source_headword"]) != normalize(graph_headword) and not row_decisions:
            errors.append(f"source row {row.get('source_row_id')} has undocumented lexical-form mismatch for {graph_id}")
    graph_pos = set(metadata.get("partsOfSpeech", []))
    source_pos = set(row.get("source_parts_of_speech", [])) if isinstance(row.get("source_parts_of_speech"), list) else set()
    if source_pos and graph_pos != source_pos and not row_decisions:
        errors.append(f"source row {row.get('source_row_id')} has undocumented POS mismatch for {graph_id}")
    graph_forms = {normalize(value) for value in metadata.get("matchForms", []) if isinstance(value, str)}
    source_forms = {normalize(value) for value in row.get("source_forms", []) if isinstance(value, str)}
    if source_forms - graph_forms and not row_decisions:
        errors.append(f"source row {row.get('source_row_id')} has undocumented lexical-form/variant mismatch for {graph_id}")

# A source-to-graph audit must explain graph-only YLE memberships; inventory
# rows alone cannot make these extras disappear.
resolved_graph_refs = defaultdict(list)
for decision in decision_rows:
    if not isinstance(decision, dict):
        continue
    for graph_ref in decision.get("graph_refs", []) if isinstance(decision.get("graph_refs"), list) else []:
        resolved_graph_refs[graph_ref].append(decision)
for graph_id in sorted(yle_ids - matched_ids):
    candidates = [decision for decision in resolved_graph_refs.get(graph_id, []) if decision.get("finding_class") in {"false-include", "bad-merge"}]
    if not candidates:
        errors.append(f"current YLE graph skill lacks a source-row mapping or false-inclusion/bad-merge decision: {graph_id}")

# Every current direct membership must either be source-backed by a fixture row
# or have an explicit decision; cumulative levels may not be invented here.
actual_pairs = set()
for graph_id, exams in contains.items():
    for exam in exams:
        actual_pairs.add((graph_id, exam))
expected_pairs = {(graph_id, exam) for graph_id, exams in expected_by_graph.items() for exam in exams}
for graph_id, exam in sorted(actual_pairs - expected_pairs):
    if not any(decision.get("finding_class") in {"false-include", "bad-merge"} for decision in resolved_graph_refs.get(graph_id, [])):
        errors.append(f"graph direct membership has no source row or false-inclusion decision: {graph_id} -> {exam}")

print(f"Mapped graph skill count: {len(matched_ids)}")
print(f"Actual direct graph membership pairs: {len(actual_pairs)}")
if errors:
    print("; ".join(errors[:40]))
    if len(errors) > 40:
        print(f"Additional fixture comparison failures: {len(errors) - 40}")
    raise SystemExit(1)
PY
)"
if [[ -n "$fixture_errors" ]]; then
  fail "$fixture_errors"
else
  pass "all direct source rows compare to graph IDs, exams, forms, POS, MWEs, variants, and local PDF locations"
fi

echo "=== durable decisions, collision queue, and omission/false-inclusion coverage ==="
decision_errors="$(python3 - "$INVENTORY" "$GRAPH" "$DECISIONS" "$EXCEPTIONS" "$COLLISIONS" "$STARTERS_FIXTURE" "$MOVERS_FIXTURE" "$FLYERS_FIXTURE" <<'PY' 2>&1
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

inventory_path, graph_path, decisions_path, exceptions_path, collisions_path, *fixture_paths = map(Path, sys.argv[1:])
source_id = "cambridge-yle-word-list-2025"
allowed_statuses = {"open", "accepted", "rejected", "quarantined", "superseded"}
allowed_classes = {"omit", "false-include", "bad-merge", "group", "support", "other"}
errors = []

def jsonl(path, required=True):
    if not path.is_file():
        if required:
            errors.append(f"missing durable audit artifact: {path}")
        return []
    rows = []
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError as exc:
            errors.append(f"{path}:{line_number} invalid JSON: {exc}")
    return rows

def valid_source_location(location, label):
    if not isinstance(location, dict):
        errors.append(f"{label} source_location must be structured")
        return
    if not isinstance(location.get("pdf"), str) or not location["pdf"].endswith("source-pdfs/cambridge-yle-word-list-2025.pdf"):
        errors.append(f"{label} source_location must cite the local YLE PDF path")
    if not isinstance(location.get("pdf_page"), int) or not 1 <= location["pdf_page"] <= 44:
        errors.append(f"{label} source_location needs a PDF page from 1 through 44")
    if not isinstance(location.get("section"), str) or not location["section"].strip():
        errors.append(f"{label} source_location needs an official-list section")

try:
    inventory = json.loads(inventory_path.read_text(encoding="utf-8"))
    graph = json.loads(graph_path.read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError) as exc:
    print(f"cannot load tracked inventory/graph: {exc}")
    raise SystemExit(1)
decisions = jsonl(decisions_path)
exceptions = jsonl(exceptions_path)
collision_rows = jsonl(collisions_path)

decision_by_id = {}
for row in decisions:
    if not isinstance(row, dict):
        errors.append("decision log contains a non-object")
        continue
    decision_id = row.get("decision_id")
    if not isinstance(decision_id, str) or not decision_id.strip():
        errors.append("decision lacks stable decision_id")
        continue
    if decision_id in decision_by_id:
        errors.append(f"duplicate decision_id: {decision_id}")
    decision_by_id[decision_id] = row
    if row.get("status") not in allowed_statuses:
        errors.append(f"decision {decision_id} has unsupported status")
    if not isinstance(row.get("reviewer_role"), str) or not row["reviewer_role"].strip():
        errors.append(f"decision {decision_id} lacks reviewer_role")
    if not isinstance(row.get("reviewed_at"), str) or not re.match(r"^20[0-9]{2}-[0-9]{2}-[0-9]{2}(?:T|$)", row["reviewed_at"]):
        errors.append(f"decision {decision_id} lacks an ISO-8601 reviewed_at")
    valid_source_location(row.get("source_location"), f"decision {decision_id}")
    if not isinstance(row.get("graph_refs"), list):
        errors.append(f"decision {decision_id} lacks graph_refs list")
    if row.get("finding_class") not in allowed_classes:
        errors.append(f"decision {decision_id} has unsupported finding_class")
    for field in ("finding", "evidence", "disposition"):
        value = row.get(field)
        if value is None or (isinstance(value, str) and not value.strip()):
            errors.append(f"decision {decision_id} lacks {field}")
    for field in ("supersedes", "superseded_by"):
        if field not in row:
            errors.append(f"decision {decision_id} lacks {field} field")
    for key in ("source_excerpt", "source_text", "pdf_text", "pdf_contents"):
        if key in row:
            errors.append(f"decision {decision_id} commits publisher PDF content through {key}")

for path, rows in ((exceptions_path, exceptions), (collisions_path, collision_rows)):
    if not path.is_file():
        continue
    for row in rows:
        if not isinstance(row, dict):
            errors.append(f"{path} contains a non-object")
            continue
        if not isinstance(row.get("decision_id"), str) or row["decision_id"] not in decision_by_id:
            errors.append(f"{path} row references a missing decision_id")
        if path == exceptions_path:
            if row.get("severity") not in {"low", "medium", "high"}:
                errors.append("exception row lacks low/medium/high severity")
            for field in ("scope", "owner", "resolution"):
                if not isinstance(row.get(field), str) or not row[field].strip():
                    errors.append(f"exception row lacks {field}")

yle_nodes = [node for node in graph.get("nodes", []) if node.get("kind") == "skill" and source_id in node.get("sourceRefs", [])]
yle_ids = {node.get("id") for node in yle_nodes}
by_form = defaultdict(list)
for node in yle_nodes:
    normalized = node.get("metadata", {}).get("sourceNormalizedForm")
    if not isinstance(normalized, str):
        normalized = node.get("metadata", {}).get("lexicalForm", "")
    by_form[normalized.casefold()].append(node.get("id"))
collision_groups = {form: sorted(ids) for form, ids in by_form.items() if len(ids) > 1}
print(f"High-severity collision groups requiring review: {len(collision_groups)}")
if len(collision_rows) < len(collision_groups):
    errors.append(f"collision queue row count is below the high-severity collision group count: expected {len(collision_groups)}, found {len(collision_rows)}")
seen_collision_forms = set()
for row in collision_rows:
    if not isinstance(row, dict):
        continue
    form = row.get("normalized_form")
    if not isinstance(form, str) or form.casefold() not in collision_groups:
        errors.append(f"collision queue has unknown normalized_form: {form}")
        continue
    key = form.casefold()
    seen_collision_forms.add(key)
    if row.get("severity") != "high":
        errors.append(f"collision queue case {form} is not marked high severity")
    if not isinstance(row.get("graph_refs"), list) or set(row["graph_refs"]) != set(collision_groups[key]):
        errors.append(f"collision queue case {form} does not enumerate every colliding graph skill")
    decision_id = row.get("decision_id")
    decision = decision_by_id.get(decision_id)
    if decision is None or decision.get("finding_class") not in {"bad-merge", "false-include", "other"}:
        errors.append(f"collision queue case {form} lacks a durable bad-merge/false-include decision")
    if decision is not None and decision.get("status") == "open":
        errors.append(f"high-severity collision decision remains open: {decision_id}")
for form in sorted(set(collision_groups) - seen_collision_forms):
    errors.append(f"high-severity collision has no queue case: {form}")

# Every omission and every graph-only item needs a decision reference in the
# source-row fixtures or durable graph_refs; an inventory copy cannot hide it.
fixture_rows = []
for path in fixture_paths:
    for row in jsonl(path, required=False):
        if isinstance(row, dict):
            fixture_rows.append(row)
for row in fixture_rows:
    if row.get("status") == "omission":
        if not row.get("decision_ids"):
            errors.append(f"omission row lacks decision_ids: {row.get('source_row_id')}")
        for decision_id in row.get("decision_ids", []):
            if decision_id not in decision_by_id:
                errors.append(f"omission row references missing decision_id: {decision_id}")

print(f"Durable membership decision count: {len(decisions)}")
print(f"Exception-list row count: {len(exceptions)}")
if errors:
    print("; ".join(errors[:50]))
    if len(errors) > 50:
        print(f"Additional decision/collision failures: {len(errors) - 50}")
    raise SystemExit(1)
PY
)"
if [[ -n "$decision_errors" ]]; then
  fail "$decision_errors"
else
  pass "omissions, false inclusions, POS/variant decisions, and every high-severity collision have durable records"
fi

echo "=== report metrics, cumulative consumption policy, and blocker count are executable ==="
report_errors="$(python3 - "$INVENTORY" "$GRAPH" "$REPORT" "$DECISIONS" "$EXCEPTIONS" "$COLLISIONS" "$STARTERS_FIXTURE" "$MOVERS_FIXTURE" "$FLYERS_FIXTURE" <<'PY' 2>&1
import json
import math
import re
import sys
from collections import defaultdict
from pathlib import Path

inventory_path, graph_path, report_path, decisions_path, exceptions_path, collisions_path, *fixture_paths = map(Path, sys.argv[1:])
source_id = "cambridge-yle-word-list-2025"
exam_ids = {"pre-a1-starters", "a1-movers", "a2-flyers"}
errors = []

def read_json(path):
    if not path.is_file():
        errors.append(f"missing report/artifact: {path}")
        return {}
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        errors.append(f"{path} is not valid JSON: {exc}")
        return {}
    if not isinstance(value, dict):
        errors.append(f"{path} must contain a JSON object")
        return {}
    return value

def jsonl(path):
    if not path.is_file():
        return []
    rows = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.strip():
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError:
                pass
    return [row for row in rows if isinstance(row, dict)]

def labeled_metric(metrics, key, label, threshold=None):
    metric = metrics.get(key)
    if not isinstance(metric, dict):
        errors.append(f"missing labeled metric: {key}")
        return None
    if metric.get("label") != label:
        errors.append(f"metric {key} has no exact label {label}")
    value = metric.get("value")
    if not isinstance(value, (int, float)) or isinstance(value, bool) or not math.isfinite(value):
        errors.append(f"metric {key} lacks numeric value")
        return None
    if threshold is not None and value < threshold:
        errors.append(f"metric {key} is below threshold {threshold}: {value}")
    return metric

def compare_metric(metrics, key, label, numerator, denominator, threshold):
    metric = labeled_metric(metrics, key, label, threshold)
    if metric is None:
        return
    if metric.get("numerator") != numerator or metric.get("denominator") != denominator:
        errors.append(f"metric {key} numerator/denominator does not match executable comparison: expected {numerator}/{denominator}")
    expected_value = numerator / denominator if denominator else 0.0
    if abs(metric.get("value", -1) - expected_value) > 1e-9:
        errors.append(f"metric {key} value does not match numerator/denominator")
    if metric.get("population") != "all-current-yle-source-rows":
        errors.append(f"metric {key} does not declare the full source-row population")

try:
    inventory = json.loads(inventory_path.read_text(encoding="utf-8"))
    graph = json.loads(graph_path.read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError) as exc:
    print(f"cannot load tracked inventory/graph: {exc}")
    raise SystemExit(1)
report = read_json(report_path)
decisions = jsonl(decisions_path)
exceptions = jsonl(exceptions_path)
collision_rows = jsonl(collisions_path)
fixture_rows = []
for path in fixture_paths:
    fixture_rows.extend(jsonl(path))
yle_inventory = [row for row in inventory if source_id in row.get("sourceRefs", [])]
yle_nodes = [node for node in graph.get("nodes", []) if node.get("kind") == "skill" and source_id in node.get("sourceRefs", [])]
yle_ids = {node.get("id") for node in yle_nodes}
exam_nodes = {f"english.vocabulary.exam.{exam}": exam for exam in exam_ids}
actual_pairs = set()
for edge in graph.get("edges", []):
    if edge.get("type") == "contains" and edge.get("sourceId") in exam_nodes and edge.get("targetId") in yle_ids:
        actual_pairs.add((edge.get("targetId"), exam_nodes[edge.get("sourceId")]))
source_pairs = set()
correct_source_rows = 0
for row in fixture_rows:
    if row.get("status") == "matched" and isinstance(row.get("graph_skill_id"), str):
        pair = (row["graph_skill_id"], row.get("expected_exam"))
        source_pairs.add(pair)
        if pair in actual_pairs:
            correct_source_rows += 1
precision_tp = len(actual_pairs & source_pairs)
print(f"Current YLE skill count: {len(yle_inventory)}")
print(f"Source membership row count: {len(fixture_rows)}")
print(f"Graph direct membership pair count: {len(actual_pairs)}")
print(f"Membership precision true-positive count: {precision_tp}")
print(f"Membership recall correct-row count: {correct_source_rows}")

if report.get("source_ref") != source_id:
    errors.append("report source_ref is not the official YLE source ID")
if report.get("source_pdf") != "source-pdfs/cambridge-yle-word-list-2025.pdf":
    errors.append("report source_pdf must be a local source-location reference")
if report.get("source_sha256") != "6f7a0ad1e277bd10ae8b3bcccfb76c058f611a607c6c9947601abbd7e16a99fa":
    errors.append("report source_sha256 does not match the registered YLE PDF")
if report.get("coverage_scope") != "all-current-yle-source-rows":
    errors.append("report must claim all-current-yle-source-rows, not an inventory-only sample")
source_population = report.get("source_population")
if not isinstance(source_population, dict):
    errors.append("report lacks source_population")
else:
    if source_population.get("method") != "official-local-pdf":
        errors.append("source_population method must be official-local-pdf")
    if source_population.get("inventory_independent") is not True:
        errors.append("source_population must explicitly be independent of the inventory under test")
for key, expected in (
    ("source_row_count", sum(sum(exam in row.get("exams", []) for row in yle_inventory) for exam in exam_ids)),
    ("unique_skill_count", len(yle_inventory)),
    ("fixture_row_count", len(fixture_rows)),
):
    if report.get(key) != expected:
        errors.append(f"report {key} mismatch: expected {expected}, found {report.get(key)}")
covered_ids = {row.get("graph_skill_id") for row in fixture_rows if row.get("status") == "matched" and isinstance(row.get("graph_skill_id"), str)}
for decision in decisions:
    for graph_ref in decision.get("graph_refs", []) if isinstance(decision.get("graph_refs"), list) else []:
        if graph_ref in yle_ids:
            covered_ids.add(graph_ref)
if report.get("graph_skill_coverage_count") != len(covered_ids) or len(covered_ids) != len(yle_ids):
    errors.append(f"report graph skill coverage is not complete: covered {len(covered_ids)} of current YLE skill count {len(yle_ids)}")

metrics = report.get("metrics") if isinstance(report.get("metrics"), dict) else {}
compare_metric(metrics, "alphabetical_membership_precision", "YLE alphabetical membership precision", precision_tp, len(actual_pairs), 0.995)
compare_metric(metrics, "alphabetical_membership_recall", "YLE alphabetical membership recall", correct_source_rows, len(fixture_rows), 0.99)

identity = report.get("identity_coverage")
if not isinstance(identity, dict):
    errors.append("report lacks identity_coverage")
else:
    counts = {
        "lexical_form_rows": len(fixture_rows),
        "pos_rows": sum(bool(row.get("source_parts_of_speech")) for row in fixture_rows),
        "mwe_rows": sum(bool(row.get("is_mwe")) for row in fixture_rows),
        "variant_rows": sum(bool(row.get("is_variant")) for row in fixture_rows),
    }
    labels = {
        "lexical_form_rows": "YLE lexical-form rows reviewed",
        "pos_rows": "YLE POS rows reviewed",
        "mwe_rows": "YLE MWE rows reviewed",
        "variant_rows": "YLE variant rows reviewed",
    }
    for key, expected in counts.items():
        value = identity.get(key)
        if not isinstance(value, dict) or value.get("label") != labels[key] or value.get("reviewed_rows") != expected:
            errors.append(f"identity coverage {key} is not a labeled full-population count")
    if identity.get("all_rows_have_identity_fields") is not True:
        errors.append("identity coverage does not assert complete lexical/POS/MWE/variant fields")

cumulative = report.get("cumulative_interpretation")
if not isinstance(cumulative, dict):
    errors.append("report lacks cumulative_interpretation")
else:
    if cumulative.get("mode") != "consumption-policy-only":
        errors.append("cumulative interpretation must be a consumption-policy-only rule")
    if cumulative.get("movers_inherits") != ["pre-a1-starters"]:
        errors.append("Movers cumulative policy must inherit Starters in consumption")
    if cumulative.get("flyers_inherits") != ["pre-a1-starters", "a1-movers"]:
        errors.append("Flyers cumulative policy must inherit Starters and Movers in consumption")
    if cumulative.get("duplicate_membership_edges") is not False:
        errors.append("cumulative policy must not add duplicate membership edges")
    if cumulative.get("prerequisite_edges_added") != 0:
        errors.append("cumulative policy must add zero prerequisite edges")
prerequisite_count = sum(edge.get("type") == "prerequisite_for" for edge in graph.get("edges", []))
print(f"prerequisite_for count: {prerequisite_count}")
if prerequisite_count != 0:
    errors.append("graph contains a prerequisite_for edge; cumulative need is not a hard prerequisite")

quality = report.get("quality") if isinstance(report.get("quality"), dict) else {}
blocker_metric = quality.get("unresolved_high_severity_blockers")
if not isinstance(blocker_metric, dict) or blocker_metric.get("label") != "Unresolved high-severity blockers" or blocker_metric.get("value") != 0:
    errors.append("report must contain labeled Unresolved high-severity blockers: 0")
open_high = []
for row in exceptions:
    if row.get("severity") == "high" and row.get("status", "open") in {"open", "unresolved"}:
        open_high.append(row.get("decision_id"))
for row in collision_rows:
    if row.get("severity") == "high" and row.get("status", "open") in {"open", "unresolved"}:
        open_high.append(row.get("decision_id"))
for row in decisions:
    if row.get("severity") == "high" and row.get("status") == "open":
        open_high.append(row.get("decision_id"))
if open_high:
    errors.append(f"unresolved high-severity blocker decision IDs: {open_high}")

print(f"Unresolved high-severity blockers: {len(open_high)}")
if errors:
    print("; ".join(errors[:40]))
    if len(errors) > 40:
        print(f"Additional report failures: {len(errors) - 40}")
    raise SystemExit(1)
PY
)"
if [[ -n "$report_errors" ]]; then
  fail "$report_errors"
else
  pass "full-population precision/recall, identity coverage, cumulative policy, and zero-blocker metrics agree with graph comparisons"
fi

echo "=== thematic memberships and grammatical-list treatment are explicitly audited ==="
group_errors="$(python3 - "$GRAPH" "$THEMATIC" "$GRAMMATICAL" "$REPORT" "$DECISIONS" <<'PY' 2>&1
import json
import math
import re
import sys
from collections import defaultdict
from pathlib import Path

graph_path, thematic_path, grammatical_path, report_path, decisions_path = map(Path, sys.argv[1:])
source_id = "cambridge-yle-word-list-2025"
errors = []

def load_json(path, label):
    if not path.is_file():
        errors.append(f"missing {label}: {path}")
        return {}
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        errors.append(f"{label} is invalid JSON: {exc}")
        return {}
    return value

def load_jsonl(path, label):
    if not path.is_file():
        errors.append(f"missing {label}: {path}")
        return []
    rows = []
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError as exc:
            errors.append(f"{label}:{line_number} invalid JSON: {exc}")
    return rows

graph = load_json(graph_path, "graph")
thematic_rows = load_jsonl(thematic_path, "thematic fixture")
grammatical = load_json(grammatical_path, "grammatical-list decision")
decisions = load_jsonl(decisions_path, "decision log")
by_decision = {row.get("decision_id"): row for row in decisions if isinstance(row, dict)}

groups = [node for node in graph.get("nodes", []) if node.get("kind") == "content_group" and node.get("metadata", {}).get("source") == source_id and node.get("metadata", {}).get("groupType") == "topic"]
group_by_title = {node.get("title"): node for node in groups}
print(f"YLE thematic group count: {len(groups)}")
if len(groups) != 20:
    errors.append(f"current graph has unexpected YLE thematic group count: {len(groups)}")
if len(thematic_rows) < 100:
    errors.append(f"INCOMPLETE: thematic reviewed membership row count: {len(thematic_rows)}; minimum is 100")
seen_groups = set()
contains = {(edge.get("sourceId"), edge.get("targetId")) for edge in graph.get("edges", []) if edge.get("type") == "contains"}
tp = 0
predicted = 0
for row in thematic_rows:
    if not isinstance(row, dict):
        errors.append("thematic fixture contains a non-object")
        continue
    title = row.get("source_group_title")
    group = group_by_title.get(title)
    if group is None:
        errors.append(f"thematic fixture references unknown retained group: {title}")
        continue
    seen_groups.add(title)
    location = row.get("source_location")
    if not isinstance(location, dict) or not isinstance(location.get("pdf_page"), int) or not 38 <= location.get("pdf_page", 0) <= 43:
        errors.append(f"thematic row {row.get('review_id')} lacks a thematic-list PDF page 38 through 43")
    if not isinstance(location, dict) or not isinstance(location.get("pdf"), str) or not location["pdf"].endswith("source-pdfs/cambridge-yle-word-list-2025.pdf"):
        errors.append(f"thematic row {row.get('review_id')} lacks local YLE PDF source location")
    graph_id = row.get("graph_skill_id")
    actual = (group.get("id"), graph_id) in contains
    source_membership = row.get("source_membership")
    if not isinstance(source_membership, bool):
        errors.append(f"thematic row {row.get('review_id')} lacks boolean source_membership")
        continue
    if actual:
        predicted += 1
        if source_membership:
            tp += 1
    if actual != source_membership:
        decision_ids = row.get("decision_ids") if isinstance(row.get("decision_ids"), list) else []
        if not decision_ids or not any(decision_id in by_decision for decision_id in decision_ids):
            errors.append(f"thematic graph/source disagreement lacks a decision: {row.get('review_id')}")
    if not isinstance(row.get("source_headword"), str) or not row["source_headword"].strip():
        errors.append(f"thematic row {row.get('review_id')} lacks source_headword")
    for key in ("source_excerpt", "source_text", "pdf_text", "pdf_contents"):
        if key in row:
            errors.append(f"thematic row {row.get('review_id')} commits publisher PDF content through {key}")
if seen_groups != set(group_by_title):
    errors.append(f"thematic fixture does not cover every retained YLE topic group; missing: {sorted(set(group_by_title) - seen_groups)}")

report = load_json(report_path, "YLE membership report")
thematic_report = report.get("thematic") if isinstance(report, dict) else None
if not isinstance(thematic_report, dict):
    errors.append("report lacks thematic quality section")
else:
    if thematic_report.get("source_group_count") != len(groups):
        errors.append("thematic report source_group_count does not match graph")
    if thematic_report.get("reviewed_membership_count") != len(thematic_rows):
        errors.append("thematic report reviewed_membership_count does not match executable fixture rows")
    metric = thematic_report.get("membership_precision")
    expected_precision = tp / predicted if predicted else 0.0
    if not isinstance(metric, dict) or metric.get("label") != "YLE thematic membership precision":
        errors.append("thematic precision lacks the required label")
    else:
        if metric.get("numerator") != tp or metric.get("denominator") != predicted:
            errors.append("thematic precision numerator/denominator does not match executable graph comparison")
        if not isinstance(metric.get("value"), (int, float)) or abs(metric.get("value", -1) - expected_precision) > 1e-9:
            errors.append("thematic precision value does not match executable graph comparison")
        if metric.get("value", 0) < 0.98:
            errors.append("thematic membership precision is below the 0.98 threshold")

if not isinstance(grammatical, dict):
    errors.append("grammatical-list decision must be a JSON object")
else:
    if grammatical.get("handling") not in {"represented", "accepted-omission"}:
        errors.append("grammatical-list handling must be represented or accepted-omission")
    for field in ("decision_id", "status", "reviewer_role", "reviewed_at", "source_location", "finding_class", "finding", "evidence", "disposition", "supersedes", "superseded_by"):
        if field not in grammatical:
            errors.append(f"grammatical-list decision lacks {field}")
    decision_id = grammatical.get("decision_id")
    if decision_id not in by_decision:
        errors.append("grammatical-list decision is not linked to membership-decisions.jsonl")
    location = grammatical.get("source_location")
    if not isinstance(location, dict) or not isinstance(location.get("pdf_page"), int) or not 31 <= location.get("pdf_page", 0) <= 37:
        errors.append("grammatical-list decision must cite the local grammatical-list pages 31 through 37")
    if grammatical.get("handling") == "accepted-omission" and not isinstance(grammatical.get("rationale"), str):
        errors.append("accepted grammatical-list omission lacks a rationale")
    if grammatical.get("handling") == "represented" and not grammatical.get("graph_refs"):
        errors.append("represented grammatical lists must cite graph group references")

print(f"Thematic reviewed membership row count: {len(thematic_rows)}")
print(f"Thematic precision numerator: {tp}")
print(f"Thematic precision denominator: {predicted}")
if errors:
    print("; ".join(errors[:40]))
    if len(errors) > 40:
        print(f"Additional group-treatment failures: {len(errors) - 40}")
    raise SystemExit(1)
PY
)"
if [[ -n "$group_errors" ]]; then
  fail "$group_errors"
else
  pass "all 20 YLE topic groups meet the reviewed sample contract and grammatical lists have an explicit decision"
fi

echo "=== attributable curriculum approval exists for the Phase 2 fidelity audit ==="
approval_errors="$(python3 - "$APPROVAL" <<'PY' 2>&1
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
if not path.is_file():
    print(f"missing attributable curriculum approval: {path}")
    raise SystemExit(1)
text = path.read_text(encoding="utf-8")
errors = []
if not re.search(r"\b(?:decision|recommendation)\s*:\s*(?:go|conditional-go)\b", text, re.IGNORECASE):
    errors.append("approval must record go or conditional-go, not a draft or no-go")
if not re.search(r"curriculum[ /-]*language", text, re.IGNORECASE):
    errors.append("approval lacks curriculum/language owner role")
if not re.search(r"\b(?:owner|reviewer|approved by)\s*:\s*[^\n]+", text, re.IGNORECASE):
    errors.append("approval lacks an attributable owner/reviewer field")
if re.search(r"\b(?:owner|reviewer|approved by)\s*:\s*(?:tbd|pending|anonymous|unknown|\[.*?\])\b", text, re.IGNORECASE):
    errors.append("approval owner/reviewer is a placeholder")
if not re.search(r"\b20[0-9]{2}-[0-9]{2}-[0-9]{2}\b", text):
    errors.append("approval lacks an ISO date")
if not re.search(r"YLE|membership|fidelity", text, re.IGNORECASE):
    errors.append("approval does not identify the YLE fidelity scope")
if errors:
    print("; ".join(errors))
    raise SystemExit(1)
PY
)"
if [[ -n "$approval_errors" ]]; then
  fail "$approval_errors"
else
  pass "curriculum/language approval is attributable, dated, and scoped to YLE fidelity"
fi

printf '%s\n' "${RESULTS[@]}"
echo "=== Total: $((PASS_COUNT + FAIL_COUNT)) checks (PASS=$PASS_COUNT, FAIL=$FAIL_COUNT) ==="
exit "$FAILED"
