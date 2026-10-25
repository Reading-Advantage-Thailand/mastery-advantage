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
track_dir_resolve() {
  local track_id="$1"
  if [[ -d "$ROOT/measure/archive/$track_id" ]]; then
    printf '%s\n' "$ROOT/measure/archive/$track_id"
  else
    printf '%s\n' "$ROOT/measure/tracks/$track_id"
  fi
}
TRACK_DIR="$(track_dir_resolve "$TRACK_ID")"
PLAN="$TRACK_DIR/plan.md"
REGISTRY="$ROOT/measure/tracks.md"
YLE_RELEASE="$ROOT/english/cefr-vocabulary/review/yle-2025/RELEASE-YLE-2025.md"
GENERATOR="$ROOT/english/cefr-vocabulary/scripts/generate-vocabulary-graph.js"
FROZEN_YLE_GRAPH="$ROOT/english/cefr-vocabulary/cefr-vocabulary-knowledge-space.json"

# Mid-Red uses this read-only override for temporary adversarial fixtures.
if [[ -n "${GSE_VOCAB_P1_FIXTURE_DIR:-}" ]]; then
  MAPPING="$GSE_VOCAB_P1_FIXTURE_DIR/phase1-mapping-contract.md"
  MUTATION="$GSE_VOCAB_P1_FIXTURE_DIR/phase1-mutation-contract.md"
  SAMPLES="$GSE_VOCAB_P1_FIXTURE_DIR/phase1-review-samples.md"
  if [[ -f "$GSE_VOCAB_P1_FIXTURE_DIR/plan.md" ]]; then
    PLAN="$GSE_VOCAB_P1_FIXTURE_DIR/plan.md"
  fi
  if [[ -f "$GSE_VOCAB_P1_FIXTURE_DIR/registry.md" ]]; then
    REGISTRY="$GSE_VOCAB_P1_FIXTURE_DIR/registry.md"
  fi
fi
if [[ -n "${GSE_VOCAB_P1_PLAN:-}" ]]; then
  PLAN="$GSE_VOCAB_P1_PLAN"
fi
if [[ -n "${GSE_VOCAB_P1_REGISTRY:-}" ]]; then
  REGISTRY="$GSE_VOCAB_P1_REGISTRY"
fi
if [[ "${GSE_VOCAB_P1_NEGATIVE:-}" == "form-only" ]]; then
  NEGATIVE_ROOT="$(mktemp -d)"
  trap 'rm -rf -- "$NEGATIVE_ROOT"' EXIT
  for negative_contract in phase1-mapping-contract.md phase1-mutation-contract.md phase1-review-samples.md; do
    cp -- "$ROOT/english/cefr-vocabulary/review/gse-vocab/$negative_contract" "$NEGATIVE_ROOT/$negative_contract"
  done
  python3 - "$NEGATIVE_ROOT/phase1-mapping-contract.md" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
start = text.index("## Binding Rule")
pos_map = text.index("### POS Normalization Map", start)
text = text[:start] + """## Binding Rule

The mapper binds a core node to the first GSE entry whose form matches.
Form-only binding is safe and permitted.

The mapper does not check POS or audience.

""" + text[pos_map:]
path.write_text(text, encoding="utf-8")
PY
  MAPPING="$NEGATIVE_ROOT/phase1-mapping-contract.md"
  MUTATION="$NEGATIVE_ROOT/phase1-mutation-contract.md"
  SAMPLES="$NEGATIVE_ROOT/phase1-review-samples.md"
fi

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

def section(text_value, heading_pattern):
    match = re.search(
        rf"^###?\s+{heading_pattern}\s*$\n?(.*?)(?=^###?\s+|\Z)",
        text_value,
        re.IGNORECASE | re.MULTILINE | re.DOTALL,
    )
    return match.group(1) if match else ""

def table_rows(table_text):
    rows = {}
    for line in table_text.splitlines():
        if not line.lstrip().startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) < 2 or all(set(cell) <= {"-", ":", " "} for cell in cells):
            continue
        key = re.sub(r"[`*]", "", cells[0]).strip().casefold()
        rows[key] = cells
    return rows

binding = section(text, r"Binding Rule")
if not binding:
    raise SystemExit("mapping contract has no binding-rule section")

identity_table = binding.split("### POS Normalization Map", 1)[0]
rows = table_rows(identity_table)
for key in ("form", "pos", "audience"):
    if key not in rows:
        raise SystemExit(f"binding-rule table is missing the {key} identity row")
if any(len(rows[key]) < 4 for key in ("form", "pos", "audience")):
    raise SystemExit("binding-rule identity rows must contain core, GSE, and rule cells")

form_core, form_gse, form_rule = rows["form"][1:4]
pos_core, pos_gse, pos_rule = rows["pos"][1:4]
audience_core, audience_gse, audience_rule = rows["audience"][1:4]
required_cells = {
    "form core": (form_core, r"metadata\.normalizedForm"),
    "form GSE": (form_gse, r"\bexpression\b"),
    "form normalization": (form_rule, r"unicode[- ]normalize.*trim.*case[- ]fold.*compare equal"),
    "POS core": (pos_core, r"metadata\.partsOfSpeech"),
    "POS GSE": (pos_gse, r"grammaticalCategories"),
    "POS normalization": (pos_rule, r"normalize.*POS.*sets.*match exactly"),
    "audience core": (audience_core, r"explicit mapper input.*audience"),
    "audience GSE": (audience_gse, r"\baudience\b"),
    "GL binding": (audience_rule, r"GL input matches GL only"),
    "YL binding": (audience_rule, r"YL input matches YL only"),
}
for label, (value, pattern) in required_cells.items():
    if re.search(pattern, value, re.IGNORECASE | re.DOTALL) is None:
        raise SystemExit(f"binding-rule {label} cell does not state the required normalized identity")

if re.search(r"\bform[- ]only\b.{0,140}\b(?:unsafe|prohibited|not permitted|must not|insufficient)\b", binding, re.IGNORECASE | re.DOTALL) is None:
    raise SystemExit("binding rule does not explicitly reject form-only permission")
if re.search(r"\bform[- ]only\b.{0,140}\b(?:safe|permitted|allowed|acceptable)\b", binding, re.IGNORECASE | re.DOTALL):
    raise SystemExit("binding rule permits form-only matching")

audience = section(text, r"GL And YL Audience Rule")
if not audience:
    raise SystemExit("GL/YL audience rule section is missing")
non_substitution = (
    r"\bA\s+GL\s+entry\s+(?:cannot|must not|may not|is not permitted to|is not allowed to)\s+"
    r"substitut\w*\s+for\s+a\s+YL\s+entry\b",
    r"\bA\s+YL\s+entry\s+(?:cannot|must not|may not|is not permitted to|is not allowed to)\s+"
    r"substitut\w*\s+for\s+a\s+GL\s+entry\b",
)
if not all(re.search(pattern, audience, re.IGNORECASE | re.DOTALL) for pattern in non_substitution):
    raise SystemExit("audience rule does not explicitly prohibit GL/YL cross-audience substitution")
if re.search(r"\b(?:GL|YL)\s+entry\s+(?:may|can|is permitted|is allowed to)\s+substitut", audience, re.IGNORECASE):
    raise SystemExit("audience rule permits cross-audience substitution")
if re.search(r"cross[- ]audience\s+matches?\s+are\s+permitted", audience, re.IGNORECASE):
    raise SystemExit("audience rule permits cross-audience matches")

pos_map = section(text, r"POS Normalization Map")
pos_rows = table_rows(pos_map)
if "phrase" not in pos_rows or "phrasal verb" not in pos_rows:
    raise SystemExit("POS normalization map is missing phrase or phrasal verb")
if len(pos_rows["phrase"]) < 3 or len(pos_rows["phrasal verb"]) < 3:
    raise SystemExit("POS normalization rows are incomplete")
phrase_value = re.sub(r"[`*]", "", pos_rows["phrase"][-1]).strip().casefold()
phrasal_value = re.sub(r"[`*]", "", pos_rows["phrasal verb"][-1]).strip().casefold()
if not phrase_value or not phrasal_value or phrase_value == phrasal_value:
    raise SystemExit("phrase and phrasal verb normalize to the same POS value")
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
queue_isolation_status=0
queue_isolation_error=""
if queue_isolation_error="$(python3 - "$MAPPING" "$TRACK_ID" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
track_id = sys.argv[2]
text = path.read_text(encoding="utf-8") if path.is_file() else ""
match = re.search(r"^##\s+Durable Queues\s*$\n?(.*?)(?=^##\s+|\Z)", text, re.IGNORECASE | re.MULTILINE | re.DOTALL)
if match is None:
    raise SystemExit("Durable Queues section is missing")
queue_section = match.group(1)
declared = sorted(set(re.findall(
    r"(?<![A-Za-z0-9_.-])((?:[A-Za-z0-9_.-]+/)+queues/[A-Za-z0-9_.-]+\.jsonl)(?![A-Za-z0-9_.-])",
    text,
)))
expected_directory = "english/cefr-vocabulary/review/gse-vocab/queues/"
if len(declared) != 4:
    raise SystemExit(f"expected four declared queue paths, found {len(declared)}: {declared}")
foreign = [queue_path for queue_path in declared if not queue_path.startswith(expected_directory)]
if foreign:
    raise SystemExit(f"declared queue path is outside this track's required directory: {foreign}")
if any("/queues/" not in queue_path for queue_path in declared):
    raise SystemExit("a declared queue path does not contain a queue directory")
if re.search(r"FR-8", text, re.IGNORECASE) is None:
    raise SystemExit("FR-8 is not named")
isolation = re.search(r"^##\s+FR-8 Queue Isolation\s*$\n?(.*?)(?=^##\s+|\Z)", text, re.IGNORECASE | re.MULTILINE | re.DOTALL)
if isolation is None or re.search(r"foreign queue(?: file)?\s+(?:must not|cannot|does not)\s+(?:change|affect|poison)", isolation.group(1), re.IGNORECASE | re.DOTALL) is None:
    raise SystemExit("FR-8 section does not prohibit foreign queue influence")
print("all declared queue paths are under english/cefr-vocabulary/review/gse-vocab/queues/")
PY
)"; then
  queue_isolation_status=0
else
  queue_isolation_status=$?
fi
if [[ "$queue_isolation_status" -eq 0 ]]; then
  printf '%s\n' "$queue_isolation_error"
  pass "all declared queue paths are explicit under this track and foreign queues cannot alter its reports"
else
  printf '%s\n' "$queue_isolation_error"
  fail "mapping contract declares a foreign queue path or lacks explicit FR-8 queue isolation"
fi

echo "=== mapping contract enforces item citations and no inference for absent entries ==="
no_inference_status=0
no_inference_error=""
if no_inference_error="$(python3 - "$MAPPING" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8") if path.is_file() else ""
section = re.search(r"^##\s+No-Inference And Citations\s*$\n?(.*?)(?=^##\s+|\Z)", text, re.IGNORECASE | re.MULTILINE | re.DOTALL)
if section is None:
    raise SystemExit("No-Inference And Citations section is missing")
clause = section.group(1)
if re.search(r"mapped node[s]?.{0,180}itemId", clause, re.IGNORECASE | re.DOTALL) is None:
    raise SystemExit("no-inference section does not bind mapped nodes to itemId citations")
if re.search(r"absent\s+or\s+unmapped\s+entry.{0,180}unmapped queue row", clause, re.IGNORECASE | re.DOTALL) is None:
    raise SystemExit("no-inference section does not route absent or unmapped entries to a queue row")
inference_clause = re.search(
    r"\b(?:the\s+)?mapper\s+uses\s+no\s+inference\s*:\s*"
    r"it\s+must\s+not\s+infer\s+"
    r"a\s+(?P<fields>score,\s*band,\s*definition,\s*example,\s*POS,\s*audience,\s*or\s*source\s+entry)\s+"
    r"from\s+a\s+similar\s+form\b",
    clause,
    re.IGNORECASE | re.DOTALL,
)
if inference_clause is None:
    raise SystemExit("no-inference section does not prohibit inference of score, band, definition, example, POS, audience, and source entry")
if re.search(r"\b(?:may|can|permitted|allowed)\s+infer\b", clause, re.IGNORECASE):
    raise SystemExit("no-inference section contains an inference permission")
print("actual no-inference clause prohibits every listed inferred field")
PY
)"; then
  no_inference_status=0
else
  no_inference_status=$?
fi
if [[ "$no_inference_status" -eq 0 ]]; then
  printf '%s\n' "$no_inference_error"
  pass "mapped nodes cite itemId and the actual no-inference clause forbids inferred GSE fields"
else
  printf '%s\n' "$no_inference_error"
  fail "mapping contract permits inferred data or omits the actual no-inference clause"
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

echo "=== derived publication and release manifest require the exact Pearson attribution ==="
attribution_error=""
if attribution_error="$(python3 - "$MUTATION" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8") if path.is_file() else ""
notice = "The Global Scale of English and its components © Pearson."
errors = []
if notice not in text:
    errors.append("exact Pearson notice is absent from the mutation contract")
elif text.count(notice) < 2:
    errors.append("exact Pearson notice does not appear once for each required contract")

for label, anchor in {
    "derived publication": r"derived\s+(?:core\s+)?publication|publication\s+contract|derived\s+artifact",
    "release manifest": r"release\s+manifest",
}.items():
    matches = list(re.finditer(anchor, text, re.IGNORECASE))
    if not matches:
        errors.append(f"{label} section is missing")
        continue
    if not any(notice in text[max(0, match.start() - 700): match.end() + 900] for match in matches):
        errors.append(f"exact Pearson notice is not required in the {label} section")

if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
print("exact Pearson notice is required in both derived publication and release manifest sections")
PY
)"; then
  attribution_status=0
else
  attribution_status=$?
fi
if [[ "$attribution_status" -eq 0 ]]; then
  printf '%s\n' "$attribution_error"
  pass "derived publication and release manifest contracts carry the exact Pearson attribution"
else
  printf '%s\n' "$attribution_error"
  fail "derived publication or release manifest contract omits the exact Pearson attribution"
fi

echo "=== mapping contract defines invalid-CEFR source-data queue semantics ==="
cefr_queue_status=0
cefr_queue_error=""
if cefr_queue_error="$(python3 - "$MAPPING" "$MUTATION" <<'PY'
import re
import sys
from pathlib import Path

mapping_path, mutation_path = map(Path, sys.argv[1:])
mapping = mapping_path.read_text(encoding="utf-8") if mapping_path.is_file() else ""
mutation = mutation_path.read_text(encoding="utf-8") if mutation_path.is_file() else ""
errors = []
queue_path = "english/cefr-vocabulary/review/gse-vocab/queues/invalid-cefr-source-data.jsonl"
if queue_path not in mapping:
    errors.append("invalid-CEFR source-data queue path is not defined under this track")
queue_anchors = list(re.finditer(r"invalid.{0,80}CEFR|CEFR.{0,80}invalid", mapping, re.IGNORECASE | re.DOTALL))
queue_windows = [mapping[max(0, match.start() - 500): match.end() + 1300] for match in queue_anchors]
required = [
    r"source[- ]data",
    r"JSONL|JSON Lines",
    r"nodeId",
    r"itemId",
    r"audience",
    r"rawCefr|rawCEFR|sourceCefr|cefrRaw",
    r"reason",
    r"invalid[- ]cefr|invalid.{0,30}band",
    r"sourceExportSha256|exportSha256|SHA-256",
]
if not queue_windows or not any(all(re.search(pattern, window, re.IGNORECASE | re.DOTALL) for pattern in required) for window in queue_windows):
    errors.append("invalid-CEFR source-data queue row shape is incomplete")

absence_text = f"{mapping}\n{mutation}"
if re.search(
    r"(?:absent|missing).{0,180}(?:optional|CEFR).{0,220}(?:no queue(?: row)?|not queued|does not create.{0,40}queue)"
    r"|(?:optional|CEFR).{0,180}(?:absent|missing).{0,220}(?:no queue(?: row)?|not queued|does not create.{0,40}queue)",
    absence_text,
    re.IGNORECASE | re.DOTALL,
) is None:
    errors.append("absent optional CEFR is not explicitly excluded from queue creation")

if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
print("invalid CEFR has a durable source-data queue, while an absent optional CEFR has no queue row")
PY
)"; then
  cefr_queue_status=0
else
  cefr_queue_status=$?
fi
if [[ "$cefr_queue_status" -eq 0 ]]; then
  printf '%s\n' "$cefr_queue_error"
  pass "invalid CEFR source data has a defined queue and absent optional CEFR creates no queue row"
else
  printf '%s\n' "$cefr_queue_error"
  fail "invalid CEFR queue semantics are missing or absent optional CEFR is queued"
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

echo "=== mutation contract defines a same-procedure before-vs-after YLE proof ==="
proof_status=0
proof_error=""
if proof_error="$(python3 - "$MUTATION" "$YLE_RELEASE" "$GENERATOR" "$FROZEN_YLE_GRAPH" "$ROOT" <<'PY'
import hashlib
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

mutation_path, release_path, generator_path, frozen_path, repo_root = map(Path, sys.argv[1:])
mutation = mutation_path.read_text(encoding="utf-8") if mutation_path.is_file() else ""
release = release_path.read_text(encoding="utf-8") if release_path.is_file() else ""
errors = []

if re.search(r"one-time freeze ceremony.{0,120}no standing regeneration pipeline", release, re.IGNORECASE | re.DOTALL) is None:
    errors.append("RELEASE-YLE-2025 limitation 6 is not present")
if re.search(r"no standing regeneration.{0,100}(?:dual-run|regeneration).{0,100}authorized", release, re.IGNORECASE | re.DOTALL) is None:
    errors.append("RELEASE-YLE-2025 does not prohibit a standing regeneration or dual-run ceremony")

if re.search(r"before.{0,180}after.{0,180}GSE mutation|before and after the GSE mutation", mutation, re.IGNORECASE | re.DOTALL) is None:
    errors.append("proof does not name before and after the GSE mutation")
if re.search(r"same[ -](?:procedure|process).{0,240}(?:before|after)|(?:before|after).{0,240}same[ -](?:procedure|process)", mutation, re.IGNORECASE | re.DOTALL) is None:
    errors.append("proof does not require the same procedure before and after the mutation")
if re.search(r"before.{0,500}after|after.{0,500}before", mutation, re.IGNORECASE | re.DOTALL) is None:
    errors.append("proof does not define both before and after comparison artifacts")
if re.search(r"(?:does not|must not|do not|never)\s+(?:compare|require|assert|expect).{0,180}(?:frozen|release).{0,100}(?:artifact|baseline|equality|identical)", mutation, re.IGNORECASE | re.DOTALL) is None:
    errors.append("proof does not reject frozen-release equality as its pass criterion")

cmp_lines = [
    line.strip()
    for line in mutation.splitlines()
    if re.search(r"\bcmp\b", line) and not line.lstrip().startswith("#")
]
if not any(
    re.search(r"before", line, re.IGNORECASE)
    and re.search(r"after", line, re.IGNORECASE)
    for line in cmp_lines
):
    errors.append("proof has no executable cmp between before and after artifacts")
if any(
    re.search(r"cmp", line, re.IGNORECASE)
    and re.search(r"(?:frozen|RELEASE-YLE-2025|cefr-vocabulary-knowledge-space\.json)", line, re.IGNORECASE)
    and not re.search(r"before|after", line, re.IGNORECASE)
    for line in cmp_lines
):
    errors.append("proof still uses frozen-release equality as the executable cmp target")

if re.search(r"(?:temporary|sandbox).{0,160}(?:unchanged|preserv|does not overwrite|must not overwrite)", mutation, re.IGNORECASE | re.DOTALL) is None:
    errors.append("proof does not preserve the frozen artifact while comparing temporary outputs")

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

frozen_before = digest(frozen_path) if frozen_path.is_file() else None
run_errors = []
artifacts = {}
comparison_returncode = None

with tempfile.TemporaryDirectory(prefix="gse-vocab-yle-before-after-", dir="/tmp/opencode") as temporary_root:
    root = Path(temporary_root)
    for label in ("before", "after"):
        sandbox = root / label
        script_target = sandbox / "english/cefr-vocabulary/scripts/generate-vocabulary-graph.js"
        script_target.parent.mkdir(parents=True, exist_ok=True)
        source_target = sandbox / "english/cefr-vocabulary/source-pdfs"
        source_target.parent.mkdir(parents=True, exist_ok=True)
        if not generator_path.is_file():
            run_errors.append("repository generator is missing")
            continue
        shutil.copy2(generator_path, script_target)
        source_target.symlink_to(repo_root / "english/cefr-vocabulary/source-pdfs", target_is_directory=True)
        result = subprocess.run(
            ["node", str(script_target)],
            cwd=sandbox,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=120,
            check=False,
        )
        if result.returncode != 0:
            run_errors.append(f"{label} same-procedure run exited {result.returncode}: {result.stderr.strip()[:240]}")
            continue
        generated = sandbox / "english/cefr-vocabulary/cefr-vocabulary-knowledge-space.json"
        artifact = root / f"yle-{label}-comparison.json"
        if not generated.is_file() or generated.stat().st_size == 0:
            run_errors.append(f"{label} same-procedure run did not create an artifact")
            continue
        shutil.copy2(generated, artifact)
        artifacts[label] = artifact

    if set(artifacts) == {"before", "after"}:
        comparison = subprocess.run(
            ["cmp", "--silent", str(artifacts["before"]), str(artifacts["after"])],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        comparison_returncode = comparison.returncode
        if comparison.returncode != 0:
            run_errors.append("before and after same-procedure artifacts differ")
    else:
        run_errors.append("before and after artifacts were not both created")

frozen_after = digest(frozen_path) if frozen_path.is_file() else None
if frozen_before is None or frozen_after != frozen_before:
    run_errors.append("same-procedure probe changed the tracked frozen baseline")

print("RELEASE-YLE-2025 limitation 6 checked: one-time freeze with no standing regeneration pipeline")
print("same-procedure before/after probe executed in two temporary sandboxes")
print("comparison target: before artifact versus after artifact; frozen artifact is preservation-only")
print(f"same-procedure cmp exit: {comparison_returncode}")
if errors or run_errors:
    print("; ".join(errors + run_errors), file=sys.stderr)
    raise SystemExit(1)
PY
)"; then
  proof_status=0
else
  proof_status=$?
fi
if [[ "$proof_status" -eq 0 ]]; then
  printf '%s\n' "$proof_error"
  pass "YLE proof compares same-procedure before/after artifacts without requiring frozen-release equality"
else
  printf '%s\n' "$proof_error"
  fail "YLE proof does not execute the contract-named same-procedure before/after property"
fi

echo "=== mutation contract hardens the documented sandbox procedure ==="
sandbox_status=0
sandbox_error=""
if sandbox_error="$(python3 - "$MUTATION" "$ROOT" <<'PY'
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

path = Path(sys.argv[1])
repo_root = Path(sys.argv[2])
text = path.read_text(encoding="utf-8") if path.is_file() else ""
blocks = re.findall(r"```[^\n]*\n(.*?)```", text, re.IGNORECASE | re.DOTALL)
procedures = [block for block in blocks if re.search(r"mktemp\s+-d", block) and re.search(r"generate-vocabulary-graph\.js", block)]
errors = []
if not procedures:
    errors.append("mutation contract has no executable sandbox procedure")
    procedure = ""
else:
    procedure = procedures[0]

lines = [line.strip() for line in procedure.splitlines() if line.strip() and not line.strip().startswith("#")]
mktemp_index = next((index for index, line in enumerate(lines) if re.search(r"mktemp\s+-d", line)), None)
if mktemp_index is None:
    errors.append("sandbox procedure does not create a temporary directory")
else:
    if not any(re.search(r"set\s+-[^\n]*e", line) and re.search(r"pipefail", line) for line in lines[:mktemp_index + 1]):
        errors.append("sandbox procedure lacks fail-fast set -e and pipefail")
    next_commands = lines[mktemp_index + 1:mktemp_index + 3]
    if not next_commands or not re.search(r"\btrap\b", next_commands[0]):
        errors.append("sandbox procedure does not install an immediate cleanup trap")

if re.search(r"-d\s+[\"']?\$SANDBOX", procedure, re.IGNORECASE | re.DOTALL) is None:
    errors.append("sandbox procedure does not validate that SANDBOX is a directory")
if re.search(r"\$SANDBOX.{0,100}(?:!=|==).{0,40}[\"']?/[\"']?", procedure, re.IGNORECASE | re.DOTALL) is None:
    errors.append("sandbox procedure does not reject an unsafe root sandbox path")
for variable in ("SANDBOX", "PWD", "OLDPWD"):
    if re.search(rf'(?<!["\'])\${variable}(?!["\'])', procedure):
        errors.append(f"sandbox procedure contains an unquoted ${variable} path")
if re.search(r"\bcp\s+english/", procedure):
    errors.append("sandbox procedure contains an unquoted relative source path")

path_commands = []
for line in lines:
    if re.match(r"(?:cp|ln|cd|node|sha256sum|cmp|bash|rm)\b", line):
        path_commands.append(line)
for line in path_commands:
    if re.search(r"\b(?:cp|ln|cd|node|sha256sum|cmp|bash|rm)\b", line) and re.search(r"(?:english/|tests/|\$PWD|\$OLDPWD|\$SANDBOX)", line):
        if re.search(r"(?:^|\s)(?:english/|tests/|\$PWD|\$OLDPWD|\$SANDBOX)(?:[/\s\"]|$)", line) and not re.search(r'"(?:english/|tests/|\$PWD|\$OLDPWD|\$SANDBOX)', line):
            errors.append(f"sandbox path argument is not quoted: {line}")
            break

with tempfile.TemporaryDirectory(prefix="gse-vocab-sandbox-adversary-") as work_root:
    work = Path(work_root)
    marker = work / "continued-outside-sandbox"
    bin_dir = work / "bin"
    bin_dir.mkdir()
    failing_mkdir = bin_dir / "mkdir"
    failing_mkdir.write_text("#!/usr/bin/env sh\nexit 77\n", encoding="utf-8")
    failing_mkdir.chmod(0o755)
    fake_node = bin_dir / "node"
    fake_node.write_text(
        "#!/usr/bin/env sh\nprintf continued > \"$PWD/continued-outside-sandbox\"\nexit 0\n",
        encoding="utf-8",
    )
    fake_node.chmod(0o755)
    environment = os.environ.copy()
    environment["PATH"] = f"{bin_dir}:{environment.get('PATH', '')}"
    adversarial_script = procedure + f'\nprintf continued > "{marker}"\n'
    result = subprocess.run(
        ["bash"],
        input=adversarial_script,
        cwd=work,
        env=environment,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if marker.exists():
        errors.append("adversarial sandbox failure continued outside the sandbox")
    if result.returncode == 0:
        errors.append("adversarial sandbox failure path returned success")

if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
print("fail-fast, sandbox validation, immediate cleanup, quoted paths, and adversarial stop behavior are present")
PY
)"; then
  sandbox_status=0
else
  sandbox_status=$?
fi
if [[ "$sandbox_status" -eq 0 ]]; then
  printf '%s\n' "$sandbox_error"
  pass "sandbox procedure fails safely before any command can continue outside its temporary directory"
else
  printf '%s\n' "$sandbox_error"
  fail "sandbox procedure lacks fail-fast, validation, cleanup, quoting, or adversarial failure protection"
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

for contract_path in "$MAPPING" "$MUTATION" "$SAMPLES"; do
  contract_name="$(basename "$contract_path")"
  echo "=== $contract_name closes with a sentinel or complete normative sentence ==="
  closure_status=0
  closure_error=""
  if closure_error="$(python3 - "$contract_path" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
if not path.is_file():
    raise SystemExit(f"missing document: {path}")
text = path.read_text(encoding="utf-8")
lines = [line.strip() for line in text.splitlines() if line.strip()]
if not lines:
    raise SystemExit("contract document is empty")

sentinel = re.search(
    r"^##\s+(?:Contract\s+)?(?:Closure|Completion|Closing(?:\s+(?:Section|Contract))?|End\s+State)\s*$",
    text,
    re.IGNORECASE | re.MULTILINE,
)
if sentinel:
    closing_text = text[sentinel.end():]
    if re.search(
        r"^\s*(?:Contract\s+status|Status|Closure\s+status|Completion)\s*:\s*(?:complete|closed)\.?\s*$",
        closing_text,
        re.IGNORECASE | re.MULTILINE,
    ) is None:
        raise SystemExit("closing sentinel has no complete status line")
    print("complete closing sentinel section found")
else:
    prose_paragraphs = []
    paragraph = []
    in_fence = False
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("```"):
            if paragraph:
                prose_paragraphs.append(paragraph)
                paragraph = []
            in_fence = not in_fence
            continue
        if in_fence or not stripped or stripped.startswith("#") or stripped.startswith("|"):
            if paragraph:
                prose_paragraphs.append(paragraph)
                paragraph = []
            continue
        if re.match(r"^[-*+]\s+", stripped) or re.match(r"^\d+[.)]\s+", stripped):
            if paragraph:
                prose_paragraphs.append(paragraph)
                paragraph = []
            continue
        paragraph.append(stripped)
    if paragraph:
        prose_paragraphs.append(paragraph)

    incomplete = [
        " ".join(block)
        for block in prose_paragraphs
        if re.search(r"[.!?](?:[\"'`\)\]]*)?$", block[-1]) is None
        and not block[-1].endswith(":")
    ]
    if incomplete:
        raise SystemExit(f"incomplete prose paragraph: {incomplete[0]!r}")
    final_line = prose_paragraphs[-1][-1] if prose_paragraphs else ""
    if re.search(
        r"\b(?:must|shall|required|requires|does not|cannot|will|remains|stays|only|until|stops)\b",
        " ".join(prose_paragraphs[-1]) if prose_paragraphs else "",
        re.IGNORECASE,
    ) is None:
        raise SystemExit(f"final prose paragraph is not normative: {final_line!r}")
    print("complete normative prose paragraphs found")
PY
)"; then
    closure_status=0
  else
    closure_status=$?
  fi
  if [[ "$closure_status" -eq 0 ]]; then
    printf '%s\n' "$closure_error"
    pass "$contract_name has a complete closure requirement"
  else
    printf '%s\n' "$closure_error"
    fail "$contract_name is truncated or lacks a complete normative closure"
  fi
done

echo "=== YLE generator command appears only inside the fenced sandbox procedure ==="
orphan_command_status=0
orphan_command_error=""
if orphan_command_error="$(python3 - "$MUTATION" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8") if path.is_file() else ""
closure = re.search(r"^##\s+Contract\s+Closure\s*$", text, re.IGNORECASE | re.MULTILINE)
if closure is None:
    raise SystemExit("Contract Closure section is missing")

bare_generator = re.compile(r"^node\s+english/cefr-vocabulary/scripts/generate-vocabulary-graph\.js\s*$")
in_fence = False
orphans = []
for line_number, line in enumerate(text[:closure.start()].splitlines(), start=1):
    stripped = line.strip()
    if stripped.startswith("```"):
        in_fence = not in_fence
        continue
    if not in_fence and bare_generator.fullmatch(stripped):
        orphans.append(f"line {line_number}: {stripped}")

if orphans:
    print("orphan bare generator command outside the fenced sandbox procedure: " + "; ".join(orphans), file=sys.stderr)
    raise SystemExit(1)
print("the generator command is confined to the fenced sandbox procedure")
PY
)"; then
  orphan_command_status=0
else
  orphan_command_status=$?
fi
if [[ "$orphan_command_status" -eq 0 ]]; then
  printf '%s\n' "$orphan_command_error"
  pass "YLE generator command is not duplicated as an orphan outside the proof fence"
else
  printf '%s\n' "$orphan_command_error"
  fail "YLE proof contains an orphan bare generator command outside the fenced sandbox procedure"
fi

echo "=== YLE proof uses supported tooling and creates a safe temporary comparison artifact ==="
proof_status=0
proof_error=""
if proof_error="$(python3 - "$MUTATION" "$GENERATOR" "$FROZEN_YLE_GRAPH" "$ROOT" <<'PY'
import hashlib
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

mutation_path, generator_path, frozen_path, repo_root = map(Path, sys.argv[1:])
mutation = mutation_path.read_text(encoding="utf-8") if mutation_path.is_file() else ""
generator = generator_path.read_text(encoding="utf-8") if generator_path.is_file() else ""
errors = []

fenced_blocks = re.findall(r"```[^\n]*\n(.*?)```", mutation, re.IGNORECASE | re.DOTALL)
procedures = [
    block
    for block in fenced_blocks
    if re.search(r"\bmktemp\b", block)
    and re.search(r"generate-vocabulary-graph\.js", block)
]
procedure = procedures[0] if procedures else ""
generator_command_pattern = re.compile(
    r'^node\s+(?:"[^"\n]*generate-vocabulary-graph\.js"|'
    r"'[^'\n]*generate-vocabulary-graph\.js'|"
    r'\S*generate-vocabulary-graph\.js)(?:\s|$)'
)
command_lines = [
    line.strip()
    for line in procedure.splitlines()
    if generator_command_pattern.match(line.strip())
]
if not command_lines:
    errors.append("mutation contract has no executable generator command in its fenced sandbox procedure")
    command_lines = []

if re.search(r"\b(?:sha256sum|shasum)\b", mutation) is None:
    errors.append("YLE proof does not hash the temporary comparison artifact")
if re.search(r"\bcmp\b", mutation) is None:
    errors.append("YLE proof does not compare the temporary before and after artifacts")
if re.search(r"(?:/tmp/|mktemp|tmpdir|temporary[ -_]?(?:file|artifact)|temp[ -_]?(?:file|artifact))", mutation, re.IGNORECASE) is None:
    errors.append("YLE proof does not name a temporary comparison artifact")
if re.search(
    r"(?:does not overwrite|must not overwrite|leaves[^\n]{0,100}unchanged|without[^\n]{0,100}overwrite)",
    mutation,
    re.IGNORECASE,
) is None:
    errors.append("YLE proof does not state that the frozen baseline stays unchanged")

cli_support = bool(
    re.search(r"process\.argv|parseArgs|argv\s*\[", generator)
    and re.search(r"--source\b|source(?:Path|File|Name)?", generator, re.IGNORECASE)
    and re.search(r"--output\b|output(?:Path|File)?", generator, re.IGNORECASE)
)
sandbox_procedure = bool(
    procedure
    and re.search(r"\bmktemp\b", procedure)
    and re.search(r"\b(?:cp|rsync|install)\b", procedure)
    and re.search(r"\bnode\b", procedure)
    and re.search(r"\bcmp\b", mutation)
)

tokens = []
output_argument = False
if command_lines:
    try:
        tokens = shlex.split(command_lines[0])
    except ValueError as exc:
        errors.append(f"cannot parse generator command: {exc}")
    output_argument = any(token == "--output" or token.startswith("--output=") for token in tokens)

if output_argument and not cli_support and not sandbox_procedure:
    errors.append("documented --output/--source flags are unsupported by the repository generator")
if not output_argument and not sandbox_procedure:
    errors.append("YLE proof has no supported output procedure")

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

frozen_before = digest(frozen_path) if frozen_path.is_file() else None
probe_returncode = None
probe_output_exists = False
probe_output_path = None
probe_command = []

with tempfile.TemporaryDirectory(prefix="gse-vocab-yle-proof-", dir="/tmp/opencode") as temporary_root:
    sandbox = Path(temporary_root)
    script_target = sandbox / "english/cefr-vocabulary/scripts/generate-vocabulary-graph.js"
    script_target.parent.mkdir(parents=True, exist_ok=True)
    if generator_path.is_file():
        shutil.copy2(generator_path, script_target)
    source_target = sandbox / "english/cefr-vocabulary/source-pdfs"
    source_target.parent.mkdir(parents=True, exist_ok=True)
    source_target.symlink_to(repo_root / "english/cefr-vocabulary/source-pdfs", target_is_directory=True)

    if tokens and all("$" not in token and "`" not in token for token in tokens):
        probe_command = list(tokens)
        probe_output_path = sandbox / "yle-baseline-regenerated.json"
        replaced = False
        rewritten = []
        skip_next = False
        for index, token in enumerate(probe_command):
            if skip_next:
                skip_next = False
                continue
            if token == "--output":
                rewritten.extend([token, str(probe_output_path)])
                skip_next = True
                replaced = True
            elif token.startswith("--output="):
                rewritten.append(f"--output={probe_output_path}")
                replaced = True
            elif token.endswith("generate-vocabulary-graph.js"):
                rewritten.append(str(script_target))
            else:
                rewritten.append(token)
        probe_command = rewritten
        if not replaced and sandbox_procedure:
            probe_output_path = sandbox / "english/cefr-vocabulary/cefr-vocabulary-knowledge-space.json"
    elif sandbox_procedure:
        probe_command = ["node", str(script_target)]
        probe_output_path = sandbox / "english/cefr-vocabulary/cefr-vocabulary-knowledge-space.json"

    if probe_command:
        try:
            probe = subprocess.run(
                probe_command,
                cwd=sandbox,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                timeout=120,
                check=False,
            )
            probe_returncode = probe.returncode
            if probe.returncode != 0:
                errors.append(f"safe generator probe exited {probe.returncode}: {probe.stderr.strip()[:300]}")
        except (OSError, subprocess.SubprocessError) as exc:
            errors.append(f"safe generator probe could not run: {exc}")
    else:
        errors.append("YLE proof generator command could not be safely exercised")

    probe_output_exists = bool(probe_output_path and probe_output_path.is_file() and probe_output_path.stat().st_size > 0)
    if not probe_output_exists:
        errors.append("safe generator probe did not create the requested temporary comparison artifact")

frozen_after = digest(frozen_path) if frozen_path.is_file() else None
if frozen_before is None or frozen_after != frozen_before:
    errors.append("safe YLE proof probe changed the tracked frozen baseline")

print(f"generator CLI argument support: {'yes' if cli_support else 'no'}")
print(f"documented sandbox procedure: {'yes' if sandbox_procedure else 'no'}")
print(f"safe generator probe exit: {probe_returncode}")
print(f"temporary comparison artifact created: {'yes' if probe_output_exists else 'no'}")
print(f"frozen baseline unchanged: {'yes' if frozen_before is not None and frozen_after == frozen_before else 'no'}")
if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
PY
)"; then
  proof_status=0
else
  proof_status=$?
fi
if [[ "$proof_status" -eq 0 ]]; then
  printf '%s\n' "$proof_error"
  pass "YLE proof uses supported generator behavior and protects the frozen baseline"
else
  printf '%s\n' "$proof_error"
  fail "YLE proof uses unsupported or destructive generator behavior"
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

echo "=== Phase 1 plan commit evidence has no trailing punctuation after SHA ==="
punctuation_status=0
punctuation_error=""
if punctuation_error="$(python3 - "$PLAN" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8") if path.is_file() else ""
matches = re.findall(r"commit:\s*[0-9a-f]{7,40}\.", text, re.IGNORECASE)
if matches:
    print("trailing punctuation after commit SHA: " + ", ".join(matches), file=sys.stderr)
    raise SystemExit(1)
print("commit SHA evidence uses canonical punctuation")
PY
)"; then
  punctuation_status=0
else
  punctuation_status=$?
fi
if [[ "$punctuation_status" -eq 0 ]]; then
  printf '%s\n' "$punctuation_error"
  pass "Phase 1 plan commit SHA evidence has normalized punctuation"
else
  printf '%s\n' "$punctuation_error"
  fail "Phase 1 plan commit SHA evidence has trailing punctuation"
fi

echo "=== cycle-2 Red plan evidence matches the recorded result and Green closure ==="
cycle2_evidence_status=0
cycle2_evidence_error=""
if cycle2_evidence_error="$(python3 - "$PLAN" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8") if path.is_file() else ""
match = re.search(
    r"^\*\*Mid-Red remediation cycle 2 evidence \(2026-08-12\):\*\*"
    r"(.*?)(?=^\*\*Jr-Green remediation cycle 2 evidence|^## Phase 2:|\Z)",
    text,
    re.MULTILINE | re.DOTALL,
)
if match is None:
    raise SystemExit("cycle-2 Mid-Red evidence section is missing")
red_evidence = match.group(1)
required = {
    "recorded Red result": r"Total:\s*26\s+checks\s+\(PASS=21,\s*FAIL=5\)",
    "punctuation failure": r"Phase 1 plan commit SHA evidence has trailing punctuation",
    "Green RA-P1-N4 closure": r"RA-P1-N4\s+(?:is\s+)?closed\s+in\s+Green\s+at\s+1d0ce0d",
}
missing = [label for label, pattern in required.items() if re.search(pattern, red_evidence, re.IGNORECASE) is None]
if missing:
    raise SystemExit("cycle-2 Red evidence is missing: " + ", ".join(missing))
print("cycle-2 Red evidence records PASS=21 FAIL=5, the punctuation failure, and Green closure of RA-P1-N4 at 1d0ce0d")
PY
)"; then
  cycle2_evidence_status=0
else
  cycle2_evidence_status=$?
fi
if [[ "$cycle2_evidence_status" -eq 0 ]]; then
  printf '%s\n' "$cycle2_evidence_error"
  pass "cycle-2 Red plan evidence matches the recorded failure result and Green RA-P1-N4 closure"
else
  printf '%s\n' "$cycle2_evidence_error"
  fail "cycle-2 Red plan evidence does not match the recorded result or Green RA-P1-N4 closure"
fi

echo "=== cycle-3 Red plan evidence matches the recorded adversarial result ==="
cycle3_evidence_status=0
cycle3_evidence_error=""
if cycle3_evidence_error="$(python3 - "$PLAN" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8") if path.is_file() else ""
match = re.search(
    r"^\*\*Mid-Red evidence remediation cycle 3 \(2026-08-12\):\*\*"
    r"(.*?)(?=^\*\*|^## Phase 2:|\Z)",
    text,
    re.MULTILINE | re.DOTALL,
)
if match is None:
    raise SystemExit("cycle-3 Mid-Red evidence section is missing")
evidence = match.group(1)
required = {
    "exit status": r"Result:\s*exit\s*`1`",
    "recorded Red result": r"Total:\s*28\s+checks\s+\(PASS=26,\s*FAIL=2\)",
    "orphan-command failure": r"orphan bare generator command",
    "cycle-2 evidence failure": r"cycle-2 Red plan evidence",
}
missing = [label for label, pattern in required.items() if re.search(pattern, evidence, re.IGNORECASE) is None]
if missing:
    raise SystemExit("cycle-3 Red evidence is missing: " + ", ".join(missing))
if re.search(r"Result:\s*exit\s*`0`|PASS=28,\s*FAIL=0", evidence, re.IGNORECASE):
    raise SystemExit("cycle-3 Red evidence claims a passing result")
print("cycle-3 Red evidence records exit 1, PASS=26 FAIL=2, and both expected failures")
PY
)"; then
  cycle3_evidence_status=0
else
  cycle3_evidence_status=$?
fi
if [[ "$cycle3_evidence_status" -eq 0 ]]; then
  printf '%s\n' "$cycle3_evidence_error"
  pass "cycle-3 Red plan evidence matches exit 1 with PASS=26 FAIL=2 and its two failures"
else
  printf '%s\n' "$cycle3_evidence_error"
  fail "cycle-3 Red plan evidence does not match exit 1 with PASS=26 FAIL=2"
fi

echo "=== plan claims bind all-checks evidence to a precise successful command ==="
claim_status=0
claim_error=""
if claim_error="$(python3 - "$PLAN" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8") if path.is_file() else ""
headings = list(re.finditer(r"(?im)^(##\s+[^\n]+|\*\*[^*\n]+\*\*:?)[ \t]*$", text))
# Inline code can quote a claim as attack evidence. Validate only prose claims.
masked = re.sub(r"`[^`\n]*`", lambda match: " " * len(match.group(0)), text)
claims = list(re.finditer(r"\ball checks pass\b|\bPASS=\d+\s*,?\s*FAIL=0\b", masked, re.IGNORECASE))
for claim in claims:
    prior_headings = [heading for heading in headings if heading.start() < claim.start()]
    heading = prior_headings[-1] if prior_headings else None
    heading_title = re.sub(r"^##\s+|^\*\*|\*\*:?$", "", heading.group(1)).strip() if heading else ""
    if heading is None or "evidence" not in heading_title.casefold():
        raise SystemExit("unbound all-checks claim is outside a named evidence section")
    section_start = heading.end()
    following_headings = [item for item in headings if item.start() > heading.start()]
    section_end = following_headings[0].start() if following_headings else len(text)
    evidence_section = text[section_start:section_end]
    claim_offset = claim.start() - section_start
    before_claim = evidence_section[:claim_offset]
    if re.search(
        r"(?im)^\s*-?\s*(?:Normal command:\s*)?`?bash\s+tests/gse_vocab_p1_contracts\.sh`?\s+"
        r"exited\s+`?0`?\b",
        before_claim,
    ) is None:
        raise SystemExit("successful checks claim is not bound to bash tests/gse_vocab_p1_contracts.sh exiting 0")
print("all successful-check claims are confined to evidence sections with an exit-0 command")
PY
)"; then
  claim_status=0
else
  claim_status=$?
fi
if [[ "$claim_status" -eq 0 ]]; then
  printf '%s\n' "$claim_error"
  pass "plan all-checks claims use a precise evidence section and an exit-0 command"
else
  printf '%s\n' "$claim_error"
  fail "plan contains an unbound all-checks claim"
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
