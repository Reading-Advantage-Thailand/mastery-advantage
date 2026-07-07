# Phase 2 Acceptance Examples — kst-srs.v3.1 (Calibration & Evidence)

> Normative test artifacts per decisions D1–D7. Wilson lower bound is
> one-sided 95% (z = 1.645, z² = 2.706):
> `lower = [p̂ + z²/2n − z·√(p̂(1−p̂)/n + z²/4n²)] / (1 + z²/n)`.

## E1: Guess-Floor And Wilson Correction (D3 / FR-3)

**E1a — chance performer no longer reads as competent.** 3/10 correct on
4-option multiple choice (`g = 0.25`): raw rate 0.30; Wilson lower = 0.127;
corrected = max(0, (0.127 − 0.25)/0.75) = **0** → contributes nothing to
proficiency. (v3: raw 0.30 counted at face value.) ✓

**E1b — inflated MC evidence deflated.** 8/10 on the same format: raw 0.80
(≥ essential retention threshold!); Wilson lower = 0.541; corrected =
(0.541 − 0.25)/0.75 = **0.388** → not proficient. Free response (g = 0) with
8/10: corrected = Wilson lower = 0.541 — format now matters. ✓

**E1c — small perfect sample capped.** 5/5 on free response: Wilson lower =
0.649 (not 1.0), and n = 5 < 6 caps `evidenceConfidence` at `medium` — the
`mastered` label (requires `high`) is unreachable from 5 attempts. ✓

## E2: Recency Weighting (D5 / FR-5)

12 attempts, oldest 6 failed, newest 6 passed (half-life 10):
weighted rate = **0.60** vs raw all-time rate 0.50; effective sample
n_eff = (Σw)²/Σw² ≈ 11.4. Early struggles wash out as competence develops;
in v3 they dragged the rate forever. ✓

## E3: Rating Mapper Caps (D5 / FR-5)

| Submission | v3 rating | v3.1 rating |
|---|---|---|
| All correct, 0 hints, fast (z ≤ −1, baseline reliable) | "Good or Easy" (unspecified) | `Easy` |
| All correct, 2 hints | unspecified | `Good` (hint cap) |
| All correct, 4 hints | unspecified | `Hard` (hint cap) |
| All correct after 1 revealed step | `Good`/`Easy` possible | `Hard` (reveal cap) |
| All correct, all steps revealed | `Good`/`Easy` possible | `Again` (re-study, not recall) |
| All correct, slow (z ≥ +2) | "may downgrade" | one-step downgrade → `Hard` |

Timing adjustments require timing confidence ≥ `medium` AND
`baselineSampleCount ≥ 10`; the §13.3 misconception cap still applies last.

## E4: Placement Multi-Probe (D4 / FR-4)

**E4a — lucky pass contained.** Single-probe v3: one lucky MC pass
(P = 0.25 by pure guessing) seeded the node and its hard-edge ancestors.
v3.1: advance requires pass-pass (P ≈ 0.06 by guessing) or 2-of-3; probe
outcomes are guess-corrected first.

**E4b — decision walk.** Node probe: pass, fail → tie-break probe: pass →
advance (2 of 3). Budget 24 probes resolves ~8–12 decision points; frontier
stable for 4 consecutive probes also stops. Direct estimates cap at
`medium` (H = 15 d seeds per §11.4) unless the adapter declares a
high-fidelity instrument.

## E5: FSRS Fitting Lifecycle (D1 / FR-1)

Population `english.gse × primary`: 220 students, 41,300 reviews in the term
window → gate (≥10,000 / ≥100) passed → fit → holdout log-loss 0.412 vs
incumbent 0.446 → human release review approves
`fsrs-params.english.gse.primary.v2`; subsequent review logs stamp that
`paramsVersion`. Population `math.im3 × secondary` with 3,800 reviews fails
the gate → schedules with `(math.im3)` domain params → FSRS defaults if none.

## E6: Ability Stratification (D6 / FR-6)

Edge A→B, ¬A rows only, banded by overall proficiency terciles:
low band c=1, d=9 (mean 0.83); mid band c=2, d=8 (mean 0.75) → bands agree
within 0.2, both have c+d ≥ 5 → pooled verdict stands. Counter-case: low
band mean 0.85, high band mean 0.30 (strong students skip A safely) →
divergence > 0.2 → `untested`, reason `confounded_by_ability`. ✓

## E7: Harness Invariants And Replay Metrics (D7 / FR-7)

Simulation invariants: no hard-gate-violating recommendation; queue caps and
`newCardsPerDay` never exceeded; placement terminates within budget;
provisional mastery decays without review; misconception remediation
precedes progression. Replay metrics with release thresholds: retention
prediction MAE (≤ incumbent + 0.02), 10-bin calibration max gap (≤ 0.10),
placement agreement within 0.25 vs first-3-attempt evidence, fringe flap
rate (≤ incumbent × 1.10), edge Brier score on holdout cohort.
