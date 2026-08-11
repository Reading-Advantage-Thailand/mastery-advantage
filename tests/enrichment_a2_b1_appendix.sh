#!/usr/bin/env bash
# Validate A2 Key and B1 Preliminary appendix enrichment overlays.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VOCAB="$ROOT/english/cefr-vocabulary"
PASS_COUNT=0
FAIL_COUNT=0
FAILED=0
RESULTS=()
pass() { RESULTS+=("PASS: $1"); PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { RESULTS+=("FAIL: $1"); FAIL_COUNT=$((FAIL_COUNT + 1)); FAILED=1; }

BUILDER="$VOCAB/scripts/build-a2-b1-appendix-groups.py"
CORE="$VOCAB/cefr-vocabulary-knowledge-space.json"

echo "=== builder compiles ==="
if [[ -f "$BUILDER" ]] && python3 -m py_compile "$BUILDER"; then
  pass "build-a2-b1-appendix-groups.py compiles"
else
  fail "builder missing or broken"
fi

echo "=== core graph byte-identical to git HEAD ==="
if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if git -C "$ROOT" diff --quiet -- "$CORE" 2>/dev/null; then
    pass "core graph unmodified in working tree"
  else
    # also accept clean tracked identity via hash vs HEAD blob
    if git -C "$ROOT" cat-file -e "HEAD:$CORE" 2>/dev/null; then
      head_hash="$(git -C "$ROOT" rev-parse "HEAD:$CORE")"
      work_hash="$(git -C "$ROOT" hash-object "$CORE")"
      if [[ "$head_hash" == "$work_hash" ]]; then
        pass "core graph byte-identical to git HEAD"
      else
        fail "core graph differs from HEAD"
      fi
    else
      fail "core graph not in HEAD"
    fi
  fi
else
  fail "not a git repo"
fi

check_layer() {
  local exam_key="$1"
  local layer="$2"
  local overlay="$VOCAB/overlays/${exam_key}-appendix.overlay.json"
  local report="$VOCAB/reports/enrichment/${exam_key}-appendix.json"
  local fixture="$VOCAB/fixtures/enrichment/${exam_key}-structure.json"
  local unmatched="$VOCAB/review/enrichment/queues/${exam_key}-unmatched.jsonl"
  local ambiguous="$VOCAB/review/enrichment/queues/${exam_key}-ambiguous.jsonl"
  local min_az_rate="$3"
  local min_topic_rate="$4"
  local min_exam_skills="$5"

  echo "=== artifacts present ($exam_key) ==="
  if [[ -f "$overlay" && -f "$report" && -f "$fixture" && -f "$unmatched" ]]; then
    pass "$exam_key overlay, report, fixture, unmatched queue present"
  else
    fail "$exam_key missing artifacts"
    return
  fi

  echo "=== overlay isolation and fidelity ($exam_key) ==="
  python3 - "$overlay" "$report" "$CORE" "$layer" "$min_az_rate" "$min_topic_rate" "$min_exam_skills" "$unmatched" <<'PY' || return 1
import json
import sys
from pathlib import Path

ov_p, rep_p, core_p, layer = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3]), sys.argv[4]
min_az = float(sys.argv[5])
min_topic = float(sys.argv[6])
min_skills = int(sys.argv[7])
unmatched_p = Path(sys.argv[8])

errors = []
ov = json.loads(ov_p.read_text(encoding="utf-8"))
rep = json.loads(rep_p.read_text(encoding="utf-8"))
core = json.loads(core_p.read_text(encoding="utf-8"))

if ov.get("enrichmentLayer") != layer:
    errors.append(f"layer id mismatch: {ov.get('enrichmentLayer')}")
if any(e.get("type") == "prerequisite_for" for e in ov.get("edges", [])):
    errors.append("prerequisite_for present")
if ov.get("hardProhibitions", {}).get("doesNotCreateDuplicateSkills") is not True:
    errors.append("must declare doesNotCreateDuplicateSkills")

core_ids = {n["id"] for n in core.get("nodes", [])}
core_skills = {n["id"] for n in core.get("nodes", []) if n.get("kind") == "skill"}
for n in ov.get("nodes", []):
    if n["id"] in core_ids:
        errors.append(f"overlay node collides with core: {n['id']}")
    if n.get("kind") == "skill":
        errors.append("overlay must not introduce skill nodes")

exam_edges = [
    e for e in ov.get("edges", [])
    if e.get("type") == "contains"
    and (e.get("metadata") or {}).get("section") == "a-z"
    and str(e.get("targetId", "")).startswith("english.vocabulary.skill.")
]
topic_edges = [
    e for e in ov.get("edges", [])
    if e.get("type") == "contains"
    and (e.get("metadata") or {}).get("section") == "topic"
    and str(e.get("targetId", "")).startswith("english.vocabulary.skill.")
]

for e in exam_edges + topic_edges:
    if e["targetId"] not in core_skills:
        errors.append(f"membership target not a core skill: {e['targetId']}")
        break

stats = ov.get("stats") or {}
az_rate = float(stats.get("azMatchRate") or 0)
topic_rate = float(stats.get("topicMatchRate") or 0)
exam_skills = int(stats.get("examMembershipSkillCount") or 0)
if az_rate < min_az:
    errors.append(f"az match rate {az_rate} < {min_az}")
if topic_rate < min_topic:
    errors.append(f"topic match rate {topic_rate} < {min_topic}")
if exam_skills < min_skills:
    errors.append(f"exam skills {exam_skills} < {min_skills}")
if stats.get("noNewSkills") is not True:
    errors.append("stats.noNewSkills must be true")

if rep.get("prerequisite_for_count_in_overlay") != 0:
    errors.append("report prereq nonzero")
if rep.get("coreGraphUntouched") is not True:
    errors.append("core must be untouched")
if rep.get("noNewSkillNodes") is not True:
    errors.append("report must affirm no new skills")

# Unmatched queue is valid JSONL (may be empty)
if unmatched_p.is_file():
    for i, line in enumerate(unmatched_p.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        try:
            json.loads(line)
        except json.JSONDecodeError as exc:
            errors.append(f"unmatched JSONL line {i}: {exc}")
            break

print(f"exam A–Z edges: {len(exam_edges)}; topic edges: {len(topic_edges)}")
print(f"azRate={az_rate} topicRate={topic_rate} examSkills={exam_skills}")
if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
PY
  if [[ $? -eq 0 ]]; then
    pass "$exam_key overlay is isolated co-membership with high match rates"
  else
    fail "$exam_key overlay semantics failed"
  fi
}

# A2: near-perfect A–Z; topics ~0.96 after heading filter
check_layer "a2-key" "enrichment.cambridge.a2-key-appendix" "0.99" "0.95" "1500"
# B1: near-perfect A–Z; topics slightly lower due to longer inventory
check_layer "b1-preliminary" "enrichment.cambridge.b1-preliminary-appendix" "0.99" "0.90" "2800"

echo "=== shared-skill policy: Key/Flyers may share skills ==="
python3 - "$VOCAB/overlays/a2-key-appendix.overlay.json" "$CORE" <<'PY' || exit 1
import json
import sys
from pathlib import Path

ov = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
core = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))

# Core flyers membership
flyers = set()
for e in core.get("edges", []):
    if e.get("sourceId") == "english.vocabulary.exam.a2-flyers" and e.get("type") in (None, "contains"):
        # edge type may be absent in core; treat as contains when target is skill
        tid = e.get("targetId", "")
        if tid.startswith("english.vocabulary.skill."):
            flyers.add(tid)
    if e.get("sourceId") == "english.vocabulary.exam.a2-flyers":
        tid = e.get("targetId", "")
        if tid.startswith("english.vocabulary.skill."):
            flyers.add(tid)

key_skills = set()
for e in ov.get("edges", []):
    if (e.get("metadata") or {}).get("section") == "a-z":
        tid = e.get("targetId", "")
        if tid.startswith("english.vocabulary.skill."):
            key_skills.add(tid)

shared = key_skills & flyers
print(f"A2 Key skills: {len(key_skills)}; Flyers skills: {len(flyers)}; shared: {len(shared)}")
if len(shared) < 100:
    print("expected substantial Key/Flyers overlap via shared skill ids", file=sys.stderr)
    raise SystemExit(1)
# Overlay must not invent parallel *-key-only skill ids for shared forms
if any(".key-only." in s or s.endswith(".a2-key") for s in key_skills):
    print("found key-only skill suffix — identity split forbidden", file=sys.stderr)
    raise SystemExit(1)
PY
if [[ $? -eq 0 ]]; then
  pass "Key membership reuses core skill ids and overlaps Flyers"
else
  fail "shared-skill policy check failed"
fi

echo "=== core still validates alone ==="
if node "$VOCAB/scripts/validate-vocabulary-graph.js" >/dev/null; then
  pass "core graph validates without enrichment"
else
  fail "core validation failed"
fi

echo "=== results ==="
printf '%s\n' "${RESULTS[@]}"
echo "=== Total: $((PASS_COUNT + FAIL_COUNT)) checks (PASS=$PASS_COUNT, FAIL=$FAIL_COUNT) ==="
exit "$FAILED"
