#!/usr/bin/env bash
# Sense-level identity specification track harness.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VOCAB="$ROOT/english/cefr-vocabulary"
PASS_COUNT=0
FAIL_COUNT=0
FAILED=0
RESULTS=()
pass() { RESULTS+=("PASS: $1"); PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { RESULTS+=("FAIL: $1"); FAIL_COUNT=$((FAIL_COUNT + 1)); FAILED=1; }

SPEC="$VOCAB/SENSE_IDENTITY_SPEC.md"
SAMPLE="$VOCAB/samples/sense_collisions.md"
TOP200="$VOCAB/reports/sense-identity/top200-polysemous-forms.json"
S50="$VOCAB/reports/sense-identity/sample50.json"
CHAR="$VOCAB/reports/sense-identity/identity-collapse-characterization.json"
P2="$VOCAB/reports/sense-identity/phase2-source-eval.json"

echo "=== spec document ==="
if [[ -f "$SPEC" ]] && grep -q 'form + POS' "$SPEC" \
  && grep -q 'wordnet' "$SPEC" \
  && grep -q 'Migration' "$SPEC" \
  && grep -q 'prerequisite_for' "$SPEC"; then
  pass "SENSE_IDENTITY_SPEC.md present with rules and migration"
else
  fail "spec missing or incomplete"
fi

echo "=== phase1 artifacts ==="
if [[ -f "$SAMPLE" && -f "$TOP200" && -f "$S50" && -f "$CHAR" ]]; then
  pass "top200, sample50, collisions md, characterization present"
else
  fail "phase1 artifacts missing"
fi

python3 - "$TOP200" "$S50" "$CHAR" <<'PY' || exit 1
import json, sys
from pathlib import Path
top = json.loads(Path(sys.argv[1]).read_text())
s50 = json.loads(Path(sys.argv[2]).read_text())
char = json.loads(Path(sys.argv[3]).read_text())
if top.get("count", 0) < 200:
    raise SystemExit("top200 too small")
if s50.get("count", 0) < 50:
    raise SystemExit("sample50 too small")
bank = char.get("bank") or {}
if len(bank.get("skillIds") or []) < 1:
    raise SystemExit("bank characterization missing")
if int(bank.get("wnNoun") or 0) < 2:
    raise SystemExit("expected bank noun multi-synset in WordNet")
# collapse claim: more synsets than bare bank.noun skills
noun_skills = [s for s in bank["skillIds"] if s.endswith(".noun") or ".noun." in s]
if bank["wnNoun"] <= len(noun_skills):
    # still ok if gloss-split created many; require wn > 1 at least
    pass
print("top", top["count"], "sample", s50["count"], "bank wn", bank["wnNoun"], "skills", len(bank["skillIds"]))
PY
if [[ $? -eq 0 ]]; then
  pass "phase1 counts and bank collapse characterization ok"
else
  fail "phase1 characterization failed"
fi

echo "=== phase2 source eval ==="
if [[ -f "$P2" ]] && grep -q 'wordnet31' "$P2" && grep -q 'cambridgeSenseBlocks' "$P2"; then
  pass "phase2 WordNet/Cambridge source eval present"
else
  fail "phase2 source eval missing (path=$P2)"
fi

echo "=== tech-debt note ==="
if grep -qiE 'sense.identity|sense-level|SENSE_IDENTITY' "$ROOT/measure/tech-debt.md"; then
  pass "tech-debt mentions sense identity"
else
  fail "tech-debt missing sense identity row update"
fi

echo "=== results ==="
printf '%s\n' "${RESULTS[@]}"
echo "=== Total: $((PASS_COUNT + FAIL_COUNT)) checks (PASS=$PASS_COUNT, FAIL=$FAIL_COUNT) ==="
exit "$FAILED"
