#!/usr/bin/env bash
# Phase 5 Red/Green harness: YLE reading-program matching and coverage.
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
EVALUATOR="$ROOT/english/cefr-vocabulary/scripts/yle-reading-contract.js"
FIXTURES="$ROOT/english/cefr-vocabulary/fixtures/yle-reading"
APPROVAL="$ROOT/english/cefr-vocabulary/review/yle-2025/phase5-approval.md"

echo "=== Phase 5 plan markers ==="
plan_output="$(python3 - "$PLAN" <<'PY'
import re
import sys
from pathlib import Path

plan_path = Path(sys.argv[1])
errors = []
text = plan_path.read_text(encoding="utf-8") if plan_path.is_file() else ""
phase_matches = list(re.finditer(r"^## Phase 5: Reading-Program Validation[ \t]*$", text, re.M))
next_matches = list(re.finditer(r"^## Phase 6: Freeze Package, Sanity Check, And Decision[ \t]*$", text, re.M))
if len(phase_matches) != 1 or len(next_matches) != 1:
    errors.append("Phase 5/Phase 6 boundaries are not uniquely resolvable")
    phase = ""
else:
    phase = text[phase_matches[0].end():next_matches[0].start()]
completed = len(re.findall(r"^- \[x\][ \t]+Task:", phase, re.M))
blocked = len(re.findall(r"^- \[b\][ \t]+Task:", phase, re.M))
if re.findall(r"^- \[ \][ \t]", phase, re.M):
    errors.append("legacy [ ] remains in Phase 5")
after = text[phase_matches[0].start():] if phase_matches else ""
if "yle_p5_reading.sh" not in after:
    errors.append("Phase 5 plan/evidence lacks yle_p5_reading.sh")
print(f"Phase 5 completed task count: {completed}")
print(f"Phase 5 human-gate task count: {blocked}")
if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
PY
)"
plan_status=$?
printf '%s\n' "$plan_output"
if [[ "$plan_status" -ne 0 ]]; then
  fail "Phase 5 plan markers invalid"
else
  pass "Phase 5 plan structure is valid"
fi

echo "=== S/M/F reading fixtures present ==="
fixture_ok=1
for stage in starters movers flyers; do
  for file in text.txt profile.json expected.json; do
    if [[ ! -f "$FIXTURES/$stage/$file" ]]; then
      echo "missing $stage/$file"
      fixture_ok=0
    fi
  done
done
if [[ "$fixture_ok" -eq 1 ]]; then
  pass "Starters, Movers, and Flyers reading fixtures exist"
else
  fail "one or more reading fixtures are missing"
fi

echo "=== reading evaluator syntax ==="
if [[ -f "$EVALUATOR" ]] && node --check "$EVALUATOR"; then
  pass "yle-reading-contract.js syntax ok"
else
  fail "yle-reading-contract.js missing or syntax-invalid"
fi

echo "=== offline reading self-check (match, coverage, cap, rationale) ==="
if [[ -f "$EVALUATOR" && -f "$GRAPH" && -d "$FIXTURES" ]]; then
  check_output="$(node "$EVALUATOR" --self-check "$GRAPH" "$FIXTURES" 2>&1)"
  check_status=$?
  printf '%s\n' "$check_output"
  if [[ "$check_status" -ne 0 ]]; then
    fail "reading self-check failed"
  else
    pass "reading self-check passes for all three stages"
  fi
else
  fail "cannot run reading self-check"
fi

echo "=== unmatched tokens remain in eligible coverage denominator ==="
denom_output="$(python3 - "$EVALUATOR" "$GRAPH" "$FIXTURES" <<'PY'
import json
import subprocess
import sys
from pathlib import Path

evaluator, graph, fixtures = sys.argv[1:4]
errors = []
for stage in ("starters", "movers", "flyers"):
    case = Path(fixtures) / stage
    proc = subprocess.run(
        ["node", evaluator, graph, str(case)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    if proc.returncode != 0:
        errors.append(f"{stage}: evaluator failed: {proc.stderr.strip()}")
        continue
    result = json.loads(proc.stdout)
    metrics = result["metrics"]
    denom = metrics["known_coverage"]["denominator"]
    eligible = metrics["eligible_token_span_count"]["value"]
    unmatched = metrics["unmatched_span_count"]["value"]
    print(f"{stage}: eligible={eligible} unmatched={unmatched} coverage_denom={denom} known_coverage={metrics['known_coverage']['value']}")
    if denom != eligible:
        errors.append(f"{stage}: coverage denominator {denom} != eligible {eligible}")
    if unmatched < 1:
        errors.append(f"{stage}: expected deliberate unmatched token(s)")
    # Known coverage must count unmatched against the learner (not ignore them).
    known = metrics["known_span_count"]["value"]
    expected_cov = 0 if not denom else round(known / denom, 6)
    if abs(metrics["known_coverage"]["value"] - expected_cov) > 1e-9:
        errors.append(f"{stage}: known coverage arithmetic mismatch")
    # Target cap
    tv = result["targetVocabulary"]
    if tv["size"] > tv["cap"]:
        errors.append(f"{stage}: target size {tv['size']} exceeds cap {tv['cap']}")
    for item in tv["items"]:
        if not any(fact.get("kind") == "matchForms" for fact in item.get("graphFacts", [])):
            errors.append(f"{stage}: target {item.get('skillId')} lacks matchForms fact")
        if not item.get("rationale"):
            errors.append(f"{stage}: target lacks rationale")
if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
PY
)"
denom_status=$?
printf '%s\n' "$denom_output"
if [[ "$denom_status" -ne 0 ]]; then
  fail "coverage denominator / unmatched / target-cap contract failed"
else
  pass "unmatched tokens stay in denominator; targets capped with matchForms rationales"
fi

echo "=== progress evidence trace under simulated review ==="
progress_output="$(python3 - "$EVALUATOR" "$GRAPH" "$FIXTURES/starters" <<'PY'
import json
import subprocess
import sys

evaluator, graph, case = sys.argv[1:4]
proc = subprocess.run(
    ["node", evaluator, graph, case],
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
)
if proc.returncode != 0:
    print(proc.stderr, file=sys.stderr)
    raise SystemExit(1)
result = json.loads(proc.stdout)
progress = result["progress"]
before = progress["beforeKnownCoverage"]
after = progress["afterSimulatedReviewKnownCoverage"]
print(f"before={before} after={after} skill={progress['simulatedReviewedSkillId']}")
if after < before:
    print("simulated review decreased known coverage", file=sys.stderr)
    raise SystemExit(1)
if progress["simulatedReviewedSkillId"] is None and result["targetVocabulary"]["size"] > 0:
    print("missing simulatedReviewedSkillId while targets exist", file=sys.stderr)
    raise SystemExit(1)
PY
)"
progress_status=$?
printf '%s\n' "$progress_output"
if [[ "$progress_status" -ne 0 ]]; then
  fail "progress trace missing or decreased after simulated review"
else
  pass "simulated review produces non-decreasing known-coverage progress trace"
fi

echo "=== curriculum plausibility remains human gate ==="
approval_output="$(python3 - "$APPROVAL" "$PLAN" <<'PY'
import re
import sys
from pathlib import Path

approval_path, plan_path = map(Path, sys.argv[1:])
errors = []
marker = None
plan = plan_path.read_text(encoding="utf-8") if plan_path.is_file() else ""
phase_matches = list(re.finditer(r"^## Phase 5: Reading-Program Validation[ \t]*$", plan, re.M))
next_matches = list(re.finditer(r"^## Phase 6: Freeze Package, Sanity Check, And Decision[ \t]*$", plan, re.M))
phase = ""
if phase_matches and next_matches and next_matches[0].start() > phase_matches[0].end():
    phase = plan[phase_matches[0].end():next_matches[0].start()]
markers = re.findall(
    r"^- \[([~xb])\][ \t]+Task: Curriculum plausibility review\b",
    phase,
    re.M,
)
if len(markers) != 1:
    errors.append("Phase 5 curriculum plausibility task marker is not unique")
else:
    marker = markers[0]
    if marker not in {"b", "x"}:
        errors.append("Phase 5 curriculum plausibility must be [b] or [x]")

if not approval_path.is_file():
    if not errors and marker == "b":
        print("Phase 5 curriculum approval artifact: absent (human gate open)")
        raise SystemExit(0)
    if marker == "x":
        errors.append("Phase 5 approval is [x] but phase5-approval.md is absent")
    elif marker is not None:
        errors.append("approval artifact is absent and Phase 5 task is not the truthful [b] state")
else:
    text = approval_path.read_text(encoding="utf-8")
    if not re.search(r"\b(?:decision|recommendation)\s*:\s*(?:go|conditional-go)\b", text, re.I):
        errors.append("approval lacks go or conditional-go decision")
    if not re.search(r"curriculum[ /-]*language", text, re.I):
        errors.append("approval lacks curriculum/language owner role")
    if not re.search(r"\b(?:owner|reviewer|approved by)\s*:\s*[^\n]+", text, re.I):
        errors.append("approval lacks attributable owner/reviewer")
    if not re.search(r"\b20[0-9]{2}-[0-9]{2}-[0-9]{2}\b", text):
        errors.append("approval lacks ISO date")
    if marker == "b":
        errors.append("phase5-approval.md is present but plan still marks plausibility as [b]")
    print("Phase 5 curriculum approval artifact: present")

if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
PY
)"
approval_status=$?
printf '%s\n' "$approval_output"
if [[ "$approval_status" -ne 0 ]]; then
  fail "curriculum plausibility gate mis-marked"
else
  pass "curriculum reading-fixture plausibility remains an honest human gate"
fi

echo "=== results ==="
printf '%s\n' "${RESULTS[@]}"
echo "=== Total: $((PASS_COUNT + FAIL_COUNT)) checks (PASS=$PASS_COUNT, FAIL=$FAIL_COUNT) ==="
exit "$FAILED"
