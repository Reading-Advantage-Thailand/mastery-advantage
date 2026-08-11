#!/usr/bin/env bash
# Validate wordfreq frequency enrichment layer (node metadata only, never edges).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS_COUNT=0
FAIL_COUNT=0
FAILED=0
RESULTS=()
pass() { RESULTS+=("PASS: $1"); PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { RESULTS+=("FAIL: $1"); FAIL_COUNT=$((FAIL_COUNT + 1)); FAILED=1; }

VOCAB="$ROOT/english/cefr-vocabulary"
FIXTURE="$VOCAB/fixtures/enrichment/frequency-fixture-schema.json"
MANIFEST="$VOCAB/fixtures/enrichment/manifest.json"
BUILDER="$VOCAB/scripts/build-frequency-metadata.py"
CORE="$VOCAB/cefr-vocabulary-knowledge-space.json"
CORE_REL="english/cefr-vocabulary/cefr-vocabulary-knowledge-space.json"
LAYER="enrichment.frequency.wordfreq"
SOURCE_VERSION="3.1.1"

echo "=== fixture and manifest pins ==="
if [[ -f "$FIXTURE" && -f "$MANIFEST" ]]; then
  pass "frequency fixture schema and fixture manifest present"
else
  fail "frequency fixture schema or manifest missing"
fi

if python3 - "$FIXTURE" "$MANIFEST" "$LAYER" "$SOURCE_VERSION" <<'PY'
import json
import sys
from pathlib import Path

fix_p, man_p, layer, sver = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3], sys.argv[4]
errors = []
if not fix_p.is_file():
    print("fixture schema missing", file=sys.stderr)
    raise SystemExit(1)
fix = json.loads(fix_p.read_text(encoding="utf-8"))

if fix.get("layerId") != layer:
    errors.append(f"fixture layerId != {layer}")
if fix.get("source") != "wordfreq":
    errors.append("fixture source != wordfreq")
if fix.get("sourceVersion") != sver:
    errors.append(f"fixture sourceVersion != {sver} (got {fix.get('sourceVersion')!r})")
if "PIN_AT_IMPLEMENTATION" in fix_p.read_text(encoding="utf-8"):
    errors.append("fixture still contains PIN_AT_IMPLEMENTATION")

cases = fix.get("cases") or []
kinds = [c.get("expect") or c.get("kind") for c in cases]
required = {"has-zipf", "mwe-policy-documented", "missing-true", "rank-tie", "unreliable"}
absent = sorted(required - set(kinds))
if absent:
    errors.append(f"fixture cases missing: {absent}")
if None in kinds:
    errors.append("fixture case without expect/kind")

if man_p.is_file():
    man = json.loads(man_p.read_text(encoding="utf-8"))
    if layer not in json.dumps(man):
        errors.append("manifest does not register the frequency layer id")
    if "frequency-fixture-schema.json" not in (man.get("fixtures") or []):
        errors.append("manifest fixtures list omits frequency-fixture-schema.json")
else:
    errors.append("manifest missing")

print(f"Fixture cases: {kinds}")
if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
PY
then
  pass "fixture pins layerId/source/sourceVersion=$SOURCE_VERSION and all five cases; manifest registers layer"
else
  fail "fixture/manifest pin checks failed"
fi

echo "=== builder present and compiles ==="
if [[ -f "$BUILDER" ]] && python3 -m py_compile "$BUILDER" 2>/dev/null; then
  pass "build-frequency-metadata.py present and compiles"
else
  fail "builder missing or does not compile: $BUILDER"
fi

echo "=== builder outputs discovered (no vacuous pass) ==="
# Resolve overlay/report by contract path first, then by declared layer id.
OVERLAY=""
REPORT=""
if [[ -f "$VOCAB/overlays/frequency.overlay.json" ]]; then
  OVERLAY="$VOCAB/overlays/frequency.overlay.json"
else
  while IFS= read -r cand; do
    [[ -f "$cand" ]] || continue
    if python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));sys.exit(0 if d.get("enrichmentLayer")==sys.argv[2] else 1)' "$cand" "$LAYER" 2>/dev/null; then
      OVERLAY="$cand"
      break
    fi
  done < <(find "$VOCAB/overlays" -maxdepth 1 -name '*.overlay.json' 2>/dev/null | sort)
fi
if [[ -f "$VOCAB/reports/enrichment/frequency.json" ]]; then
  REPORT="$VOCAB/reports/enrichment/frequency.json"
else
  while IFS= read -r cand; do
    [[ -f "$cand" ]] || continue
    if grep -q "$LAYER" "$cand" 2>/dev/null; then
      REPORT="$cand"
      break
    fi
  done < <(find "$VOCAB/reports/enrichment" -maxdepth 1 -name '*.json' 2>/dev/null | sort)
fi
REPORT_MD=""
if [[ -n "$REPORT" ]]; then
  REPORT_MD="${REPORT%.json}.md"
  [[ -f "$REPORT_MD" ]] || REPORT_MD=""
fi

if [[ -n "$OVERLAY" ]]; then
  echo "overlay: $OVERLAY"
  pass "frequency overlay artifact found"
else
  echo "no overlay for layer $LAYER under $VOCAB/overlays" >&2
  fail "frequency overlay missing (expected $VOCAB/overlays/frequency.overlay.json)"
fi
if [[ -n "$REPORT" ]]; then
  echo "report: $REPORT"
  pass "frequency report JSON artifact found"
else
  echo "no report for layer $LAYER under $VOCAB/reports/enrichment" >&2
  fail "frequency report JSON missing (expected $VOCAB/reports/enrichment/frequency.json)"
fi
if [[ -n "$REPORT_MD" ]]; then
  pass "frequency report markdown artifact found"
else
  fail "frequency report markdown missing (expected ${REPORT:-$VOCAB/reports/enrichment/frequency}.md)"
fi

echo "=== core graph byte-identical to git HEAD ==="
head_blob="$(git -C "$ROOT" rev-parse "HEAD:$CORE_REL" 2>/dev/null || true)"
work_blob="$(git -C "$ROOT" hash-object "$CORE" 2>/dev/null || true)"
dirty="$(git -C "$ROOT" status --porcelain -- "$CORE_REL" 2>/dev/null || true)"
if [[ -z "$head_blob" || -z "$work_blob" ]]; then
  fail "could not hash core graph against git HEAD"
elif [[ "$head_blob" != "$work_blob" ]]; then
  echo "HEAD=$head_blob WORKTREE=$work_blob" >&2
  fail "core graph differs from git HEAD - frozen file was modified"
elif [[ -n "$dirty" ]]; then
  echo "$dirty" >&2
  fail "core graph has pending git changes"
else
  echo "core blob $work_blob unchanged vs HEAD"
  pass "cefr-vocabulary-knowledge-space.json byte-identical to git HEAD"
fi

echo "=== overlay header, edge prohibition, and sourceVersion ==="
if [[ -n "$OVERLAY" ]]; then
  if python3 - "$OVERLAY" "$LAYER" "$SOURCE_VERSION" "${REPORT:-}" <<'PY'
import json
import sys
from pathlib import Path

ov_p, layer, sver = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
rep_p = Path(sys.argv[4]) if len(sys.argv) > 4 and sys.argv[4] else None
errors = []
raw = ov_p.read_text(encoding="utf-8")
ov = json.loads(raw)

if ov.get("enrichmentLayer") != layer:
    errors.append(f"enrichmentLayer != {layer} (got {ov.get('enrichmentLayer')!r})")
if ov.get("coreGraph") != "cefr-vocabulary-knowledge-space.json":
    errors.append(f"coreGraph != cefr-vocabulary-knowledge-space.json (got {ov.get('coreGraph')!r})")
for key in ("generatedAt", "description", "hardProhibitions", "nodes", "edges", "stats"):
    if key not in ov:
        errors.append(f"overlay header missing {key}")

hp = ov.get("hardProhibitions") or {}
if hp.get("frequency_as_edge") is not False:
    errors.append("hardProhibitions.frequency_as_edge must be false")
if hp.get("frequencyIsNotPrerequisite") is not True:
    errors.append("hardProhibitions.frequencyIsNotPrerequisite must be true")

# --- hard prohibition: no edges at all, and no prerequisite_for anywhere ---
edges = ov.get("edges")
if edges != []:
    errors.append(f"overlay edges must be [] (got {type(edges).__name__} len={len(edges) if isinstance(edges, list) else 'n/a'})")

def walk(node, path="$"):
    if isinstance(node, dict):
        if node.get("type") == "prerequisite_for":
            errors.append(f"prerequisite_for edge object at {path}")
        if "sourceId" in node and "targetId" in node:
            errors.append(f"edge-shaped object (sourceId+targetId) at {path}")
        if node.get("relationshipType") == "prerequisite_for":
            errors.append(f"prerequisite_for relationshipType at {path}")
        for k, v in node.items():
            if "edge" in k.lower() and isinstance(v, list) and v:
                errors.append(f"non-empty edge list at {path}.{k} (len={len(v)})")
            walk(v, f"{path}.{k}")
    elif isinstance(node, list):
        for i, v in enumerate(node[:200000]):
            walk(v, f"{path}[{i}]")

walk(ov)
if '"prerequisite_for"' in raw:
    errors.append('literal "prerequisite_for" value present in overlay JSON')

# --- sourceVersion must be 3.1.1 everywhere it appears ---
seen = []

def collect(node):
    if isinstance(node, dict):
        for k, v in node.items():
            if k == "sourceVersion":
                seen.append(v)
            collect(v)
    elif isinstance(node, list):
        for v in node:
            collect(v)

collect(ov)
if not seen:
    errors.append("overlay records no sourceVersion at all")
bad = sorted({repr(v) for v in seen if v != sver})
if bad:
    errors.append(f"sourceVersion values != {sver}: {bad[:5]}")
if "PIN_AT_IMPLEMENTATION" in raw:
    errors.append("overlay contains PIN_AT_IMPLEMENTATION")

if rep_p is not None and rep_p.is_file():
    rep_raw = rep_p.read_text(encoding="utf-8")
    rep = json.loads(rep_raw)
    rseen = []

    def rcollect(node):
        if isinstance(node, dict):
            for k, v in node.items():
                if k == "sourceVersion":
                    rseen.append(v)
                rcollect(v)
        elif isinstance(node, list):
            for v in node:
                rcollect(v)

    rcollect(rep)
    rbad = sorted({repr(v) for v in rseen if v != sver})
    if rbad:
        errors.append(f"report sourceVersion values != {sver}: {rbad[:5]}")
    if "PIN_AT_IMPLEMENTATION" in rep_raw:
        errors.append("report contains PIN_AT_IMPLEMENTATION")

nodes = ov.get("nodes")
n_len = len(nodes) if isinstance(nodes, (list, dict)) else 0
print(f"Overlay nodes: {n_len}; edges: {len(edges) if isinstance(edges, list) else 'NOT-A-LIST'}")
print(f"sourceVersion occurrences in overlay: {len(seen)} (all == {sver}: {not bad})")
if errors:
    print("; ".join(sorted(set(errors))[:20]), file=sys.stderr)
    raise SystemExit(1)
PY
  then
    pass "overlay header correct, edges empty, zero prerequisite_for, sourceVersion pinned to $SOURCE_VERSION"
  else
    fail "overlay header / edge prohibition / sourceVersion checks failed"
  fi
else
  fail "overlay header / edge prohibition / sourceVersion NOT EVALUATED - overlay absent"
fi

echo "=== independent wordfreq $SOURCE_VERSION tokenization ==="
# Exclusion keys on token count, so the harness must tokenize with the pinned
# wordfreq itself rather than trust the builder's own bookkeeping.
UV="$(command -v uv || true)"
[[ -n "$UV" && -x "$UV" ]] || UV="$HOME/.local/bin/uv"
TOKENS="$(mktemp -t frequency-tokens.XXXXXX.json)"
trap 'rm -f "$TOKENS"' EXIT
if [[ -x "$UV" ]] && "$UV" run --quiet --with "wordfreq==$SOURCE_VERSION" python - "$CORE" "$TOKENS" "$SOURCE_VERSION" <<'PY'
import json
import sys
from pathlib import Path

import wordfreq
from wordfreq import tokenize, zipf_frequency

core_p, out_p, sver = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
if getattr(wordfreq, "__version__", sver) != sver:
    print(f"wordfreq version {wordfreq.__version__} != pinned {sver}", file=sys.stderr)
    raise SystemExit(1)
core = json.loads(core_p.read_text(encoding="utf-8"))
skills = {}
for n in core.get("nodes", []):
    if n.get("kind") != "skill":
        continue
    nf = (n.get("metadata") or {}).get("normalizedForm") or ""
    toks = tokenize(nf, "en")
    skills[n["id"]] = {
        "nf": nf,
        "tokens": len(toks),
        "zipf": zipf_frequency(nf, "en") if len(toks) == 1 else None,
    }
out_p.write_text(json.dumps({"wordfreqVersion": sver, "skills": skills}), encoding="utf-8")
multi = sum(1 for v in skills.values() if v["tokens"] > 1)
print(f"Tokenized {len(skills)} core skills: {multi} multi-token, {len(skills) - multi} single-token")
PY
then
  pass "core skills tokenized independently with pinned wordfreq $SOURCE_VERSION"
else
  echo "uv (${UV}) or wordfreq==$SOURCE_VERSION unavailable; cannot verify token-count exclusion" >&2
  fail "independent wordfreq tokenization unavailable"
  : > "$TOKENS"
fi

echo "=== node metadata invariants and fixture cases ==="
if [[ -n "$OVERLAY" && -s "$TOKENS" ]]; then
  if python3 - "$OVERLAY" "$FIXTURE" "$CORE" "$SOURCE_VERSION" "${REPORT:-}" "${REPORT_MD:-}" "$TOKENS" <<'PY'
import json
import sys
from collections import defaultdict
from pathlib import Path

ov_p, fix_p, core_p, sver = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3]), sys.argv[4]
rep_p = Path(sys.argv[5]) if sys.argv[5] else None
md_p = Path(sys.argv[6]) if sys.argv[6] else None
errors = []
ov = json.loads(ov_p.read_text(encoding="utf-8"))
fix = json.loads(fix_p.read_text(encoding="utf-8"))
core = json.loads(core_p.read_text(encoding="utf-8"))
core_ids = {n["id"] for n in core.get("nodes", [])}

# Exclusion keys on wordfreq TOKEN COUNT, never on whitespace and never on
# metadata.lexicalUnit:  exclude iff len(tokenize(normalizedForm, "en")) > 1.
# - whitespace misses hyphen/slash compounds ('no-one' 6.10, 'make-up' 5.91,
#   'full-time' 5.47, 'cafe/cafe' 3.59) that are inflated the same way 'a good
#   start' (5.45) beats 'cat' (4.78) under wordfreq's independence assumption.
# - lexicalUnit over-excludes: 115 skills are labelled multiword-expression only
#   because the parser kept a parenthetical gloss ("apartment (UK flat)" ->
#   normalizedForm "apartment"); those are ordinary words and MUST be scored.
tok = json.loads(Path(sys.argv[7]).read_text(encoding="utf-8"))
core_norm = {i: v["nf"] for i, v in tok["skills"].items()}
TOKCOUNT = {i: v["tokens"] for i, v in tok["skills"].items()}
MULTI = {i for i, c in TOKCOUNT.items() if c > 1}
SINGLE = {i for i, c in TOKCOUNT.items() if c <= 1}
LABEL_ONLY = {
    n["id"] for n in core.get("nodes", [])
    if n.get("kind") == "skill"
    and (n.get("metadata") or {}).get("lexicalUnit") == "multiword-expression"
    and n["id"] in SINGLE
}
EXPECTED_MULTI_COUNT = 393
EXCLUDE_REASON = "multi-token-not-comparable"
# 363 whitespace + 28 hyphen + 2 slash + 0 other = 393.
# The whitespace set is 365, but the two 'at / @' forms tokenize to ['at'] and
# return to the scored set, hence 365 - 2 + 30 = 393.
EXPECTED_KIND_COUNTS = {"whitespace": 363, "hyphen": 28, "slash": 2, "other": 0}
MULTI_TOKEN_KINDS = set(EXPECTED_KIND_COUNTS)
# gloss-artifact regression: mislabelled multiword-expression, single token, must be scored
REGRESSION_IDS = [
    "english.vocabulary.skill.apartment-uk-flat.noun",
    "english.vocabulary.skill.autumn-us-fall.noun",
    "english.vocabulary.skill.backpack-uk-rucksack.noun",
    "english.vocabulary.skill.among-amongst.preposition",
]
# hyphen-compound regression: whitespace-free but multi-token, must be excluded
HYPHEN_FORMS = {"no-one", "make-up", "part-time", "full-time", "old-fashioned"}
HYPHEN_IDS = sorted(i for i, nf in core_norm.items() if nf in HYPHEN_FORMS)
# malformed 'at / @' forms tokenize to ['at'] and must be scored, not excluded
AT_IDS = sorted(i for i, nf in core_norm.items() if "@" in nf and i in SINGLE)
if set(core_norm) != {n["id"] for n in core.get("nodes", []) if n.get("kind") == "skill"}:
    errors.append("tokenization precompute does not cover exactly the core skill set")

raw_nodes = ov.get("nodes") or []
if isinstance(raw_nodes, dict):
    raw_nodes = [dict(v, id=v.get("id", k)) for k, v in raw_nodes.items()]

FREQ = {}          # skillId -> frequency block
for n in raw_nodes:
    if not isinstance(n, dict):
        errors.append("overlay node is not an object")
        continue
    nid = n.get("id") or n.get("skillId") or n.get("nodeId")
    blk = None
    md = n.get("metadata")
    if isinstance(md, dict) and isinstance(md.get("frequency"), dict):
        blk = md["frequency"]
    elif isinstance(n.get("frequency"), dict):
        blk = n["frequency"]
    if nid and blk is not None:
        FREQ[nid] = blk

if not FREQ:
    print("overlay carries ZERO frequency metadata blocks - vacuous overlay", file=sys.stderr)
    raise SystemExit(1)
if len(FREQ) < 3000:
    errors.append(f"only {len(FREQ)} frequency blocks; expected coverage of ~3769 core skills")

unknown_ids = [i for i in FREQ if i not in core_ids]
if unknown_ids:
    errors.append(f"{len(unknown_ids)} overlay ids absent from core graph, e.g. {unknown_ids[:3]}")


def num(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool)


scored, multi_token, missing_corpus, unreliable, ranked = [], [], [], [], []
unreliable_any = []
kind_counts = defaultdict(int)
for nid, f in FREQ.items():
    if f.get("source") != "wordfreq":
        errors.append(f"{nid}: source != wordfreq")
    if f.get("sourceVersion") != sver:
        errors.append(f"{nid}: sourceVersion != {sver}")
    if not f.get("calculatedAt"):
        errors.append(f"{nid}: missing calculatedAt")
    if not isinstance(f.get("missing"), bool):
        errors.append(f"{nid}: missing flag is not a boolean")

    has_zipf = "zipf" in f and f.get("zipf") is not None
    is_missing = f.get("missing") is True

    # HARD: never both missing:true and a zipf value
    if is_missing and has_zipf:
        errors.append(f"{nid}: missing:true carries a zipf value ({f.get('zipf')})")
    if is_missing:
        if not f.get("missingReason"):
            errors.append(f"{nid}: missing:true without missingReason")
        if "rankWithinInventory" in f and f.get("rankWithinInventory") is not None:
            errors.append(f"{nid}: missing:true carries rankWithinInventory")
        reason = f.get("missingReason")
        if reason == EXCLUDE_REASON:
            multi_token.append(nid)
            kind = f.get("multiTokenKind")
            if kind not in MULTI_TOKEN_KINDS:
                errors.append(
                    f"{nid}: multiTokenKind {kind!r} not one of {sorted(MULTI_TOKEN_KINDS)}"
                )
            else:
                kind_counts[kind] += 1
        elif reason == "not-in-corpus":
            missing_corpus.append(nid)
        elif reason == "mwe-not-comparable":
            errors.append(f"{nid}: retired reason mwe-not-comparable; use {EXCLUDE_REASON}")
    else:
        if not has_zipf:
            errors.append(f"{nid}: missing:false without zipf")
        elif not num(f["zipf"]):
            errors.append(f"{nid}: zipf is not numeric")
        elif f["zipf"] == 0:
            errors.append(f"{nid}: zipf 0.0 stored as a real score")
        else:
            scored.append(nid)

    if f.get("reliable") is False:
        # "unreliable" = a value was kept but flagged; missing nodes are not unreliable
        if has_zipf:
            unreliable.append(nid)
        unreliable_any.append(nid)
        if "rankWithinInventory" in f and f.get("rankWithinInventory") is not None:
            errors.append(f"{nid}: reliable:false but ranked")
        if f.get("missingReason") != "below-reliability-floor" and not is_missing:
            errors.append(f"{nid}: reliable:false without below-reliability-floor reason")

    r = f.get("rankWithinInventory")
    if r is not None:
        if not isinstance(r, int) or isinstance(r, bool):
            errors.append(f"{nid}: rankWithinInventory is not an int")
        # HARD: every ranked node is reliable and not missing
        if f.get("reliable") is not True:
            errors.append(f"{nid}: ranked but reliable is not true")
        if f.get("missing") is not False:
            errors.append(f"{nid}: ranked but missing is not false")
        if not has_zipf:
            errors.append(f"{nid}: ranked without zipf")
        else:
            ranked.append(nid)

    # componentMinZipf is diagnostic only; it must never be the ranking key
    if "componentMinZipf" in f and r is not None:
        errors.append(f"{nid}: componentMinZipf present on a ranked node")

if not ranked:
    errors.append("no node carries rankWithinInventory - ranking never happened")

# --- exclusion set == the wordfreq multi-token set, in BOTH directions ---
excluded = set(multi_token)
if len(excluded) != EXPECTED_MULTI_COUNT:
    errors.append(
        f"{EXCLUDE_REASON} count is {len(excluded)}, expected {EXPECTED_MULTI_COUNT} "
        f"(363 whitespace + 30 hyphen/slash); 365 would mean the whitespace rule, "
        f"480 the lexicalUnit rule"
    )
over = sorted(excluded - MULTI)
under = sorted(MULTI - excluded)
if over:
    errors.append(
        f"{len(over)} single-token skills excluded as multi-token, e.g. "
        f"{[(i, core_norm.get(i)) for i in over[:3]]}"
    )
if under:
    errors.append(
        f"{len(under)} multi-token skills not excluded, e.g. "
        f"{[(i, core_norm.get(i), TOKCOUNT.get(i)) for i in under[:3]]}"
    )


actual_kinds = {k: kind_counts.get(k, 0) for k in MULTI_TOKEN_KINDS}
if actual_kinds != EXPECTED_KIND_COUNTS:
    errors.append(
        f"multiTokenKind breakdown {actual_kinds} != expected {EXPECTED_KIND_COUNTS}"
    )
if sum(actual_kinds.values()) != len(excluded):
    errors.append(
        f"multiTokenKind subtypes cover {sum(actual_kinds.values())} of {len(excluded)} "
        f"excluded nodes - the field is missing on some"
    )


def must_be_scored(rid, label):
    if rid not in core_ids:
        errors.append(f"{label}: id {rid} absent from core graph")
        return
    f = FREQ.get(rid)
    if f is None:
        errors.append(f"{label}: {rid} absent from overlay")
    elif f.get("missing") is not False:
        errors.append(
            f"{label}: {rid} (normalizedForm {core_norm.get(rid)!r}, "
            f"{TOKCOUNT.get(rid)} token) excluded as {f.get('missingReason')!r} "
            f"but tokenizes to one token and must be scored"
        )
    elif not num(f.get("zipf")) or f["zipf"] <= 0:
        errors.append(f"{label}: {rid} has no real zipf ({f.get('zipf')!r})")
    elif not isinstance(f.get("rankWithinInventory"), int) or isinstance(f.get("rankWithinInventory"), bool):
        errors.append(f"{label}: {rid} has no rankWithinInventory")


# regression A: gloss-artifact skills (mislabelled multiword-expression) must be scored
for rid in REGRESSION_IDS:
    if rid in MULTI:
        errors.append(f"regression-gloss: {rid} unexpectedly tokenizes to >1 token")
        continue
    must_be_scored(rid, "regression-gloss")
label_scored = sum(
    1 for i in LABEL_ONLY
    if i in FREQ and FREQ[i].get("missing") is False and num(FREQ[i].get("zipf"))
)
if label_scored != len(LABEL_ONLY):
    errors.append(
        f"only {label_scored}/{len(LABEL_ONLY)} single-token skills labelled "
        f"multiword-expression are scored; all must be scored as ordinary words"
    )

# regression B: whitespace-free hyphen compounds must be EXCLUDED as multi-token
if len(HYPHEN_IDS) < len(HYPHEN_FORMS):
    found = {core_norm[i] for i in HYPHEN_IDS}
    errors.append(f"regression-hyphen: core graph lacks forms {sorted(HYPHEN_FORMS - found)}")
for rid in HYPHEN_IDS:
    f = FREQ.get(rid)
    nf = core_norm.get(rid)
    if f is None:
        errors.append(f"regression-hyphen: {rid} absent from overlay")
    elif f.get("missing") is not True or f.get("missingReason") != EXCLUDE_REASON:
        errors.append(
            f"regression-hyphen: {rid} ({nf!r} -> {TOKCOUNT.get(rid)} tokens) must be "
            f"missing:true/{EXCLUDE_REASON}, got {f.get('missing')!r}/"
            f"{f.get('missingReason')!r} - whitespace rule would wrongly score it"
        )
    elif "zipf" in f or f.get("rankWithinInventory") is not None:
        errors.append(f"regression-hyphen: {rid} retains zipf/rank")

# regression C: malformed 'at / @' forms tokenize to ['at'] and must be scored
if not AT_IDS:
    errors.append("regression-at: no '@' normalizedForm resolved to a single token")
for rid in AT_IDS:
    must_be_scored(rid, "regression-at")

# --- rank tie policy on real data ---
stats = ov.get("stats") or {}
flat_stats = {}


def flatten(d, prefix=""):
    for k, v in (d or {}).items():
        if isinstance(v, dict):
            flatten(v, prefix + k + ".")
        else:
            flat_stats[prefix + k] = v


flatten(stats)
merged = dict(flat_stats)
for k, v in ov.items():
    if not isinstance(v, (dict, list)):
        merged[k] = v


def find_key(*needles, exclude=()):
    """Locate a stats entry by fuzzy name so the harness asserts on values, not on
    key names it guessed. Shortest match wins; `exclude` keeps aggregate lookups
    from binding to a subtype bucket."""
    hits = []
    for k, v in merged.items():
        nk = "".join(ch for ch in k.lower() if ch.isalnum())
        if all(n in nk for n in needles) and not any(x in nk for x in exclude):
            hits.append((len(nk), k, v))
    if not hits:
        return None, None
    hits.sort()
    return hits[0][1], hits[0][2]


SUBTYPE_WORDS = ("whitespace", "hyphen", "slash", "other")


_, tie_policy = find_key("ranktiepolicy")
if tie_policy is None:
    _, tie_policy = find_key("tiepolicy")
if tie_policy != "dense-equal-rank":
    errors.append(f"rankTiePolicy must be recorded as dense-equal-rank (got {tie_policy!r})")

by_zipf = defaultdict(set)
rank_of_zipf = defaultdict(set)
for nid in ranked:
    f = FREQ[nid]
    by_zipf[f["zipf"]].add(nid)
    rank_of_zipf[f["zipf"]].add(f["rankWithinInventory"])

split = [z for z, rs in rank_of_zipf.items() if len(rs) > 1]
if split:
    errors.append(f"{len(split)} zipf values map to multiple ranks, e.g. zipf={split[0]} ranks={sorted(rank_of_zipf[split[0]])[:4]}")

rank_to_zipf = defaultdict(set)
for z, rs in rank_of_zipf.items():
    for r in rs:
        rank_to_zipf[r].add(z)
collide = [r for r, zs in rank_to_zipf.items() if len(zs) > 1]
if collide:
    errors.append(f"{len(collide)} ranks shared by different zipf values, e.g. rank={collide[0]}")

tie_groups = {z: ids for z, ids in by_zipf.items() if len(ids) > 1}
if not tie_groups:
    errors.append("no equal-zipf tie group found in ranked data - tie policy unexercised")

# dense-equal-rank: descending zipf order, contiguous ranks starting at 1
ordered = sorted(rank_of_zipf.keys(), reverse=True)
expected = {z: i + 1 for i, z in enumerate(ordered)}
mismatch = [z for z in ordered if next(iter(rank_of_zipf[z])) != expected[z]]
if mismatch:
    z = mismatch[0]
    errors.append(
        f"ranks are not dense-equal (1..{len(ordered)} over distinct zipf desc): "
        f"zipf={z} rank={sorted(rank_of_zipf[z])} expected={expected[z]}; {len(mismatch)} mismatches"
    )

# --- reliability floor recorded and honoured ---
# never bind the floor to a *count* of below-floor nodes
NOT_A_FLOOR = ("count", "below", "num")
floor_key, floor = find_key("floor", "zipf", exclude=NOT_A_FLOOR)
if floor is None:
    floor_key, floor = find_key("reliab", "floor", exclude=NOT_A_FLOOR)
if floor is None:
    floor_key, floor = find_key("floor", exclude=NOT_A_FLOOR)
if floor is None or not num(floor):
    errors.append("reliability floor not recorded as a number in overlay stats/header")
elif floor <= 0:
    errors.append(f"reliability floor {floor} is not a positive zipf threshold ({floor_key})")
else:
    for nid, f in FREQ.items():
        if f.get("missing") is True or "zipf" not in f or not num(f.get("zipf")):
            continue
        if f["zipf"] < floor and f.get("reliable") is not False:
            errors.append(f"{nid}: zipf {f['zipf']} below floor {floor} but reliable is not false")
        if f["zipf"] >= floor and f.get("reliable") is not True:
            errors.append(f"{nid}: zipf {f['zipf']} at/above floor {floor} but reliable is not true")

# --- stats counts present and consistent ---
recount = {
    ("scored",): len(scored),
    ("multitoken",): len(multi_token),
    ("missing", "corpus"): len(missing_corpus),
    ("unreliable",): len(unreliable),
    ("ranked",): len(ranked),
}
for needles, actual in recount.items():
    k, v = find_key(*needles, exclude=SUBTYPE_WORDS)
    if k is None:
        errors.append(f"stats missing a count for {'/'.join(needles)}")
    elif isinstance(v, int) and not isinstance(v, bool) and v != actual:
        errors.append(f"stats {k}={v} disagrees with overlay data ({actual})")

# stats must carry the multi-token subtype breakdown; match on values, not on
# key names the harness would otherwise be guessing
def find_breakdown(node):
    """The subtype breakdown is the stats sub-dict keyed by the subtype names.
    Bind to it structurally so the harness never guesses at key spelling."""
    if isinstance(node, dict):
        keys = {str(k).lower() for k in node}
        if len(keys & MULTI_TOKEN_KINDS) >= 3 and all(
            isinstance(v, int) and not isinstance(v, bool) for v in node.values()
        ):
            return node
        for v in node.values():
            found = find_breakdown(v)
            if found is not None:
                return found
    return None


breakdown = find_breakdown(stats)
if breakdown is None:
    errors.append("stats carry no multi-token subtype breakdown (whitespace/hyphen/slash/other)")
else:
    got = {str(k).lower(): v for k, v in breakdown.items()}
    for kind, expected_n in EXPECTED_KIND_COUNTS.items():
        if kind not in got:
            if expected_n:
                errors.append(f"subtype breakdown lacks {kind}")
        elif got[kind] != expected_n:
            errors.append(f"subtype breakdown {kind}={got[kind]}, expected {expected_n}")
    extra = sorted(set(got) - MULTI_TOKEN_KINDS)
    if extra:
        errors.append(f"subtype breakdown has unexpected subtypes {extra}")

# --- fixture cases, driven from the fixture file itself ---
report_text = ""
if rep_p is not None and rep_p.is_file():
    report_text += rep_p.read_text(encoding="utf-8")
if md_p is not None and md_p.is_file():
    report_text += md_p.read_text(encoding="utf-8")
report_text = report_text.lower()

handled = set()
for case in fix.get("cases") or []:
    kind = case.get("expect") or case.get("kind")
    sid = case.get("skillId")
    handled.add(kind)
    real = sid in core_ids if sid else False

    if kind == "has-zipf":
        if not real:
            errors.append(f"case has-zipf: skillId {sid} not in core graph")
            continue
        f = FREQ.get(sid)
        if f is None:
            errors.append(f"case has-zipf: {sid} absent from overlay")
        elif f.get("missing") is not False or not num(f.get("zipf")) or f.get("zipf") <= 0:
            errors.append(f"case has-zipf: {sid} has no usable zipf ({f.get('zipf')!r}, missing={f.get('missing')!r})")
        elif f.get("reliable") is not True or not isinstance(f.get("rankWithinInventory"), int):
            errors.append(f"case has-zipf: {sid} not reliable/ranked")
        else:
            print(f"  has-zipf: {sid} zipf={f['zipf']} rank={f['rankWithinInventory']}")

    elif kind == "mwe-policy-documented":
        if not real:
            errors.append(f"case mwe-policy-documented: skillId {sid} not in core graph")
            continue
        f = FREQ.get(sid)
        if f is None:
            errors.append(f"case mwe: {sid} absent from overlay")
        elif f.get("missing") is not True or f.get("missingReason") != EXCLUDE_REASON:
            errors.append(f"case mwe: {sid} must be missing:true/{EXCLUDE_REASON} (got {f.get('missing')!r}/{f.get('missingReason')!r})")
        elif "zipf" in f or f.get("rankWithinInventory") is not None:
            errors.append(f"case mwe: {sid} must omit zipf and rankWithinInventory")
        else:
            print(f"  mwe-policy-documented: {sid} -> {f.get('missingReason')} "
                  f"(normalizedForm {core_norm.get(sid)!r} -> {TOKCOUNT.get(sid)} tokens, "
                  f"kind={f.get('multiTokenKind')!r})")
        # exact-count and set-equality checks live in the invariants block above
        if not any(k in report_text for k in ("multi-token", "multitoken", "mwe", "multiword", "multi-word")):
            errors.append("case mwe: report does not document the multi-token exclusion policy")

    elif kind == "missing-true":
        # fixture skillId may be a sentinel that is absent from the core graph
        if real:
            f = FREQ.get(sid)
            if f is None or f.get("missing") is not True or f.get("missingReason") != "not-in-corpus":
                errors.append(f"case missing-true: {sid} must be missing:true/not-in-corpus")
        if not missing_corpus:
            errors.append("case missing-true: no node carries missingReason not-in-corpus")
        else:
            for nid in missing_corpus:
                f = FREQ[nid]
                if "zipf" in f or f.get("rankWithinInventory") is not None:
                    errors.append(f"case missing-true: {nid} retains zipf/rank")
                    break
            print(f"  missing-true: {len(missing_corpus)} not-in-corpus, e.g. {sorted(missing_corpus)[:2]}")

    elif kind == "rank-tie":
        if tie_policy != "dense-equal-rank":
            errors.append("case rank-tie: rankTiePolicy not recorded as dense-equal-rank")
        if not tie_groups:
            errors.append("case rank-tie: no real equal-zipf group to prove shared ranking")
        else:
            z, ids = max(tie_groups.items(), key=lambda kv: len(kv[1]))
            ranks = {FREQ[i]["rankWithinInventory"] for i in ids}
            if len(ranks) != 1:
                errors.append(f"case rank-tie: zipf {z} split across ranks {sorted(ranks)[:4]}")
            else:
                print(f"  rank-tie: {len(ids)} nodes at zipf={z} all share rank {ranks.pop()}")
        # duplicate normalizedForms across senses (e.g. "catch", "biscuit") are a
        # legitimate tie, not an error: same form -> same zipf -> same rank
        dup = defaultdict(list)
        for nid in ranked:
            dup[core_norm.get(nid, "")].append(nid)
        dups = {k: v for k, v in dup.items() if k and len(v) > 1}
        for form, ids in list(dups.items())[:50]:
            if len({FREQ[i]["zipf"] for i in ids}) != 1:
                errors.append(f"case rank-tie: duplicate form {form!r} got differing zipf")
            elif len({FREQ[i]["rankWithinInventory"] for i in ids}) != 1:
                errors.append(f"case rank-tie: duplicate form {form!r} split across ranks")
        if dups:
            form, ids = next(iter(dups.items()))
            print(f"  rank-tie: {len(dups)} duplicate normalizedForms across senses tolerated, "
                  f"e.g. {form!r} x{len(ids)} at rank {FREQ[ids[0]]['rankWithinInventory']}")

    elif kind == "unreliable":
        if floor is None or not num(floor):
            errors.append("case unreliable: no documented reliability floor")
        elif "floor" not in report_text and "reliab" not in report_text:
            errors.append("case unreliable: report does not justify the reliability floor")
        else:
            below = [n for n, f in FREQ.items() if num(f.get("zipf")) and f["zipf"] < floor]
            for nid in below:
                if FREQ[nid].get("reliable") is not False or FREQ[nid].get("rankWithinInventory") is not None:
                    errors.append(f"case unreliable: {nid} below floor but reliable/ranked")
                    break
            print(f"  unreliable: floor={floor} ({floor_key}); {len(unreliable)} scored-but-flagged, "
                  f"{len(below)} below floor, {len(unreliable_any)} carrying reliable:false")

    else:
        errors.append(f"unhandled fixture case kind {kind!r} - harness would pass vacuously")

for need in ("has-zipf", "mwe-policy-documented", "missing-true", "rank-tie", "unreliable"):
    if need not in handled:
        errors.append(f"fixture case {need} was never evaluated")

print(f"Frequency blocks: {len(FREQ)}")
print(f"multi-token excluded={len(excluded)} (expected {EXPECTED_MULTI_COUNT}); "
      f"gloss-artifact single-token skills scored={label_scored}/{len(LABEL_ONLY)}; "
      f"hyphen regressions={len(HYPHEN_IDS)}; at/@ scored={len(AT_IDS)}")
print(f"scored={len(scored)} ranked={len(ranked)} multi-token-excluded={len(multi_token)} "
      f"not-in-corpus={len(missing_corpus)} unreliable={len(unreliable)}")
print(f"distinct ranked zipf values: {len(rank_of_zipf)}; tie groups: {len(tie_groups)}")
if errors:
    uniq = sorted(set(errors))
    print(f"{len(uniq)} distinct errors; first 20:", file=sys.stderr)
    print("; ".join(uniq[:20]), file=sys.stderr)
    raise SystemExit(1)
PY
  then
    pass "node metadata invariants hold and all five fixture cases are satisfied by the overlay"
  else
    fail "node metadata / fixture case checks failed"
  fi
elif [[ -z "$OVERLAY" ]]; then
  fail "node metadata / fixture case checks NOT EVALUATED - overlay absent"
else
  fail "node metadata / fixture case checks NOT EVALUATED - tokenization unavailable"
fi

echo "=== zipf values recomputed independently from wordfreq $SOURCE_VERSION ==="
if [[ -n "$OVERLAY" && -s "$TOKENS" ]]; then
  if python3 - "$OVERLAY" "$TOKENS" <<'PY'
import json
import sys
from pathlib import Path

ov = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
tok = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))["skills"]
errors = []
nodes = ov.get("nodes") or []
if isinstance(nodes, dict):
    nodes = [dict(v, id=v.get("id", k)) for k, v in nodes.items()]
checked = 0
for n in nodes:
    if not isinstance(n, dict):
        continue
    nid = n.get("id") or n.get("skillId") or n.get("nodeId")
    md = n.get("metadata")
    f = md.get("frequency") if isinstance(md, dict) else n.get("frequency")
    if not isinstance(f, dict) or "zipf" not in f or f.get("zipf") is None:
        continue
    exp = (tok.get(nid) or {}).get("zipf")
    if exp is None:
        errors.append(f"{nid}: carries a zipf but is not a single-token form")
        continue
    if abs(float(f["zipf"]) - float(exp)) > 0.01:
        errors.append(f"{nid} ({tok[nid]['nf']!r}): zipf {f['zipf']} != wordfreq {exp}")
    checked += 1
if checked < 3000:
    errors.append(f"only {checked} zipf values recomputed; expected ~3376 single-token skills")
print(f"Recomputed {checked} zipf values against wordfreq")
if errors:
    uniq = sorted(set(errors))
    print(f"{len(uniq)} mismatches; first 10: " + "; ".join(uniq[:10]), file=sys.stderr)
    raise SystemExit(1)
PY
  then
    pass "every stored zipf matches an independent wordfreq $SOURCE_VERSION recomputation"
  else
    fail "stored zipf values disagree with wordfreq $SOURCE_VERSION"
  fi
else
  fail "zipf recomputation NOT EVALUATED - overlay or tokenization unavailable"
fi

echo "=== label-anomaly review queue ==="
QUEUE="$VOCAB/review/enrichment/queues/frequency-label-anomalies.jsonl"
if [[ -f "$QUEUE" ]]; then
  if python3 - "$QUEUE" <<'PY'
import json
import sys
from pathlib import Path

p = Path(sys.argv[1])
errors = []
lines = [ln for ln in p.read_text(encoding="utf-8").splitlines() if ln.strip()]
if not lines:
    print("label-anomaly queue is empty", file=sys.stderr)
    raise SystemExit(1)
objs = []
for i, ln in enumerate(lines, 1):
    try:
        o = json.loads(ln)
    except json.JSONDecodeError as exc:
        errors.append(f"line {i} is not valid JSON: {exc}")
        if len(errors) > 3:
            break
        continue
    if not isinstance(o, dict):
        errors.append(f"line {i} is not a JSON object")
    else:
        objs.append(o)
# covers gloss-label, punctuation, and malformed 'at / @' classes; counts are not pinned
if not objs:
    errors.append("queue has no usable JSON object entries")
print(f"Label-anomaly queue entries: {len(objs)}")
if errors:
    print("; ".join(errors[:5]), file=sys.stderr)
    raise SystemExit(1)
PY
  then
    pass "frequency-label-anomalies.jsonl exists, is valid JSONL, and is non-empty"
  else
    fail "label-anomaly queue invalid or under-populated"
  fi
else
  fail "review queue missing: $QUEUE"
fi

echo "=== report affirms isolation ==="
if [[ -n "$REPORT" ]]; then
  if python3 - "$REPORT" "$LAYER" <<'PY'
import json
import sys
from pathlib import Path

rep = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
layer = sys.argv[2]
errors = []
flat = json.dumps(rep)
if layer not in flat:
    errors.append("report does not name the frequency layer")
if rep.get("prerequisite_for_count_in_overlay") not in (0, None):
    errors.append("report shows nonzero prerequisite_for")
if rep.get("prerequisite_for_count_in_overlay") is None:
    errors.append("report must state prerequisite_for_count_in_overlay: 0")
if rep.get("coreGraphUntouched") is not True:
    errors.append("report must affirm coreGraphUntouched: true")
if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
PY
  then
    pass "report affirms zero prerequisite_for and untouched core graph"
  else
    fail "report isolation affirmations missing or wrong"
  fi
else
  fail "report isolation affirmations NOT EVALUATED - report absent"
fi

echo "=== core graph still validates alone ==="
if node "$VOCAB/scripts/validate-vocabulary-graph.js" >/dev/null 2>&1; then
  pass "core graph validates without enrichment"
else
  fail "core graph validation failed"
fi

echo "=== results ==="
printf '%s\n' "${RESULTS[@]}"
echo "=== Total: $((PASS_COUNT + FAIL_COUNT)) checks (PASS=$PASS_COUNT, FAIL=$FAIL_COUNT) ==="
exit "$FAILED"
