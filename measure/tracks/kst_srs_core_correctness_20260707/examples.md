# Phase 2 Acceptance Examples — kst-srs.v3

> Normative test artifacts. Each example pairs the v2 defect with the v3
> result on identical inputs, per decisions D1–D4. Retention uses the FSRS
> power curve `R(t, S) = (1 + (19/81)·t/S)^(−0.5)`, so `R(S, S) = 0.9`
> exactly.

## E1: Gated Readiness (D1 / FR-1)

Node B; `hardGateThreshold = 1.0`; thresholds ready ≥ 0.80, nearly ≥ 0.50.

**E1a — compensatory failure (the defect).** Prereqs: A (w=1.0, m=0),
C (w=0.5, m=1), D (w=0.5, m=1), E (w=0.5, m=1).

- v2: (1.0·0 + 0.5 + 0.5 + 0.5) / (1.0 + 1.5) = 1.5/2.5 = **0.60 → nearly_ready** ✗
- v3: gate = min(0) = 0; comp = 1.5/1.5 = 1.0; readiness = 0 × 1.0 = **0 → blocked** ✓

**E1b — decaying hard gate.** A (w=1.0, m=0.92), C (w=0.5, m=1.0),
D (w=0.5, m=0.70).

- v3: gate = 0.92; comp = (0.50 + 0.35)/1.0 = 0.85; readiness = 0.92 × 0.85
  = **0.782 → nearly_ready** (v2 average said 1.77/2.0 = 0.885 → ready).

**E1c — edge cases.** No prereqs → 1.0 (unchanged). Only hard: A (m=0.95),
B (m=0.90) → min = **0.90 → ready**. Only soft: identical to v2 weighted
average (migration property: graphs with no w ≥ 1.0 edges are bit-identical
under v3).

## E2: Edge-Calibration Posterior (D-FR-2)

Edge A → B, prior Beta(1,1). Cohort: a = 470 (both proficient), b = 20,
c = 4 (violations), d = 6.

- v2 (counts cells a and d as α): α = 1 + 476 = 477, β = 1 + 4 = 5 →
  mean = 477/482 = **0.990**, sd ≈ 0.0046 → falsely **confirmed** with high
  confidence, though only 10 students ever tested necessity. ✗
- v3 (¬A rows only: d → α, c → β): α = 1 + 6 = 7, β = 1 + 4 = 5 →
  mean = 7/12 = **0.583**, sd ≈ 0.137 → wide posterior on n = 10 →
  **untested / needs order-variation**. ✓

**E2b — genuine refutation.** c = 40, d = 10 → α = 11, β = 41 →
mean = 11/52 = **0.212**, sd ≈ 0.056 → tight and low → **refuted**. ✓

## E3: Retention Signature And Aggregation (D2 / FR-3)

`stabilityToRetention(S = 10, t)`: t = 0 → 1.000; t = 10 → 0.900 (exactly, by
construction); t = 30 → (1 + 0.23457·3)^(−0.5) = 1.7037^(−0.5) = **0.766**.
(v2's §13.5 one-argument signature cannot produce these values. ✗)

**E3b — objective-level aggregation.** Objective with variant cards:
V1 (S = 20, t = 5 → R = 0.972), V2 (S = 8, t = 12 → R = 0.860),
V3 (reps = 0 → excluded).

- v3 objective retention = min(0.972, 0.860) = **0.860**.
- Hysteresis interplay: 0.860 is inside [masteryExit 0.70, masteryEnter
  0.90): a currently-mastered objective **stays mastered** (m = 1.0); an
  objective already in `decaying` reports m = 0.860.
- v2: undefined which card's stability applies. ✗

## E4: Placement Seeding And Closure (D3 / FR-4)

Probe pass at node B: estimate 0.95, confidence high.

- Seeded card: S₀ = 30 × 0.95 = **28.5 days**, state `review`, reps = 1,
  provenance `placement`. Retention: t = 14 → 0.947; t = 28.5 → 0.900.
- Knowledge state: 0.95 ≥ masteryEnter (0.90) and confidence ≥ medium →
  enters **mastered (provisional)**; first review due per scheduler — the
  skill has a live decay curve from day one.
- Hard-edge ancestor A (w = 1.0 into B): inferred estimate 0.95, confidence
  high→**medium**, S₀ = 15 × 0.95 = 14.25 d → also provisional mastered,
  reaching R = 0.90 at 14.25 d (earlier confirmation review than B).
- Soft-edge neighbor (w = 0.6): **no propagation**.
- Weak probe: estimate 0.60, confidence low → S₀ = 3 d, enters `inProgress`
  with retentionStrength 0.60 (not mastered).
- v2: these results had no path into `getKnowledgeState` at all. ✗

## E5: Queue Ordering And Backlog (D4 / FR-5)

Student returns from a 7-day absence: 25 overdue review cards, 6 new-card
candidates; `maxReviewsPerDay = 20`, `newCardsPerDay = 4`.

- v2: new cards first (uncapped — `newCardsPerDay` referenced by no rule) →
  6 new + 14 reviews by days-overdue; the 11 most-decayed cards can be
  dropped. ✗
- v3: due reviews (25) > cap (20) → backlog mode, new-card allowance 0;
  queue = 20 **lowest-retention** reviews; 5 remain due and drain next day;
  new cards resume when due count ≤ cap. ✓

**E5b — retention-ascending beats days-overdue.** Card X (S = 3, t = 8 d →
R = 0.784) vs card Y (S = 30, t = 12 d → R = 0.956). v2 ordered Y first
(more days overdue); v3 orders X first (more forgotten). ✓

**E5c — normal day.** 12 due reviews, 6 new candidates, same caps → 12
reviews (retention ascending), then 4 new (capped, essential → supporting →
extension), total 16 ≤ 20. Misconception-remediation items, if any, inject
ahead of both pools (unchanged).
