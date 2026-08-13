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
MUTATION_FIXTURE="$FIXTURE_DIR/mutation-cases.json"
ENTRYPOINT="$ROOT/english/cefr-vocabulary/scripts/gse-vocabulary-core.js"
FROZEN_YLE="$ROOT/english/cefr-vocabulary/cefr-vocabulary-knowledge-space.json"
QUEUE_NAMES=(
  "ambiguous-node-to-entry.jsonl"
  "unmapped-node-to-entry.jsonl"
  "unmatched-gse-entry.jsonl"
  "invalid-cefr-source-data.jsonl"
)

TEMP_ROOT=""
cleanup() {
  if [[ -n "$TEMP_ROOT" && -d "$TEMP_ROOT" ]]; then
    rm -rf -- "$TEMP_ROOT"
  fi
}
trap cleanup EXIT HUP INT TERM

if ! TEMP_ROOT="$(mktemp -d "/tmp/opencode/gse-vocab-p3-review.XXXXXX")"; then
  echo "=== prior graph preserves unrelated sentinel node ==="
  fail "prior graph preserves unrelated sentinel node"
  echo "=== newGraph prior increments version and reports zero mutation ==="
  fail "newGraph prior increments version and reports zero mutation"
  echo "=== validate-output rejects missing afternoon definition ==="
  fail "validate-output rejects missing afternoon definition"
  echo "=== results ==="
  printf '%s\n' "${RESULTS[@]}"
  echo "=== Total: $((PASS_COUNT + FAIL_COUNT)) checks (PASS=$PASS_COUNT, FAIL=$FAIL_COUNT) ==="
  exit "$FAILED"
fi

write_prior_graph() {
  local mode="$1"
  local destination="$2"
  python3 - "$MUTATION_FIXTURE" "$mode" "$destination" <<'PY'
import copy
import json
import sys
from pathlib import Path

fixture_path, mode, destination_arg = sys.argv[1:]
fixture = json.loads(Path(fixture_path).read_text(encoding="utf-8"))
mutation = next(
    row for row in fixture["cases"]
    if row.get("caseId") == "byte-diff-report-actual-mutation"
)

if mode == "sentinel":
    graph = copy.deepcopy(mutation["priorGraph"])
    graph["nodes"].append({
        "id": "fixture:core:unrelated-sentinel",
        "metadata": {"sentinel": "preserve-me"},
    })
elif mode == "new-graph":
    graph = copy.deepcopy(mutation["newGraph"])
else:
    raise SystemExit(f"unknown prior graph mode: {mode}")

destination = Path(destination_arg)
destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text(
    json.dumps(graph, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n",
    encoding="utf-8",
)
PY
}

run_cli() {
  local run_root="$1"
  local prior_graph="$2"
  local output_dir="$run_root/output"
  local queue_root="$run_root/english/cefr-vocabulary/review/gse-vocab/queues"
  local queue_name
  local queue_path
  local args=(
    node "$ENTRYPOINT"
    --fixture-dir "$FIXTURE_DIR"
    --prior-graph "$prior_graph"
    --output-dir "$output_dir"
  )

  mkdir -p "$queue_root" "$run_root/reports" || return 1
  for queue_name in "${QUEUE_NAMES[@]}"; do
    queue_path="$queue_root/$queue_name"
    : > "$queue_path" || return 1
    args+=(--queue-file "${queue_name}=${queue_path}")
  done
  args+=(
    --byte-diff-report "$run_root/reports/byte-diff.json"
    --mapping-quality-report "$run_root/reports/mapping-quality.json"
    --conflict-report "$run_root/reports/cambridge-gse-cefr-conflicts.jsonl"
    --frozen-yle "$FROZEN_YLE"
  )

  "${args[@]}" > "$run_root/stdout.log" 2> "$run_root/stderr.log"
}

probe_preserves_sentinel() {
  local run_root="$TEMP_ROOT/preserve-sentinel"
  local prior_graph="$run_root/prior-graph.json"
  mkdir -p "$run_root" || return 1
  write_prior_graph sentinel "$prior_graph" || return 1
  run_cli "$run_root" "$prior_graph" || return 1

  python3 - "$run_root/output/graph/new-graph.json" <<'PY'
import json
import sys
from pathlib import Path

graph = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
expected = {
    "id": "fixture:core:unrelated-sentinel",
    "metadata": {"sentinel": "preserve-me"},
}
if expected not in graph.get("nodes", []):
    raise SystemExit("unrelated sentinel node was not preserved")
PY
}

probe_zero_mutation_from_new_graph() {
  local run_root="$TEMP_ROOT/zero-mutation"
  local prior_graph="$run_root/prior-graph.json"
  mkdir -p "$run_root" || return 1
  write_prior_graph new-graph "$prior_graph" || return 1
  run_cli "$run_root" "$prior_graph" || return 1

  python3 - \
    "$prior_graph" \
    "$run_root/output/graph/new-graph.json" \
    "$run_root/reports/byte-diff.json" <<'PY'
import json
import re
import sys
from pathlib import Path

prior = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
current = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
report = json.loads(Path(sys.argv[3]).read_text(encoding="utf-8"))

prior_version = prior.get("schemaVersion")
match = re.fullmatch(r"(gse-vocab-[0-9]{8}-r)([0-9]+)", str(prior_version))
if match is None:
    raise SystemExit("prior graph version has no incrementable format")
expected_version = f"{match.group(1)}{int(match.group(2)) + 1:02d}"
if current.get("schemaVersion") != expected_version:
    raise SystemExit("graph version did not increment")
if report.get("changedNodeIds") != []:
    raise SystemExit("zero-mutation report contains changed node IDs")

counts = report.get("diffCounts")
if not isinstance(counts, dict):
    raise SystemExit("zero-mutation report lacks labelled diff counts")
for label in ("Levels added", "Levels corrected"):
    value = counts.get(label)
    if type(value) is not int or value != 0:
        raise SystemExit(f"{label} is not zero")
PY
}

probe_rejects_missing_definition() {
  local run_root="$TEMP_ROOT/missing-definition"
  local prior_graph="$run_root/prior-graph.json"
  local valid_graph="$run_root/output/graph/new-graph.json"
  local malformed_graph="$run_root/malformed-output.json"
  local diagnostic
  local validate_status
  mkdir -p "$run_root" || return 1
  write_prior_graph sentinel "$prior_graph" || return 1
  run_cli "$run_root" "$prior_graph" || return 1

  if ! node "$ENTRYPOINT" \
    --validate-output "$valid_graph" \
    --fixture-dir "$FIXTURE_DIR" \
    > "$run_root/valid-validation.stdout" \
    2> "$run_root/valid-validation.stderr"; then
    return 1
  fi

  python3 - "$valid_graph" "$malformed_graph" <<'PY'
import json
import sys
from pathlib import Path

source = Path(sys.argv[1])
destination = Path(sys.argv[2])
graph = json.loads(source.read_text(encoding="utf-8"))
for node in graph.get("nodes", []):
    if node.get("id") == "fixture:core:afternoon":
        gse = node.get("metadata", {}).get("gse")
        if not isinstance(gse, dict) or "definition" not in gse:
            raise SystemExit("valid output lacks the required afternoon definition")
        del gse["definition"]
        break
else:
    raise SystemExit("afternoon node is missing from valid output")

destination.write_text(
    json.dumps(graph, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n",
    encoding="utf-8",
)
PY

  if diagnostic="$(node "$ENTRYPOINT" \
    --validate-output "$malformed_graph" \
    --fixture-dir "$FIXTURE_DIR" 2>&1)"; then
    validate_status=0
  else
    validate_status=$?
  fi
  if [[ "$validate_status" -eq 0 ]]; then
    return 1
  fi
  diagnostic="${diagnostic,,}"
  [[ "$diagnostic" == *definition* || "$diagnostic" == *source* ]]
}

echo "=== prior graph preserves unrelated sentinel node ==="
if probe_preserves_sentinel; then
  pass "prior graph preserves unrelated sentinel node"
else
  fail "prior graph does not preserve unrelated sentinel node"
fi

echo "=== newGraph prior increments version and reports zero mutation ==="
if probe_zero_mutation_from_new_graph; then
  pass "newGraph prior increments version and reports zero mutation"
else
  fail "newGraph prior does not report an increment and zero mutation"
fi

echo "=== validate-output rejects missing afternoon definition ==="
if probe_rejects_missing_definition; then
  pass "validate-output rejects missing afternoon definition"
else
  fail "validate-output accepts missing afternoon definition or lacks a diagnostic"
fi

echo "=== results ==="
printf '%s\n' "${RESULTS[@]}"
echo "=== Total: $((PASS_COUNT + FAIL_COUNT)) checks (PASS=$PASS_COUNT, FAIL=$FAIL_COUNT) ==="
exit "$FAILED"
