#!/usr/bin/env bash
set -uo pipefail

FAILED=0
PASS_COUNT=0
FAIL_COUNT=0
RESULTS=()

pass() {
  RESULTS+=("PASS: $1")
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  RESULTS+=("FAIL: $1")
  FAIL_COUNT=$((FAIL_COUNT + 1))
  FAILED=1
}

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="$ROOT/english/cefr-vocabulary/fixtures/gse-vocab"
ENTRYPOINT="$ROOT/english/cefr-vocabulary/scripts/gse-vocabulary-core.js"
FROZEN_YLE="$ROOT/english/cefr-vocabulary/cefr-vocabulary-knowledge-space.json"
TEMP_ROOT=""
CLI_ARGS=()
CLI_OUTPUT=""
CLI_STATUS=1

if ! TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/gse-vocab-p3-review-safety.XXXXXX")"; then
  TEMP_ROOT=""
fi

cleanup() {
  if [[ -n "$TEMP_ROOT" ]]; then
    rm -rf -- "$TEMP_ROOT"
  fi
}
trap cleanup EXIT HUP INT TERM

make_prior_graph() {
  local fixture_dir="$1"
  local destination="$2"
  python3 - "$fixture_dir/mutation-cases.json" "$destination" <<'PY'
import json
import sys
from pathlib import Path

source_path = Path(sys.argv[1])
destination = Path(sys.argv[2])
document = json.loads(source_path.read_text(encoding="utf-8"))
matches = [
    row.get("priorGraph")
    for row in document.get("cases", [])
    if row.get("caseId") == "byte-diff-report-actual-mutation"
]
if len(matches) != 1 or not isinstance(matches[0], dict):
    raise SystemExit("the byte-diff fixture does not provide one prior graph")
destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text(
    json.dumps(matches[0], ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n",
    encoding="utf-8",
)
PY
}

build_args() {
  local run_dir="$1"
  local fixture_dir="$2"
  local frozen_path="$3"
  local diff_report="$4"
  local yle_output="$5"

  CLI_ARGS=(
    node "$ENTRYPOINT"
    --fixture-dir "$fixture_dir"
    --prior-graph "$run_dir/prior-graph.json"
    --output-dir "$run_dir/output"
    --queue-file "ambiguous-node-to-entry.jsonl=$run_dir/queues/ambiguous-node-to-entry.jsonl"
    --queue-file "unmapped-node-to-entry.jsonl=$run_dir/queues/unmapped-node-to-entry.jsonl"
    --queue-file "unmatched-gse-entry.jsonl=$run_dir/queues/unmatched-gse-entry.jsonl"
    --queue-file "invalid-cefr-source-data.jsonl=$run_dir/queues/invalid-cefr-source-data.jsonl"
    --byte-diff-report "$diff_report"
    --mapping-quality-report "$run_dir/reports/mapping-quality-report.json"
    --conflict-report "$run_dir/reports/conflict-report.jsonl"
    --yle-output "$yle_output"
    --frozen-yle "$frozen_path"
  )
}

run_cli() {
  CLI_OUTPUT="$("${CLI_ARGS[@]}" 2>&1)"
  CLI_STATUS=$?
}

probe_frozen_alias() {
  [[ -n "$TEMP_ROOT" && -d "$FIXTURE_DIR" && -f "$ENTRYPOINT" ]] || return 1
  local run_dir="$TEMP_ROOT/frozen-alias"
  local alias_path="$run_dir/frozen-and-diff.bin"
  local expected_alias="$run_dir/frozen-and-diff.expected"
  mkdir -p -- "$run_dir" || return 1
  make_prior_graph "$FIXTURE_DIR" "$run_dir/prior-graph.json" || return 1
  printf 'frozen-input-sentinel\n' > "$alias_path" || return 1
  cp -- "$alias_path" "$expected_alias" || return 1

  build_args "$run_dir" "$FIXTURE_DIR" "$alias_path" "$alias_path" "$run_dir/yle-output.json"
  run_cli
  (( CLI_STATUS != 0 )) || return 1
  cmp -s "$alias_path" "$expected_alias" || return 1
  [[ ! -e "$run_dir/output" ]] || return 1
  [[ ! -e "$run_dir/queues" ]] || return 1
  [[ ! -e "$run_dir/reports" ]] || return 1
  [[ ! -e "$run_dir/yle-output.json" ]] || return 1
}

probe_unknown_option() {
  [[ -n "$TEMP_ROOT" && -d "$FIXTURE_DIR" && -f "$ENTRYPOINT" ]] || return 1
  local run_dir="$TEMP_ROOT/unknown-option"
  mkdir -p -- "$run_dir" || return 1
  make_prior_graph "$FIXTURE_DIR" "$run_dir/prior-graph.json" || return 1
  build_args "$run_dir" "$FIXTURE_DIR" "$FROZEN_YLE" "$run_dir/reports/byte-diff-report.json" "$run_dir/yle-output.json"
  CLI_ARGS+=(--unknown-option unexpected)
  run_cli
  (( CLI_STATUS != 0 )) || return 1
  [[ "${CLI_OUTPUT,,}" == *unknown*option* ]]
}

probe_yle_independence() {
  python3 "$ROOT/tests/gse_vocab_p3_review_support.py" yle-graph
}

echo "=== frozen YLE and byte-diff paths reject an alias before writes ==="
if probe_frozen_alias; then
  pass "the shared frozen YLE and byte-diff path is rejected without writes"
else
  fail "the shared frozen YLE and byte-diff path was accepted or changed"
fi

echo "=== unknown CLI options are rejected with a diagnostic ==="
if probe_unknown_option; then
  pass "the unknown option fails with an unknown-option diagnostic"
else
  fail "the unknown option was accepted or lacked an unknown-option diagnostic"
fi

echo "=== YLE proof output is independent of frozen input bytes ==="
if probe_yle_independence; then
  pass "before and after temporary YLE outputs match, differ from frozen bytes, and preserve the frozen artifact"
else
  fail "the independent before-and-after YLE proof failed"
fi

echo "=== results ==="
printf '%s\n' "${RESULTS[@]}"
echo "=== Total: $((PASS_COUNT + FAIL_COUNT)) checks (PASS=$PASS_COUNT, FAIL=$FAIL_COUNT) ==="
exit "$FAILED"
