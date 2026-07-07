# Phase 2 Acceptance Examples — kst-srs.v3.2 (Planner & Domain Utility)

> Normative test artifacts per decisions D1–D5.

## E1: Term Normalization (D1 / FR-1)

Graph max reach 120. Node P: readiness 0.85, reach 40. Node Q: readiness
1.0, reach 2. No goal, no weaknesses, no provider.

- **Dominance defect (pre-v3.2, raw counts):** P = 0.4·0.85 + 0.3·40 =
  **12.34**; Q = 0.4·1.0 + 0.3·2 = **1.0**. The unlock count term is ~30×
  every other term — configured weights are meaningless. ✗
- **v3.2 (normalized):** u_P = ln(41)/ln(121) = 0.774; u_Q = ln(3)/ln(121)
  = 0.229. P = 0.35·0.85 + 0.20·0.774 = **0.452**; Q = 0.35·1.0 + 0.20·0.229
  = **0.396**. High-reach P still leads, but readiness is competitive again
  and all terms share one scale. ✓

## E2: Utility-Led Vocabulary Ranking (D2, D3 / FR-2, FR-3)

CEFR lexical domain: ~0% of skill nodes have prerequisite in-edges →
prerequisite-sparse → utility-led mode (readiness gates at 1.0 for all
untouched words; ranking = 0.7·utility + 0.3·weaknessFit).

Provider `english.cefr.frequency-utility v1` (utility = corpus-frequency
percentile among domain lemmas):

| Word | Zipf | utility | weaknessFit | Score |
|------|------|---------|-------------|-------|
| make | 6.2 | 0.98 | 0 | **0.686** |
| environment | 4.9 | 0.71 | 0.5 (active confusion link) | **0.647** |
| hitherto | 2.9 | 0.08 | 0 | **0.056** |

Every score carries provenance:
`signals: [{source: "wordfreq-en", sourceVersion: "3.1", value: 6.2, weight: 1.0}]`.
Pre-v3.2 the planner had no opinion (readiness 1.0, unlock 0, goal 0 for
all 4,000 words); no synthetic prerequisite edges were added. ✓

## E3: Diversity And Review-Load Budget (D4 / FR-4, FR-5)

**E3a — diversity.** Top-5 by raw priority all belong to
`math.im3.unit.m1.l2`. Cap (2 per nearest `contains` ancestor) keeps ranks
1–2, replaces ranks 3–5 with the next-highest nodes from other units;
tie-break priority desc then nodeId asc → deterministic. ✓

**E3b — review-load throttle.** 180 cards due in the next 7 days → projected
25.7/day; budget = 20 × 0.8 = 16 → `saturated` → planner recommends 0 new
skills and surfaces "review day"; at 11/day (≥ 60% of budget) the state is
`elevated`; below, `normal`. ✓

## E4: Session Composition (D5 / FR-6)

**E4a — interleaving.** Day's selected reviews: 3 cards obj-A, 2 obj-B,
1 obj-C → presented A,B,C,A,B,A (round-robin) instead of the blocked
AAABBC. Selection (v3 §12.7 retention-ascending, caps) unchanged. ✓

**E4b — fuzz + load balancing.** Card interval 30 d; `hash(cardId, reps)` →
+0.03 → 30.9 d; window [28.5, 31.5] → lands on the projected-lightest day
(e.g. day 31 with 9 due vs day 30 with 17). Deterministic: same card and
rep count always produce the same date. ✓
