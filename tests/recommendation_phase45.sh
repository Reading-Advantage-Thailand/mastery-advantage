#!/usr/bin/env bash
# Recommendation Phases 4–5 approval and evaluation artifacts.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VOCAB="$ROOT/english/cefr-vocabulary"
PASS_COUNT=0
FAIL_COUNT=0
FAILED=0
RESULTS=()
pass() { RESULTS+=("PASS: $1"); PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { RESULTS+=("FAIL: $1"); FAIL_COUNT=$((FAIL_COUNT + 1)); FAILED=1; }

echo "=== Phase 4 procedure and judgments ==="
if [[ -f "$VOCAB/review/enrichment/recommendation-phase4-procedure.md" ]] \
  && [[ -f "$VOCAB/review/enrichment/recommendation-phase4-judgments.jsonl" ]] \
  && [[ -f "$VOCAB/reports/enrichment/recommendation-phase4-evaluation.json" ]]; then
  pass "phase4 procedure, judgments, evaluation present"
else
  fail "phase4 artifacts missing"
fi

python3 - "$VOCAB/reports/enrichment/recommendation-phase4-evaluation.json" \
  "$VOCAB/review/enrichment/recommendation-phase4-judgments.jsonl" <<'PY' || exit 1
import json, sys
from pathlib import Path
summary = json.loads(Path(sys.argv[1]).read_text())
lines = [ln for ln in Path(sys.argv[2]).read_text().splitlines() if ln.strip()]
if summary.get("allPass") is not True:
    raise SystemExit("phase4 summary allPass is not true")
if summary.get("passed", 0) < 9:
    raise SystemExit("need ≥9 passed cases")
if len(lines) < 9:
    raise SystemExit("need ≥9 judgment rows")
for ln in lines:
    row = json.loads(ln)
    if row.get("result") != "pass":
        raise SystemExit(f"failed judgment: {row.get('caseId')}")
print("judgments", len(lines), "all pass")
PY
if [[ $? -eq 0 ]]; then
  pass "phase4 judgments 9/9 pass"
else
  fail "phase4 judgments incomplete"
fi

echo "=== Phase 4–5 approvals ==="
for f in phase4-recommendation-approval.md phase5-recommendation-approval.md RELEASE-RECOMMENDATION-2026-08-11.md; do
  p="$VOCAB/review/enrichment/$f"
  if [[ -f "$p" ]] && grep -qiE 'Decision:\**[[:space:]]*go|Approved' "$p"; then
    pass "$f records go/approved"
  else
    fail "$f missing go"
  fi
done

echo "=== consumption guide ==="
if [[ -f "$VOCAB/RECOMMENDATION-CONSUMPTION.md" ]] \
  && grep -q 'eligibleKnownCoverage' "$VOCAB/RECOMMENDATION-CONSUMPTION.md"; then
  pass "RECOMMENDATION-CONSUMPTION.md present"
else
  fail "consumption guide missing"
fi

echo "=== base harness still green ==="
if bash "$ROOT/tests/recommendation_contract.sh" >/tmp/rec-base.out 2>&1; then
  pass "recommendation_contract.sh still green"
else
  fail "recommendation_contract.sh failed"
  cat /tmp/rec-base.out >&2 || true
fi

echo "=== results ==="
printf '%s\n' "${RESULTS[@]}"
echo "=== Total: $((PASS_COUNT + FAIL_COUNT)) checks (PASS=$PASS_COUNT, FAIL=$FAIL_COUNT) ==="
exit "$FAILED"
