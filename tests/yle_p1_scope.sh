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
PLAN="$TRACK_DIR/plan.md"
SCOPE="$ROOT/english/cefr-vocabulary/review/yle-2025/phase1-scope.md"
INVENTORY="$ROOT/english/cefr-vocabulary/data/cambridge-vocabulary-inventory.json"
GRAPH="$ROOT/english/cefr-vocabulary/cefr-vocabulary-knowledge-space.json"
SOURCES="$ROOT/english/cefr-vocabulary/SOURCES.md"
SOURCE_ID="cambridge-yle-word-list-2025"
SOURCE_URL="https://www.cambridgeenglish.org/Images/739104-starters-movers-flyers-word-list-2025.pdf"
SOURCE_SHA="6f7a0ad1e277bd10ae8b3bcccfb76c058f611a607c6c9947601abbd7e16a99fa"

# Phase 1 must be Red until the scope-lock artifact exists.  Counts are derived
# from tracked inputs and matched only through labeled fields (anti-pattern A3).
echo "=== no legacy task markers in the track plan ==="
if [[ ! -f "$PLAN" ]]; then
  fail "track plan is missing"
elif rg -n '^- \[ \] ' "$PLAN" >/dev/null 2>&1; then
  fail "legacy [ ] task marker remains in plan.md"
else
  pass "plan uses only the current task-marker vocabulary"
fi

echo "=== labeled baseline facts and official source identity ==="
fact_errors="$(python3 - "$SCOPE" "$INVENTORY" "$GRAPH" "$SOURCES" \
  "$SOURCE_ID" "$SOURCE_URL" "$SOURCE_SHA" <<'PY' 2>&1
import json
import re
import sys
from pathlib import Path

scope_path, inventory_path, graph_path, sources_path, source_id, source_url, source_sha = sys.argv[1:]
errors = []
scope = Path(scope_path)
if not scope.is_file():
    print(f"missing {scope_path}")
    raise SystemExit(1)

text = scope.read_text(encoding="utf-8")
with open(inventory_path, encoding="utf-8") as handle:
    inventory = json.load(handle)
with open(graph_path, encoding="utf-8") as handle:
    graph = json.load(handle)

yle_skills = [entry for entry in inventory if source_id in entry.get("sourceRefs", [])]
yle_ids = {
    node["id"] for node in graph["nodes"]
    if node.get("kind") == "skill" and source_id in node.get("sourceRefs", [])
}
expected = {
    "YLE skill count:": len(yle_skills),
    "Starters membership:": sum("pre-a1-starters" in entry.get("exams", []) for entry in yle_skills),
    "Movers membership:": sum("a1-movers" in entry.get("exams", []) for entry in yle_skills),
    "Flyers membership:": sum("a2-flyers" in entry.get("exams", []) for entry in yle_skills),
    "YLE topic group count:": sum(
        node.get("kind") == "content_group"
        and node.get("metadata", {}).get("source") == source_id
        and node.get("metadata", {}).get("groupType") == "topic"
        for node in graph["nodes"]
    ),
    "YLE-touching supports count:": sum(
        edge.get("type") == "supports"
        and (edge.get("sourceId") in yle_ids or edge.get("targetId") in yle_ids)
        for edge in graph["edges"]
    ),
    "prerequisite_for count:": sum(
        edge.get("type") == "prerequisite_for" for edge in graph["edges"]
    ),
}
for label, expected_value in expected.items():
    pattern = re.compile(
        rf"^\s*(?:[-*]\s*)?{re.escape(label)}\s*([0-9]+)\s*$",
        re.MULTILINE,
    )
    matches = pattern.findall(text)
    if len(matches) != 1:
        errors.append(f"{label} missing or not a single labeled integer")
    elif int(matches[0]) != expected_value:
        errors.append(f"{label} expected {expected_value}, found {matches[0]}")

for required in (source_id, source_url, source_sha):
    if required not in text:
        errors.append(f"scope does not cite {required}")
if source_sha not in Path(sources_path).read_text(encoding="utf-8"):
    errors.append("SOURCES.md does not contain the frozen YLE SHA-256")

if errors:
    print("; ".join(errors))
    raise SystemExit(1)
PY
)" || true
if [[ -n "$fact_errors" ]]; then
  fail "$fact_errors"
else
  pass "labeled counts match the tracked inventory/graph and source registry"
fi

echo "=== fact-vs-signal catalog labels YLE edge classes ==="
catalog_errors="$(python3 - "$SCOPE" <<'PY' 2>&1
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
if not path.is_file():
    print(f"missing {path}")
    raise SystemExit(1)
rows = path.read_text(encoding="utf-8").splitlines()
required = {
    "contains": "source-backed fact",
    "aligned_to_standard": "source-backed fact",
    "supports": "derived support signal",
}
errors = []
for edge_type, classification in required.items():
    matches = []
    for row in rows:
        match = re.match(r"^\|\s*([^|]+?)\s*\|", row)
        if match and match.group(1).strip().strip("`") == edge_type:
            matches.append(row.lower())
    if len(matches) != 1:
        errors.append(f"{edge_type} catalog row count is {len(matches)}")
    elif classification not in matches[0]:
        errors.append(f"{edge_type} row lacks {classification}")
if errors:
    print("; ".join(errors))
    raise SystemExit(1)
PY
)" || true
if [[ -n "$catalog_errors" ]]; then
  fail "$catalog_errors"
else
  pass "contains/aligned_to_standard are facts and supports is a derived signal"
fi

echo "=== Phase 1 rules prohibit hard prerequisite_for edges ==="
prerequisite_errors="$(python3 - "$SCOPE" <<'PY' 2>&1
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
if not path.is_file():
    print(f"missing {path}")
    raise SystemExit(1)
rows = path.read_text(encoding="utf-8").splitlines()
matches = []
for row in rows:
    match = re.match(r"^\|\s*([^|]+?)\s*\|", row)
    if match and match.group(1).strip().strip("`") == "prerequisite_for":
        matches.append(row.lower())
if len(matches) != 1:
    print(f"prerequisite_for catalog row count is {len(matches)}")
    raise SystemExit(1)
row = matches[0]
if "prohibit" not in row or not re.search(r"\b(?:zero|none|0)\b", row):
    print("prerequisite_for row must explicitly prohibit non-zero edges")
    raise SystemExit(1)
PY
)" || true
if [[ -n "$prerequisite_errors" ]]; then
  fail "$prerequisite_errors"
else
  pass "prerequisite_for is explicitly prohibited at zero edges"
fi

echo "=== Phase 1 human approval markers have owner/date evidence ==="
approval_errors="$(python3 - "$PLAN" "$ROOT/english/cefr-vocabulary/review/yle-2025/phase1-approval.md" <<'PY' 2>&1
import re
import sys
from pathlib import Path

plan_path, approval_path = map(Path, sys.argv[1:])
if not plan_path.is_file():
    print(f"missing {plan_path}")
    raise SystemExit(1)
text = plan_path.read_text(encoding="utf-8")
match = re.search(
    r"^## Phase 1: Freeze Scope, Facts Inventory, And Review Rules$.*?^## Phase 2:",
    text,
    re.MULTILINE | re.DOTALL,
)
phase = match.group(0) if match else ""
claims = [
    line for line in phase.splitlines()
    if re.match(r"^- \[x\] ", line)
    and re.search(r"Approve Phase 1 rules|owner accepts|human-gate", line, re.IGNORECASE)
]
if claims:
    if not approval_path.is_file():
        print("completed human approval task lacks phase1-approval.md")
        raise SystemExit(1)
    approval = approval_path.read_text(encoding="utf-8")
    if not re.search(r"\b(?:owner|reviewer|role)\b", approval, re.IGNORECASE):
        print("phase1-approval.md lacks an owner or reviewer field")
        raise SystemExit(1)
    if not re.search(r"\bdate\b|\b20[0-9]{2}-[0-9]{2}-[0-9]{2}\b", approval, re.IGNORECASE):
        print("phase1-approval.md lacks a date field")
        raise SystemExit(1)
PY
)" || true
if [[ -n "$approval_errors" ]]; then
  fail "$approval_errors"
else
  pass "no human approval is marked complete without owner/date evidence"
fi

printf '%s\n' "${RESULTS[@]}"
echo "=== Total: $((PASS_COUNT + FAIL_COUNT)) checks (PASS=$PASS_COUNT, FAIL=$FAIL_COUNT) ==="
exit "$FAILED"
