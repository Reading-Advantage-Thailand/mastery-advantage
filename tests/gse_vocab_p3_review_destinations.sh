#!/usr/bin/env bash
set -uo pipefail
FAILED=0; PASS_COUNT=0; FAIL_COUNT=0; RESULTS=()
pass() { RESULTS+=("PASS: $1"); PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { RESULTS+=("FAIL: $1"); FAIL_COUNT=$((FAIL_COUNT + 1)); FAILED=1; }
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
for check in leaf-symlink leaf-hardlink parent-symlink dot-segments input-equality malformed-mapping-itemId malformed-mapping-definition malformed-mapping-temporaryGse malformed-mutation-itemId malformed-mutation-definition malformed-mutation-temporaryGse; do
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
