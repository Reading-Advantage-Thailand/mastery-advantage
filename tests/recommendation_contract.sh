#!/usr/bin/env bash
# Portable recommendation contract harness (matching, metrics, ranking).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VOCAB="$ROOT/english/cefr-vocabulary"
PASS_COUNT=0
FAIL_COUNT=0
FAILED=0
RESULTS=()
pass() { RESULTS+=("PASS: $1"); PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { RESULTS+=("FAIL: $1"); FAIL_COUNT=$((FAIL_COUNT + 1)); FAILED=1; }

CONTRACT="$VOCAB/RECOMMENDATION-CONTRACT.md"
REF="$VOCAB/scripts/recommendation-contract.js"
FIX="$VOCAB/fixtures/recommendation"
GRAPH="$VOCAB/cefr-vocabulary-knowledge-space.json"
FREQ="$VOCAB/overlays/frequency.overlay.json"

echo "=== contract document ==="
if [[ -f "$CONTRACT" ]] \
  && grep -q 'eligibleKnownCoverage' "$CONTRACT" \
  && grep -q 'unmatchedTokenRate' "$CONTRACT" \
  && grep -q 'Longest-MWE' "$CONTRACT" \
  && grep -q 'prerequisite_for' "$CONTRACT" \
  && grep -q 'matchedTokenCoverage' "$CONTRACT"; then
  pass "RECOMMENDATION-CONTRACT.md defines matching, metrics, ranking bans"
else
  fail "recommendation contract missing or incomplete"
fi

echo "=== reference compiles / self-check ==="
if [[ -f "$REF" ]] && node --check "$REF" 2>/dev/null; then
  pass "recommendation-contract.js syntax ok"
else
  # node --check may not exist on old node; try require
  if node -e "require('$REF')"; then
    pass "recommendation-contract.js loads"
  else
    fail "recommendation-contract.js broken"
  fi
fi

echo "=== offline fixtures self-check ==="
if node "$REF" --self-check "$GRAPH" "$FIX" "$FREQ" >/tmp/rec-self-check.json; then
  pass "recommendation fixtures self-check green"
else
  fail "recommendation fixtures self-check failed"
fi

echo "=== fixture index and cases ==="
python3 - "$FIX" <<'PY' || exit 1
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
idx = json.loads((root / "index.json").read_text())
errors = []
if len(idx.get("cases") or []) < 8:
    errors.append("need ≥8 cases")
for c in idx["cases"]:
    d = root / c["id"]
    for name in ("text.txt", "profile.json", "expected.json"):
        if not (d / name).is_file():
            errors.append(f"missing {c['id']}/{name}")
if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
print("cases", len(idx["cases"]))
PY
if [[ $? -eq 0 ]]; then
  pass "fixture pack complete (≥8 cases)"
else
  fail "fixture pack incomplete"
fi

echo "=== Phase 1 approval ==="
APPROVAL="$VOCAB/review/enrichment/phase1-recommendation-approval.md"
if [[ -f "$APPROVAL" ]] && grep -qiE 'Decision:\**[[:space:]]*go' "$APPROVAL"; then
  pass "phase1-recommendation-approval.md records go"
else
  fail "recommendation Phase 1 approval missing"
fi

echo "=== plan markers ==="
PLAN="$ROOT/measure/tracks/lexical_recommendation_contract_20260610/plan.md"
if [[ -f "$PLAN" ]] && grep -q 'RECOMMENDATION-CONTRACT.md' "$PLAN" \
  && grep -q 'phase1-recommendation-approval' "$PLAN"; then
  pass "recommendation plan references contract + Phase 1 go"
else
  fail "recommendation plan missing evidence"
fi

echo "=== results ==="
printf '%s\n' "${RESULTS[@]}"
echo "=== Total: $((PASS_COUNT + FAIL_COUNT)) checks (PASS=$PASS_COUNT, FAIL=$FAIL_COUNT) ==="
exit "$FAILED"
