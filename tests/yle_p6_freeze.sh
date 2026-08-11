#!/usr/bin/env bash
# Phase 6 Red/Green harness: YLE freeze package + bounded one-shot sanity.
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
TRACKS_MD="$ROOT/measure/tracks.md"
GRAPH="$ROOT/english/cefr-vocabulary/cefr-vocabulary-knowledge-space.json"
SOURCES="$ROOT/english/cefr-vocabulary/SOURCES.md"
REVIEW="$ROOT/english/cefr-vocabulary/review/yle-2025"
RELEASE="$REVIEW/RELEASE-YLE-2025.md"
QUALITY="$REVIEW/quality-summary.md"
READING_INDEX="$REVIEW/reading-fixture-index.md"
METHOD_APPENDIX="$REVIEW/method-appendix-a2-b1.md"
CONSUMPTION="$ROOT/english/cefr-vocabulary/YLE-CONSUMPTION.md"
VALIDATOR="$ROOT/english/cefr-vocabulary/scripts/validate-vocabulary-graph.js"
SOURCE_SHA="6f7a0ad1e277bd10ae8b3bcccfb76c058f611a607c6c9947601abbd7e16a99fa"
SOURCE_ID="cambridge-yle-word-list-2025"

echo "=== Phase 6 plan markers and honest completion state ==="
plan_output="$(python3 - "$PLAN" "$TRACKS_MD" <<'PY'
import re
import sys
from pathlib import Path

plan_path, tracks_path = map(Path, sys.argv[1:])
errors = []
plan = plan_path.read_text(encoding="utf-8") if plan_path.is_file() else ""
tracks = tracks_path.read_text(encoding="utf-8") if tracks_path.is_file() else ""
phase_matches = list(re.finditer(r"^## Phase 6: Freeze Package, Sanity Check, And Decision[ \t]*$", plan, re.M))
if len(phase_matches) != 1:
    errors.append("Phase 6 heading not uniquely resolvable")
    phase = plan
else:
    phase = plan[phase_matches[0].end():]
completed = len(re.findall(r"^- \[x\][ \t]+Task:", phase, re.M))
blocked = len(re.findall(r"^- \[b\][ \t]+Task:", phase, re.M))
if re.findall(r"^- \[ \][ \t]", phase, re.M):
    errors.append("legacy [ ] remains in Phase 6")
after = plan[phase_matches[0].start():] if phase_matches else plan
if "yle_p6_freeze.sh" not in after:
    errors.append("Phase 6 plan/evidence lacks yle_p6_freeze.sh")
# Dual human decision may be [b] (open) or [x] (with phase6-approval evidence).
if not re.search(r"^- \[[bx]\][ \t]+Task: Dual human freeze decision", phase, re.M):
    errors.append("dual human freeze decision task missing")
print(f"Phase 6 completed task count: {completed}")
print(f"Phase 6 human-gate task count: {blocked}")
if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
PY
)"
plan_status=$?
printf '%s\n' "$plan_output"
if [[ "$plan_status" -ne 0 ]]; then
  fail "Phase 6 plan/tracks honesty check failed"
else
  pass "Phase 6 plan markers and tracks honesty are valid"
fi

echo "=== freeze package required files ==="
pkg_output="$(python3 - "$REVIEW" "$RELEASE" "$QUALITY" "$READING_INDEX" "$METHOD_APPENDIX" "$CONSUMPTION" <<'PY'
import sys
from pathlib import Path

review, release, quality, reading, method, consumption = map(Path, sys.argv[1:])
required = [
    release,
    quality,
    reading,
    method,
    consumption,
    review / "membership-decisions.jsonl",
    review / "membership-exceptions.jsonl",
    review / "support-inventory.json",
    review / "support-class-dispositions.json",
    review / "progression-policy.md",
    review / "phase1-scope.md",
]
errors = []
for path in required:
    if not path.is_file():
        errors.append(f"missing package file: {path}")
print(f"Required package files checked: {len(required)}")
if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
# A2/B1 method appendix must exist and disclaim release authority.
text = method.read_text(encoding="utf-8")
if "A2" not in text or "B1" not in text:
    print("method appendix lacks A2/B1", file=sys.stderr)
    raise SystemExit(1)
if "not" not in text.lower() and "Not" not in text:
    print("method appendix must disclaim current release authority", file=sys.stderr)
    raise SystemExit(1)
print("Method appendix present with A2/B1 later-method note")
PY
)"
pkg_status=$?
printf '%s\n' "$pkg_output"
if [[ "$pkg_status" -ne 0 ]]; then
  fail "freeze package files missing"
else
  pass "freeze package files and A2/B1 method appendix are present"
fi

echo "=== RELEASE decision honesty (unsigned draft or dual go freeze) ==="
release_output="$(python3 - "$RELEASE" "$PLAN" "$REVIEW/phase6-approval.md" <<'PY'
import re
import sys
from pathlib import Path

release_path, plan_path, approval_path = map(Path, sys.argv[1:])
errors = []
if not release_path.is_file():
    errors.append("missing RELEASE-YLE-2025.md")
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
text = release_path.read_text(encoding="utf-8")
print(f"RELEASE-YLE-2025.md bytes: {len(text.encode('utf-8'))}")
for label in (
    "YLE skill count:",
    "Starters membership:",
    "Movers membership:",
    "Flyers membership:",
    "prerequisite_for count:",
    "YLE-touching supports count:",
):
    if label not in text:
        errors.append(f"RELEASE lacks labeled metric {label}")

plan = plan_path.read_text(encoding="utf-8") if plan_path.is_file() else ""
phase = ""
m = re.search(r"^## Phase 6:.*$", plan, re.M)
if m:
    phase = plan[m.end():]
dual_x = bool(re.search(r"^- \[x\][ \t]+Task: Dual human freeze decision", phase, re.M))
dual_b = bool(re.search(r"^- \[b\][ \t]+Task: Dual human freeze decision", phase, re.M))
curr_go = bool(re.search(r"\|\s*Curriculum[^\n]*\|\s*(go|conditional-go)\s*\|", text, re.I))
eng_go = bool(re.search(r"\|\s*Engineering[^\n]*\|\s*(go|conditional-go)\s*\|", text, re.I))

if dual_b:
    if curr_go and eng_go and not re.search(r"signed by|signature:|approved by|owner:", text, re.I):
        errors.append("RELEASE claims go decisions while dual task remains [b] without attributable signatures")
    if not (curr_go and eng_go):
        if "_pending_" not in text and "pending" not in text.lower() and "unsigned" not in text.lower():
            errors.append("dual decision still [b] but RELEASE does not show pending/unsigned state")
    print("RELEASE draft decision section is honestly unsigned/pending")
elif dual_x:
    if not approval_path.is_file():
        errors.append("dual freeze [x] requires phase6-approval.md")
    else:
        appr = approval_path.read_text(encoding="utf-8")
        if not re.search(r"\b(?:decision|recommendation)\s*:\s*(?:go|conditional-go)\b", appr, re.I):
            errors.append("phase6-approval.md lacks go or conditional-go")
        if not re.search(r"curriculum[ /-]*language", appr, re.I):
            errors.append("phase6-approval.md lacks curriculum/language owner")
        if not re.search(r"engineering", appr, re.I):
            errors.append("phase6-approval.md lacks engineering owner")
    if not (curr_go and eng_go):
        errors.append("frozen RELEASE must record curriculum and engineering go/conditional-go")
    if "frozen" not in text.lower() and "freeze" not in text.lower():
        errors.append("RELEASE lacks freeze status wording")
    print("RELEASE freeze decision section records dual go with phase6-approval")
else:
    errors.append("dual freeze task marker missing")

if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
PY
)"
release_status=$?
printf '%s\n' "$release_output"
if [[ "$release_status" -ne 0 ]]; then
  fail "RELEASE honesty/labeled-metrics check failed"
else
  pass "RELEASE-YLE-2025.md decision section is honest for draft or frozen state"
fi

echo "=== source identity (SOURCES.md SHA-256) ==="
if [[ -f "$SOURCES" ]] && grep -q "$SOURCE_ID" "$SOURCES" && grep -q "$SOURCE_SHA" "$SOURCES"; then
  echo "SOURCES.md cites $SOURCE_ID and SHA-256"
  pass "YLE source identity is registered in SOURCES.md"
else
  fail "SOURCES.md missing YLE source id or SHA-256"
fi

echo "=== bounded structural sanity: validate graph + labeled live counts ==="
sanity_output="$(python3 - "$GRAPH" "$VALIDATOR" "$RELEASE" "$SOURCE_SHA" <<'PY'
import json
import re
import subprocess
import sys
from pathlib import Path

graph_path = Path(sys.argv[1])
validator = Path(sys.argv[2])
release_path = Path(sys.argv[3])
source_sha = sys.argv[4]
errors = []
YLE = {"pre-a1-starters", "a1-movers", "a2-flyers"}

proc = subprocess.run(
    ["node", str(validator)],
    cwd=str(graph_path.parent),
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
)
print(proc.stdout.strip())
if proc.returncode != 0:
    errors.append(f"validate-vocabulary-graph.js failed: {proc.stderr.strip()}")

graph = json.loads(graph_path.read_text(encoding="utf-8"))
nodes = graph.get("nodes", [])
edges = graph.get("edges", [])
ids = [node.get("id") for node in nodes]
if len(ids) != len(set(ids)):
    errors.append("duplicate node ids")
# dangling edges
node_ids = set(ids)
for edge in edges:
    if edge.get("sourceId") not in node_ids or edge.get("targetId") not in node_ids:
        errors.append(f"dangling edge {edge.get('id')}")
        break

yle_skills = [
    node
    for node in nodes
    if node.get("kind") == "skill"
    and YLE.intersection(node.get("metadata", {}).get("examAlignments", []))
]
prereq = sum(1 for edge in edges if edge.get("type") == "prerequisite_for")
supports = [
    edge
    for edge in edges
    if edge.get("type") == "supports"
    and (
        edge.get("sourceId") in {n["id"] for n in yle_skills}
        or edge.get("targetId") in {n["id"] for n in yle_skills}
    )
]
print(f"YLE skill count: {len(yle_skills)}")
print(f"YLE-touching supports count: {len(supports)}")
print(f"prerequisite_for count: {prereq}")
print(f"Graph node count: {len(nodes)}")
print(f"Graph edge count: {len(edges)}")

if prereq != 0:
    errors.append(f"prerequisite_for count must be 0, found {prereq}")
if len(yle_skills) != 1405:
    errors.append(f"YLE skill count expected 1405, found {len(yle_skills)}")

release = release_path.read_text(encoding="utf-8") if release_path.is_file() else ""
for label, value in (
    ("YLE skill count", len(yle_skills)),
    ("prerequisite_for count", prereq),
    ("YLE-touching supports count", len(supports)),
):
    m = re.search(rf"{re.escape(label)}:\s*\*?\*?(\d+)", release)
    if not m:
        errors.append(f"RELEASE missing labeled {label}")
    elif int(m.group(1)) != value:
        errors.append(f"RELEASE {label} {m.group(1)} != live {value}")

if source_sha not in release:
    errors.append("RELEASE missing source SHA-256 citation")

# No digit-only assertion style in this harness: all prints are labeled above.
if errors:
    print("; ".join(errors[:20]), file=sys.stderr)
    raise SystemExit(1)
PY
)"
sanity_status=$?
printf '%s\n' "$sanity_output"
if [[ "$sanity_status" -ne 0 ]]; then
  fail "bounded structural sanity check failed"
else
  pass "graph validates; labeled YLE counts consistent; prerequisite_for count: 0"
fi

echo "=== package consistency with prior phase reports ==="
consist_output="$(python3 - "$REVIEW" <<'PY'
import json
import sys
from pathlib import Path

review = Path(sys.argv[1])
errors = []
inv = json.loads((review / "support-inventory.json").read_text(encoding="utf-8"))
rel = json.loads((review.parent.parent / "reports/yle-relationship-audit.json").read_text(encoding="utf-8"))
if inv.get("yle_touching_supports_count") != rel["metrics"]["yle_touching_supports_count"]["value"]:
    errors.append("support inventory count != relationship report")
if inv.get("prerequisite_for_count") != 0:
    errors.append("inventory prereq non-zero")
exceptions = (review / "membership-exceptions.jsonl").read_text(encoding="utf-8").strip()
# empty file is ok
print(f"Membership exceptions lines: {0 if not exceptions else len(exceptions.splitlines())}")
print(f"Support inventory YLE-touching supports count: {inv.get('yle_touching_supports_count')}")
if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
PY
)"
consist_status=$?
printf '%s\n' "$consist_output"
if [[ "$consist_status" -ne 0 ]]; then
  fail "freeze package inconsistent with phase reports"
else
  pass "freeze package consistent with support inventory / relationship report"
fi

echo "=== dual freeze decision remains human gate ==="
decision_output="$(python3 - "$PLAN" "$REVIEW/phase6-approval.md" <<'PY'
import re
import sys
from pathlib import Path

plan_path, approval_path = map(Path, sys.argv[1:])
errors = []
marker = None
plan = plan_path.read_text(encoding="utf-8") if plan_path.is_file() else ""
phase_matches = list(re.finditer(r"^## Phase 6: Freeze Package, Sanity Check, And Decision[ \t]*$", plan, re.M))
phase = plan[phase_matches[0].end():] if phase_matches else ""
markers = re.findall(
    r"^- \[([~xb])\][ \t]+Task: Dual human freeze decision\b",
    phase,
    re.M,
)
if len(markers) != 1:
    errors.append("Phase 6 dual freeze decision task marker is not unique")
else:
    marker = markers[0]
    if marker not in {"b", "x"}:
        errors.append("Phase 6 dual freeze decision must be [b] or [x]")

if not approval_path.is_file():
    if not errors and marker == "b":
        print("Phase 6 dual freeze decision: [b] open (no approval artifact)")
        raise SystemExit(0)
    if marker == "x":
        errors.append("Phase 6 dual freeze decision is [x] but phase6-approval.md is absent")
    elif marker is not None:
        errors.append("approval artifact is absent and Phase 6 task is not the truthful [b] state")
else:
    text = approval_path.read_text(encoding="utf-8")
    if not re.search(r"\b(?:decision|recommendation)\s*:\s*(?:go|conditional-go)\b", text, re.I):
        errors.append("approval lacks go or conditional-go decision")
    if not re.search(r"curriculum[ /-]*language", text, re.I):
        errors.append("approval lacks curriculum/language owner role")
    if not re.search(r"engineering", text, re.I):
        errors.append("approval lacks engineering owner role")
    if not re.search(r"\b(?:owner|reviewer|approved by)\s*:\s*[^\n]+", text, re.I):
        errors.append("approval lacks attributable owner/reviewer")
    if not re.search(r"\b20[0-9]{2}-[0-9]{2}-[0-9]{2}\b", text):
        errors.append("approval lacks ISO date")
    if marker == "b":
        errors.append("phase6-approval.md is present but plan still marks dual freeze as [b]")
    print("Phase 6 dual freeze decision: approval present")

if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
PY
)"
decision_status=$?
printf '%s\n' "$decision_output"
if [[ "$decision_status" -ne 0 ]]; then
  fail "dual human freeze decision is mis-marked or unattributable"
else
  pass "dual human freeze decision remains an honest gate"
fi

echo "=== results ==="
printf '%s\n' "${RESULTS[@]}"
echo "=== Total: $((PASS_COUNT + FAIL_COUNT)) checks (PASS=$PASS_COUNT, FAIL=$FAIL_COUNT) ==="
exit "$FAILED"
