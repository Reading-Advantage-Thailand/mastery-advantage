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
TRACK_ID="gse_vocabulary_core_enrichment_20260811"
SOURCES="$ROOT/english/cefr-vocabulary/GSE_VOCABULARY_SOURCES.md"
GL_JSON="$ROOT/english/cefr-vocabulary/source-pdfs/gse-vocabulary-gl-10-67-2026-08-11.json"
YL_JSON="$ROOT/english/cefr-vocabulary/source-pdfs/gse-vocabulary-yl-10-59-2026-08-11.json"
REVIEW_DIR="$ROOT/english/cefr-vocabulary/review/gse-vocab"
MAPPING="$REVIEW_DIR/phase1-mapping-contract.md"
MUTATION="$REVIEW_DIR/phase1-mutation-contract.md"
SAMPLES="$REVIEW_DIR/phase1-review-samples.md"
PLAN="$ROOT/measure/tracks/$TRACK_ID/plan.md"
REGISTRY="$ROOT/measure/tracks.md"
YLE_RELEASE="$ROOT/english/cefr-vocabulary/review/yle-2025/RELEASE-YLE-2025.md"

doc_patterns() {
  local file="$1"
  shift
  python3 - "$file" "$@" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
patterns = sys.argv[2:]
if not path.is_file():
    print(f"missing document: {path}")
    raise SystemExit(1)

text = path.read_text(encoding="utf-8")
missing = [pattern for pattern in patterns if re.search(pattern, text, re.IGNORECASE | re.DOTALL) is None]
if missing:
    print(f"missing patterns in {path}:")
    for pattern in missing:
        print(f"  {pattern}")
    raise SystemExit(1)
PY
}

echo "=== pinned source provenance records both exports and policy decisions ==="
if doc_patterns "$SOURCES" \
  'gse-vocabulary-gl-10-67-2026-08-11\.json' \
  'gse-vocabulary-yl-10-59-2026-08-11\.json' \
  'gseRange=10;67' \
  'gseRange=10;59' \
  'audience=GL' \
  'audience=YL' \
  'api/v1/vocabulary/search' \
  'page' \
  'size=2000' \
  'query_string=\*' \
  'sort=gse' \
  'grammaticalCategories' \
  '2026-08-11' \
  'e63298d796eecc1d9ed68cd5bde28d01912cfe3312a1381d2b074cdbe9b90800' \
  '6b8c895055ea6c24c8f29b9e2999676444ffe3507a61725a9595f6eab784ab30' \
  'SHA-256' \
  'Licensing' \
  'Redistribution Decision' \
  'Cache Policy'; then
  pass "GSE GL/YL URLs, query parameters, date, hashes, licence, redistribution, and cache policy are pinned"
else
  fail "GSE source provenance is incomplete"
fi

echo "=== FR-6 records the owner decision for definition and example text ==="
if doc_patterns "$SOURCES" \
  'FR-6 option b' \
  'definition and example text' \
  'measuring mastery levels and planning instruction' \
  'non-commercial'; then
  pass "FR-6 owner words and permitted use are recorded"
else
  fail "FR-6 owner decision or use boundary is missing"
fi

source_probe_status=0
source_probe_output=""
if source_probe_output="$(python3 - "$GL_JSON" "$YL_JSON" <<'PY'
import json
import sys
from pathlib import Path

gl_path, yl_path = map(Path, sys.argv[1:])

def load_records(path):
    payload = json.loads(path.read_text(encoding="utf-8"))
    records = payload.get("data")
    if not isinstance(records, list):
        raise ValueError(f"data is not a list in {path}")
    if payload.get("count") != len(records):
        raise ValueError(f"count field does not match data length in {path}")
    return records

gl = load_records(gl_path)
yl = load_records(yl_path)
values = {
    "GL items": len(gl),
    "YL items": len(yl),
    "starred GL gse": sum(
        isinstance(row.get("gse"), str) and "*" in row["gse"] for row in gl
    ),
    "YL temporaryGse": sum(row.get("temporaryGse") is True for row in yl),
}
expected = {
    "GL items": 11586,
    "YL items": 3024,
    "starred GL gse": 70,
    "YL temporaryGse": 129,
}
for label, value in values.items():
    print(f"{label}: {value}")
if values != expected:
    raise SystemExit(f"unexpected labelled source counts: {values!r}")
PY
)"; then
  source_probe_status=0
else
  source_probe_status=$?
fi

echo "=== read-only source probe verifies labelled inventory and special-value counts ==="
printf '%s\n' "$source_probe_output"
if [[ "$source_probe_status" -eq 0 ]] \
  && [[ "$source_probe_output" == *"GL items: 11586"* ]] \
  && [[ "$source_probe_output" == *"YL items: 3024"* ]] \
  && [[ "$source_probe_output" == *"starred GL gse: 70"* ]] \
  && [[ "$source_probe_output" == *"YL temporaryGse: 129"* ]]; then
  pass "pinned cache has GL items: 11586, YL items: 3024, starred GL gse: 70, and YL temporaryGse: 129"
else
  fail "pinned cache labelled counts do not match the source record"
fi

tracked_raw="$(git -C "$ROOT" ls-files -- 'english/cefr-vocabulary/source-pdfs/*.json')"
unignored_raw=""
for raw_path in \
  "english/cefr-vocabulary/source-pdfs/gse-vocabulary-gl-10-67-2026-08-11.json" \
  "english/cefr-vocabulary/source-pdfs/gse-vocabulary-yl-10-59-2026-08-11.json"; do
  if ! git -C "$ROOT" check-ignore -q --no-index -- "$raw_path"; then
    unignored_raw+=" $raw_path"
  fi
done
echo "=== raw GSE exports remain outside the tracked publication set ==="
if [[ -z "$tracked_raw" && -z "$unignored_raw" ]]; then
  pass "raw source-pdfs JSON exports are not tracked"
else
  fail "raw GSE exports must be ignored and untracked; tracked=[$tracked_raw] unignored=[$unignored_raw]"
fi

echo "=== source hashes match the pinned provenance record ==="
hash_status=0
hash_error=""
if hash_error="$(python3 - "$SOURCES" "$GL_JSON" "$YL_JSON" <<'PY'
import hashlib
import re
import sys
from pathlib import Path

sources_path, gl_path, yl_path = map(Path, sys.argv[1:])
text = sources_path.read_text(encoding="utf-8")
for path in (gl_path, yl_path):
    actual = hashlib.sha256(path.read_bytes()).hexdigest()
    if actual not in text:
        print(f"{path.name} SHA-256 is absent or does not match the provenance document")
        raise SystemExit(1)
PY
)"; then
  hash_status=0
else
  hash_status=$?
fi
if [[ "$hash_status" -eq 0 ]]; then
  pass "read-only SHA-256 probes match both pinned export records"
else
  printf '%s\n' "$hash_error"
  fail "a pinned export hash does not match its provenance record"
fi

echo "=== mapping contract binds core form and POS to GSE expression and categories ==="
binding_status=0
binding_error=""
if binding_error="$(python3 - "$MAPPING" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
if not path.is_file():
    raise SystemExit(f"missing document: {path}")
text = path.read_text(encoding="utf-8")

anchors = list(re.finditer(r"binding rule|node[- ]to[- ]entry|mapping rule|matching rule", text, re.IGNORECASE))
windows = [text[max(0, match.start() - 220): match.end() + 1500] for match in anchors]
required = {
    "core form identity": r"core node|normalizedHeadword|form",
    "core POS": r"partsOfSpeech|part[s]?[- ]of[- ]speech|\bPOS\b",
    "GSE expression": r"GSE.{0,80}expression|expression",
    "GSE grammatical categories": r"grammaticalCategories|grammatical categor(?:y|ies)",
    "audience": r"audience",
    "GL audience": r"\bGL\b",
    "YL audience": r"\bYL\b",
    "binding operation": r"match|bind|join|key|equal|correspond",
}
if not windows:
    raise SystemExit("mapping contract has no binding-rule section")
if not any(
    all(re.search(pattern, window, re.IGNORECASE | re.DOTALL) for pattern in required.values())
    for window in windows
):
    raise SystemExit("one binding-rule section does not require core form + POS, GSE expression + categories, and audience")

pos_anchors = list(re.finditer(r"POS.{0,80}(?:normalization|mapping)|(?:normalization|mapping).{0,80}POS", text, re.IGNORECASE))
pos_windows = [text[max(0, match.start() - 160): match.end() + 900] for match in pos_anchors]
if not any(
    re.search(r"phrase", window, re.IGNORECASE)
    and re.search(r"phrasal verb", window, re.IGNORECASE)
    and re.search(r"map|normaliz|correspond|=>|->", window, re.IGNORECASE)
    for window in pos_windows
):
    raise SystemExit("POS normalization map does not distinguish phrase and phrasal verb")

audience_anchors = list(re.finditer(r"audience.{0,100}(?:rule|match|handling|filter|separat|distinguish)|(?:rule|match|handling|filter|separat|distinguish).{0,100}audience", text, re.IGNORECASE))
audience_windows = [text[max(0, match.start() - 120): match.end() + 650] for match in audience_anchors]
if not any(
    re.search(r"\bGL\b", window)
    and re.search(r"\bYL\b", window)
    and re.search(r"match|separat|filter|distinguish|not.{0,30}(?:cross|mix|substitut)", window, re.IGNORECASE)
    for window in audience_windows
):
    raise SystemExit("audience rule does not separate or match GL and YL")

form_only_anchors = list(re.finditer(r"form[- ]only|only the form|form alone", text, re.IGNORECASE))
if not any(
    re.search(r"not|reject|unsafe|insufficient|prohibit|forbid|does not|cannot", text[max(0, match.start() - 160): match.end() + 260], re.IGNORECASE)
    for match in form_only_anchors
):
    raise SystemExit("mapping contract does not reject form-only mapping")
PY
)"; then
  binding_status=0
else
  binding_status=$?
fi
if [[ "$binding_status" -eq 0 ]]; then
  pass "mapping requires form, POS normalization, and GL/YL audience handling instead of form-only matching"
else
  printf '%s\n' "$binding_error"
  fail "mapping contract does not prove form + POS + audience binding and form-only rejection"
fi

echo "=== mapping contract preserves and explains starred and temporary source values ==="
special_status=0
special_error=""
if special_error="$(python3 - "$MAPPING" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
if not path.is_file():
    raise SystemExit(f"missing document: {path}")
text = path.read_text(encoding="utf-8")

groups = [
    (
        r"\b70\b",
        [r"starred", r"\bgse\b", r"preserv|retain|keep|not.{0,20}drop|do not.{0,20}drop", r"explain|semantic|meaning|marker|asterisk|source value"],
        "70 starred GL gse values",
    ),
    (
        r"\b129\b",
        [r"temporaryGse", r"preserv|retain|keep|not.{0,20}drop|do not.{0,20}drop", r"explain|semantic|meaning|flag|boolean|source value"],
        "129 YL temporaryGse values",
    ),
]

for anchor, requirements, label in groups:
    found = False
    for match in re.finditer(anchor, text, re.IGNORECASE):
        window = text[max(0, match.start() - 260): match.end() + 520]
        if all(re.search(pattern, window, re.IGNORECASE | re.DOTALL) for pattern in requirements):
            found = True
            break
    if not found:
        print(f"missing preservation/explanation clause for {label}")
        raise SystemExit(1)
PY
)"; then
  special_status=0
else
  special_status=$?
fi
if [[ "$special_status" -eq 0 ]]; then
  pass "mapping contract retains source semantics for 70 starred GL gse values and 129 YL temporaryGse values"
else
  printf '%s\n' "$special_error"
  fail "mapping contract can drop or misinterpret starred/temporary source values"
fi

echo "=== mapping contract defines durable ambiguous and unmapped queue row shapes ==="
queue_shape_status=0
queue_shape_error=""
if queue_shape_error="$(python3 - "$MAPPING" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
if not path.is_file():
    raise SystemExit(f"missing document: {path}")
text = path.read_text(encoding="utf-8")

def section_windows(anchor):
    return [
        text[max(0, match.start() - 120): match.end() + 1100]
        for match in re.finditer(anchor, text, re.IGNORECASE)
    ]

requirements = {
    "ambiguous": [
        r"node[_ ]?Id|node identity",
        r"candidate(?:s|ItemIds)?|possible",
        r"reason",
        r"form|normalizedHeadword",
        r"durable|persist",
    ],
    "unmapped": [
        r"node[_ ]?Id|item[_ ]?Id",
        r"reason",
        r"form|expression|normalizedHeadword",
        r"audience",
        r"durable|persist",
    ],
}
for label, patterns in requirements.items():
    windows = section_windows(label)
    if not windows:
        print(f"missing {label} queue section")
        raise SystemExit(1)
    if not any(
        all(re.search(pattern, window, re.IGNORECASE | re.DOTALL) for pattern in patterns)
        for window in windows
    ):
        print(f"{label} queue section lacks its durable row fields")
        raise SystemExit(1)
PY
)"; then
  queue_shape_status=0
else
  queue_shape_status=$?
fi
if [[ "$queue_shape_status" -eq 0 ]]; then
  pass "ambiguous and unmapped queues define durable identity, candidate/source, reason, form, and audience fields"
else
  printf '%s\n' "$queue_shape_error"
  fail "ambiguous or unmapped queue shape is missing"
fi

echo "=== mapping contract isolates queues to this track and rejects foreign queue influence ==="
if doc_patterns "$MAPPING" \
  'FR-8' \
  'queue[ -]?(?:isolation|files|directory)' \
  "(?:review/gse-vocab|measure/tracks/$TRACK_ID)/queues?/" \
  'foreign queue.{0,220}(?:must not|cannot|does not|must never).{0,220}(?:change|affect|poison|report)' \
  'ambiguous' \
  'unmapped'; then
  pass "queue paths are explicit under this track and foreign queues cannot alter its reports"
else
  fail "mapping contract lacks explicit FR-8 queue isolation"
fi

echo "=== mapping contract enforces item citations and no inference for absent entries ==="
if doc_patterns "$MAPPING" \
  '(?:mapped node|mapped nodes).{0,220}(?:itemId|item ID)' \
  'no[- ]inference|no inference|must not infer|do not infer|never infer' \
  '(?:absent|unmapped|no matching).{0,220}(?:queue|no GSE data|no data)'; then
  pass "mapped nodes cite itemId and absent matches create queue evidence without inferred GSE data"
else
  fail "mapping contract permits inferred data or omits mapped itemId citations"
fi

echo "=== mutation contract names all source-backed node fields ==="
if doc_patterns "$MUTATION" \
  'GSE score|gseScore|gse_score' \
  'CEFR band|cefrBand|cefr_band' \
  'definition' \
  'example' \
  'itemId|item ID' \
  '(?:itemId|item ID).{0,180}(?:citation|cite|source)|(?:citation|cite|source).{0,180}(?:itemId|item ID)' \
  'source[- ]backed|source stated|source value'; then
  pass "mutation contract names GSE score, CEFR band, definition, example, and itemId citation fields"
else
  fail "mutation contract omits one or more required source-backed node fields"
fi

echo "=== mutation contract defines a distinct core version and byte-level diff ==="
if doc_patterns "$MUTATION" \
  '(?:core graph|core) version' \
  'version bump|bump.{0,80}version|new core version' \
  '(?:distinct|separate|different).{0,180}(?:YLE|baseline|version)|(?:YLE|baseline).{0,180}(?:distinct|separate|different)' \
  'byte[- ](?:level )?diff|bytewise.{0,80}diff|byte[- ]identical.{0,180}diff' \
  'diff report'; then
  pass "mutation contract requires a version bump distinct from the frozen YLE baseline and a byte-level diff report"
else
  fail "mutation contract lacks version-bump or byte-diff mechanics"
fi

echo "=== mutation contract defines the YLE byte-identical reproducibility proof ==="
if doc_patterns "$MUTATION" \
  '(?:YLE|Cambridge YLE).{0,300}baseline' \
  'baseline.{0,260}(?:regenerat|reproduc|re-run)' \
  'byte[- ]identical|bytewise identical' \
  'proof|assert|compare|verification' \
  'RELEASE-YLE-2025|review/yle-2025|yle-2025' \
  'SHA-256|checksum|cmp|diff'; then
  pass "mutation contract specifies a byte-identical regeneration proof against the frozen YLE baseline"
else
  fail "mutation contract lacks the YLE freeze reproducibility proof"
fi

echo "=== mutation contract uses labelled integer fields for every byte-diff count ==="
report_shape_status=0
report_shape_error=""
if report_shape_error="$(python3 - "$MUTATION" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
if not path.is_file():
    raise SystemExit(f"missing document: {path}")
text = path.read_text(encoding="utf-8")
if re.search(r"byte[- ](?:level )?diff|bytewise.{0,80}diff", text, re.IGNORECASE) is None:
    raise SystemExit("byte-diff report is not named")
if re.search(r"label(?:l)?ed counts?", text, re.IGNORECASE) is None:
    raise SystemExit("labelled counts are not required")

labels = [
    r"nodes? mapped",
    r"levels? added",
    r"levels? corrected",
    r"conflicts?",
    r"unmapped GSE entries queued",
    r"GSE entries with no matching node",
]
for label in labels:
    match = re.search(label, text, re.IGNORECASE)
    if match is None:
        print(f"missing labelled count: {label}")
        raise SystemExit(1)
    window = text[match.start(): match.end() + 180]
    if re.search(r"[:|=]", window) is None:
        print(f"count field has no label separator: {label}")
        raise SystemExit(1)
    field = text[match.start(): match.end() + 120]
    if re.search(
        r"(?:[:|=][ \t]*)(?:non[- ]negative[ \t]+)?integer\b"
        r"|(?:[:|=][ \t]*)(?:count|number|N)\b"
        r"|(?:[:|=][ \t]*)<[^>]+>",
        field,
        re.IGNORECASE,
    ) is None:
        print(f"count field is not typed as an integer: {label}")
        raise SystemExit(1)
PY
)"; then
  report_shape_status=0
else
  report_shape_status=$?
fi
if [[ "$report_shape_status" -eq 0 ]]; then
  pass "byte-diff report shape carries labelled integer fields for mapped, added, corrected, conflict, and queued cases"
else
  printf '%s\n' "$report_shape_error"
  fail "byte-diff report shape is weak or uses unlabeled counts"
fi

echo "=== YLE release record proves the frozen baseline before GSE mutation ==="
if doc_patterns "$YLE_RELEASE" \
  'Status.{0,50}Frozen' \
  'Dual human.{0,80}go' \
  'phase6-approval\.md' \
  'SHA-256' \
  'prerequisite_for count:[ \t]*0'; then
  pass "frozen YLE release record and labelled zero prerequisite count are present"
else
  fail "frozen YLE release proof is missing or incomplete"
fi

echo "=== review contract requires at least 100 stratified mappings and a precision threshold ==="
review_status=0
review_error=""
if review_error="$(python3 - "$SAMPLES" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
if not path.is_file():
    raise SystemExit(f"missing document: {path}")
text = path.read_text(encoding="utf-8")

if re.search(r"stratif", text, re.IGNORECASE) is None:
    raise SystemExit("review sample is not stratified")
sample_ok = False
for match in re.finditer(
    r"(?:at least|>=|≥|minimum(?: of)?|size\s*[:=])\s*(\d+)\b",
    text,
    re.IGNORECASE,
):
    if int(match.group(1)) >= 100:
        window = text[max(0, match.start() - 120): match.end() + 160]
        if re.search(r"mapping|node[- ]to[- ]entry", window, re.IGNORECASE):
            sample_ok = True
            break
if not sample_ok:
    raise SystemExit("review sample does not define a labelled threshold of at least 100 mappings")

precision_windows = []
for match in re.finditer(r"precision", text, re.IGNORECASE):
    precision_windows.append(text[max(0, match.start() - 120): match.end() + 220])
if not any(re.search(r"threshold|minimum|target|>=|at least", window, re.IGNORECASE) for window in precision_windows):
    raise SystemExit("precision threshold is missing")

for label, patterns in {
    "POS": [r"\bPOS\b|part[s]?[- ]of[- ]speech"],
    "audience": [r"audience", r"GL", r"YL"],
    "multi-POS": [r"multi[- ]POS|multiple POS|multiple part[s]?[- ]of[- ]speech"],
    "conflict cases": [r"conflict"],
}.items():
    if not all(re.search(pattern, text, re.IGNORECASE) for pattern in patterns):
        print(f"review stratification axis is missing: {label}")
        raise SystemExit(1)
PY
)"; then
  review_status=0
else
  review_status=$?
fi
if [[ "$review_status" -eq 0 ]]; then
  pass "review contract sets a stratified sample threshold of at least 100 mappings and a precision threshold"
else
  printf '%s\n' "$review_error"
  fail "review sample threshold, precision threshold, or stratification axes are missing"
fi

echo "=== Phase 1 plan keeps canonical markers, evidence, and the human gate honest ==="
plan_status=0
plan_error=""
if plan_error="$(python3 - "$PLAN" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
if not path.is_file():
    raise SystemExit(f"missing plan: {path}")
text = path.read_text(encoding="utf-8")
phase_match = re.search(r"^## Phase 1:.*?(?=^## Phase 2:|\Z)", text, re.MULTILINE | re.DOTALL)
if phase_match is None:
    raise SystemExit("Phase 1 section is missing")
phase = phase_match.group(0)

if re.search(r"^\s*-\s+\[ \]", text, re.MULTILINE):
    raise SystemExit("deprecated [ ] marker remains in the plan")

gate = re.search(r"^- \[([~xb])\] Task: Complete Phase 1 review gate.*$", phase, re.MULTILINE)
if gate is None or gate.group(1) != "b" or "deferred:both-owners" not in gate.group(0):
    raise SystemExit("Phase 1 human gate is not [b] deferred:both-owners")

for task in (
    "Define the node-to-entry mapping contract",
    "Define the core mutation contract",
    "Define review samples and thresholds",
):
    pattern = rf"^- \[x\] Task: {re.escape(task)}.*commit:\s*[0-9a-f]{{7,40}}"
    if re.search(pattern, phase, re.MULTILINE | re.IGNORECASE) is None:
        raise SystemExit(f"completed task with commit evidence is missing: {task}")

print("Phase 1 plan has three completed contract tasks with commit evidence")
print("Phase 1 human gate remains [b] deferred:both-owners")
PY
)"; then
  plan_status=0
else
  plan_status=$?
fi
if [[ "$plan_status" -eq 0 ]]; then
  printf '%s\n' "$plan_error"
  pass "Phase 1 plan uses [x]/[~]/[b], has completed task SHA evidence, and keeps both-owner review blocked"
else
  printf '%s\n' "$plan_error"
  fail "Phase 1 plan markers, completed-task evidence, or human-gate state is invalid"
fi

echo "=== track registry does not claim GSE core release before dual owner gates ==="
registry_status=0
registry_error=""
if registry_error="$(python3 - "$REGISTRY" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
match = re.search(
    r"^- \[[^]]\] \*\*Track: GSE Vocabulary Core Enrichment\*\*.*?(?=^- \[[^]]\] \*\*Track:|\Z)",
    text,
    re.MULTILINE | re.DOTALL | re.IGNORECASE,
)
if match is None:
    raise SystemExit("GSE Vocabulary Core Enrichment registry entry is missing")
block = match.group(0)
if re.search(r"status:\s*(?:new|in progress)", block, re.IGNORECASE) is None:
    raise SystemExit("registry entry does not state new or in-progress status")
if re.search(r"complete|released", block, re.IGNORECASE):
    raise SystemExit("registry entry overstates completion or release")
PY
)"; then
  registry_status=0
else
  registry_status=$?
fi
if [[ "$registry_status" -eq 0 ]]; then
  pass "track registry remains new/in progress until the separate dual release gates"
else
  printf '%s\n' "$registry_error"
  fail "track registry claims completion or release too early"
fi

printf '%s\n' "${RESULTS[@]}"
echo "=== Total: $((PASS_COUNT + FAIL_COUNT)) checks (PASS=$PASS_COUNT, FAIL=$FAIL_COUNT) ==="
exit "$FAILED"
