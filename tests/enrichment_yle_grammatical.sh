#!/usr/bin/env bash
# Validate YLE grammatical-groups enrichment overlay.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VOCAB="$ROOT/english/cefr-vocabulary"
PASS_COUNT=0
FAIL_COUNT=0
FAILED=0
RESULTS=()
pass() { RESULTS+=("PASS: $1"); PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { RESULTS+=("FAIL: $1"); FAIL_COUNT=$((FAIL_COUNT + 1)); FAILED=1; }

BUILDER="$VOCAB/scripts/build-yle-grammatical-groups.py"
OVERLAY="$VOCAB/overlays/yle-grammatical-groups.overlay.json"
REPORT="$VOCAB/reports/enrichment/yle-grammatical-groups.json"
CORE="$VOCAB/cefr-vocabulary-knowledge-space.json"
LAYER="enrichment.cambridge.grammatical-groups"

echo "=== builder compiles ==="
if [[ -f "$BUILDER" ]] && python3 -m py_compile "$BUILDER"; then
  pass "build-yle-grammatical-groups.py compiles"
else
  fail "builder missing or broken"
fi

echo "=== artifacts present ==="
if [[ -f "$OVERLAY" && -f "$REPORT" && -f "$VOCAB/fixtures/enrichment/yle-grammatical-structure.json" ]]; then
  pass "overlay, report, and fixture present"
else
  fail "missing grammatical enrichment artifacts"
fi

echo "=== overlay isolation and semantics ==="
python3 - "$OVERLAY" "$REPORT" "$CORE" "$LAYER" <<'PY' || exit 1
import json
import sys
from pathlib import Path

ov_p, rep_p, core_p, layer = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3]), sys.argv[4]
errors = []
ov = json.loads(ov_p.read_text(encoding="utf-8"))
rep = json.loads(rep_p.read_text(encoding="utf-8"))
core = json.loads(core_p.read_text(encoding="utf-8"))

if ov.get("enrichmentLayer") != layer:
    errors.append("layer id mismatch")
if any(e.get("type") == "prerequisite_for" for e in ov.get("edges", [])):
    errors.append("prerequisite_for present")
core_ids = {n["id"] for n in core.get("nodes", [])}
if any(n["id"] in core_ids for n in ov.get("nodes", [])):
    errors.append("overlay node ids collide with core")

groups = [n for n in ov.get("nodes", []) if (n.get("metadata") or {}).get("role") == "grammatical-group"]
if len(groups) < 10:
    errors.append(f"too few grammatical groups: {len(groups)}")

mem = [
    e for e in ov.get("edges", [])
    if e.get("type") == "contains"
    and str(e.get("targetId", "")).startswith("english.vocabulary.skill.")
]
if len(mem) < 500:
    errors.append(f"membership edges too few: {len(mem)}")

rate = float((ov.get("stats") or {}).get("matchRate") or 0)
if rate < 0.9:
    errors.append(f"match rate below 0.9: {rate}")

if rep.get("prerequisite_for_count_in_overlay") != 0:
    errors.append("report prereq nonzero")
if rep.get("coreGraphUntouched") is not True:
    errors.append("core must be untouched")

print(f"Groups: {len(groups)}")
print(f"Membership edges: {len(mem)}")
print(f"Match rate: {rate}")
if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
PY
if [[ $? -eq 0 ]]; then
  pass "grammatical overlay is isolated co-membership with high match rate"
else
  fail "overlay semantics failed"
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
