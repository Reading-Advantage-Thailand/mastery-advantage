#!/usr/bin/env bash
set -uo pipefail
FAILED=0; PASS_COUNT=0; FAIL_COUNT=0; RESULTS=()
pass() { RESULTS+=("PASS: $1"); PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { RESULTS+=("FAIL: $1"); FAIL_COUNT=$((FAIL_COUNT + 1)); FAILED=1; }
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export TMPDIR="${TMPDIR:-/tmp/opencode}"
for check in \
  RB-P3R-B1-dangling-generated-leaf \
  RB-P3R-B1-tracked-report \
  RB-P3R-B1-tracked-generated-leaf \
  RB-P3R-B1-tracked-foreign-queue \
  RB-P3R-B1-foreign-queue-sentinel \
  RB-P3R-B2-validate-ambiguous \
  RB-P3R-B2-validate-invalid-cefr \
  RB-P3R-B2-mismatched-prior-identity \
  RB-P3R-B3-missing-citation-hash \
  RB-P3R-B3-malformed-citation-hash \
  RB-P3R-B3-conflicting-duplicate-identity \
  RB-P3R-B3-conflicting-duplicate-source \
  RB-P3R-B3-unsupported-audience \
  RB-P3R-B3-agreeing-duplicate; do
  echo "=== $check ==="
  if python3 "$ROOT/tests/gse_vocab_p3_review_support.py" "$check"; then
    pass "$check"
  else
    fail "$check"
  fi
done
printf '%s\n' "${RESULTS[@]}"
echo "=== Total: $((PASS_COUNT + FAIL_COUNT)) checks (PASS=$PASS_COUNT, FAIL=$FAIL_COUNT) ==="
exit "$FAILED"
