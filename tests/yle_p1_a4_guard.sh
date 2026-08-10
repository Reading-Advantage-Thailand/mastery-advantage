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
if [[ -d "$ROOT/measure/archive/$TRACK_ID" ]]; then
  TRACK_DIR="$ROOT/measure/archive/$TRACK_ID"
else
  TRACK_DIR="$ROOT/measure/tracks/$TRACK_ID"
fi
SOURCE_PLAN="$TRACK_DIR/plan.md"
SCOPE_HARNESS="$ROOT/tests/yle_p1_scope.sh"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/yle-p1-a4-guard.XXXXXX")"
FIXTURE_PLAN="$TMP_DIR/phase1-all-in-progress.md"
SCOPE_OUTPUT="$TMP_DIR/scope-output.txt"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# Green contract seam (documented here for the implementation role):
#   PLAN_OVERRIDE=/absolute/path/to/plan.md bash tests/yle_p1_scope.sh
# The scope harness must use PLAN_OVERRIDE for every plan read so this test can
# exercise Phase 1 marker guards without changing the tracked plan.
echo "=== isolated plan rewrites every Phase 1 completed task and adds an indented legacy marker ==="
fixture_errors="$(python3 - "$SOURCE_PLAN" "$FIXTURE_PLAN" <<'PY' 2>&1
import re
import sys
from pathlib import Path

source_path, fixture_path = map(Path, sys.argv[1:])
text = source_path.read_text(encoding="utf-8")
match = re.search(
    r"^## Phase 1: Freeze Scope, Facts Inventory, And Review Rules$.*?(?=^## Phase 2:)",
    text,
    re.MULTILINE | re.DOTALL,
)
if match is None:
    raise SystemExit("Phase 1/Phase 2 boundaries are missing")

phase = match.group(0)
task_marker = re.compile(r"^[ \t]*-[ \t]*\[([x~ ])\](?=[ \t])", re.MULTILINE)
completed_before = len(task_marker.findall(phase))
if completed_before == 0:
    raise SystemExit("Phase 1 fixture source has no task markers")

rewritten, replacements = re.subn(
    r"^([ \t]*-[ \t]*)\[x\](?=[ \t])",
    r"\1[~]",
    phase,
    flags=re.MULTILINE,
)
if replacements == 0:
    raise SystemExit("Phase 1 fixture source has no completed task markers")
if re.search(r"^[ \t]*-[ \t]*\[x\](?=[ \t])", rewritten, re.MULTILINE):
    raise SystemExit("a Phase 1 completed task marker was not rewritten")

legacy_line = "  - [ ] Synthetic indented legacy subtask marker for A4\n"
rewritten = rewritten.replace("\n", "\n" + legacy_line, 1)
fixture = text[:match.start()] + rewritten + text[match.end():]
fixture_path.write_text(fixture, encoding="utf-8")

if not re.search(r"^  - \[ \] Synthetic indented legacy subtask marker for A4$", fixture, re.MULTILINE):
    raise SystemExit("indented legacy marker was not added to the fixture")
if re.search(r"^## Phase 1:.*?(?=^## Phase 2:).*^[ \t]*-[ \t]*\[x\](?=[ \t])", fixture, re.MULTILINE | re.DOTALL):
    raise SystemExit("fixture still contains a Phase 1 completed task marker")
PY
)"
if [[ -n "$fixture_errors" ]]; then
  fail "$fixture_errors"
else
  pass "fixture has zero completed Phase 1 task markers and an indented [ ] subtask"
fi

scope_status=125
scope_output=""
if [[ -f "$FIXTURE_PLAN" && -x "$SCOPE_HARNESS" ]]; then
  PLAN_OVERRIDE="$FIXTURE_PLAN" bash "$SCOPE_HARNESS" >"$SCOPE_OUTPUT" 2>&1
  scope_status=$?
  scope_output="$(<"$SCOPE_OUTPUT")"
else
  fail "scope harness or isolated fixture is unavailable"
fi

echo "=== scope override reports incomplete with a labeled zero completed-task count ==="
if (( scope_status != 0 )) \
  && [[ "$scope_output" == *INCOMPLETE* ]] \
  && printf '%s\n' "$scope_output" | rg -q 'Completed Phase 1 tasks:[[:space:]]*0'; then
  pass "isolated zero-complete Phase 1 is rejected as INCOMPLETE"
else
  fail "expected nonzero scope exit plus INCOMPLETE and 'Completed Phase 1 tasks: 0' (exit=$scope_status)"
fi

echo "=== scope legacy-marker detection covers indented task/subtask markers ==="
if printf '%s\n' "$scope_output" | rg -qi 'FAIL: .*legacy[[:space:]]+\[ \].*marker'; then
  pass "indented [ ] task marker is reported by the scope harness"
else
  fail "scope harness did not report the indented legacy [ ] task marker"
fi

printf '%s\n' "${RESULTS[@]}"
echo "=== Total: $((PASS_COUNT + FAIL_COUNT)) checks (PASS=$PASS_COUNT, FAIL=$FAIL_COUNT) ==="
exit "$FAILED"
