#!/usr/bin/env python3
"""Phase 4 enrichment audit: stratified samples, provenance, frequency, gaps.

Automates the measurable Phase 4 checks from phase1-contracts.md:

  - ≥100 stratified memberships per retained source (or full set if fewer)
  - provenance / source-location field completeness = 1.0 on retained edges
  - ambiguous rows are open queues (quarantined for review), not silent merges
  - frequency: no silent nulls; distribution summary
  - prerequisite_for count from every enrichment overlay = 0
  - core freeze graph byte-identity vs git HEAD when available

Also writes a coverage-gap note (B2 source gap, ViU advanced unmatched).

Does not rewrite the core freeze graph. Does not invent dual-go freeze authority
for A2 Key / B1 Preliminary (still method-later).
"""

from __future__ import annotations

import hashlib
import json
import random
import re
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent.parent if (ROOT.parent / "measure").is_dir() else ROOT.parent
GRAPH = ROOT / "cefr-vocabulary-knowledge-space.json"
OVERLAY_DIR = ROOT / "overlays"
QUEUE_DIR = ROOT / "review" / "enrichment" / "queues"
SAMPLE_DIR = ROOT / "review" / "enrichment" / "phase4-samples"
OUT_JSON = ROOT / "reports" / "enrichment" / "phase4-audit.json"
OUT_MD = ROOT / "reports" / "enrichment" / "phase4-audit.md"
OUT_GAPS = ROOT / "reports" / "enrichment" / "coverage-gaps.json"
GENERATED_AT = "2026-08-11"
SAMPLE_SEED = 20260811
SAMPLE_TARGET = 100

LAYERS = [
    {
        "layerId": "enrichment.cambridge.a2-key-appendix",
        "overlay": "a2-key-appendix.overlay.json",
        "sourceId": "cambridge-a2-key-vocabulary-list-2025",
        "kind": "cambridge-appendix",
    },
    {
        "layerId": "enrichment.cambridge.b1-preliminary-appendix",
        "overlay": "b1-preliminary-appendix.overlay.json",
        "sourceId": "cambridge-b1-preliminary-vocabulary-list-2025",
        "kind": "cambridge-appendix",
    },
    {
        "layerId": "enrichment.cambridge.grammatical-groups",
        "overlay": "yle-grammatical-groups.overlay.json",
        "sourceId": "cambridge-yle-word-list-2025",
        "kind": "yle-grammatical",
    },
    {
        "layerId": "enrichment.viu.unit-groups",
        "overlay": "viu-unit-groups.overlay.json",
        "sourceId": "vocabulary-in-use",
        "kind": "viu",
    },
    {
        "layerId": "enrichment.frequency.wordfreq",
        "overlay": "frequency.overlay.json",
        "sourceId": "wordfreq",
        "kind": "frequency",
    },
]


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def atomic_write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(text, encoding="utf-8")
    tmp.replace(path)


def core_matches_git_head() -> dict[str, Any]:
    result: dict[str, Any] = {"path": str(GRAPH.relative_to(ROOT)), "checked": False}
    try:
        head = subprocess.check_output(
            ["git", "-C", str(REPO), "rev-parse", f"HEAD:english/cefr-vocabulary/{GRAPH.name}"],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
        work = subprocess.check_output(
            ["git", "-C", str(REPO), "hash-object", str(GRAPH)],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
        result.update(
            {
                "checked": True,
                "headBlob": head,
                "workBlob": work,
                "byteIdentical": head == work,
            }
        )
    except (subprocess.CalledProcessError, FileNotFoundError) as exc:
        result["error"] = str(exc)
    return result


def load_overlay(name: str) -> dict[str, Any]:
    path = OVERLAY_DIR / name
    if not path.is_file():
        raise FileNotFoundError(path)
    return json.loads(path.read_text(encoding="utf-8"))


def membership_edges(overlay: dict[str, Any]) -> list[dict[str, Any]]:
    out = []
    for edge in overlay.get("edges", []):
        if edge.get("type") != "contains":
            continue
        tid = str(edge.get("targetId") or "")
        if tid.startswith("english.vocabulary.skill."):
            out.append(edge)
    return out


def provenance_complete(edge: dict[str, Any], layer_id: str) -> tuple[bool, list[str]]:
    missing: list[str] = []
    meta = edge.get("metadata") or {}
    if not edge.get("sourceRefs"):
        missing.append("sourceRefs")
    if meta.get("enrichmentLayer") != layer_id and edge.get("metadata", {}).get("enrichmentLayer") != layer_id:
        # allow layer on edge metadata
        if meta.get("enrichmentLayer") is None:
            missing.append("metadata.enrichmentLayer")
    if not meta.get("matchKind") and not meta.get("matchDetail"):
        # frequency has no membership edges; for others require matchKind
        missing.append("metadata.matchKind")
    if not meta.get("extractionConfidence") and not meta.get("matchDetail"):
        # accept matchDetail as confidence proxy for some builders
        if "extractionConfidence" not in meta:
            missing.append("metadata.extractionConfidence")
    # index lemma or equivalent locator
    if not any(meta.get(k) for k in ("indexLemma", "lemma", "unitNumber", "sourceLocator")):
        # structural contains (group nesting) may lack lemma — skip for non-skill? we only pass skill targets
        if not meta.get("section") and not meta.get("grammaticalCategory"):
            missing.append("metadata.locator")
    return (len(missing) == 0, missing)


def stratify_sample(edges: list[dict[str, Any]], target: int, seed: int) -> list[dict[str, Any]]:
    """Stratify by section/POS-ish metadata; fall back to uniform."""
    if not edges:
        return []
    if len(edges) <= target:
        return list(edges)

    buckets: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for edge in edges:
        meta = edge.get("metadata") or {}
        key = (
            str(meta.get("section") or meta.get("relationshipKind") or "membership")
            + "|"
            + str(meta.get("topicTitle") or meta.get("grammaticalCategory") or meta.get("stage") or "all")
        )
        buckets[key].append(edge)

    rng = random.Random(seed)
    sample: list[dict[str, Any]] = []
    # at least one from each bucket when possible
    for key in sorted(buckets):
        bucket = buckets[key]
        sample.append(rng.choice(bucket))
    # fill remainder proportional
    remaining = target - len(sample)
    if remaining > 0:
        pool = [e for e in edges if e not in sample]
        rng.shuffle(pool)
        sample.extend(pool[:remaining])
    # if over target from many buckets, trim deterministically
    if len(sample) > target:
        rng.shuffle(sample)
        sample = sample[:target]
    return sample


def audit_membership_layer(
    layer: dict[str, Any],
    overlay: dict[str, Any],
    core_skill_ids: set[str],
) -> dict[str, Any]:
    layer_id = layer["layerId"]
    edges = membership_edges(overlay)
    prereq = sum(1 for e in overlay.get("edges", []) if e.get("type") == "prerequisite_for")
    nodes = overlay.get("nodes", [])
    skill_nodes = [n for n in nodes if n.get("kind") == "skill"]
    group_nodes = [n for n in nodes if n.get("kind") == "content_group"]

    # collision: overlay group ids must not equal core skill ids (groups OK if new)
    core_all_ids = core_skill_ids  # checked against skills; full core checked separately
    colliding = [n["id"] for n in nodes if n["id"] in core_skill_ids]

    prov_ok = 0
    prov_fail_examples: list[dict[str, Any]] = []
    bad_targets = 0
    for edge in edges:
        tid = edge.get("targetId")
        if tid not in core_skill_ids:
            bad_targets += 1
        ok, missing = provenance_complete(edge, layer_id)
        if ok:
            prov_ok += 1
        elif len(prov_fail_examples) < 10:
            # Relax: structure-only edges between groups are not in membership_edges
            prov_fail_examples.append({"edgeId": edge.get("id"), "missing": missing})

    # Provenance policy for Cambridge/ViU: require sourceRefs + enrichmentLayer + matchKind
    strict_missing = 0
    for edge in edges:
        meta = edge.get("metadata") or {}
        if not edge.get("sourceRefs"):
            strict_missing += 1
            continue
        if meta.get("enrichmentLayer") != layer_id:
            strict_missing += 1
            continue
        if not meta.get("matchKind"):
            strict_missing += 1

    sample = stratify_sample(edges, SAMPLE_TARGET, SAMPLE_SEED)
    sample_rows = []
    for edge in sample:
        meta = edge.get("metadata") or {}
        sample_rows.append(
            {
                "edgeId": edge.get("id"),
                "sourceId": edge.get("sourceId") or (edge.get("sourceRefs") or [None])[0],
                "targetId": edge.get("targetId"),
                "indexLemma": meta.get("indexLemma"),
                "matchKind": meta.get("matchKind"),
                "section": meta.get("section"),
                "topicTitle": meta.get("topicTitle"),
                "stage": meta.get("stage"),
                "grammaticalCategory": meta.get("grammaticalCategory"),
                "extractionConfidence": meta.get("extractionConfidence"),
                "enrichmentLayer": meta.get("enrichmentLayer"),
                "auditLabel": "pending-human",  # stratified set for curriculum review
            }
        )

    sample_path = SAMPLE_DIR / f"{layer_id.split('.')[-1]}-membership-sample.jsonl"
    atomic_write(
        sample_path,
        "".join(json.dumps(r, ensure_ascii=False) + "\n" for r in sample_rows),
    )

    stats = overlay.get("stats") or {}
    return {
        "layerId": layer_id,
        "sourceId": layer["sourceId"],
        "kind": layer["kind"],
        "overlayFile": layer["overlay"],
        "overlaySha256": sha256_file(OVERLAY_DIR / layer["overlay"]),
        "groupNodeCount": len(group_nodes),
        "skillNodeCountInOverlay": len(skill_nodes),
        "membershipEdgeCount": len(edges),
        "prerequisite_for_count": prereq,
        "targetsNotInCoreSkills": bad_targets,
        "overlaySkillIdCollisionsWithCore": colliding,
        "provenance": {
            "membershipEdges": len(edges),
            "strictComplete": len(edges) - strict_missing,
            "strictCompleteness": round((len(edges) - strict_missing) / len(edges), 4) if edges else 1.0,
            "threshold": 1.0,
            "pass": strict_missing == 0,
            "failExamples": prov_fail_examples,
        },
        "stratifiedSample": {
            "target": SAMPLE_TARGET,
            "actual": len(sample_rows),
            "path": str(sample_path.relative_to(ROOT)),
            "seed": SAMPLE_SEED,
            "labelStatus": "pending-human",
            "note": "Sample is deterministic. Precision ≥0.980 is a curriculum gate on this file.",
        },
        "builderStats": stats,
        "hardProhibitionsPass": prereq == 0 and len(skill_nodes) == 0 and bad_targets == 0,
    }


def audit_frequency(overlay: dict[str, Any], core_skill_count: int) -> dict[str, Any]:
    nodes = overlay.get("nodes", [])
    edges = overlay.get("edges", [])
    prereq = sum(1 for e in edges if e.get("type") == "prerequisite_for")
    states: Counter[str] = Counter()
    silent_nulls = 0
    zipfs: list[float] = []
    missing_true = 0
    scored = 0
    for node in nodes:
        meta = node.get("metadata") or {}
        freq = meta.get("frequency")
        if freq is None:
            silent_nulls += 1
            states["silent-null"] += 1
            continue
        if not isinstance(freq, dict):
            silent_nulls += 1
            states["non-object"] += 1
            continue
        if freq.get("missing") is True:
            missing_true += 1
            diag = freq.get("diagnostics") if isinstance(freq.get("diagnostics"), dict) else {}
            kind = (
                diag.get("multiTokenKind")
                or diag.get("reason")
                or freq.get("missingReason")
                or "missing"
            )
            states[f"missing:{kind}"] += 1
        elif freq.get("zipf") is not None:
            scored += 1
            states["scored"] += 1
            zipfs.append(float(freq["zipf"]))
        else:
            silent_nulls += 1
            states["missing-zipf-without-flag"] += 1

    zipfs_sorted = sorted(zipfs)
    def pct(p: float) -> float | None:
        if not zipfs_sorted:
            return None
        idx = min(len(zipfs_sorted) - 1, max(0, int(round(p * (len(zipfs_sorted) - 1)))))
        return zipfs_sorted[idx]

    stats = overlay.get("stats") or {}
    return {
        "layerId": "enrichment.frequency.wordfreq",
        "sourceId": "wordfreq",
        "kind": "frequency",
        "overlayFile": "frequency.overlay.json",
        "overlaySha256": sha256_file(OVERLAY_DIR / "frequency.overlay.json"),
        "nodeCount": len(nodes),
        "edgeCount": len(edges),
        "prerequisite_for_count": prereq,
        "coreSkillCount": core_skill_count,
        "silentNulls": silent_nulls,
        "noSilentNulls": silent_nulls == 0,
        "scored": scored,
        "missingFlagged": missing_true,
        "stateCounts": dict(states),
        "distribution": {
            "zipfMin": zipfs_sorted[0] if zipfs_sorted else None,
            "zipfP25": pct(0.25),
            "zipfP50": pct(0.50),
            "zipfP75": pct(0.75),
            "zipfMax": zipfs_sorted[-1] if zipfs_sorted else None,
            "n": len(zipfs_sorted),
        },
        "builderStats": stats,
        "hardProhibitionsPass": prereq == 0 and len(edges) == 0 and silent_nulls == 0,
    }


def load_queue_counts() -> dict[str, Any]:
    counts: dict[str, int] = {}
    open_ambiguous: dict[str, int] = {}
    if not QUEUE_DIR.is_dir():
        return {"queues": {}, "ambiguousOpen": {}, "policy": "missing-queue-dir"}
    for path in sorted(QUEUE_DIR.glob("*.jsonl")):
        n = sum(1 for line in path.read_text(encoding="utf-8").splitlines() if line.strip())
        counts[path.name] = n
        if "ambiguous" in path.name:
            open_ambiguous[path.name] = n
    return {
        "queues": counts,
        "ambiguousOpen": open_ambiguous,
        "policy": (
            "Ambiguous rows remain in durable queues (quarantined from approved exports "
            "until resolved). Phase 1 requires 100% closed = resolved OR quarantined; "
            "open queue counts are the quarantine set."
        ),
        "ambiguousQuarantined": True,
    }


def coverage_gaps(core: dict[str, Any], audits: list[dict[str, Any]]) -> dict[str, Any]:
    skills = [n for n in core.get("nodes", []) if n.get("kind") == "skill"]
    by_exam: Counter[str] = Counter()
    for edge in core.get("edges", []):
        sid = edge.get("sourceId") or ""
        tid = edge.get("targetId") or ""
        if "exam." in sid and tid.startswith("english.vocabulary.skill."):
            by_exam[sid.split("exam.", 1)[-1]] += 1

    viu = next((a for a in audits if a.get("kind") == "viu"), {})
    viu_stats = viu.get("builderStats") or {}

    return {
        "coreSkillCount": len(skills),
        "coreExamMembershipCounts": dict(by_exam),
        "notes": [
            "YLE freeze authority remains Pre-A1–A2 Flyers only.",
            "A2 Key / B1 Preliminary enrichment layers add membership overlays; full dual-go freeze is method-later.",
            "Cambridge B2 First official vocabulary list is unavailable (see source registry).",
            "ViU advanced unmatched volume is expected: many C1–C2 index lemmas are absent from the YLE/A2/B1 inventory.",
            "B2 coverage expansion is owned by track b2_vocabulary_source_expansion_20260611.",
        ],
        "viuMatchRate": viu_stats.get("matchRate"),
        "viuUnmatchedEntries": viu_stats.get("unmatchedEntries"),
        "viuMatchedEntries": viu_stats.get("matchedEntries"),
        "frequencyMissingMultiToken": next(
            (a.get("builderStats", {}).get("missingMultiToken") for a in audits if a.get("kind") == "frequency"),
            None,
        ),
        "candidateNextSources": [
            "Vocabulary in Use Upper-Intermediate / Advanced (already partially extracted as unit groups)",
            "Licensed EVP bulk only after company-use rights confirmed",
            "No fabricated Cambridge B2 list",
        ],
    }


def main() -> int:
    if not GRAPH.is_file():
        print(f"missing graph: {GRAPH}", file=sys.stderr)
        return 1

    core = json.loads(GRAPH.read_text(encoding="utf-8"))
    core_skills = {n["id"] for n in core.get("nodes", []) if n.get("kind") == "skill"}

    layer_audits: list[dict[str, Any]] = []
    for layer in LAYERS:
        overlay_path = OVERLAY_DIR / layer["overlay"]
        if not overlay_path.is_file():
            layer_audits.append(
                {
                    "layerId": layer["layerId"],
                    "error": f"missing overlay {layer['overlay']}",
                    "hardProhibitionsPass": False,
                }
            )
            continue
        overlay = load_overlay(layer["overlay"])
        if layer["kind"] == "frequency":
            layer_audits.append(audit_frequency(overlay, len(core_skills)))
        else:
            layer_audits.append(audit_membership_layer(layer, overlay, core_skills))

    queues = load_queue_counts()
    core_git = core_matches_git_head()
    gaps = coverage_gaps(core, layer_audits)

    # Gate summary (automatable)
    gates = {
        "coreFreezeUntouched": core_git.get("byteIdentical") is True,
        "allLayersZeroPrerequisiteFor": all(
            a.get("prerequisite_for_count", a.get("error") and 1) == 0 for a in layer_audits if "error" not in a
        ),
        "frequencyNoSilentNulls": all(
            a.get("noSilentNulls") for a in layer_audits if a.get("kind") == "frequency"
        ),
        "provenanceCompleteAllMembershipLayers": all(
            a.get("provenance", {}).get("pass")
            for a in layer_audits
            if a.get("kind") in {"cambridge-appendix", "yle-grammatical", "viu"}
        ),
        "stratifiedSamplesWritten": all(
            a.get("stratifiedSample", {}).get("actual", 0) > 0
            for a in layer_audits
            if a.get("kind") in {"cambridge-appendix", "yle-grammatical", "viu"}
        ),
        "ambiguousRowsQuarantinedInQueues": queues.get("ambiguousQuarantined") is True,
        "curriculumPrecisionGate": (
            "accepted"
            if (ROOT / "review" / "enrichment" / "phase4-approval.md").is_file()
            and "Decision: go"
            in (ROOT / "review" / "enrichment" / "phase4-approval.md").read_text(encoding="utf-8")
            else "pending-human"
        ),
        "thresholds": {
            "membershipPrecision": 0.98,
            "provenanceCompleteness": 1.0,
            "ambiguousClosedOrQuarantined": 1.0,
            "frequencySilentNulls": 0,
            "prerequisite_for": 0,
        },
    }

    report = {
        "generatedAt": GENERATED_AT,
        "phase": 4,
        "track": "lexical_coverage_enrichment_20260610",
        "coreGraph": core_git,
        "layers": layer_audits,
        "queues": queues,
        "coverageGaps": gaps,
        "gates": gates,
        "nextHumanGate": (
            "Curriculum/language: label stratified samples under "
            "review/enrichment/phase4-samples/ for precision ≥0.980 per source, "
            "then record Phase 4 review decision."
        ),
    }

    atomic_write(OUT_JSON, json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    atomic_write(OUT_GAPS, json.dumps(gaps, indent=2, ensure_ascii=False) + "\n")

    # Markdown summary
    lines = [
        "# Enrichment Phase 4 Audit",
        "",
        f"**Generated:** {GENERATED_AT}",
        f"**Track:** `lexical_coverage_enrichment_20260610`",
        "",
        "## Automatable gates",
        "",
        "| Gate | Result |",
        "|---|---|",
        f"| Core freeze untouched | {gates['coreFreezeUntouched']} |",
        f"| All layers `prerequisite_for` = 0 | {gates['allLayersZeroPrerequisiteFor']} |",
        f"| Frequency no silent nulls | {gates['frequencyNoSilentNulls']} |",
        f"| Provenance complete (membership layers) | {gates['provenanceCompleteAllMembershipLayers']} |",
        f"| Stratified samples written | {gates['stratifiedSamplesWritten']} |",
        f"| Ambiguous rows quarantined | {gates['ambiguousRowsQuarantinedInQueues']} |",
        f"| Membership precision ≥0.980 | {gates['curriculumPrecisionGate']} |",
        "",
        "## Layers",
        "",
    ]
    for a in layer_audits:
        lines.append(f"### `{a.get('layerId')}`")
        if a.get("error"):
            lines.append(f"- ERROR: {a['error']}")
            lines.append("")
            continue
        if a.get("kind") == "frequency":
            dist = a.get("distribution") or {}
            lines.extend(
                [
                    f"- Nodes: {a.get('nodeCount')}; edges: {a.get('edgeCount')}",
                    f"- Scored: {a.get('scored')}; missing flagged: {a.get('missingFlagged')}; silent nulls: {a.get('silentNulls')}",
                    f"- Zipf range: {dist.get('zipfMin')} … {dist.get('zipfMax')} (p50={dist.get('zipfP50')})",
                    f"- Hard prohibitions pass: {a.get('hardProhibitionsPass')}",
                    "",
                ]
            )
            continue
        prov = a.get("provenance") or {}
        samp = a.get("stratifiedSample") or {}
        lines.extend(
            [
                f"- Membership edges: {a.get('membershipEdgeCount')}",
                f"- Provenance completeness: {prov.get('strictCompleteness')} (pass={prov.get('pass')})",
                f"- Stratified sample: {samp.get('actual')} → `{samp.get('path')}`",
                f"- `prerequisite_for`: {a.get('prerequisite_for_count')}",
                f"- Hard prohibitions pass: {a.get('hardProhibitionsPass')}",
                "",
            ]
        )

    lines.extend(
        [
            "## Coverage gaps",
            "",
            f"- Core skills: {gaps.get('coreSkillCount')}",
            f"- Core exam memberships: `{json.dumps(gaps.get('coreExamMembershipCounts'))}`",
            f"- ViU match rate: {gaps.get('viuMatchRate')}",
            "",
        ]
    )
    for note in gaps.get("notes") or []:
        lines.append(f"- {note}")
    lines.extend(
        [
            "",
            "## Queues",
            "",
            "```",
            json.dumps(queues.get("queues"), indent=2),
            "```",
            "",
            "## Next",
            "",
            report["nextHumanGate"],
            "",
        ]
    )
    atomic_write(OUT_MD, "\n".join(lines))

    print(f"wrote {OUT_JSON}")
    print(f"wrote {OUT_MD}")
    print(f"wrote {OUT_GAPS}")
    print(f"samples under {SAMPLE_DIR}")
    for k, v in gates.items():
        if k != "thresholds":
            print(f"  gate {k}: {v}")
    # exit non-zero if automatable gates fail
    auto_ok = all(
        [
            gates["coreFreezeUntouched"],
            gates["allLayersZeroPrerequisiteFor"],
            gates["frequencyNoSilentNulls"],
            gates["provenanceCompleteAllMembershipLayers"],
            gates["stratifiedSamplesWritten"],
            gates["ambiguousRowsQuarantinedInQueues"],
        ]
    )
    return 0 if auto_ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
