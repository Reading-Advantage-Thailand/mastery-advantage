#!/usr/bin/env bash
# Validate ranking utility sample against approved frequency overlay.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VOCAB="$ROOT/english/cefr-vocabulary"
PASS_COUNT=0
FAIL_COUNT=0
FAILED=0
RESULTS=()
pass() { RESULTS+=("PASS: $1"); PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { RESULTS+=("FAIL: $1"); FAIL_COUNT=$((FAIL_COUNT + 1)); FAILED=1; }

SPEC="$VOCAB/RANKING_LAYER_SPEC.md"
VALIDATOR="$VOCAB/scripts/validate-frequency-utility-sample.py"
OVERLAY="$VOCAB/overlays/frequency.overlay.json"

echo "=== ranking spec present ==="
if [[ -f "$SPEC" ]] && grep -q 'english.cefr.frequency-utility' "$SPEC" \
  && grep -q 'rankWithinInventory' "$SPEC" \
  && grep -q 'weight' "$SPEC"; then
  pass "RANKING_LAYER_SPEC.md defines provider, rank normalization, weights"
else
  fail "RANKING_LAYER_SPEC.md missing or incomplete"
fi

echo "=== frequency overlay approved pin ==="
if [[ -f "$OVERLAY" ]] && python3 - "$OVERLAY" <<'PY'
import json, sys
from pathlib import Path
ov = json.loads(Path(sys.argv[1]).read_text())
assert ov.get("enrichmentLayer") == "enrichment.frequency.wordfreq"
st = ov.get("stats") or {}
assert st.get("sourceVersion") == "3.1.1" or st.get("source") == "wordfreq"
assert int(st.get("maxRank") or 0) >= 2
assert len(ov.get("edges") or []) == 0
print("maxRank", st.get("maxRank"), "scored", st.get("scored"))
PY
then
  pass "frequency overlay usable for utility sample"
else
  fail "frequency overlay missing or invalid"
fi

echo "=== 500-node utility sample ==="
if python3 -m py_compile "$VALIDATOR" && python3 "$VALIDATOR"; then
  pass "validate-frequency-utility-sample.py 500-node check"
else
  fail "utility sample validation failed"
fi

echo "=== inert signals documented ==="
if grep -q 'weight_semantic = 0' "$SPEC" || grep -q 'weight.*0\.0' "$SPEC"; then
  pass "semantic/article signals documented at weight 0"
else
  fail "inert signal weights not documented"
fi

echo "=== results ==="
printf '%s\n' "${RESULTS[@]}"
echo "=== Total: $((PASS_COUNT + FAIL_COUNT)) checks (PASS=$PASS_COUNT, FAIL=$FAIL_COUNT) ==="
exit "$FAILED"
