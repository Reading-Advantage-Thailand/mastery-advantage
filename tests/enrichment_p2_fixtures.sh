#!/usr/bin/env bash
# Harness for Coverage Enrichment Phase 2 structure fixtures.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS_COUNT=0
FAIL_COUNT=0
FAILED=0
RESULTS=()
pass() { RESULTS+=("PASS: $1"); PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { RESULTS+=("FAIL: $1"); FAIL_COUNT=$((FAIL_COUNT + 1)); FAILED=1; }

FIX="$ROOT/english/cefr-vocabulary/fixtures/enrichment"
PDF="$ROOT/english/cefr-vocabulary/source-pdfs"
PLAN="$ROOT/measure/tracks/lexical_coverage_enrichment_20260610/plan.md"

echo "=== required structure fixtures exist ==="
required=(
  yle-grammatical-structure.json
  a2-key-structure.json
  b1-preliminary-structure.json
  viu-elementary-structure.json
  frequency-fixture-schema.json
  isolation-contract.json
  manifest.json
)
missing=0
for f in "${required[@]}"; do
  if [[ ! -f "$FIX/$f" ]]; then
    echo "missing $f"
    missing=1
  fi
done
if [[ "$missing" -eq 0 ]]; then
  pass "all Phase 2 structure fixtures present"
else
  fail "one or more Phase 2 structure fixtures missing"
fi

echo "=== fixture integrity and source pins ==="
python3 - "$FIX" "$PDF" <<'PY' || exit 1
import hashlib
import json
import sys
from pathlib import Path

fix, pdf_dir = map(Path, sys.argv[1:])
errors = []

def load(name):
    p = fix / name
    if not p.is_file():
        errors.append(f"missing {name}")
        return {}
    return json.loads(p.read_text(encoding="utf-8"))

def check_sha(meta, key_pdf, key_sha):
    rel = meta.get(key_pdf)
    if not rel:
        return
    # path may be relative to english/cefr-vocabulary
    name = Path(rel).name
    path = pdf_dir / name
    if not path.is_file():
        errors.append(f"pdf missing for {rel}")
        return
    dig = hashlib.sha256(path.read_bytes()).hexdigest()
    if meta.get(key_sha) and meta[key_sha] != dig:
        errors.append(f"sha mismatch for {name}")

yle = load("yle-grammatical-structure.json")
if yle:
    check_sha(yle, "pdf", "sha256")
    sc = yle.get("structureChecks") or {}
    if not sc.get("titlePresent") or not sc.get("columnsPresent"):
        errors.append("YLE grammatical structure checks failed")
    if int(yle.get("labeledCategoryDetectCount") or 0) < 3:
        errors.append("YLE grammatical category detect count too low")
    if yle.get("layerId") != "enrichment.cambridge.grammatical-groups":
        errors.append("YLE layerId wrong")

a2 = load("a2-key-structure.json")
if a2:
    check_sha(a2, "pdf", "sha256")
    sc = a2.get("structureChecks") or {}
    if not sc.get("titleHasA2Key"):
        errors.append("A2 structure missing A2 Key title signal")

b1 = load("b1-preliminary-structure.json")
if b1:
    check_sha(b1, "pdf", "sha256")
    sc = b1.get("structureChecks") or {}
    if not sc.get("titleHasB1"):
        errors.append("B1 structure missing B1 title signal")

viu = load("viu-elementary-structure.json")
if viu:
    for k in ("frontmatterPdf", "indexPdf"):
        name = Path(viu.get(k, "")).name
        if not (pdf_dir / name).is_file():
            errors.append(f"ViU pdf missing: {name}")
    catalog = viu.get("unitCatalog") or {}
    if int(catalog.get("labeledUnitCount") or 0) < 10:
        errors.append("ViU unit catalog too small")
    if not catalog.get("unitNumberIsNotPrerequisite"):
        errors.append("ViU must declare unitNumber is not prerequisite")
    sample = viu.get("indexSample") or {}
    if int(sample.get("sampleSize") or 0) < 10:
        errors.append("ViU index sample too small")
    cases = {c.get("kind") for c in viu.get("fixtureCases") or []}
    for need in ("unmatched", "multi-unit", "variant"):
        if need not in cases:
            errors.append(f"ViU fixtureCases missing {need}")

freq = load("frequency-fixture-schema.json")
if freq:
    if freq.get("layerId") != "enrichment.frequency.wordfreq":
        errors.append("frequency layerId wrong")
    kinds = {c.get("kind") or c.get("expect") for c in freq.get("cases") or []}
    if "missing-true" not in kinds and "has-zipf" not in kinds:
        errors.append("frequency cases incomplete")

iso = load("isolation-contract.json")
if iso:
    if iso.get("forbiddenEdgeTypeFromEnrichment") != "prerequisite_for":
        errors.append("isolation must forbid prerequisite_for")
    if not iso.get("coreMustLoadWithoutEnrichment"):
        errors.append("isolation must allow core-only load")

# Reject full expressive wordlist dumps in fixture dir
for p in fix.glob("*.jsonl"):
    errors.append(f"unexpected full jsonl fixture dump: {p.name}")
for p in fix.glob("*wordlist*"):
    errors.append(f"unexpected wordlist artifact: {p.name}")

print(f"Fixture JSON count: {len(list(fix.glob('*.json')))}")
print(f"YLE category detect count: {yle.get('labeledCategoryDetectCount')}")
print(f"ViU labeled unit count: {(viu.get('unitCatalog') or {}).get('labeledUnitCount')}")
print(f"ViU index sample size: {(viu.get('indexSample') or {}).get('sampleSize')}")
if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
PY
fix_status=$?
if [[ "$fix_status" -eq 0 ]]; then
  pass "fixture integrity, source pins, and non-expressive policy hold"
else
  fail "fixture integrity checks failed"
fi

echo "=== plan references Phase 2 fixtures ==="
if grep -q 'fixtures/enrichment' "$PLAN" 2>/dev/null || grep -q 'enrichment_p2_fixtures' "$PLAN" 2>/dev/null; then
  pass "plan references enrichment fixtures or harness"
else
  # soft: still fail so plan gets updated
  fail "plan lacks fixtures/enrichment or enrichment_p2_fixtures evidence"
fi

echo "=== results ==="
printf '%s\n' "${RESULTS[@]}"
echo "=== Total: $((PASS_COUNT + FAIL_COUNT)) checks (PASS=$PASS_COUNT, FAIL=$FAIL_COUNT) ==="
exit "$FAILED"
