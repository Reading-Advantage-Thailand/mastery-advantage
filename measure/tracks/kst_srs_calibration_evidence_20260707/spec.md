# Specification: KST+SRS Calibration & Evidence Quality

## Overview

The kst-srs engine captures rich learner data (review logs §12.5, timing
baselines, contingency tables §6) but never uses most of it to improve its
own parameters, and its evidence math is not robust to guessing, scaffolding,
or stale history. This track makes the engine self-calibrating and its
evidence trustworthy: an FSRS parameter-fitting loop, retention targets that
vary by objective priority, guess/slip-corrected proficiency evidence, a
noise-robust placement decision rule, a fully specified rating mapper,
ability-adjusted edge calibration, and an offline evaluation harness that
makes "bulletproof" measurable.

**Dependencies:** builds on the corrected formulas from
`kst_srs_core_correctness_20260707` (corrected §6.4 update, objective-level
retention aggregation, queue rules). Phase 1 decisions here must not begin
until that track's Phase 1 decisions are approved.

## Functional Requirements

### FR-1: FSRS parameter-fitting loop

Default FSRS weights are fit to adult self-selected flashcard users; young
learners in school settings will have materially different forgetting curves.
Specify a batch calibration loop, architecturally mirroring edge calibration
(§6): fit FSRS parameters from accumulated review logs per **population key**
(domain × age band, at minimum), on a defined cadence, with a minimum
review-log volume gate below which populations inherit defaults. Fitted
parameter sets are versioned artifacts with provenance (log window, cohort
size, loss metric); cards record which parameter version scheduled them.
Per-learner fitting is explicitly deferred (documented as a future stage).
The graph and student state are never auto-edited; fitted parameters enter
through a reviewed release step.

### FR-2: Per-priority retention targets

A single global `requestRetention = 0.9` spends review budget equally on
skills that do not matter equally. Extend `SchedulerConfig` (§12.3) so
`requestRetention` can vary by `ObjectivePriority` (defaults to decide in
Phase 1; working proposal: essential 0.95, supporting 0.90, extension 0.80).
Define interaction with `maximumInterval` and with the queue-size
implications (higher targets → more reviews).

### FR-3: Guess/slip-corrected proficiency evidence

`retentionStrength` (§13.1) is a raw correctness rate: it is inflated by
lucky guessing (multiple-choice formats have a ~25% guess floor) and
permanently dragged by early careless errors. Specify: (a) a lower-bound
estimator (Wilson score or Beta posterior lower bound, decided in Phase 1)
replacing raw rates in proficiency thresholds (§13.2); (b) a per-format
**guess floor** declared by the domain adapter (§15) and used to rescale
correctness evidence for selectable-answer formats; (c) explicit treatment of
small samples (evidence confidence must not read `high` from few attempts
even at 100% correct).

### FR-4: Noise-robust placement

Placement (§11.2) currently moves through the graph on single probes, so one
lucky pass or careless failure misplaces a learner by a subtree, and the
"O(log n)" walk is only defined for chain-like structures, not a wide DAG.
Specify: (a) a multi-evidence decision rule — either k probes per decision
point (k = 2–3) or a posterior over the mastery frontier updated per probe
with guess/slip parameters; (b) DAG-aware traversal (how siblings and
multiple parents are selected and pruned); (c) stopping criteria (probe
budget, confidence threshold); (d) confidence semantics of the resulting
seed estimates consistent with the seeding contract from the core
correctness track.

### FR-5: Fully specified rating mapper

§8.4 leaves the highest-volume decision in the pipeline underspecified.
Define normatively: (a) hint-usage thresholds separating `Easy` from `Good`
(and when hints degrade to `Hard`); (b) a `revealStepsSeen` cap — answers
produced after seeing worked steps are not retrieval and cap the rating
(guided-mode evidence policy made explicit); (c) recency weighting for
`retentionStrength` (exponential decay or last-k window, decided in Phase 1)
so early failures wash out; (d) the timing-adjustment thresholds ("
significantly faster/slower") as configurable z-score bounds against the
variant baseline.

### FR-6: Ability-adjusted edge calibration

Students who reach B without being proficient in A are self-selected
(typically stronger), biasing necessity estimates from observational data.
Extend §6 with an ability adjustment: stratify observations by a student
overall-proficiency band, or fit a logistic model with a student-ability
covariate, and compute necessity within strata (method decided in Phase 1).
Define minimum per-stratum counts and how adjusted results map to the
`confirmed / refuted / untested` statuses.

### FR-7: Offline evaluation harness contract

"Bulletproof" must be measurable. Specify an evaluation harness contract
(new spec section + fixtures): (a) **synthetic learners** — parameterized
simulators (ability, forgetting rate, guess/slip, compliance) run against
the engine to test invariants (no hard-gate violations recommended, queue
caps respected, placement converges within probe budget); (b) **logged
replay** — metrics computed from real review logs: retention prediction
error (predicted vs observed recall, calibration curves), placement accuracy
against subsequent evidence, fringe stability (state-flapping rate), and
edge-calibration posterior quality; (c) metric definitions, reporting
format, and regression thresholds for engine releases. Fixtures are
synthetic only (no proprietary curriculum or learner data), consistent with
Appendix B.

## Non-Functional Requirements

- **Domain neutrality:** all calibration machinery is domain-neutral; domain
  specifics (guess floors, population keys) enter only via adapter-declared
  metadata.
- **Determinism and provenance:** every fitted artifact (FSRS parameters,
  strata definitions) is versioned, reproducible from its declared inputs,
  and carries provenance; nothing is auto-applied without a release step.
- **Privacy:** evaluation and fitting contracts operate on pseudonymous IDs;
  no fixture contains real learner data.
- **Worked examples:** every new estimator or rule includes a worked numeric
  example (inputs → outputs).

## Acceptance Criteria

1. The FSRS fitting loop is specified end-to-end: population keys, cadence,
   volume gate, artifact versioning, fallback to defaults, and release
   review — with a worked lifecycle example.
2. `SchedulerConfig` supports per-priority retention targets with decided
   defaults and documented queue-load implications.
3. Proficiency evidence uses a lower-bound estimator and per-format guess
   floors; a worked example shows a 4-option multiple-choice learner no
   longer reading as proficient from chance-level performance, and a
   small-sample 100% learner not reading `high` confidence.
4. The placement section specifies multi-evidence decisions, DAG traversal,
   and stopping criteria; a worked example shows a single lucky pass no
   longer seeding an advanced subtree.
5. The rating mapper has no unspecified thresholds; guided-mode
   (`revealStepsSeen`) capping is normative.
6. Edge calibration defines ability adjustment with strata minimums and
   status mapping.
7. The evaluation harness section defines synthetic-learner invariant tests
   and replay metrics with reporting format and release thresholds.
8. Version/changelog updated (coordinated with other in-flight kst-srs
   tracks); migration notes enumerate downstream changes.

## Out of Scope

- Fixing the v2 correctness defects themselves
  (→ `kst_srs_core_correctness_20260707`).
- Planner priority normalization, domain utility, interleaving
  (→ `kst_srs_planner_domain_utility_20260707`).
- Per-learner FSRS parameter fitting (documented as future stage only).
- Running actual calibrations or building the harness implementation —
  this track specifies contracts; implementations live in consuming repos.
