# Phase 1 Decision Log — KST+SRS Calibration & Evidence Quality

> Decisions frozen 2026-07-07, building on kst-srs.v3 (core correctness
> decisions D1–D4). Normative input to Phase 2 examples and Phase 3 edits.

## D1: FSRS Parameter-Fitting Loop (FR-1)

**Decision:**

- **Population key:** `(domain, ageBand)`, with `ageBand` declared by the
  domain adapter. Fallback hierarchy at scheduling time:
  `(domain, ageBand)` → `(domain)` → FSRS defaults.
- **Cadence:** batch fit once per term (~13 weeks), or on demand.
- **Volume gate:** a population is fit only with ≥ 10,000 review-log entries
  from ≥ 100 distinct students in the fitting window; otherwise it inherits
  the fallback.
- **Objective:** minimize log-loss of predicted recall probability at review
  time vs observed outcome (`Again` = forget; `Hard`/`Good`/`Easy` = recall),
  evaluated on a held-out 20% split.
- **Artifact:** `fsrs-params.<domain>.<ageBand>.vN` with provenance: log
  window, student and review counts, optimizer version, holdout log-loss vs
  incumbent. **Release step is human-reviewed** — a fitted set ships only if
  holdout log-loss improves on the incumbent; nothing is auto-applied
  (mirrors the §6 never-auto-edited stance).
- **Stamping:** every review log entry records the `paramsVersion` that
  scheduled the card.
- **Per-learner fitting:** explicitly deferred (documented future stage).

**Alternative considered:** continuous online fitting — rejected: silent
parameter drift is unauditable and violates the release-review principle.

## D2: Per-Priority Retention Targets (FR-2)

**Decision:** add `requestRetentionByPriority?: Partial<Record<ObjectivePriority, number>>`
to `SchedulerConfig`, overriding the scalar `requestRetention` per priority.
Defaults: essential 0.95, supporting 0.90, extension 0.80 (`triaged` is
excluded from the queue entirely). Backward compatible: absent map = scalar
behavior. `maximumInterval` applies after the target computation. Load note:
raising essential to 0.95 roughly doubles review frequency for those cards
vs 0.90 (FSRS interval at target R scales superlinearly as R → 1); the
review-load budget mechanism lands in the planner track.

## D3: Guess/Slip-Corrected Evidence (FR-3)

**Decision:**

- **Estimator:** one-sided 95% Wilson lower bound (z = 1.645) on per-variant
  correctness, replacing raw rates wherever `retentionStrength` feeds
  proficiency thresholds (§13.2). Chosen over a Beta posterior bound for its
  closed form and prior-free auditability (numerically near-identical).
- **Guess floor:** the domain adapter declares `guessFloor g ∈ [0, 1)` per
  answer format (4-option MC → 0.25; free response → 0). Correction:
  `corrected = max(0, (wilsonLower − g) / (1 − g))`.
- **Small samples:** `evidenceConfidence` caps by attempt count regardless
  of correctness: n < 3 → at most `low`; n < 6 → at most `medium`.

## D4: Noise-Robust Placement (FR-4)

**Decision:**

- **Decision rule: k = 2 probes per decision point, tie-break third.**
  pass-pass → advance; fail-fail → retreat; mixed → third probe decides;
  `partial` counts as half a pass. Probe outcomes use guess-corrected
  performance (D3) for formats with `g > 0`. Chosen over a full posterior
  over the frontier: comparable noise reduction, no model infrastructure,
  works for both reference implementations (GSE chatbot, math bank).
- **DAG traversal:** maintain a frontier set (not a single cursor). A node
  is probe-eligible only when all its hard-edge parents are resolved
  (mastered/inferred/failed). Wide levels: probe at most 3 representative
  nodes per `content_group`, selected by descending unlock value; unprobed
  siblings inherit `inferred` estimates per §11.4 closure only via hard
  edges (soft-edge siblings stay untouched).
- **Stopping:** probe budget (default 24), or frontier stable for 4
  consecutive probes, or all frontier nodes resolved.
- **Confidence:** direct placement estimates cap at `medium` by default
  (single-session evidence); `high` is available only where the domain
  adapter declares a high-fidelity probe instrument (e.g. proctored test).
  Consistent with §11.4: medium → H = 15 d seeds; inferred estimates
  downgrade per hop as already specified.

## D5: Rating Mapper Thresholds (FR-5)

**Decision (all normative, replacing §8.4 hand-waving):**

- **Hints:** `hintsUsed = 0` → up to `Easy`; `1–2` → cap `Good`; `≥ 3` →
  cap `Hard`.
- **Reveal cap:** `revealStepsSeen ≥ 1` → cap `Hard` (seeing worked steps is
  not retrieval); all steps revealed → `Again` (the attempt was re-study).
- **Recency:** per-variant `retentionStrength` uses exponentially weighted
  correctness with a half-life of 10 attempts (weight `0.5^(k/10)` for an
  attempt `k` positions in the past), feeding the D3 Wilson bound via
  effective sample size `n_eff = (Σw)² / Σw²`.
- **Timing:** per-part z-score vs the variant baseline; `z ≤ −1` makes a
  correct answer `Easy`-eligible; `z ≥ +2` downgrades one step; timing
  adjustments apply only when timing confidence ≥ `medium` AND
  `baselineSampleCount ≥ 10`.
- Misconception cap (§13.3) still applies last and wins.

## D6: Ability-Adjusted Edge Calibration (FR-6)

**Decision: stratification** (over a logistic ability covariate — simpler,
auditable, no fitting infrastructure):

- Students are banded into terciles by overall proficiency rate at
  observation time.
- The ¬A-row necessity posterior (§6.4) is computed per band.
- An adjusted verdict is reported only when ≥ 2 bands have `c + d ≥ 5`; the
  pooled verdict stands only if band posterior means agree within 0.2;
  otherwise the edge is `untested` with reason `confounded_by_ability`.

## D7: Offline Evaluation Harness (FR-7)

**Decision:**

- **Synthetic learners:** parameterized simulators
  `{ability, forgetRateMultiplier, guessProb, slipProb, complianceRate}`
  with a defined generative rule
  `P(correct) = guess + (1 − guess − slip) · mastery`.
- **Invariants (must always hold in simulation):** (1) no recommendation
  whose hard-gate readiness is violated; (2) queue caps and
  `newCardsPerDay` never exceeded; (3) placement terminates within budget;
  (4) provisional mastery decays without review (no immortal mastery);
  (5) misconception remediation precedes normal progression.
- **Replay metrics (real logs):** retention prediction MAE + 10-bin
  calibration curve (report max bin gap); placement accuracy = share of
  placed nodes whose estimate agrees with first-3-attempt evidence within
  0.25; fringe stability = state flaps per student-week; edge-calibration
  Brier score on a holdout cohort.
- **Release regression thresholds:** retention MAE within +0.02 of the
  incumbent; calibration max bin gap ≤ 0.10; flap rate ≤ incumbent × 1.10.

## Approval Record

- **Engineering/data review:** D1–D7 recorded with alternatives and
  rationale; approved under the project owner's 2026-07-07 directive to
  fully implement this track.
- **Pedagogy review:** ⚠ constants (retention targets, hint/reveal caps,
  half-life 10, tercile banding) folded into the existing curriculum-review
  tech-debt item — ratify alongside the v3 constants before app adoption.
- Unresolved: none blocking; per-learner FSRS fitting and logistic ability
  models documented as future stages.
