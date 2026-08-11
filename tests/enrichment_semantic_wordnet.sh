#!/usr/bin/env bash
# WordNet semantic candidate overlay harness.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VOCAB="$ROOT/english/cefr-vocabulary"
PASS_COUNT=0
FAIL_COUNT=0
FAILED=0
RESULTS=()
pass() { RESULTS+=("PASS: $1"); PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { RESULTS+=("FAIL: $1"); FAIL_COUNT=$((FAIL_COUNT + 1)); FAILED=1; }

BUILDER="$VOCAB/scripts/build-wordnet-semantic.py"
OVERLAY="$VOCAB/overlays/semantic-wordnet.overlay.json"
REPORT="$VOCAB/reports/enrichment/semantic-wordnet.json"
AMBIG="$VOCAB/review/enrichment/queues/semantic-ambiguous.jsonl"
CORE="$VOCAB/cefr-vocabulary-knowledge-space.json"
FIXTURE="$VOCAB/fixtures/enrichment/semantic-relation-fixtures.json"

echo "=== builder present ==="
if [[ -f "$BUILDER" ]]; then
  pass "build-wordnet-semantic.py present"
else
  fail "builder missing"
fi

echo "=== artifacts present ==="
if [[ -f "$OVERLAY" && -f "$REPORT" && -f "$AMBIG" && -f "$FIXTURE" ]]; then
  pass "overlay, report, ambiguous queue, fixtures present"
else
  fail "missing semantic wordnet artifacts"
fi

echo "=== overlay isolation and contract ==="
python3 - "$OVERLAY" "$REPORT" "$CORE" "$AMBIG" <<'PY' || exit 1
import json, sys
from pathlib import Path
ov = json.loads(Path(sys.argv[1]).read_text())
rep = json.loads(Path(sys.argv[2]).read_text())
core = json.loads(Path(sys.argv[3]).read_text())
ambig_path = Path(sys.argv[4])
errors = []
if ov.get("enrichmentLayer") != "enrichment.semantic.wordnet":
    errors.append("layer family mismatch")
if any(e.get("type") == "prerequisite_for" for e in ov.get("edges", [])):
    errors.append("prerequisite_for present")
if any(n.get("kind") == "skill" for n in ov.get("nodes", [])):
    errors.append("overlay must not add skills")
core_skills = {n["id"] for n in core.get("nodes", []) if n.get("kind") == "skill"}
edges = ov.get("edges") or []
if len(edges) < 100:
    errors.append(f"too few edges: {len(edges)}")
rels = set()
for e in edges:
    meta = e.get("metadata") or {}
    if not meta.get("semanticRelation"):
        errors.append("edge missing semanticRelation")
        break
    if not meta.get("enrichmentLayer", "").startswith("enrichment.semantic.wordnet."):
        errors.append("edge layer id wrong")
        break
    if e.get("sourceId") not in core_skills or e.get("targetId") not in core_skills:
        errors.append("edge endpoints must be core skills")
        break
    if not meta.get("sourceSenseId"):
        errors.append("missing sourceSenseId")
        break
    rels.add(meta["semanticRelation"])
need = {"synonym", "antonym", "hypernym", "hyponym", "meronym", "holonym"}
if not need.issubset(rels):
    errors.append(f"missing relations: {need - rels}")
if rep.get("prerequisite_for_count_in_overlay") != 0:
    errors.append("report prereq")
if rep.get("ambiguousQuarantined") is not True:
    errors.append("must quarantine ambiguous")
ambig = [ln for ln in ambig_path.read_text().splitlines() if ln.strip()]
if len(ambig) < 10:
    errors.append("ambiguous queue too small")
print(f"edges={len(edges)} relations={sorted(rels)} ambig={len(ambig)}")
if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
PY
if [[ $? -eq 0 ]]; then
  pass "wordnet overlay isolation and relation coverage ok"
else
  fail "wordnet overlay checks failed"
fi

echo "=== core validates alone ==="
if node "$VOCAB/scripts/validate-vocabulary-graph.js" >/dev/null; then
  pass "core validates without semantic overlay"
else
  fail "core validation failed"
fi

echo "=== phase1 approval still recorded ==="
if grep -qiE 'Decision:\**[[:space:]]*go' "$VOCAB/review/enrichment/phase1-semantic-approval.md"; then
  pass "semantic Phase 1 go present"
else
  fail "semantic Phase 1 go missing"
fi

echo "=== results ==="
printf '%s\n' "${RESULTS[@]}"
echo "=== Total: $((PASS_COUNT + FAIL_COUNT)) checks (PASS=$PASS_COUNT, FAIL=$FAIL_COUNT) ==="
exit "$FAILED"
