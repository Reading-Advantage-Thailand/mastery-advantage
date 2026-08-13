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

prepare_yle_fixtures() {
  local before_fixture="$1"
  local after_fixture="$2"
  cp -R -- "$FIXTURE_DIR" "$before_fixture" || return 1
  cp -R -- "$FIXTURE_DIR" "$after_fixture" || return 1

  python3 - "$before_fixture/records.json" "$after_fixture/records.json" <<'PY'
import json
import sys
from pathlib import Path

before_path = Path(sys.argv[1])
after_path = Path(sys.argv[2])
before = json.loads(before_path.read_text(encoding="utf-8"))
after = json.loads(after_path.read_text(encoding="utf-8"))

target_index = None
for index, row in enumerate(after.get("records", [])):
    record = row.get("record") if isinstance(row, dict) else None
    if isinstance(record, dict) and isinstance(record.get("gse"), str):
        target_index = index
        old_value = record["gse"]
        break
if target_index is None:
    raise SystemExit("the fixture has no GSE record to mutate")

new_value = "20*"
if old_value == new_value:
    new_value = "21*"
after["records"][target_index]["record"]["gse"] = new_value
after_path.write_text(
    json.dumps(after, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n",
    encoding="utf-8",
)

def differences(left, right, path=()):
    if type(left) is not type(right):
        return [path]
    if isinstance(left, dict):
        if set(left) != set(right):
            return [path]
        result = []
        for key in sorted(left):
            result.extend(differences(left[key], right[key], path + (key,)))
        return result
    if isinstance(left, list):
        if len(left) != len(right):
            return [path]
        result = []
        for index, (left_item, right_item) in enumerate(zip(left, right)):
            result.extend(differences(left_item, right_item, path + (index,)))
        return result
    return [] if left == right else [path]

updated = json.loads(after_path.read_text(encoding="utf-8"))
expected = [("records", target_index, "record", "gse")]
if differences(before, updated) != expected:
    raise SystemExit("YLE fixture copies differ outside one GSE record")
PY
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
  [[ -n "$TEMP_ROOT" && -d "$FIXTURE_DIR" && -f "$ENTRYPOINT" && -f "$FROZEN_YLE" ]] || return 1
  local before_fixture="$TEMP_ROOT/yle-before-fixture"
  local after_fixture="$TEMP_ROOT/yle-after-fixture"
  local before_run="$TEMP_ROOT/yle-before-run"
  local after_run="$TEMP_ROOT/yle-after-run"
  local frozen_before
  local frozen_after

  frozen_before="$(sha256sum -- "$FROZEN_YLE")" || return 1
  frozen_before="${frozen_before%% *}"
  prepare_yle_fixtures "$before_fixture" "$after_fixture" || return 1
  mkdir -p -- "$before_run" "$after_run" || return 1
  make_prior_graph "$before_fixture" "$before_run/prior-graph.json" || return 1
  make_prior_graph "$after_fixture" "$after_run/prior-graph.json" || return 1

  build_args "$before_run" "$before_fixture" "$FROZEN_YLE" "$before_run/reports/byte-diff-report.json" "$before_run/yle-output.json"
  CLI_ARGS+=(--run-label before --mutation-applied-between-runs)
  run_cli
  (( CLI_STATUS == 0 )) || return 1

  build_args "$after_run" "$after_fixture" "$FROZEN_YLE" "$after_run/reports/byte-diff-report.json" "$after_run/yle-output.json"
  CLI_ARGS+=(--run-label after --mutation-applied-between-runs)
  run_cli
  (( CLI_STATUS == 0 )) || return 1

  [[ -s "$before_run/yle-output.json" && -s "$after_run/yle-output.json" ]] || return 1
  cmp -s "$before_run/yle-output.json" "$after_run/yle-output.json" || return 1
  if cmp -s "$before_run/yle-output.json" "$FROZEN_YLE"; then
    return 1
  fi
  if cmp -s "$after_run/yle-output.json" "$FROZEN_YLE"; then
    return 1
  fi
  frozen_after="$(sha256sum -- "$FROZEN_YLE")" || return 1
  frozen_after="${frozen_after%% *}"
  [[ "$frozen_before" == "$frozen_after" ]]
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
