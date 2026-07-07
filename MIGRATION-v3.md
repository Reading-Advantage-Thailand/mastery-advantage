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

---

# v3 → v3.1 Migration Notes (Calibration & Evidence)

## 7. Proficiency evidence math (§13.1–13.2)

**Change:** `retentionStrength` = guess-floor-rescaled one-sided 95% Wilson
lower bound of recency-weighted (half-life 10) correctness; small-sample
confidence caps (n < 3 → `low`, n < 6 → `medium`).

**Action:** replace raw-rate computation in the proficiency assessor; obtain
per-format guess floors from the domain adapter. **Impact:** proficiency
rates will drop, most sharply for multiple-choice-heavy domains — this is
removal of inflation, not regression. Expect some previously-proficient
objectives to revert to `in_progress`.

## 8. Rating mapper (§8.4)

**Change:** normative hint (0 / 1–2 / ≥3), reveal (≥1 → `Hard`, all →
`Again`), and timing (z ≤ −1 / z ≥ +2, reliability-gated) thresholds.

**Action:** replace any ad-hoc mapper logic; verify against the E3 table in
the track's examples. Guided-mode submissions with reveals will now rate
lower (intended).

## 9. Placement (§11.2)

**Change:** 2-probe decisions with guess-corrected passes, frontier-set DAG
traversal, budget-24 stopping, `medium` confidence cap.

**Action:** rewrite the walk; roughly doubles probe count per decision
point, so revisit session UX (the GSE chatbot asks more questions or places
fewer nodes per session).

## 10. Scheduler config (§12.3)

**Change:** optional `requestRetentionByPriority` (0.95/0.90/0.80 defaults).

**Action:** additive and backward compatible; adopting it increases
essential-card review frequency — monitor queue load.

## 11. FSRS fitting + evaluation harness (§12.10, §17)

**Change:** new batch calibration loop and release-gating harness.

**Action:** new infrastructure, adoptable last; prerequisite: start stamping
`paramsVersion` in review logs now so replay attribution works later.
Adapters must declare `ageBand` (§15.2).

## 12. Edge calibration (§6.7)

**Change:** tercile ability stratification; new `confounded_by_ability`
untested reason.

**Action:** extend the §6.4 batch job; requires an overall-proficiency
banding computation per student per cohort window.

## v3.1 adoption order

Items 7–8 (evidence + mapper) first — they change learner-facing truth;
then 9–10; 11–12 are offline/batch and can trail.

---

# v3.1 → v3.2 Migration Notes (Planner & Domain Utility)

## 13. Priority score (§10.1–10.2)

**Change:** all terms normalized to [0,1]; new `utility` term; defaults
`a=0.35, b=0.20, c=0.15, d=0.10, e=0.20`; diversity cap on
`recommendedNext`.

**Action:** replace the priority computation; precompute
`ln(1+reach)/ln(1+maxReach)` per graph release; re-derive any custom weight
configs against the normalized scale (old weights are meaningless as-is).
**Impact:** recommendation order changes materially wherever unlock counts
previously dominated.

## 14. Domain Utility Provider (§10.3, §15.2)

**Change:** adapter-registered provider supplies `utility` with mandatory
signal provenance; engine never reads domain signal layers directly.

**Action:** additive — no provider means the term is inert. Vocabulary and
other sparse domains should implement the reference frequency provider
(coordinate with the `frequency_semantic_ranking_layer` deliverables, which
must express layers as `UtilitySignal` sources).

## 15. Prerequisite-sparse mode (§10.4) and review-load budget (§10.5)

**Change:** static sparse detection (< 5% in-edges) switches ranking to
`0.7·utility + 0.3·weaknessFit`; projected load above
`maxReviewsPerDay × 0.8` recommends zero new skills with `reviewLoadState`
surfacing (§9.4 additive fields).

**Action:** compute the sparse flag at graph release; implement the 7-day
load projection; surface `reviewLoadState` in student/teacher UIs
("review day" messaging).

## 16. Session composition (§12.7)

**Change:** presentation-only round-robin interleaving; deterministic ±5%
interval fuzz (`hash(cardId, reps)`); lightest-day load balancing.

**Action:** apply after selection (selection rules from v3 are untouched);
verify determinism — same card and rep count must always yield the same
date.

## v3.2 adoption order

Item 13 first (recommendation correctness), then 15–16 (session quality);
item 14 lands per domain as providers become available.
