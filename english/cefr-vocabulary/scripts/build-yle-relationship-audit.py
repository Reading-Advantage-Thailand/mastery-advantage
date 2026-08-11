#!/usr/bin/env python3
"""Build the one-time YLE 2025 relationship / support-signal audit package.

Scans the tracked knowledge-space for YLE-touching ``supports`` edges, emits a
labeled inventory by derivation method, a stratified review queue, class-level
dispositions, sample decisions, a progression policy, and a relationship audit
report. Does not invent ``prerequisite_for`` edges or rewrite the graph.

Artifacts are staged under ignored temporary storage and swapped atomically.
"""

from __future__ import annotations

import json
import os
import tempfile
from collections import Counter, defaultdict
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GRAPH = ROOT / "cefr-vocabulary-knowledge-space.json"
REVIEW = ROOT / "review/yle-2025"
REPORTS = ROOT / "reports"

METHOD_SAME = "same-lexical-form-support-v1"
METHOD_MWE = "multiword-component-support-v1"
YLE_EXAMS = ("pre-a1-starters", "a1-movers", "a2-flyers")
SAMPLE_PER_METHOD = 40
TODAY = date.today().isoformat()


def load_graph() -> dict:
    return json.loads(GRAPH.read_text(encoding="utf-8"))


def yle_skill_ids(graph: dict) -> set[str]:
    yle = set(YLE_EXAMS)
    return {
        node["id"]
        for node in graph.get("nodes", [])
        if node.get("kind") == "skill"
        and yle.intersection(node.get("metadata", {}).get("examAlignments", []))
    }


def method_of(edge: dict) -> str:
    refs = edge.get("sourceRefs") or []
    if not refs:
        return "<unlabeled>"
    # Support edges carry a single derivation method in sourceRefs.
    return str(refs[0])


def collect_yle_supports(graph: dict, skill_ids: set[str]) -> list[dict]:
    return [
        edge
        for edge in graph.get("edges", [])
        if edge.get("type") == "supports"
        and (edge.get("sourceId") in skill_ids or edge.get("targetId") in skill_ids)
    ]


def stratified_sample(edges: list[dict], per_method: int) -> list[dict]:
    by_method: dict[str, list[dict]] = defaultdict(list)
    for edge in edges:
        by_method[method_of(edge)].append(edge)
    sample: list[dict] = []
    for method in (METHOD_SAME, METHOD_MWE):
        pool = sorted(by_method.get(method, []), key=lambda e: e["id"])
        if not pool:
            continue
        n = min(per_method, len(pool))
        if n == 1:
            chosen = [pool[0]]
        else:
            # Evenly spaced deterministic sample across the sorted edge id space.
            chosen = [pool[round(i * (len(pool) - 1) / (n - 1))] for i in range(n)]
            # De-dupe while preserving order.
            seen: set[str] = set()
            unique = []
            for edge in chosen:
                if edge["id"] not in seen:
                    seen.add(edge["id"])
                    unique.append(edge)
            chosen = unique
        for index, edge in enumerate(chosen):
            sample.append(
                {
                    "edge_id": edge["id"],
                    "derivation_method": method,
                    "source_id": edge.get("sourceId"),
                    "target_id": edge.get("targetId"),
                    "stratum": method,
                    "sample_role": "stratified-primary",
                    "sample_index": index,
                    "weight": edge.get("weight"),
                    "confidence": edge.get("confidence"),
                    "rationale": edge.get("rationale"),
                    "metadata": edge.get("metadata") or {},
                }
            )
    return sample


def class_dispositions() -> dict:
    """Engineering audit dispositions for each derivation class.

    Curriculum/language acceptance remains the plan's separate human gate.
    """
    shared_consumer = "optional_readiness_or_ranking_signal"
    classes = [
        {
            "derivation_method": METHOD_SAME,
            "decision_id": "YLE-2025-SUPPORT-CLASS-SAME-FORM",
            "status": "accepted",
            "reviewer_role": "engineering audit",
            "reviewed_at": TODAY,
            "finding_class": "support",
            "finding": (
                "Same normalized lexical form with distinct POS uses is linked by "
                "bidirectional supports edges tagged same-lexical-form-support-v1."
            ),
            "evidence": (
                "Generator rule: every POS-variant pair for the same headword gets "
                "mutual supports edges (weight 0.7, medium confidence). Live YLE-touching "
                "count is inventoried; no edge is a hard readiness gate."
            ),
            "disposition": (
                "Promote as an optional readiness or ranking signal only. Knowledge of "
                "one POS use may help another, but mastery of one form+POS skill is never "
                "a hard prerequisite for another. Consumers must keep an override path via "
                "learner state and stage goals."
            ),
            "mandatory_gate": False,
            "consumer_use": shared_consumer,
            "supersedes": None,
            "superseded_by": None,
        },
        {
            "derivation_method": METHOD_MWE,
            "decision_id": "YLE-2025-SUPPORT-CLASS-MWE-COMPONENT",
            "status": "accepted",
            "reviewer_role": "engineering audit",
            "reviewed_at": TODAY,
            "finding_class": "support",
            "finding": (
                "Component tokens of multi-word expressions support the MWE skill via "
                "multiword-component-support-v1 edges when the component is not harder "
                "than the expression."
            ),
            "evidence": (
                "Generator rule: split MWE tokens, match single-token skills, add "
                "supports from component to expression (weight 0.6, medium confidence). "
                "Some components are high-frequency function words; signal strength is "
                "advisory only."
            ),
            "disposition": (
                "Promote as an optional readiness or ranking signal only. Component "
                "knowledge may inform MWE practice ranking but is never a hard "
                "prerequisite and must not block MWE introduction when stage goals or "
                "learner state say otherwise. Weak function-word supports remain accepted "
                "signals with low instructional weight."
            ),
            "mandatory_gate": False,
            "consumer_use": shared_consumer,
            "supersedes": None,
            "superseded_by": None,
        },
    ]
    return {
        "generated_at": TODAY,
        "scope": "YLE-touching supports derivation classes only",
        "mandatory_gate_policy": (
            "No supports edge or derivation class may be treated as a hard prerequisite "
            "or required readiness gate. prerequisite_for remains prohibited (count 0)."
        ),
        "curriculum_signoff": "pending",
        "classes": classes,
    }


def sample_decisions(queue: list[dict]) -> list[dict]:
    decisions = []
    for index, row in enumerate(queue, start=1):
        method = row["derivation_method"]
        if method == METHOD_SAME:
            disposition = (
                "Accept as optional same-form POS support signal; not a hard prerequisite."
            )
            finding = (
                "Same-form POS support edge is a derived medium-confidence signal between "
                "related form+POS skills."
            )
        else:
            component = (row.get("metadata") or {}).get("component")
            component_note = f' component="{component}"' if component else ""
            disposition = (
                "Accept as optional MWE-component support signal; not a hard prerequisite."
                + (f" Component token remains advisory{component_note}." if component else "")
            )
            finding = (
                "MWE component support edge is a derived medium-confidence signal from a "
                "component skill toward a multi-word expression skill."
            )
        decisions.append(
            {
                "decision_id": f"YLE-2025-SUPPORT-SAMPLE-{index:03d}",
                "edge_id": row["edge_id"],
                "derivation_method": method,
                "status": "accepted",
                "reviewer_role": "engineering audit",
                "reviewed_at": TODAY,
                "finding_class": "support",
                "finding": finding,
                "evidence": (
                    f"edge_id={row['edge_id']}; source={row['source_id']}; "
                    f"target={row['target_id']}; weight={row.get('weight')}; "
                    f"confidence={row.get('confidence')}"
                ),
                "disposition": disposition,
                "mandatory_gate": False,
                "graph_refs": [row["edge_id"], row["source_id"], row["target_id"]],
                "supersedes": None,
                "superseded_by": None,
            }
        )
    return decisions


def progression_policy_md() -> str:
    return f"""# YLE 2025 Progression And Next-Step Policy

**Status:** Engineering draft for the YLE baseline freeze. Curriculum/language
acceptance of relationship dispositions remains a separate human gate.
**Generated:** {TODAY}

## Purpose

Document how a consuming application may order or rank next vocabulary work
from the frozen YLE graph **without inventing hard prerequisites**.

## Hard Prohibitions

1. **`prerequisite_for` is forbidden** on the YLE freeze baseline.
   - Required guard: `prerequisite_for count: 0`.
   - Do not invent `prerequisite_for` edges from CEFR bands, topic order, unit
     numbers, frequency, embedding similarity, or `supports` signals.
2. **`supports` edges are never hard gates.**
   - Both `same-lexical-form-support-v1` and `multiword-component-support-v1`
     are **optional signals** for readiness hints or ranking only.
   - No support edge is **required for readiness**. Learners and teachers must
     retain an override path (explicit goals, teacher assignment, or free choice).
3. Cumulative exam expectations (Movers includes Starters; Flyers includes
   Starters + Movers) are a **consumption rule**, not duplicate membership or
   prerequisite edges.

## What Orders Next-Step Work

Next-step ranking for a YLE learner combines, in application state:

| Input | Lives in | Role |
|---|---|---|
| Stage goals (Starters / Movers / Flyers target) | learner / session state | Primary scope filter |
| Lower-level gaps (cumulative consumption) | derived from graph membership + mastery | Prefer unresolved earlier-stage items |
| SRS due work | learner card state | Time-sensitive reviews |
| Topic / group foci | graph topic groups + learner preference | Optional thematic concentration |
| Optional utility / ranking signals | app providers (frequency, supports, etc.) | Soft re-rank only |
| `supports` derived signals | graph `supports` edges | Optional readiness hint — never mandatory |

Static graph nodes must **not** store per-student fields (mastery, due dates,
review status). Those belong in learner state.

## Support-Signal Consumer Rules

- Label every support-backed recommendation as a **derived signal**, separate
  from source-backed exam membership facts.
- Same-form POS support may gently prefer practicing a related POS after one is
  known; it must not block introduction of the other POS.
- MWE component support may gently prefer components before or with an MWE; it
  must not require component mastery before the MWE appears in stage goals or
  reading targets.
- Function-word components (e.g. "of", "to") are especially low instructional
  weight even when an edge exists.

## Relationship To Later Phases

- Phase 4 documents the full static-graph vs learner-state consumption contract
  and explainability payloads.
- Phase 5 exercises reading-program matching against YLE `matchForms`.
- This policy is frozen with the YLE baseline only; A2 Key / B1 use the same
  method later under separate tracks.

## Honesty Note

This document is not curriculum approval of individual edges. Class and sample
dispositions under `review/yle-2025/` are engineering audit records; the plan's
curriculum relationship sign-off remains `[b]`.
"""


def build_inventory(skill_ids: set[str], supports: list[dict], prereq_count: int) -> dict:
    methods = Counter(method_of(edge) for edge in supports)
    method_objects = {}
    for method in (METHOD_SAME, METHOD_MWE):
        method_objects[method] = {
            "label": method,
            "count": methods.get(method, 0),
            "classification": "derived support signal",
            "mandatory_gate": False,
        }
    other = {k: v for k, v in methods.items() if k not in {METHOD_SAME, METHOD_MWE}}
    return {
        "generated_at": TODAY,
        "source_graph": "cefr-vocabulary-knowledge-space.json",
        "yle_skill_count": len(skill_ids),
        "yle_touching_supports_count": len(supports),
        "methods": method_objects,
        "other_method_counts": other,
        "prerequisite_for_count": prereq_count,
        "classification": "derived support signal",
        "hard_gate_policy": (
            "supports edges are never hard prerequisites; prerequisite_for remains "
            "prohibited with required count 0"
        ),
        "both_endpoints_yle_count": sum(
            1
            for edge in supports
            if edge.get("sourceId") in skill_ids and edge.get("targetId") in skill_ids
        ),
        "one_endpoint_yle_count": sum(
            1
            for edge in supports
            if (edge.get("sourceId") in skill_ids) ^ (edge.get("targetId") in skill_ids)
        ),
    }


def build_report(inventory: dict, queue: list[dict], dispositions: dict, samples: list[dict]) -> tuple[dict, str]:
    same_count = inventory["methods"][METHOD_SAME]["count"]
    mwe_count = inventory["methods"][METHOD_MWE]["count"]
    report = {
        "generated_at": TODAY,
        "scope": "YLE 2025 relationship and progression review",
        "metrics": {
            "yle_skill_count": {
                "label": "YLE skill count",
                "value": inventory["yle_skill_count"],
            },
            "yle_touching_supports_count": {
                "label": "YLE-touching supports count",
                "value": inventory["yle_touching_supports_count"],
            },
            "same_lexical_form_count": {
                "label": "same-lexical-form-support-v1 count",
                "value": same_count,
            },
            "multiword_component_count": {
                "label": "multiword-component-support-v1 count",
                "value": mwe_count,
            },
            "prerequisite_for_count": {
                "label": "prerequisite_for count",
                "value": inventory["prerequisite_for_count"],
            },
            "stratified_sample_size": {
                "label": "stratified support sample size",
                "value": len(queue),
            },
            "class_disposition_count": {
                "label": "support class disposition count",
                "value": len(dispositions.get("classes", [])),
            },
            "sample_decision_count": {
                "label": "support sample decision count",
                "value": len(samples),
            },
        },
        "hard_gate_from_supports": False,
        "curriculum_signoff": "pending",
        "method_dispositions": {
            row["derivation_method"]: {
                "status": row["status"],
                "mandatory_gate": row["mandatory_gate"],
                "consumer_use": row["consumer_use"],
                "decision_id": row["decision_id"],
            }
            for row in dispositions.get("classes", [])
        },
    }
    md = f"""# YLE 2025 Relationship Audit

- YLE skill count: **{inventory['yle_skill_count']}**.
- YLE-touching supports count: **{inventory['yle_touching_supports_count']}**.
- same-lexical-form-support-v1 count: **{same_count}**.
- multiword-component-support-v1 count: **{mwe_count}**.
- prerequisite_for count: **{inventory['prerequisite_for_count']}**.
- Stratified support sample size: **{len(queue)}** ({SAMPLE_PER_METHOD} per method when available).
- Support class disposition count: **{len(dispositions.get('classes', []))}**.
- Support sample decision count: **{len(samples)}**.

Both derivation classes are accepted as **optional readiness or ranking
signals only**. No support edge is a hard prerequisite. The freeze baseline
keeps `prerequisite_for count: 0`.

Curriculum/language acceptance of relationship dispositions remains the plan's
separate human gate (`phase3-approval.md` is not fabricated here).

Progression policy: see `review/yle-2025/progression-policy.md`.
"""
    return report, md


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def write_jsonl(path: Path, rows: list[dict]) -> None:
    body = "".join(json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n" for row in rows)
    path.write_text(body, encoding="utf-8")


def atomic_publish(staged: dict[Path, Path]) -> None:
    for final_path, temp_path in staged.items():
        final_path.parent.mkdir(parents=True, exist_ok=True)
        os.replace(temp_path, final_path)


def main() -> int:
    graph = load_graph()
    skill_ids = yle_skill_ids(graph)
    supports = collect_yle_supports(graph, skill_ids)
    prereq_count = sum(1 for edge in graph.get("edges", []) if edge.get("type") == "prerequisite_for")
    if prereq_count != 0:
        raise SystemExit(f"refusing to publish: prerequisite_for count is {prereq_count}, required 0")

    inventory = build_inventory(skill_ids, supports, prereq_count)
    queue = stratified_sample(supports, SAMPLE_PER_METHOD)
    dispositions = class_dispositions()
    samples = sample_decisions(queue)
    report, report_md = build_report(inventory, queue, dispositions, samples)
    policy = progression_policy_md()

    targets = {
        REVIEW / "support-inventory.json": inventory,
        REVIEW / "support-class-dispositions.json": dispositions,
        REPORTS / "yle-relationship-audit.json": report,
    }
    jsonl_targets = {
        REVIEW / "support-review-queue.jsonl": queue,
        REVIEW / "support-sample-decisions.jsonl": samples,
    }
    text_targets = {
        REVIEW / "progression-policy.md": policy,
        REPORTS / "yle-relationship-audit.md": report_md,
    }

    staged: dict[Path, Path] = {}
    with tempfile.TemporaryDirectory(prefix="yle-p3-audit.") as tmp:
        tmp_path = Path(tmp)
        for final_path, value in targets.items():
            temp = tmp_path / final_path.name
            write_json(temp, value)
            staged[final_path] = temp
        for final_path, rows in jsonl_targets.items():
            temp = tmp_path / final_path.name
            write_jsonl(temp, rows)
            staged[final_path] = temp
        for final_path, text in text_targets.items():
            temp = tmp_path / final_path.name
            temp.write_text(text, encoding="utf-8")
            staged[final_path] = temp

        # Copy staged files out before TemporaryDirectory cleans up: write to
        # sibling temps under the real parents, then replace.
        publish: dict[Path, Path] = {}
        for final_path, temp in staged.items():
            final_path.parent.mkdir(parents=True, exist_ok=True)
            fd, name = tempfile.mkstemp(
                prefix=final_path.name + ".",
                dir=str(final_path.parent),
            )
            os.close(fd)
            dest = Path(name)
            dest.write_bytes(temp.read_bytes())
            publish[final_path] = dest
        atomic_publish(publish)

    print(f"YLE skill count: {inventory['yle_skill_count']}")
    print(f"YLE-touching supports count: {inventory['yle_touching_supports_count']}")
    print(f"same-lexical-form-support-v1 count: {same_count if (same_count := inventory['methods'][METHOD_SAME]['count']) else 0}")
    print(f"multiword-component-support-v1 count: {inventory['methods'][METHOD_MWE]['count']}")
    print(f"prerequisite_for count: {prereq_count}")
    print(f"Stratified support sample size: {len(queue)}")
    print(f"Class disposition count: {len(dispositions['classes'])}")
    print(f"Sample decision count: {len(samples)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
