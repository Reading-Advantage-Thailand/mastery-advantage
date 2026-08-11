#!/usr/bin/env bash
# Phase 3 Red/Green harness: YLE-touching support inventory, class dispositions,
# progression policy, and zero prerequisite_for.
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
TRACK_ID="lexical_graph_core_release_20260610"
track_dir_resolve() {
  local track_id="$1"
  if [[ -d "$ROOT/measure/archive/$track_id" ]]; then
    printf '%s\n' "$ROOT/measure/archive/$track_id"
  else
    printf '%s\n' "$ROOT/measure/tracks/$track_id"
  fi
}
TRACK_DIR="$(track_dir_resolve "$TRACK_ID")"
PLAN="${PLAN_OVERRIDE:-$TRACK_DIR/plan.md}"
GRAPH="$ROOT/english/cefr-vocabulary/cefr-vocabulary-knowledge-space.json"
REVIEW_DIR="$ROOT/english/cefr-vocabulary/review/yle-2025"
INVENTORY="$REVIEW_DIR/support-inventory.json"
QUEUE="$REVIEW_DIR/support-review-queue.jsonl"
DISPOSITIONS="$REVIEW_DIR/support-class-dispositions.json"
SAMPLE_DECISIONS="$REVIEW_DIR/support-sample-decisions.jsonl"
PROGRESSION="$REVIEW_DIR/progression-policy.md"
REPORT="$ROOT/english/cefr-vocabulary/reports/yle-relationship-audit.json"
REPORT_MD="$ROOT/english/cefr-vocabulary/reports/yle-relationship-audit.md"
GENERATOR="$ROOT/english/cefr-vocabulary/scripts/build-yle-relationship-audit.py"
APPROVAL="$REVIEW_DIR/phase3-approval.md"
PHASE1_SCOPE="$REVIEW_DIR/phase1-scope.md"
METHOD_SAME="same-lexical-form-support-v1"
METHOD_MWE="multiword-component-support-v1"

echo "=== Phase 3 plan markers remain non-vacuous and first executable work is relationships ==="
plan_output="$(python3 - "$PLAN" <<'PY'
import re
import sys
from pathlib import Path

plan_path = Path(sys.argv[1])
errors = []
if not plan_path.is_file():
    errors.append(f"missing plan: {plan_path}")
    text = ""
else:
    text = plan_path.read_text(encoding="utf-8")
    phase_matches = list(re.finditer(r"^## Phase 3: Relationship And Progression Review[ \t]*$", text, re.M))
    next_matches = list(re.finditer(r"^## Phase 4: Consumption And Next-Step Contract[ \t]*$", text, re.M))
    if len(phase_matches) != 1 or len(next_matches) != 1 or next_matches[0].start() <= phase_matches[0].end():
        errors.append("Phase 3/Phase 4 boundaries are not uniquely resolvable")
        phase = ""
    else:
        phase = text[phase_matches[0].end():next_matches[0].start()]
    markers = re.findall(r"^- \[([^]]+)\][ \t]+", phase, re.M)
    invalid = sorted({marker for marker in markers if marker not in {"x", "~", "b"}})
    completed = len(re.findall(r"^- \[x\][ \t]+Task:", phase, re.M))
    in_progress = len(re.findall(r"^- \[~\][ \t]+Task:", phase, re.M))
    blocked = len(re.findall(r"^- \[b\][ \t]+Task:", phase, re.M))
    if re.findall(r"^- \[ \][ \t]", phase, re.M):
        errors.append("legacy [ ] task marker remains in Phase 3")
    if invalid:
        errors.append(f"unrecognized Phase 3 markers: {invalid}")
    if "Inventory all YLE-touching" not in phase:
        errors.append("Phase 3 inventory task is absent")
    if "bash tests/yle_p3_relationships.sh" not in text and "yle_p3_relationships.sh" not in phase:
        # Evidence may live in Green prose below the phase; require the harness name somewhere after Phase 3 opens.
        after = text[phase_matches[0].start():]
        if "yle_p3_relationships.sh" not in after:
            errors.append("Phase 3 plan/evidence lacks the authoritative Red command yle_p3_relationships.sh")
    if "prerequisite_for" not in phase.lower() and "prerequisite_for" not in phase:
        errors.append("Phase 3 lacks an explicit prerequisite_for prohibition task")
    print(f"Phase 3 completed task count: {completed}")
    print(f"Phase 3 in-progress task count: {in_progress}")
    print(f"Phase 3 human-gate task count: {blocked}")
if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
PY
)"
plan_status=$?
printf '%s\n' "$plan_output"
if [[ "$plan_status" -ne 0 ]]; then
  fail "Phase 3 plan markers/structure are invalid"
else
  pass "Phase 3 plan structure and marker vocabulary are valid"
fi

echo "=== live graph: labeled YLE-touching supports and zero prerequisite_for ==="
graph_output="$(python3 - "$GRAPH" "$PHASE1_SCOPE" "$METHOD_SAME" "$METHOD_MWE" <<'PY'
import json
import re
import sys
from collections import Counter
from pathlib import Path

graph_path, scope_path = map(Path, sys.argv[1:3])
method_same, method_mwe = sys.argv[3:5]
errors = []
YLE = {"pre-a1-starters", "a1-movers", "a2-flyers"}

if not graph_path.is_file():
    print("missing graph", file=sys.stderr)
    raise SystemExit(1)
graph = json.loads(graph_path.read_text(encoding="utf-8"))
yle_skill_ids = {
    node["id"]
    for node in graph.get("nodes", [])
    if node.get("kind") == "skill"
    and YLE.intersection(node.get("metadata", {}).get("examAlignments", []))
}
supports = [
    edge
    for edge in graph.get("edges", [])
    if edge.get("type") == "supports"
    and (edge.get("sourceId") in yle_skill_ids or edge.get("targetId") in yle_skill_ids)
]
methods = Counter()
unlabeled = 0
for edge in supports:
    refs = edge.get("sourceRefs") or []
    if not refs:
        unlabeled += 1
        methods["<unlabeled>"] += 1
    else:
        for ref in refs:
            methods[ref] += 1
prereq = sum(1 for edge in graph.get("edges", []) if edge.get("type") == "prerequisite_for")

print(f"YLE skill count: {len(yle_skill_ids)}")
print(f"YLE-touching supports count: {len(supports)}")
print(f"same-lexical-form-support-v1 count: {methods.get(method_same, 0)}")
print(f"multiword-component-support-v1 count: {methods.get(method_mwe, 0)}")
print(f"unlabeled YLE-touching support count: {unlabeled}")
print(f"prerequisite_for count: {prereq}")

if prereq != 0:
    errors.append(f"prerequisite_for count must be 0, found {prereq}")
if unlabeled:
    errors.append(f"YLE-touching supports lack derivation method labels: {unlabeled}")
if methods.get(method_same, 0) < 1 or methods.get(method_mwe, 0) < 1:
    errors.append("both support derivation methods must appear in live YLE-touching edges")
# Live totals should match Phase 1 snapshot labels when present.
if scope_path.is_file():
    scope = scope_path.read_text(encoding="utf-8")
    for label, value in (
        ("YLE-touching supports count", len(supports)),
        ("prerequisite_for count", prereq),
    ):
        m = re.search(rf"{re.escape(label)}:\s*(\d+)", scope)
        if m and int(m.group(1)) != value:
            errors.append(f"phase1-scope {label} {m.group(1)} != live graph {value}")
if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
PY
)"
graph_status=$?
printf '%s\n' "$graph_output"
if [[ "$graph_status" -ne 0 ]]; then
  fail "live graph support/prereq scan failed"
else
  pass "live graph has labeled YLE-touching supports and prerequisite_for count: 0"
fi

echo "=== support inventory artifact exists with labeled method counts matching the live graph ==="
inventory_output="$(python3 - "$GRAPH" "$INVENTORY" "$METHOD_SAME" "$METHOD_MWE" <<'PY'
import json
import sys
from collections import Counter
from pathlib import Path

graph_path, inv_path = map(Path, sys.argv[1:3])
method_same, method_mwe = sys.argv[3:5]
errors = []
YLE = {"pre-a1-starters", "a1-movers", "a2-flyers"}

if not inv_path.is_file():
    errors.append(f"missing support inventory: {inv_path}")
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)

inv = json.loads(inv_path.read_text(encoding="utf-8"))
graph = json.loads(graph_path.read_text(encoding="utf-8"))
yle_skill_ids = {
    node["id"]
    for node in graph.get("nodes", [])
    if node.get("kind") == "skill"
    and YLE.intersection(node.get("metadata", {}).get("examAlignments", []))
}
live = [
    edge
    for edge in graph.get("edges", [])
    if edge.get("type") == "supports"
    and (edge.get("sourceId") in yle_skill_ids or edge.get("targetId") in yle_skill_ids)
]
live_methods = Counter()
for edge in live:
    for ref in edge.get("sourceRefs") or []:
        live_methods[ref] += 1

required = (
    "generated_at",
    "yle_skill_count",
    "yle_touching_supports_count",
    "methods",
    "prerequisite_for_count",
    "classification",
)
for field in required:
    if field not in inv:
        errors.append(f"inventory lacks {field}")

print(f"Inventory YLE-touching supports count: {inv.get('yle_touching_supports_count')}")
print(f"Inventory prerequisite_for count: {inv.get('prerequisite_for_count')}")

if inv.get("yle_touching_supports_count") != len(live):
    errors.append(
        f"inventory yle_touching_supports_count {inv.get('yle_touching_supports_count')} != live {len(live)}"
    )
if inv.get("prerequisite_for_count") != 0:
    errors.append("inventory prerequisite_for_count must be 0")
if inv.get("yle_skill_count") != len(yle_skill_ids):
    errors.append(
        f"inventory yle_skill_count {inv.get('yle_skill_count')} != live {len(yle_skill_ids)}"
    )
methods = inv.get("methods")
if not isinstance(methods, dict):
    errors.append("inventory methods must be an object of labeled counts")
else:
    for method, live_count in ((method_same, live_methods[method_same]), (method_mwe, live_methods[method_mwe])):
        entry = methods.get(method)
        if not isinstance(entry, dict):
            errors.append(f"inventory methods.{method} missing object")
            continue
        if entry.get("count") != live_count:
            errors.append(f"inventory {method} count {entry.get('count')} != live {live_count}")
        if entry.get("label") != method:
            errors.append(f"inventory {method} lacks exact label field")
        if entry.get("classification") != "derived support signal":
            errors.append(f"inventory {method} classification is not 'derived support signal'")
if inv.get("classification") != "derived support signal":
    errors.append("inventory top-level classification must remain 'derived support signal'")
hard = inv.get("hard_gate_policy")
if not isinstance(hard, str) or "never" not in hard.lower() or "prerequisite" not in hard.lower():
    errors.append("inventory hard_gate_policy must forbid treating supports as prerequisites")

if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
PY
)"
inventory_status=$?
printf '%s\n' "$inventory_output"
if [[ "$inventory_status" -ne 0 ]]; then
  fail "support inventory missing, unlabeled, or mismatched vs live graph"
else
  pass "support inventory has labeled method counts matching the live graph"
fi

echo "=== stratified review queue covers both derivation methods ==="
queue_output="$(python3 - "$GRAPH" "$QUEUE" "$METHOD_SAME" "$METHOD_MWE" <<'PY'
import json
import sys
from collections import Counter
from pathlib import Path

graph_path, queue_path = map(Path, sys.argv[1:3])
method_same, method_mwe = sys.argv[3:5]
errors = []
YLE = {"pre-a1-starters", "a1-movers", "a2-flyers"}

if not queue_path.is_file():
    errors.append(f"missing support review queue: {queue_path}")
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)

rows = []
for line_number, line in enumerate(queue_path.read_text(encoding="utf-8").splitlines(), 1):
    if not line.strip():
        continue
    try:
        rows.append(json.loads(line))
    except json.JSONDecodeError as exc:
        errors.append(f"queue line {line_number} invalid JSON: {exc}")

graph = json.loads(graph_path.read_text(encoding="utf-8"))
edge_by_id = {edge["id"]: edge for edge in graph.get("edges", []) if edge.get("type") == "supports"}
yle_skill_ids = {
    node["id"]
    for node in graph.get("nodes", [])
    if node.get("kind") == "skill"
    and YLE.intersection(node.get("metadata", {}).get("examAlignments", []))
}

method_counts = Counter()
seen = set()
for row in rows:
    edge_id = row.get("edge_id")
    method = row.get("derivation_method")
    if edge_id in seen:
        errors.append(f"duplicate queue edge_id: {edge_id}")
    seen.add(edge_id)
    edge = edge_by_id.get(edge_id)
    if edge is None:
        errors.append(f"queue edge_id not a supports edge: {edge_id}")
        continue
    if edge.get("sourceId") not in yle_skill_ids and edge.get("targetId") not in yle_skill_ids:
        errors.append(f"queue edge is not YLE-touching: {edge_id}")
    refs = edge.get("sourceRefs") or []
    if method not in refs:
        errors.append(f"queue derivation_method {method} not on edge {edge_id}")
    method_counts[method] += 1
    for field in ("stratum", "source_id", "target_id", "sample_role"):
        if field not in row:
            errors.append(f"queue row {edge_id} lacks {field}")

print(f"Support review queue size: {len(rows)}")
print(f"Queue same-lexical-form sample count: {method_counts.get(method_same, 0)}")
print(f"Queue multiword-component sample count: {method_counts.get(method_mwe, 0)}")

if method_counts.get(method_same, 0) < 25:
    errors.append(f"same-lexical-form sample must be at least 25, found {method_counts.get(method_same, 0)}")
if method_counts.get(method_mwe, 0) < 25:
    errors.append(f"multiword-component sample must be at least 25, found {method_counts.get(method_mwe, 0)}")
if len(rows) < 50:
    errors.append(f"combined stratified sample must be at least 50, found {len(rows)}")

if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
PY
)"
queue_status=$?
printf '%s\n' "$queue_output"
if [[ "$queue_status" -ne 0 ]]; then
  fail "stratified support review queue missing or incomplete"
else
  pass "stratified support review queue covers both derivation methods"
fi

echo "=== every YLE-touching derivation method has a durable class disposition ==="
disp_output="$(python3 - "$DISPOSITIONS" "$SAMPLE_DECISIONS" "$QUEUE" "$METHOD_SAME" "$METHOD_MWE" <<'PY'
import json
import re
import sys
from pathlib import Path

disp_path, sample_path, queue_path = map(Path, sys.argv[1:4])
method_same, method_mwe = sys.argv[4:6]
errors = []
required_methods = {method_same, method_mwe}

if not disp_path.is_file():
    errors.append(f"missing support-class-dispositions: {disp_path}")
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)

disp = json.loads(disp_path.read_text(encoding="utf-8"))
classes = disp.get("classes")
if not isinstance(classes, list):
    errors.append("dispositions.classes must be a list")
    classes = []
by_method = {}
for row in classes:
    method = row.get("derivation_method")
    by_method[method] = row
    for field in (
        "decision_id",
        "status",
        "reviewer_role",
        "reviewed_at",
        "finding_class",
        "disposition",
        "mandatory_gate",
        "evidence",
    ):
        if field not in row:
            errors.append(f"class disposition for {method} lacks {field}")
    if row.get("finding_class") != "support":
        errors.append(f"class disposition for {method} finding_class must be support")
    if row.get("mandatory_gate") is not False:
        errors.append(f"class disposition for {method} must set mandatory_gate false")
    text = f"{row.get('disposition', '')} {row.get('evidence', '')}".lower()
    if "prerequisite" in text and "not" not in text and "never" not in text and "optional" not in text:
        # Require explicit non-hard-gate language.
        if "hard" not in text and "optional" not in text and "never" not in text:
            errors.append(f"class disposition for {method} lacks non-mandatory language")
    if row.get("status") not in {"accepted", "quarantined", "rejected"}:
        errors.append(f"class disposition for {method} status must be closed")
    # Forbid documenting support as a hard gate. Negated phrasing
    # ("never a hard prerequisite") is allowed and expected.
    disposition = str(row.get("disposition", "")).lower()
    positive_hard = re.search(
        r"(?<!\bnever a )(?<!\bnever an )(?<!\bnot a )(?<!\bnot an )"
        r"(?<!\bno )hard prerequisite|(?<!\bnever )required for readiness",
        disposition,
    )
    if positive_hard and not re.search(
        r"never (a |an )?hard prerequisite|not (a |an )?hard prerequisite|"
        r"never required for readiness|not required for readiness",
        disposition,
    ):
        errors.append(f"class disposition for {method} treats support as a hard gate")
    if row.get("consumer_use") not in {
        "optional_readiness_or_ranking_signal",
        "quarantined",
        "rejected",
    }:
        errors.append(f"class disposition for {method} consumer_use is not an allowed non-hard value")

for method in required_methods:
    if method not in by_method:
        errors.append(f"missing class disposition for {method}")

print(f"Class disposition count: {len(classes)}")
for method in sorted(required_methods):
    row = by_method.get(method) or {}
    print(f"Disposition {method}: {row.get('status')} mandatory_gate={row.get('mandatory_gate')}")

# Sample decisions must cover the queue and remain non-mandatory.
if not sample_path.is_file():
    errors.append(f"missing support-sample-decisions: {sample_path}")
else:
    samples = [json.loads(line) for line in sample_path.read_text(encoding="utf-8").splitlines() if line.strip()]
    queue = [json.loads(line) for line in queue_path.read_text(encoding="utf-8").splitlines() if line.strip()] if queue_path.is_file() else []
    queue_ids = {row.get("edge_id") for row in queue}
    sample_ids = {row.get("edge_id") for row in samples}
    if not queue_ids.issubset(sample_ids):
        missing = sorted(queue_ids - sample_ids)[:5]
        errors.append(f"sample decisions miss queue edge_ids (examples: {missing})")
    for row in samples:
        if row.get("finding_class") != "support":
            errors.append(f"sample {row.get('decision_id')} finding_class must be support")
        if row.get("mandatory_gate") is not False:
            errors.append(f"sample {row.get('decision_id')} must set mandatory_gate false")
        if row.get("status") not in {"accepted", "quarantined", "rejected", "demoted"}:
            errors.append(f"sample {row.get('decision_id')} status not closed: {row.get('status')}")
        if not row.get("disposition"):
            errors.append(f"sample {row.get('decision_id')} lacks disposition")
    print(f"Sample support decision count: {len(samples)}")

if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
PY
)"
disp_status=$?
printf '%s\n' "$disp_output"
if [[ "$disp_status" -ne 0 ]]; then
  fail "support class/sample dispositions missing, unlabeled, or hard-gating"
else
  pass "every YLE-touching support derivation method has a non-mandatory durable disposition"
fi

echo "=== progression policy forbids hard gates and invented prerequisite_for ==="
prog_output="$(python3 - "$PROGRESSION" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
errors = []
if not path.is_file():
    errors.append(f"missing progression policy: {path}")
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)

text = path.read_text(encoding="utf-8")
print(f"Progression policy bytes: {len(text.encode('utf-8'))}")

required_phrases = [
    (r"learner state", "learner state"),
    (r"stage goal|stage goals|current stage", "stage goals"),
    (r"\bSRS\b|spaced repetition", "SRS"),
    (r"topic|group", "groups/topics"),
    (r"utility|optional ranking|optional utility", "optional utility/ranking"),
    (r"prerequisite_for", "prerequisite_for"),
    (r"never|must not|forbidden|prohibit", "prohibition language"),
    (r"supports?\b", "supports"),
    (r"not (a |an )?hard|never (a |an )?hard|optional signal|non-mandatory", "non-hard-gate language"),
]
lower = text.lower()
for pattern, label in required_phrases:
    if not re.search(pattern, text, re.I):
        errors.append(f"progression policy lacks {label}")

# Explicit ban on inventing prerequisites from support/CEFR/order.
if not re.search(r"prerequisite_for.{0,80}(0|zero|none|never|forbid|prohibit)", text, re.I | re.S):
    if "prerequisite_for count: 0" not in lower and "zero `prerequisite_for`" not in lower and "no `prerequisite_for`" not in lower:
        if not re.search(r"(never|must not|do not).{0,40}prerequisite_for", text, re.I):
            errors.append("progression policy must explicitly forbid inventing prerequisite_for")

# Allow explicit bans ("no support edge is required for readiness"); fail only
# when support is asserted as required without a never/not/no negation nearby.
for match in re.finditer(r"support.{0,60}required for readiness", text, re.I | re.S):
    start = max(0, match.start() - 40)
    window = text[start:match.end()].lower()
    if not re.search(r"\b(never|not|no)\b", window):
        errors.append("progression policy documents support as required readiness without override")
        break

if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
print("Progression policy hard-gate ban: present")
PY
)"
prog_status=$?
printf '%s\n' "$prog_output"
if [[ "$prog_status" -ne 0 ]]; then
  fail "progression policy missing or allows hard gates / invented prerequisites"
else
  pass "progression policy forbids hard gates and invented prerequisite_for"
fi

echo "=== relationship audit report labeled metrics and honesty ==="
report_output="$(python3 - "$REPORT" "$REPORT_MD" "$INVENTORY" "$DISPOSITIONS" "$METHOD_SAME" "$METHOD_MWE" <<'PY'
import json
import sys
from pathlib import Path

report_path, report_md_path, inv_path, disp_path = map(Path, sys.argv[1:5])
method_same, method_mwe = sys.argv[5:7]
errors = []

if not report_path.is_file():
    errors.append(f"missing relationship audit report: {report_path}")
if not report_md_path.is_file():
    errors.append(f"missing relationship audit markdown: {report_md_path}")
if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)

report = json.loads(report_path.read_text(encoding="utf-8"))
md = report_md_path.read_text(encoding="utf-8")
inv = json.loads(inv_path.read_text(encoding="utf-8")) if inv_path.is_file() else {}
disp = json.loads(disp_path.read_text(encoding="utf-8")) if disp_path.is_file() else {}

for label in (
    "YLE-touching supports count",
    "same-lexical-form-support-v1 count",
    "multiword-component-support-v1 count",
    "prerequisite_for count",
):
    if f"{label}:" not in md and f"**{label.split()[-1]}**" not in md:
        # Prefer exact labeled lines in markdown.
        if label not in md:
            errors.append(f"markdown report lacks labeled metric: {label}")

metrics = report.get("metrics")
if not isinstance(metrics, dict):
    errors.append("report.metrics must be an object of labeled metrics")
else:
    for key, label in (
        ("yle_touching_supports_count", "YLE-touching supports count"),
        ("same_lexical_form_count", "same-lexical-form-support-v1 count"),
        ("multiword_component_count", "multiword-component-support-v1 count"),
        ("prerequisite_for_count", "prerequisite_for count"),
    ):
        entry = metrics.get(key)
        if not isinstance(entry, dict) or entry.get("label") != label:
            errors.append(f"report metric {key} lacks exact label {label!r}")
        elif key == "prerequisite_for_count" and entry.get("value") != 0:
            errors.append("report prerequisite_for count must be 0")

if report.get("hard_gate_from_supports") is not False:
    errors.append("report must set hard_gate_from_supports false")
if report.get("curriculum_signoff") not in {"pending", "open", False, None}:
    # Must not claim curriculum approval without phase3-approval.md (checked separately).
    if report.get("curriculum_signoff") is True:
        errors.append("report claims curriculum_signoff true without separate approval artifact check")

print(f"Report metric keys: {sorted((report.get('metrics') or {}).keys())}")
print(f"Report hard_gate_from_supports: {report.get('hard_gate_from_supports')}")

if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
PY
)"
report_status=$?
printf '%s\n' "$report_output"
if [[ "$report_status" -ne 0 ]]; then
  fail "relationship audit report missing labeled metrics or overclaims"
else
  pass "relationship audit report carries labeled metrics and non-hard-gate honesty"
fi

echo "=== curriculum relationship sign-off remains an attributable human gate ==="
approval_output="$(python3 - "$APPROVAL" "$PLAN" <<'PY'
import re
import sys
from pathlib import Path

approval_path, plan_path = map(Path, sys.argv[1:])
errors = []
marker = None
plan = plan_path.read_text(encoding="utf-8") if plan_path.is_file() else ""
phase_matches = list(re.finditer(r"^## Phase 3: Relationship And Progression Review[ \t]*$", plan, re.M))
next_matches = list(re.finditer(r"^## Phase 4: Consumption And Next-Step Contract[ \t]*$", plan, re.M))
phase = ""
if phase_matches and next_matches and next_matches[0].start() > phase_matches[0].end():
    phase = plan[phase_matches[0].end():next_matches[0].start()]
markers = re.findall(
    r"^- \[([~xb])\][ \t]+Task: Curriculum sign-off on relationships\b",
    phase,
    re.M,
)
if len(markers) != 1:
    errors.append("Phase 3 curriculum sign-off task marker is not unique")
else:
    marker = markers[0]
    if marker not in {"b", "x"}:
        errors.append("Phase 3 curriculum sign-off must be [b] or [x]")

if not approval_path.is_file():
    if not errors and marker == "b":
        print("Phase 3 curriculum approval artifact: absent (human gate still open)")
        raise SystemExit(0)
    if marker == "x":
        errors.append("Phase 3 curriculum approval is [x] but phase3-approval.md is absent")
    elif marker is not None:
        errors.append("approval artifact is absent and Phase 3 curriculum task is not the truthful [b] state")
else:
    text = approval_path.read_text(encoding="utf-8")
    if not re.search(r"\b(?:decision|recommendation)\s*:\s*(?:go|conditional-go)\b", text, re.I):
        errors.append("approval lacks go or conditional-go decision")
    if not re.search(r"curriculum[ /-]*language", text, re.I):
        errors.append("approval lacks curriculum/language owner role")
    if not re.search(r"\b(?:owner|reviewer|approved by)\s*:\s*[^\n]+", text, re.I):
        errors.append("approval lacks attributable owner/reviewer")
    if not re.search(r"\b20[0-9]{2}-[0-9]{2}-[0-9]{2}\b", text):
        errors.append("approval lacks ISO date")
    if marker == "b":
        errors.append("phase3-approval.md is present but plan still marks curriculum sign-off as [b]")
    print("Phase 3 curriculum approval artifact: present")

if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
PY
)"
approval_status=$?
printf '%s\n' "$approval_output"
if [[ "$approval_status" -ne 0 ]]; then
  fail "curriculum relationship sign-off gate is mis-marked or unattributable"
else
  pass "curriculum relationship sign-off remains an honest human gate"
fi

echo "=== generator syntax when present ==="
if [[ -f "$GENERATOR" ]]; then
  if python3 -m py_compile "$GENERATOR"; then
    pass "build-yle-relationship-audit.py compiles"
  else
    fail "build-yle-relationship-audit.py failed to compile"
  fi
else
  fail "missing relationship audit generator script"
fi

echo "=== results ==="
printf '%s\n' "${RESULTS[@]}"
echo "=== Total: $((PASS_COUNT + FAIL_COUNT)) checks (PASS=$PASS_COUNT, FAIL=$FAIL_COUNT) ==="
exit "$FAILED"
