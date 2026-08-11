#!/usr/bin/env python3
"""Aggregate subagent edge judgments and split WordNet overlay by verdict.

Reads:
  review/enrichment/semantic-edge-review/judgments/batch-*.jsonl
  overlays/semantic-wordnet.overlay.json

Writes:
  review/enrichment/semantic-edge-review/summary.json
  review/enrichment/semantic-edge-review/all-judgments.jsonl
  overlays/semantic-wordnet-accepted.overlay.json  (accept only)
  review/enrichment/queues/semantic-edge-rejected.jsonl
  review/enrichment/queues/semantic-edge-uncertain.jsonl
  reports/enrichment/semantic-edge-review.md
"""

from __future__ import annotations

import json
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
JUDGE_DIR = ROOT / "review" / "enrichment" / "semantic-edge-review" / "judgments"
SRC_OVERLAY = ROOT / "overlays" / "semantic-wordnet.overlay.json"
OUT_SUMMARY = ROOT / "review" / "enrichment" / "semantic-edge-review" / "summary.json"
OUT_ALL = ROOT / "review" / "enrichment" / "semantic-edge-review" / "all-judgments.jsonl"
OUT_ACCEPT = ROOT / "overlays" / "semantic-wordnet-accepted.overlay.json"
OUT_REJECT_Q = ROOT / "review" / "enrichment" / "queues" / "semantic-edge-rejected.jsonl"
OUT_UNCERT_Q = ROOT / "review" / "enrichment" / "queues" / "semantic-edge-uncertain.jsonl"
OUT_MD = ROOT / "reports" / "enrichment" / "semantic-edge-review.md"


def main() -> int:
    files = sorted(JUDGE_DIR.glob("batch-*.jsonl"))
    if not files:
        print(f"no judgment files in {JUDGE_DIR}", file=sys.stderr)
        return 1

    judgments: list[dict] = []
    by_edge: dict[str, dict] = {}
    for path in files:
        for line in path.read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            row = json.loads(line)
            v = row.get("verdict")
            if v not in {"accept", "reject", "uncertain"}:
                print(f"bad verdict in {path.name}: {v}", file=sys.stderr)
                return 1
            eid = row.get("edgeId")
            if not eid:
                print(f"missing edgeId in {path.name}", file=sys.stderr)
                return 1
            judgments.append(row)
            by_edge[eid] = row

    ov = json.loads(SRC_OVERLAY.read_text(encoding="utf-8"))
    edges = ov.get("edges") or []
    missing = [e["id"] for e in edges if e["id"] not in by_edge]
    if missing:
        print(f"missing judgments for {len(missing)} edges (e.g. {missing[:3]})", file=sys.stderr)
        return 1

    counts = Counter(j["verdict"] for j in judgments)
    by_rel = Counter()
    accept_by_rel = Counter()
    for j in judgments:
        rel = j.get("relation") or "?"
        by_rel[rel] += 1
        if j["verdict"] == "accept":
            accept_by_rel[rel] += 1

    accept_ids = {j["edgeId"] for j in judgments if j["verdict"] == "accept"}
    reject_rows = [j for j in judgments if j["verdict"] == "reject"]
    uncert_rows = [j for j in judgments if j["verdict"] == "uncertain"]

    accepted_edges = []
    for e in edges:
        if e["id"] not in accept_ids:
            continue
        e2 = json.loads(json.dumps(e))
        e2["reviewStatus"] = "accepted"
        meta = e2.setdefault("metadata", {})
        meta["reviewVerdict"] = "accept"
        meta["reviewer"] = by_edge[e["id"]].get("reviewer", "subagent")
        accepted_edges.append(e2)

    accepted_edges.sort(key=lambda e: e["id"])
    accept_ov = {
        "enrichmentLayer": "enrichment.semantic.wordnet",
        "generatedAt": "2026-08-11",
        "coreGraph": "cefr-vocabulary-knowledge-space.json",
        "description": (
            "WordNet typed semantic edges accepted by batch review (sets of 100). "
            "Rejected/uncertain excluded. Not a prerequisite layer."
        ),
        "review": {
            "method": "subagent-batch-100",
            "batchCount": len(files),
            "verdicts": dict(counts),
        },
        "hardProhibitions": {
            "prerequisite_for": False,
            "doesNotRewriteCoreFreeze": True,
        },
        "nodes": [],
        "edges": accepted_edges,
        "stats": {
            "edgeCount": len(accepted_edges),
            "accepted": counts.get("accept", 0),
            "rejected": counts.get("reject", 0),
            "uncertain": counts.get("uncertain", 0),
            "sourceEdgeCount": len(edges),
            "acceptRate": round(counts.get("accept", 0) / len(edges), 4) if edges else 0,
            "acceptByRelation": dict(accept_by_rel),
        },
    }

    summary = {
        "generatedAt": "2026-08-11",
        "totalJudgments": len(judgments),
        "sourceEdges": len(edges),
        "batches": len(files),
        "verdicts": dict(counts),
        "acceptRate": accept_ov["stats"]["acceptRate"],
        "byRelation": {
            rel: {
                "total": by_rel[rel],
                "accept": accept_by_rel.get(rel, 0),
                "acceptRate": round(accept_by_rel.get(rel, 0) / by_rel[rel], 4) if by_rel[rel] else 0,
            }
            for rel in sorted(by_rel)
        },
        "outputs": {
            "acceptedOverlay": "overlays/semantic-wordnet-accepted.overlay.json",
            "rejectedQueue": "review/enrichment/queues/semantic-edge-rejected.jsonl",
            "uncertainQueue": "review/enrichment/queues/semantic-edge-uncertain.jsonl",
        },
    }

    OUT_SUMMARY.parent.mkdir(parents=True, exist_ok=True)
    OUT_SUMMARY.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    OUT_ALL.write_text(
        "".join(json.dumps(j, ensure_ascii=False) + "\n" for j in sorted(judgments, key=lambda x: x["edgeId"])),
        encoding="utf-8",
    )
    OUT_ACCEPT.write_text(json.dumps(accept_ov, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    OUT_REJECT_Q.parent.mkdir(parents=True, exist_ok=True)
    OUT_REJECT_Q.write_text(
        "".join(json.dumps(j, ensure_ascii=False) + "\n" for j in reject_rows), encoding="utf-8"
    )
    OUT_UNCERT_Q.write_text(
        "".join(json.dumps(j, ensure_ascii=False) + "\n" for j in uncert_rows), encoding="utf-8"
    )

    md = [
        "# Semantic WordNet Edge Review Summary",
        "",
        f"**Edges reviewed:** {len(edges)} in {len(files)} batches of ≤100",
        f"**Accept:** {counts.get('accept', 0)} ({100 * summary['acceptRate']:.1f}%)",
        f"**Reject:** {counts.get('reject', 0)}",
        f"**Uncertain:** {counts.get('uncertain', 0)}",
        "",
        "## By relation",
        "",
        "| Relation | Total | Accept | Accept rate |",
        "|---|---:|---:|---:|",
    ]
    for rel, info in summary["byRelation"].items():
        md.append(f"| {rel} | {info['total']} | {info['accept']} | {info['acceptRate']:.1%} |")
    md.extend(
        [
            "",
            "## Outputs",
            "",
            "- Accepted overlay: `overlays/semantic-wordnet-accepted.overlay.json`",
            "- Rejected queue: `review/enrichment/queues/semantic-edge-rejected.jsonl`",
            "- Uncertain queue: `review/enrichment/queues/semantic-edge-uncertain.jsonl`",
            "",
            "Accepted edges remain optional ranking signals; never `prerequisite_for`.",
            "Per-relation product promote still requires owner go if you want ranking weight > 0.",
            "",
        ]
    )
    OUT_MD.write_text("\n".join(md), encoding="utf-8")

    print(json.dumps(summary["verdicts"], indent=2))
    print("acceptRate", summary["acceptRate"])
    print("wrote", OUT_ACCEPT, "edges", len(accepted_edges))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
