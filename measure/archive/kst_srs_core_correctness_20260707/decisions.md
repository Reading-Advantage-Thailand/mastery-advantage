# Phase 1 Decision Log — KST+SRS Core Algorithm Correctness

> Decisions frozen 2026-07-07. Each decision is normative input to Phase 2
> (acceptance examples) and Phase 3 (specification edits).

## D1: Hard-Gate Readiness Formulation (FR-1)

**Decision:** Gated weighted readiness (candidate "min-gate × weighted
average"):

```
readiness(B) = gate(B) × comp(B)

gate(B) = min(m_i : w_i ≥ hardGateThreshold)   (1 if B has no hard-gate prereqs)
comp(B) = Σ(w_j·m_j) / Σ(w_j)  over w_j < hardGateThreshold   (1 if none)
```

`hardGateThreshold` is added to `MasteryConfig`, default `1.0`.

**Candidates considered:**

| Candidate | Verdict | Reason |
|---|---|---|
| Gated weighted (chosen) | ✅ | Scale-stable under fan-in; exact v2 behavior for graphs with no hard-gate edges |
| Noisy-AND `Π(1 − w_i(1 − m_i))` | ❌ | Readiness declines with prerequisite count even when all are well-mastered. The production GSE graph averages ~13 edges/node; at fan-in 5 with all m=0.8, w=0.5, noisy-AND yields 0.9⁵ ≈ 0.59 (blocked) where the average yields 0.8 (ready). Would force per-node threshold recalibration. |
| Pure min over all prereqs | ❌ | Makes every weight a hard gate; destroys the compensability semantics of low weights. |

**Rationale:** (a) the weakest hard gate is the binding constraint —
`min` is the correct aggregator for non-compensatory prerequisites;
(b) the compensatory average is retained exactly for soft prerequisites, so
the formula's scale does not depend on prerequisite count; (c) **migration
property:** on any graph with no edges at `w ≥ hardGateThreshold`, v3 output
is bit-identical to v2, so recalibration is needed only where authors
actually asserted hard gates.

**Edge-case rules:** no prerequisites → 1.0 (unchanged); only hard →
`min(m_i)`; only soft → v2 weighted average; a hard gate at m = 0 forces
readiness = 0 regardless of soft mastery.

## D2: Objective-Level Retention Aggregation (FR-3)

**Decision:** Objective-level live retention is the **minimum retention
across the objective's variant cards that have review history
(`reps ≥ 1`)**, where each card's retention is
`stabilityToRetention(stability, elapsedDays)`.

- Cards with `reps = 0` (created, never reviewed — including planner
  pre-creation) are excluded.
- Single-card objectives: that card's retention.
- No card with history: the objective cannot be `mastered`/`decaying`
  (proficiency requires practice evidence); its mastery level is the
  `inProgress`/`untouched` value per §2.1.

**Alternative considered:** stability-weighted mean. Rejected: a mean lets a
well-retained variant mask a fully decayed variant category; downstream
readiness would overstate the learner's usable mastery — the failure mode
this track exists to prevent. Minimum is conservative, deterministic, and
cheap.

**Rationale for the `reps ≥ 1` exclusion:** newly created sibling cards have
sentinel/initial stability; including them would instantly tank a genuinely
mastered objective. Breadth across variants is already enforced at mastery
entry by the coverage thresholds (§13.2), so exclusion does not weaken the
entry gate.

## D3: Placement Seeding And Mastery Closure (FR-4)

**Decision (seeding):** For each placement result
`{nodeId, masteryEstimate, confidence}` with `masteryEstimate > 0`, the
engine synthesizes one SRS card per objective (default variant,
`variantKey = objectiveId`) with:

```
initialStability S₀ = H(confidence) × masteryEstimate    (days)
H = { low: 5, medium: 15, high: 30 }        (engine constants, configurable)
state = 'review', reps = 1, lapses = 0
lastReview = placement time; dueDate per scheduler from S₀
difficulty = FSRS initial difficulty for a first 'Good' rating
card provenance metadata: source = 'placement'
```

Knowledge-state entry: `masteryEstimate ≥ masteryEnter` AND confidence ≥
`medium` → enters `mastered` (provisional); otherwise `inProgress` with
`retentionStrength = masteryEstimate`. Because R(t = S₀) = 0.9 in FSRS, a
high-confidence estimate of 1.0 stays above `masteryEnter` for ~30 days
before needing review — the intended semantics of "placed out".

**Decision (closure):** **Evidence closure along hard edges only.** A direct
placement pass on B propagates *inferred* mastery to ancestors of B
transitively via `prerequisite_for` edges with `w ≥ hardGateThreshold`:

- Inferred `masteryEstimate` = the direct estimate; inferred `confidence` =
  direct confidence downgraded one level per the ordered scale (floor `low`).
- Soft edges (`w < hardGateThreshold`) propagate nothing — compensable
  prerequisites are not logically implied by success.
- Evidence type is recorded (`direct` | `inferred`). Any subsequent direct
  evidence (practice submission, probe) replaces inferred estimates
  immediately.

**Rationale:** classical KST surmise closure, restricted to edges that are
actually non-compensatory; confidence downgrade prices in inference risk;
seeded cards give every seeded skill a retention function on day one, closing
the v2 gap where placement output had no path into `getKnowledgeState`.

## D4: Daily Queue Ordering And Backlog Policy (FR-5)

**Decision:** Rewritten §12.7 ordering:

1. Exclude `triaged`; misconception-remediation injections remain at the
   front (unchanged).
2. **Reviews before new cards.** Due and overdue review cards are one pool,
   ordered by **predicted current retention ascending**
   (`stabilityToRetention(stability, elapsedDays)`) — most-forgotten first.
   Raw days-overdue ordering is removed (a low-stability card 3 days overdue
   can be far more forgotten than a high-stability card 12 days overdue).
3. New cards are admitted only after all due reviews are scheduled within
   the day's cap, are hard-capped at `newCardsPerDay`, and are ordered by
   objective priority (`essential → supporting → extension`).
4. `maxReviewsPerDay` caps the total queue; reviews take precedence, new
   cards fill any remainder.
5. **Backlog policy:** while due-review count exceeds `maxReviewsPerDay`,
   the new-card allowance is 0; the day's queue is the `maxReviewsPerDay`
   lowest-retention cards; the remainder stays due (no penalty state) and
   drains on subsequent days. No interval punishment for backlog days.

**Rationale:** enforces the previously dead `newCardsPerDay` config; reviews
protect existing (decaying) knowledge, which dominates new acquisition after
absence — routine for school-age learners; retention-ascending is the
correct urgency metric under FSRS.

## D-Doc: Documentation Decisions (FR-6)

- §8.4 misconception-cap cross-reference corrected to §13.3.
- `progressTrend`: symmetric thresholds — `improving` iff Δmastered ≥
  +`trendThreshold`, `declining` iff Δ ≤ −`trendThreshold`, else `stable`;
  `trendThreshold` default 3, configurable; `unknown` rule unchanged.

## Approval Record

- **Engineering/algorithm review:** decisions D1–D4 and D-Doc recorded with
  rationale and alternatives; approved under the project owner's 2026-07-07
  directive to fully implement this track.
- **Curriculum/pedagogy review:** ⚠ not yet performed by a human curriculum
  reviewer — logged in the Tech Debt Registry; recommended before any
  consuming application adopts kst-srs.v3 thresholds (`H` constants,
  `trendThreshold`, backlog policy).
- Unresolved issues: none blocking; ability-adjusted calibration and
  per-priority retention targets deferred to
  `kst_srs_calibration_evidence_20260707` by design.
