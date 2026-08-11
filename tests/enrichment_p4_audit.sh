#!/usr/bin/env bash
# Phase 4 enrichment audit harness (automatable gates).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VOCAB="$ROOT/english/cefr-vocabulary"
PASS_COUNT=0
FAIL_COUNT=0
FAILED=0
RESULTS=()
pass() { RESULTS+=("PASS: $1"); PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { RESULTS+=("FAIL: $1"); FAIL_COUNT=$((FAIL_COUNT + 1)); FAILED=1; }

BUILDER="$VOCAB/scripts/build-enrichment-phase4-audit.py"
REPORT="$VOCAB/reports/enrichment/phase4-audit.json"
GAPS="$VOCAB/reports/enrichment/coverage-gaps.json"
SAMPLES="$VOCAB/review/enrichment/phase4-samples"

echo "=== builder compiles ==="
if [[ -f "$BUILDER" ]] && python3 -m py_compile "$BUILDER"; then
  pass "build-enrichment-phase4-audit.py compiles"
else
  fail "phase4 audit builder missing or broken"
fi

echo "=== run audit ==="
if python3 "$BUILDER"; then
  pass "phase4 audit exits 0 (automatable gates green)"
else
  fail "phase4 audit failed automatable gates"
fi

echo "=== artifacts present ==="
if [[ -f "$REPORT" && -f "$GAPS" && -f "$VOCAB/reports/enrichment/phase4-audit.md" ]]; then
  pass "phase4 audit report artifacts present"
else
  fail "missing phase4 audit reports"
fi

echo "=== gate and sample checks ==="
python3 - "$REPORT" "$SAMPLES" <<'PY' || exit 1
import json
import sys
from pathlib import Path

report = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
sample_dir = Path(sys.argv[2])
errors = []
gates = report.get("gates") or {}
for key in (
    "coreFreezeUntouched",
    "allLayersZeroPrerequisiteFor",
    "frequencyNoSilentNulls",
    "provenanceCompleteAllMembershipLayers",
    "stratifiedSamplesWritten",
    "ambiguousRowsQuarantinedInQueues",
):
    if gates.get(key) is not True:
        errors.append(f"gate {key} is not true: {gates.get(key)}")

if gates.get("curriculumPrecisionGate") != "pending-human":
    errors.append("curriculum precision gate must remain pending-human until labeled")

layers = {a.get("layerId"): a for a in report.get("layers") or []}
need = [
    "enrichment.cambridge.a2-key-appendix",
    "enrichment.cambridge.b1-preliminary-appendix",
    "enrichment.cambridge.grammatical-groups",
    "enrichment.viu.unit-groups",
    "enrichment.frequency.wordfreq",
]
for lid in need:
    if lid not in layers:
        errors.append(f"missing layer audit {lid}")
        continue
    a = layers[lid]
    if a.get("prerequisite_for_count", 1) != 0:
        errors.append(f"{lid} has prerequisite_for")
    if a.get("kind") != "frequency":
        n = (a.get("stratifiedSample") or {}).get("actual") or 0
        if n < 1:
            errors.append(f"{lid} sample empty")
        path = sample_dir / f"{lid.split('.')[-1]}-membership-sample.jsonl"
        # samples written with last path segment of layer id
        # a2-key-appendix -> appendix? layerId ends with a2-key-appendix etc.
    else:
        if a.get("silentNulls", 1) != 0:
            errors.append("frequency silent nulls")
        if a.get("edgeCount", 1) != 0:
            errors.append("frequency must have zero edges")

# Sample files exist and are JSONL
samples = list(sample_dir.glob("*-membership-sample.jsonl"))
if len(samples) < 4:
    errors.append(f"expected ≥4 membership sample files, found {len(samples)}")
for sp in samples:
    lines = [ln for ln in sp.read_text(encoding="utf-8").splitlines() if ln.strip()]
    if len(lines) < 1:
        errors.append(f"empty sample {sp.name}")
    for i, ln in enumerate(lines[:5], 1):
        row = json.loads(ln)
        if row.get("auditLabel") != "pending-human":
            errors.append(f"{sp.name} line {i} missing pending-human label")

freq = layers.get("enrichment.frequency.wordfreq") or {}
dist = freq.get("distribution") or {}
if dist.get("zipfMin") is None or dist.get("zipfMax") is None:
    errors.append("frequency distribution incomplete")

print(f"layers audited: {len(layers)}; sample files: {len(samples)}")
print(f"frequency zipf {dist.get('zipfMin')}..{dist.get('zipfMax')} p50={dist.get('zipfP50')}")
if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
PY
if [[ $? -eq 0 ]]; then
  pass "phase4 gates, samples, and frequency distribution valid"
else
  fail "phase4 report content failed"
fi

echo "=== core still validates alone ==="
if node "$VOCAB/scripts/validate-vocabulary-graph.js" >/dev/null; then
  pass "core graph validates without enrichment"
else
  fail "core validation failed"
fi

echo "=== results ==="
printf '%s\n' "${RESULTS[@]}"
echo "=== Total: $((PASS_COUNT + FAIL_COUNT)) checks (PASS=$PASS_COUNT, FAIL=$FAIL_COUNT) ==="
exit "$FAILED"
