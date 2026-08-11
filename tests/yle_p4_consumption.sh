#!/usr/bin/env bash
# Phase 4 Red/Green harness: YLE-CONSUMPTION contract + offline profile fixtures.
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
GRAPH="$ROOT/english/cefr-vocabulary/cefr-vocabulary-knowledge-space.json"
CONTRACT="$ROOT/english/cefr-vocabulary/YLE-CONSUMPTION.md"
EVALUATOR="$ROOT/english/cefr-vocabulary/scripts/yle-consumption-contract.js"
FIXTURES="$ROOT/english/cefr-vocabulary/fixtures/yle-consumption"
PROGRESSION="$ROOT/english/cefr-vocabulary/review/yle-2025/progression-policy.md"
APPROVAL="$ROOT/english/cefr-vocabulary/review/yle-2025/phase4-approval.md"

echo "=== Phase 4 plan markers and harness reference ==="
plan_output="$(python3 - "$PLAN" <<'PY'
import re
import sys
from pathlib import Path

plan_path = Path(sys.argv[1])
errors = []
if not plan_path.is_file():
    errors.append(f"missing plan: {plan_path}")
    text = ""
else:
    text = plan_path.read_text(encoding="utf-8")
    phase_matches = list(re.finditer(r"^## Phase 4: Consumption And Next-Step Contract[ \t]*$", text, re.M))
    next_matches = list(re.finditer(r"^## Phase 5: Reading-Program Validation[ \t]*$", text, re.M))
    if len(phase_matches) != 1 or len(next_matches) != 1:
        errors.append("Phase 4/Phase 5 boundaries are not uniquely resolvable")
        phase = ""
    else:
        phase = text[phase_matches[0].end():next_matches[0].start()]
    if re.findall(r"^- \[ \][ \t]", phase, re.M):
        errors.append("legacy [ ] marker remains in Phase 4")
    completed = len(re.findall(r"^- \[x\][ \t]+Task:", phase, re.M))
    in_progress = len(re.findall(r"^- \[~\][ \t]+Task:", phase, re.M))
    blocked = len(re.findall(r"^- \[b\][ \t]+Task:", phase, re.M))
    if "YLE-CONSUMPTION.md" not in phase:
        errors.append("Phase 4 lacks YLE-CONSUMPTION.md task")
    after = text[phase_matches[0].start():]
    if "yle_p4_consumption.sh" not in after:
        errors.append("Phase 4 plan/evidence lacks yle_p4_consumption.sh")
    print(f"Phase 4 completed task count: {completed}")
    print(f"Phase 4 in-progress task count: {in_progress}")
    print(f"Phase 4 human-gate task count: {blocked}")
if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
PY
)"
plan_status=$?
printf '%s\n' "$plan_output"
if [[ "$plan_status" -ne 0 ]]; then
  fail "Phase 4 plan markers/structure are invalid"
else
  pass "Phase 4 plan structure is valid"
fi

echo "=== YLE-CONSUMPTION.md required sections ==="
contract_output="$(python3 - "$CONTRACT" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
errors = []
if not path.is_file():
    errors.append(f"missing contract: {path}")
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
text = path.read_text(encoding="utf-8")
print(f"YLE-CONSUMPTION.md bytes: {len(text.encode('utf-8'))}")
required = [
    (r"static graph|Static Graph", "static graph vs learner state"),
    (r"learner state|Learner State", "learner state"),
    (r"per-student|must not write mastery|no per-student", "ban on per-student graph fields"),
    (r"SRS due|srs_due", "SRS due work"),
    (r"lower-level gap|lower_level_gap", "lower-level gaps"),
    (r"current stage|goalStage", "current stage"),
    (r"reading target|Reading", "reading targets mention"),
    (r"MWE|multiword", "MWE readiness"),
    (r"topic", "topic foci"),
    (r"graphFacts", "graphFacts payload"),
    (r"learnerStateFields", "learnerStateFields payload"),
    (r"derivedSignals|derived support signal", "derived signals labeled"),
    (r"prerequisite_for", "prerequisite_for prohibition"),
]
for pattern, label in required:
    if not re.search(pattern, text, re.I):
        errors.append(f"contract lacks {label}")
if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
PY
)"
contract_status=$?
printf '%s\n' "$contract_output"
if [[ "$contract_status" -ne 0 ]]; then
  fail "YLE-CONSUMPTION.md missing required sections"
else
  pass "YLE-CONSUMPTION.md has required contract sections"
fi

echo "=== profile fixtures exist (Starters, Movers gaps, Flyers due) ==="
fixture_output="$(python3 - "$FIXTURES" <<'PY'
import json
import sys
from pathlib import Path

fixtures = Path(sys.argv[1])
errors = []
if not fixtures.is_dir():
    errors.append(f"missing fixtures dir: {fixtures}")
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
required = [
    "starters-beginner.profile.json",
    "starters-beginner.expected.json",
    "movers-with-starters-gaps.profile.json",
    "movers-with-starters-gaps.expected.json",
    "flyers-mixed-due.profile.json",
    "flyers-mixed-due.expected.json",
]
for name in required:
    path = fixtures / name
    if not path.is_file():
        errors.append(f"missing fixture: {name}")
        continue
    data = json.loads(path.read_text(encoding="utf-8"))
    if name.endswith(".profile.json"):
        ls = data.get("learnerState")
        if not isinstance(ls, dict) or ls.get("goalStage") not in {"starters", "movers", "flyers"}:
            errors.append(f"{name} lacks valid learnerState.goalStage")
        if "mastery" not in (ls or {}):
            errors.append(f"{name} lacks learnerState.mastery")
    if name.startswith("movers-with-starters-gaps") and name.endswith(".expected.json"):
        if not data.get("requireLowerLevelGaps"):
            errors.append("movers expected fixture must requireLowerLevelGaps")
print(f"Fixture file count: {sum(1 for _ in fixtures.glob('*.json'))}")
if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
PY
)"
fixture_status=$?
printf '%s\n' "$fixture_output"
if [[ "$fixture_status" -ne 0 ]]; then
  fail "consumption profile fixtures missing or incomplete"
else
  pass "Starters / Movers-gap / Flyers-due profile fixtures are present"
fi

echo "=== offline contract evaluator syntax ==="
if [[ -f "$EVALUATOR" ]]; then
  if node --check "$EVALUATOR"; then
    pass "yle-consumption-contract.js syntax ok"
  else
    fail "yle-consumption-contract.js failed node --check"
  fi
else
  fail "missing yle-consumption-contract.js evaluator"
fi

echo "=== offline self-check: gap / stage / due / explainability / no graph mutation ==="
if [[ -f "$EVALUATOR" && -f "$GRAPH" && -d "$FIXTURES" ]]; then
  check_output="$(node "$EVALUATOR" --self-check "$GRAPH" "$FIXTURES" 2>&1)"
  check_status=$?
  printf '%s\n' "$check_output"
  if [[ "$check_status" -ne 0 ]]; then
    fail "offline consumption self-check failed"
  else
    pass "offline consumption self-check asserts gap/stage/due/explainability without graph mutation"
  fi
else
  fail "cannot run self-check (missing evaluator, graph, or fixtures)"
fi

echo "=== Movers-goal weak Starters profile emits lower-level gaps (falsifier) ==="
movers_output="$(python3 - "$EVALUATOR" "$GRAPH" "$FIXTURES/movers-with-starters-gaps.profile.json" <<'PY'
import json
import subprocess
import sys
from pathlib import Path

evaluator, graph, profile = sys.argv[1:4]
proc = subprocess.run(
    ["node", evaluator, graph, profile],
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
)
if proc.returncode != 0:
    print(proc.stderr, file=sys.stderr)
    raise SystemExit(1)
result = json.loads(proc.stdout)
print(f"Movers lowerLevelGaps count: {result['counts']['lowerLevelGaps']}")
print(f"Movers nextSteps categories: {sorted({item['category'] for item in result['nextSteps']})}")
if result["counts"]["lowerLevelGaps"] < 1:
    print("Movers-goal profile produced zero lower-level gaps", file=sys.stderr)
    raise SystemExit(1)
# Explainability shape on first gap item
gap = next(item for item in result["nextSteps"] if item["category"] == "lower_level_gap")
if not gap.get("graphFacts") or not gap.get("learnerStateFields"):
    print("gap item lacks graphFacts/learnerStateFields", file=sys.stderr)
    raise SystemExit(1)
if "graphFacts" not in gap or "learnerStateFields" not in gap:
    print("payload missing separate graphFacts vs learnerStateFields", file=sys.stderr)
    raise SystemExit(1)
print(f"Example gap skillId: {gap['skillId']}")
print(f"Example gap graphFacts count: {len(gap['graphFacts'])}")
print(f"Example gap learnerStateFields count: {len(gap['learnerStateFields'])}")
PY
)"
movers_status=$?
printf '%s\n' "$movers_output"
if [[ "$movers_status" -ne 0 ]]; then
  fail "Movers-goal weak Starters profile did not emit explainable lower-level gaps"
else
  pass "Movers-goal weak Starters profile emits explainable lower-level gaps"
fi

echo "=== graph snapshot is not written with student mastery fields by examples ==="
mutation_output="$(python3 - "$GRAPH" "$FIXTURES" <<'PY'
import json
import sys
from pathlib import Path

graph_path, fixtures = map(Path, sys.argv[1:])
graph = json.loads(graph_path.read_text(encoding="utf-8"))
banned = {"mastery", "dueAt", "stability", "lastReview", "studentId", "learnerId"}
errors = []
for node in graph.get("nodes", []):
    if node.get("kind") != "skill":
        continue
    for key in banned:
        if key in node or key in (node.get("metadata") or {}):
            errors.append(f"skill {node.get('id')} carries student field {key}")
# Profiles must keep mastery only under learnerState
for path in fixtures.glob("*.profile.json"):
    profile = json.loads(path.read_text(encoding="utf-8"))
    if "mastery" in profile and "learnerState" not in profile:
        errors.append(f"{path.name} places mastery outside learnerState")
    ls = profile.get("learnerState") or {}
    if "mastery" not in ls:
        errors.append(f"{path.name} lacks learnerState.mastery")
print(f"Graph skill student-field violations: {len(errors)}")
if errors:
    print("; ".join(errors[:20]), file=sys.stderr)
    raise SystemExit(1)
PY
)"
mutation_status=$?
printf '%s\n' "$mutation_output"
if [[ "$mutation_status" -ne 0 ]]; then
  fail "examples encode student mastery on the static graph"
else
  pass "fixtures keep mastery in learnerState; graph skills lack student fields"
fi

echo "=== progression policy still aligned (supports non-mandatory) ==="
if [[ -f "$PROGRESSION" ]] && grep -qi 'prerequisite_for' "$PROGRESSION"; then
  pass "progression policy present and references prerequisite_for"
else
  fail "progression policy missing or incomplete for Phase 4 alignment"
fi

echo "=== dual human approval remains an honest gate ==="
approval_output="$(python3 - "$APPROVAL" "$PLAN" <<'PY'
import re
import sys
from pathlib import Path

approval_path, plan_path = map(Path, sys.argv[1:])
errors = []
marker = None
plan = plan_path.read_text(encoding="utf-8") if plan_path.is_file() else ""
phase_matches = list(re.finditer(r"^## Phase 4: Consumption And Next-Step Contract[ \t]*$", plan, re.M))
next_matches = list(re.finditer(r"^## Phase 5: Reading-Program Validation[ \t]*$", plan, re.M))
phase = ""
if phase_matches and next_matches and next_matches[0].start() > phase_matches[0].end():
    phase = plan[phase_matches[0].end():next_matches[0].start()]
markers = re.findall(
    r"^- \[([~xb])\][ \t]+Task: Approve consumption contract\b",
    phase,
    re.M,
)
if len(markers) != 1:
    errors.append("Phase 4 approval task marker is not unique")
else:
    marker = markers[0]
    if marker not in {"b", "x"}:
        errors.append("Phase 4 approval task must be [b] or [x]")

if not approval_path.is_file():
    if not errors and marker == "b":
        print("Phase 4 approval artifact: absent (human gates still open)")
        raise SystemExit(0)
    if marker == "x":
        errors.append("Phase 4 approval is [x] but phase4-approval.md is absent")
    elif marker is not None:
        errors.append("approval artifact is absent and Phase 4 task is not the truthful [b] state")
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
        errors.append("phase4-approval.md is present but plan still marks approval as [b]")
    print("Phase 4 approval artifact: present")

if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
PY
)"
approval_status=$?
printf '%s\n' "$approval_output"
if [[ "$approval_status" -ne 0 ]]; then
  fail "Phase 4 human approval gate is mis-marked"
else
  pass "consumption contract dual approval remains an honest human gate"
fi

echo "=== results ==="
printf '%s\n' "${RESULTS[@]}"
echo "=== Total: $((PASS_COUNT + FAIL_COUNT)) checks (PASS=$PASS_COUNT, FAIL=$FAIL_COUNT) ==="
exit "$FAILED"
