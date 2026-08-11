#!/usr/bin/env bash
# Semantic enrichment Phase 1 contract harness.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VOCAB="$ROOT/english/cefr-vocabulary"
PASS_COUNT=0
FAIL_COUNT=0
FAILED=0
RESULTS=()
pass() { RESULTS+=("PASS: $1"); PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { RESULTS+=("FAIL: $1"); FAIL_COUNT=$((FAIL_COUNT + 1)); FAILED=1; }

CONTRACT="$VOCAB/review/enrichment/phase1-semantic-contract.md"
SOURCES="$VOCAB/review/enrichment/phase1-semantic-sources.md"
PLAN="$ROOT/measure/tracks/lexical_semantic_enrichment_20260610/plan.md"

echo "=== semantic contract ==="
if [[ -f "$CONTRACT" ]] \
  && grep -q 'synonym' "$CONTRACT" \
  && grep -q 'hypernym' "$CONTRACT" \
  && grep -q 'prerequisite_for' "$CONTRACT" \
  && grep -q 'enrichment.semantic.wordnet' "$CONTRACT" \
  && grep -q 'semanticRelation' "$CONTRACT"; then
  pass "phase1-semantic-contract.md defines kinds, layers, prereq ban"
else
  fail "semantic contract missing or incomplete"
fi

echo "=== source selection ==="
if [[ -f "$SOURCES" ]] \
  && grep -qi 'wordnet' "$SOURCES" \
  && grep -qi 'offline' "$SOURCES" \
  && grep -qi 'forbidden\|no live' "$SOURCES"; then
  pass "phase1-semantic-sources.md selects WordNet offline"
else
  fail "semantic sources doc missing or incomplete"
fi

echo "=== plan Phase 1 markers ==="
if [[ -f "$PLAN" ]] && grep -q 'phase1-semantic-contract' "$PLAN"; then
  pass "semantic plan references Phase 1 contract evidence"
else
  fail "semantic plan missing Phase 1 evidence"
fi

echo "=== ranking inert until semantic approve ==="
if grep -q 'enrichment.semantic' "$VOCAB/RANKING_LAYER_SPEC.md" \
  && grep -E 'weight.*0|weight_semantic = 0' "$VOCAB/RANKING_LAYER_SPEC.md" >/dev/null; then
  pass "ranking spec keeps semantic weight 0 until approved"
else
  fail "ranking/semantic coordination missing"
fi

echo "=== results ==="
printf '%s\n' "${RESULTS[@]}"
echo "=== Total: $((PASS_COUNT + FAIL_COUNT)) checks (PASS=$PASS_COUNT, FAIL=$FAIL_COUNT) ==="
exit "$FAILED"
