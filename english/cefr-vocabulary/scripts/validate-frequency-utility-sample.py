#!/usr/bin/env python3
"""Validate frequency → utility normalization on a 500-node sample.

Implements RANKING_LAYER_SPEC.md §4 against the approved frequency overlay.
Exits 0 when all scored samples yield utility in [0,1] and missing samples
follow the documented omit behavior.
"""

from __future__ import annotations

import json
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OVERLAY = ROOT / "overlays" / "frequency.overlay.json"
SAMPLE_N = 500
SEED = 20260811


def utility_from_rank(rank: int, rmax: int) -> float:
    if rmax <= 1:
        return 1.0
    u = 1.0 - (rank - 1) / (rmax - 1)
    return max(0.0, min(1.0, u))


def main() -> int:
    if not OVERLAY.is_file():
        print(f"missing {OVERLAY}", file=sys.stderr)
        return 1
    ov = json.loads(OVERLAY.read_text(encoding="utf-8"))
    stats = ov.get("stats") or {}
    rmax = int(stats.get("maxRank") or 0)
    if rmax < 2:
        print(f"invalid maxRank: {rmax}", file=sys.stderr)
        return 1

    nodes = [n for n in ov.get("nodes", []) if n.get("kind") == "skill" or n.get("id")]
    if len(nodes) < SAMPLE_N:
        print(f"need ≥{SAMPLE_N} nodes, found {len(nodes)}", file=sys.stderr)
        return 1

    rng = random.Random(SEED)
    sample = rng.sample(nodes, SAMPLE_N)

    scored = 0
    missing = 0
    errors: list[str] = []

    for node in sample:
        freq = (node.get("metadata") or {}).get("frequency") or {}
        if not freq or freq.get("missing") is True:
            missing += 1
            # utility contribution omitted → overall 0 when only frequency is live
            continue
        rank = freq.get("rankWithinInventory")
        if rank is None:
            errors.append(f"{node.get('id')}: scored without rank")
            continue
        u = utility_from_rank(int(rank), rmax)
        if not (0.0 <= u <= 1.0):
            errors.append(f"{node.get('id')}: utility {u} out of range")
            continue
        scored += 1

    # Determinism spot-check: rank 1 → 1.0, rank rmax → 0.0
    if abs(utility_from_rank(1, rmax) - 1.0) > 1e-9:
        errors.append("rank 1 must map to 1.0")
    if abs(utility_from_rank(rmax, rmax) - 0.0) > 1e-9:
        errors.append("rank Rmax must map to 0.0")

    print(f"sample={SAMPLE_N} scored={scored} missing={missing} rmax={rmax}")
    print(f"providerKey=english.cefr.frequency-utility version=1.0.0")
    if errors:
        print("; ".join(errors[:20]), file=sys.stderr)
        return 1
    if scored < 100:
        print(f"too few scored in sample: {scored}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
