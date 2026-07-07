# kst-srs.v2 → v3 Migration Notes

> Audience: implementers of the KST+SRS engine (`ra-math-advantage` and any
> future consumers). v3 is a **correctness release**: every change below
> fixes behavior that was wrong for learners, not a stylistic preference.
> Worked before/after examples for each change are embedded in the cited
> sections of `SPECIFICATION.md`.

## 1. Readiness: gated weighted formula (§2.5)

**Change:** `readiness(B) = gate(B) × comp(B)` — prerequisites with
`w ≥ hardGateThreshold` (new `MasteryConfig` field, default 1.0) gate via
`min()`; only softer prerequisites are averaged.

**Action:** update the fringe computation (§2.6), node-state computation
(§9.4), and anything else consuming readiness. Add `hardGateThreshold` and
`trendThreshold` to your `MasteryConfig`.

**Impact:** graphs with **no** `w = 1.0` prerequisite edges are bit-identical
to v2 — audit your edge weights: any edge authored at `w = 1.0` now actually
gates. Learners previously shown `ready`/`nearly_ready` past an unmastered
hard gate will reclassify as `blocked` (intended).

## 2. Edge calibration: necessity posterior conditioning (§6.4)

**Change:** only ¬A rows update the Beta posterior (cell `d` → α, cell `c`
→ β). Cells `a`/`b` feed informativeness only.

**Action:** fix the update rule; recompute all calibrated posteriors from
stored contingency tables (do **not** trust v2 posteriors — most "confirmed"
verdicts are inflated). Expect many edges to move from `confirmed` to
`untested`; that is the correct state of knowledge.

## 3. Retention: signature and objective aggregation (§13.5, §2.1.1)

**Change:** `stabilityToRetention(stability, elapsedDays)` (two arguments);
objective-level live retention = `min` across variant cards with `reps ≥ 1`.

**Action:** fix any single-argument implementation or call site. Implement
the aggregation rule wherever objective mastery level is computed (knowledge
state, hysteresis checks, §2.7 risk flags).

**Impact:** multi-variant objectives with one decayed variant will report
lower retention than any mean-based interim behavior — review-due badges may
increase initially (intended).

## 4. Placement: seeding contract and closure (§11.4)

**Change:** placement results synthesize review-state cards
(`S₀ = H(confidence) × masteryEstimate`, `H = {low:5, medium:15, high:30}`
days); estimates ≥ `masteryEnter` with confidence ≥ medium enter provisional
mastered; hard-edge-only ancestor closure with per-hop confidence downgrade;
evidence type (`direct`/`inferred`) recorded and replaced by direct evidence.

**Action:** implement card synthesis in the placement pipeline; add
provenance (`source: 'placement'`) and evidence-type fields to stored
estimates. If your v2 code had any ad-hoc bridge from placement to state,
delete it in favor of §11.4.

## 5. Daily queue: ordering, caps, backlog (§12.7)

**Change:** reviews before new cards; review pool ordered by predicted
retention ascending (not days overdue); `newCardsPerDay` is now enforced;
backlog mode (due > `maxReviewsPerDay`) suppresses new cards entirely.

**Action:** rewrite the queue builder. Verify with the §12.7 worked example
(25 overdue / cap 20 → 20 lowest-retention reviews, 0 new).

**Impact:** returning-from-absence sessions will contain no new material
until the backlog drains (intended pedagogy; surface as "review day" in UI).

## 6. Minor

- §8.4 misconception-cap reference now points to §13.3 (no behavior change).
- `progressTrend` uses symmetric `trendThreshold` (default 3): small
  mastered-count decreases now read `stable`, not `declining`.

## Suggested adoption order

1. §13.5 signature fix (mechanical, unblocks everything else)
2. §2.1.1 aggregation + §2.5 gated readiness (state-layer correctness)
3. §12.7 queue rewrite (session-layer correctness)
4. §11.4 placement seeding (cold-start correctness)
5. §6.4 recomputation (offline batch; can trail the runtime changes)

Fixture expectations for all five are the embedded worked examples
(SPECIFICATION.md Appendix B v3 note).
