#!/usr/bin/env bash
# Red/Green harness for Coverage Enrichment Phase 1 contracts.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS_COUNT=0
FAIL_COUNT=0
RESULTS=()
pass() { RESULTS+=("PASS: $1"); PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { RESULTS+=("FAIL: $1"); FAIL_COUNT=$((FAIL_COUNT + 1)); FAILED=1; }
FAILED=0

CONTRACT="$ROOT/english/cefr-vocabulary/review/enrichment/phase1-contracts.md"
REGISTRY="$ROOT/english/cefr-vocabulary/review/enrichment/phase1-source-registry.md"
PLAN="$ROOT/measure/tracks/lexical_coverage_enrichment_20260610/plan.md"
RELEASE="$ROOT/english/cefr-vocabulary/review/yle-2025/RELEASE-YLE-2025.md"
SOURCES="$ROOT/english/cefr-vocabulary/SOURCES.md"

echo "=== enrichment Phase 1 contract document ==="
if [[ -f "$CONTRACT" ]] && \
   grep -q 'enrichment.viu.unit-groups' "$CONTRACT" && \
   grep -q 'enrichment.frequency.wordfreq' "$CONTRACT" && \
   grep -qi 'prerequisite_for' "$CONTRACT" && \
   grep -q '0.980\|≥ 0.980\|>= 0.980' "$CONTRACT" && \
   grep -qi 'quarantine' "$CONTRACT"; then
  pass "phase1-contracts.md defines layers, thresholds, quarantine, and prereq ban"
else
  fail "phase1-contracts.md missing or incomplete"
fi

echo "=== enrichment Phase 1 source registry ==="
if [[ -f "$REGISTRY" ]] && \
   grep -q 'cambridge-a2-key-vocabulary-list-2025' "$REGISTRY" && \
   grep -q 'cambridge-b1-preliminary-vocabulary-list-2025' "$REGISTRY" && \
   grep -qi 'wordfreq' "$REGISTRY" && \
   grep -qi 'Unavailable\|unavailable' "$REGISTRY" && \
   grep -qi 'English Vocabulary Profile\|EVP' "$REGISTRY"; then
  pass "phase1-source-registry.md records A2/B1, wordfreq, and exclusions"
else
  fail "phase1-source-registry.md missing or incomplete"
fi

echo "=== core freeze dependency present ==="
if [[ -f "$RELEASE" ]] && grep -qi 'Frozen\|Decision: go\|dual.*go' "$RELEASE"; then
  pass "YLE RELEASE freeze record exists for core pin"
else
  fail "YLE core freeze RELEASE missing or not frozen"
fi

echo "=== SOURCES.md still lists candidate PDFs ==="
if [[ -f "$SOURCES" ]] && \
   grep -q 'cambridge-a2-key' "$SOURCES" && \
   grep -q 'Vocabulary In Use\|Vocabulary in Use' "$SOURCES"; then
  pass "SOURCES.md retains A2 Key and ViU entries"
else
  fail "SOURCES.md missing expected enrichment candidates"
fi

echo "=== plan markers: Phase 1 contracts done, review gate open or complete ==="
plan_out="$(python3 - "$PLAN" <<'PY'
import re, sys
from pathlib import Path
plan = Path(sys.argv[1])
if not plan.is_file():
    print("missing plan", file=sys.stderr)
    raise SystemExit(1)
text = plan.read_text(encoding="utf-8")
m = re.search(r"^## Phase 1:.*?(?=^## Phase 2:|\Z)", text, re.M | re.S)
if not m:
    print("Phase 1 section missing", file=sys.stderr)
    raise SystemExit(1)
phase = m.group(0)
completed = len(re.findall(r"^- \[x\][ \t]+Task:", phase, re.M))
blocked = len(re.findall(r"^- \[b\][ \t]+Task:", phase, re.M))
if completed < 3:
    print(f"expected >=3 completed Phase 1 tasks, found {completed}", file=sys.stderr)
    raise SystemExit(1)
if not re.search(r"phase1-contracts\.md", phase):
    print("Phase 1 evidence lacks phase1-contracts.md", file=sys.stderr)
    raise SystemExit(1)
print(f"Phase 1 completed task count: {completed}")
print(f"Phase 1 human-gate task count: {blocked}")
PY
)" || true
plan_status=$?
printf '%s\n' "$plan_out"
if [[ "$plan_status" -eq 0 ]]; then
  pass "Phase 1 plan has completed contract tasks and evidence paths"
else
  fail "Phase 1 plan markers/evidence incomplete"
fi

echo "=== results ==="
printf '%s\n' "${RESULTS[@]}"
echo "=== Total: $((PASS_COUNT + FAIL_COUNT)) checks (PASS=$PASS_COUNT, FAIL=$FAIL_COUNT) ==="
exit "$FAILED"
