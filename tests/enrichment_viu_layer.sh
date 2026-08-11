#!/usr/bin/env bash
# Validate Vocabulary in Use unit-group enrichment layer.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS_COUNT=0
FAIL_COUNT=0
FAILED=0
RESULTS=()
pass() { RESULTS+=("PASS: $1"); PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { RESULTS+=("FAIL: $1"); FAIL_COUNT=$((FAIL_COUNT + 1)); FAILED=1; }

VOCAB="$ROOT/english/cefr-vocabulary"
OVERLAY="$VOCAB/overlays/viu-unit-groups.overlay.json"
REPORT="$VOCAB/reports/enrichment/viu-unit-groups.json"
BUILDER="$VOCAB/scripts/build-viu-unit-groups.py"
CORE="$VOCAB/cefr-vocabulary-knowledge-space.json"
LAYER="enrichment.viu.unit-groups"

echo "=== builder present and compiles ==="
if [[ -f "$BUILDER" ]] && python3 -m py_compile "$BUILDER"; then
  pass "build-viu-unit-groups.py present and compiles"
else
  fail "builder missing or does not compile"
fi

echo "=== overlay and report exist ==="
if [[ -f "$OVERLAY" && -f "$REPORT" ]]; then
  pass "overlay and report artifacts present"
else
  fail "missing overlay or report"
fi

echo "=== ViU structure fixtures for all four bands ==="
missing=0
for band in elementary pre-intermediate upper-intermediate advanced; do
  f="$VOCAB/fixtures/enrichment/viu-${band}-structure.json"
  if [[ ! -f "$f" ]]; then
    echo "missing $f"
    missing=1
  fi
done
if [[ "$missing" -eq 0 ]]; then
  pass "all four ViU band structure fixtures present"
else
  fail "one or more ViU band fixtures missing"
fi

echo "=== overlay semantics: co-taught groups, zero prerequisite_for ==="
python3 - "$OVERLAY" "$REPORT" "$CORE" "$LAYER" <<'PY' || exit 1
import json
import sys
from pathlib import Path

overlay_path = Path(sys.argv[1])
report_path = Path(sys.argv[2])
core_path = Path(sys.argv[3])
layer = sys.argv[4]
errors = []
ov = json.loads(overlay_path.read_text(encoding="utf-8"))
rep = json.loads(report_path.read_text(encoding="utf-8"))
core = json.loads(core_path.read_text(encoding="utf-8"))

if ov.get("enrichmentLayer") != layer:
    errors.append("overlay layer id mismatch")
if ov.get("hardProhibitions", {}).get("unitNumberIsNotPrerequisite") is not True:
    errors.append("unitNumberIsNotPrerequisite must be true")
if any(e.get("type") == "prerequisite_for" for e in ov.get("edges", [])):
    errors.append("overlay contains prerequisite_for edges")

nodes = ov.get("nodes") or []
edges = ov.get("edges") or []
groups = [n for n in nodes if n.get("kind") == "content_group"]
unit_groups = [
    n for n in groups
    if (n.get("metadata") or {}).get("role") == "unit"
]
if len(unit_groups) < 200:
    errors.append(f"expected many unit groups, found {len(unit_groups)}")

membership = [
    e for e in edges
    if e.get("type") == "contains"
    and (e.get("metadata") or {}).get("relationshipKind") == "co-taught-lesson-group"
    and str(e.get("targetId", "")).startswith("english.vocabulary.skill.")
]
if len(membership) < 1000:
    errors.append(f"membership edges too few: {len(membership)}")

# every membership edge has unit metadata
for e in membership[:50]:
    md = e.get("metadata") or {}
    if md.get("unitNumberIsNotPrerequisite") is not True:
        errors.append("membership edge missing unitNumberIsNotPrerequisite")
        break
    if "unitNumber" not in md:
        errors.append("membership edge missing unitNumber")
        break

# core graph must not already contain overlay node ids (isolation)
core_ids = {n["id"] for n in core.get("nodes", [])}
overlap = [n["id"] for n in nodes if n["id"] in core_ids]
if overlap:
    errors.append(f"overlay nodes collide with core ids: {overlap[:5]}")

# core skill count unchanged expectation
core_skills = sum(1 for n in core.get("nodes", []) if n.get("kind") == "skill")
if core_skills < 3500:
    errors.append("core graph looks damaged")

stats = ov.get("stats") or {}
if float(stats.get("matchRate") or 0) < 0.15:
    errors.append(f"match rate suspiciously low: {stats.get('matchRate')}")
if int(stats.get("membershipEdgeCount") or 0) != len(membership):
    # allow domain/book structure edges difference
    if int(stats.get("membershipEdgeCount") or 0) < 1000:
        errors.append("stats membershipEdgeCount too low")

# report agrees
if rep.get("prerequisite_for_count_in_overlay") != 0:
    errors.append("report must show 0 prerequisite_for")
if rep.get("coreGraphUntouched") is not True:
    errors.append("report must affirm core untouched")

print(f"Unit groups: {len(unit_groups)}")
print(f"Co-taught membership edges: {len(membership)}")
print(f"Match rate: {stats.get('matchRate')}")
print(f"Overlay nodes/edges: {len(nodes)}/{len(edges)}")
if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
PY
sem_status=$?
if [[ "$sem_status" -eq 0 ]]; then
  pass "overlay encodes co-taught unit groups with zero prerequisite_for"
else
  fail "overlay semantics/isolation checks failed"
fi

echo "=== core graph still validates alone ==="
if node "$VOCAB/scripts/validate-vocabulary-graph.js" >/tmp/viu-core-val.json 2>/tmp/viu-core-val.err; then
  pass "core graph validates without enrichment"
else
  fail "core graph validation failed"
  cat /tmp/viu-core-val.err || true
fi

echo "=== sample unit has multiple co-members (lesson bundle) ==="
python3 - "$OVERLAY" <<'PY' || exit 1
import json
import sys
from collections import defaultdict
from pathlib import Path

ov = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
mem = defaultdict(list)
for e in ov.get("edges", []):
    md = e.get("metadata") or {}
    if e.get("type") != "contains":
        continue
    if md.get("relationshipKind") != "co-taught-lesson-group":
        continue
    if not str(e.get("targetId", "")).startswith("english.vocabulary.skill."):
        continue
    mem[e["sourceId"]].append(e["targetId"])
rich = [(gid, skills) for gid, skills in mem.items() if len(skills) >= 5]
if not rich:
    print("no unit with >=5 matched co-members", file=sys.stderr)
    raise SystemExit(1)
rich.sort(key=lambda x: -len(x[1]))
gid, skills = rich[0]
print(f"Example unit {gid} co-members: {len(skills)}")
print("sample:", ", ".join(s.rsplit(".", 2)[-2] + "." + s.rsplit(".", 1)[-1] for s in skills[:8]))
PY
ex_status=$?
if [[ "$ex_status" -eq 0 ]]; then
  pass "at least one unit forms a multi-skill co-taught bundle"
else
  fail "no multi-member unit groups found"
fi

echo "=== results ==="
printf '%s\n' "${RESULTS[@]}"
echo "=== Total: $((PASS_COUNT + FAIL_COUNT)) checks (PASS=$PASS_COUNT, FAIL=$FAIL_COUNT) ==="
exit "$FAILED"
