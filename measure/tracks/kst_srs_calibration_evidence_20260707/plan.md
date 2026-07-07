# Implementation Plan: KST+SRS Calibration & Evidence Quality

> Deliverable is normative specification text plus evaluation fixtures — no
> runtime code. Pipeline form: freeze estimator/loop decisions → author
> worked examples and evaluation fixtures (the test artifacts) → edit the
> spec → verify consistency and release.
>
> **Gate:** do not start Phase 1 until
> `kst_srs_core_correctness_20260707` Phase 1 decisions are approved (this
> track builds on the corrected §6.4 update, retention aggregation, and
> queue rules).

## Phase 1: Estimator And Loop Decision Contracts

- [ ] Task: Define the FSRS parameter-fitting loop contract (FR-1)
    - [ ] Decide population keys, fitting cadence, and minimum log volume
    - [ ] Define fitted-artifact versioning, provenance fields, and the
          release-review step
    - [ ] Define fallback-to-defaults and card parameter-version stamping
    - [ ] Record decisions and rationale in a Phase 1 decision log
- [ ] Task: Decide per-priority retention targets (FR-2)
    - [ ] Set defaults per `ObjectivePriority` and document queue-load impact
    - [ ] Define interaction with `maximumInterval`
- [ ] Task: Decide the guess/slip correction method (FR-3)
    - [ ] Choose Wilson score vs Beta posterior lower bound and its confidence
          level
    - [ ] Define adapter-declared per-format guess floors and rescaling rule
    - [ ] Define small-sample evidence-confidence limits
- [ ] Task: Decide the placement decision rule (FR-4)
    - [ ] Choose k-probes vs posterior-over-frontier; set probe budgets and
          stopping criteria
    - [ ] Define DAG-aware traversal for wide levels and multiple parents
    - [ ] Align output confidence semantics with the core-track seeding contract
- [ ] Task: Decide rating-mapper thresholds (FR-5)
    - [ ] Set hint-usage and reveal-step capping rules
    - [ ] Choose recency weighting (decay vs last-k) and timing z-score bounds
- [ ] Task: Decide ability adjustment for edge calibration (FR-6)
    - [ ] Choose stratification vs covariate model; set per-stratum minimums
    - [ ] Define mapping to confirmed/refuted/untested statuses
- [ ] Task: Approve Phase 1 decisions
    - [ ] Pedagogy reviewer approves evidence and placement behavior
    - [ ] Engineering/data reviewer approves estimators, loops, and artifacts
    - [ ] Record approvals and unresolved issues in the track

## Phase 2: Acceptance Examples And Evaluation Fixtures

- [ ] Task: Author corrected-evidence worked examples (FR-3, FR-5)
    - [ ] Multiple-choice guess-floor case: chance performer not proficient
    - [ ] Small-sample 100% case: confidence capped
    - [ ] Recency weighting: early-failure learner recovering
    - [ ] Hint/reveal capping cases across rating boundaries
- [ ] Task: Author fitting-loop and placement worked examples (FR-1, FR-4)
    - [ ] Population fitting lifecycle: below-volume fallback → fit → release →
          card stamping
    - [ ] Placement: lucky single pass no longer seeding a subtree; probe-budget
          stop
- [ ] Task: Define synthetic-learner fixtures and invariants (FR-7)
    - [ ] Simulator parameterization (ability, forgetting, guess/slip,
          compliance)
    - [ ] Invariant list: gating, queue caps, placement convergence
- [ ] Task: Define replay metrics and thresholds (FR-7)
    - [ ] Retention prediction error and calibration-curve definitions
    - [ ] Placement accuracy, fringe stability, posterior-quality metrics
    - [ ] Reporting format and release regression thresholds
- [ ] Task: Verify Phase 2
    - [ ] Check every example and fixture against Phase 1 decisions
    - [ ] Confirm each FR has at least one paired worked example or fixture

## Phase 3: Specification Edits

- [ ] Task: Add the FSRS calibration loop section (FR-1)
    - [ ] New section mirroring §6 architecture; Appendix C entry
- [ ] Task: Amend scheduler configuration (FR-2)
    - [ ] §12.3 per-priority `requestRetention` with defaults and notes
- [ ] Task: Amend proficiency evidence math (FR-3)
    - [ ] §13.1–13.2 lower-bound estimator, guess floors, small-sample rules
    - [ ] §15 adapter responsibility for format guess floors
- [ ] Task: Rewrite placement decision rule (FR-4)
    - [ ] §11.2 multi-evidence rule, DAG traversal, stopping criteria
- [ ] Task: Specify the rating mapper normatively (FR-5)
    - [ ] §8.4 thresholds, reveal cap, recency weighting, timing bounds
- [ ] Task: Add ability adjustment to edge calibration (FR-6)
    - [ ] §6 strata/covariate method, minimums, status mapping
- [ ] Task: Add the offline evaluation harness section (FR-7)
    - [ ] Synthetic-learner contract, replay metrics, Appendix B fixture rows

## Phase 4: Consistency Verification And Release

- [ ] Task: Run full cross-reference and terminology sweep
    - [ ] Verify references, config fields, and estimator naming consistency
    - [ ] Verify no conflict with kst-srs.v3 core-correctness text
- [ ] Task: Bump version and changelog
    - [ ] Coordinate version increment with other in-flight kst-srs tracks
    - [ ] Update Appendix C and affected Appendix B rows
- [ ] Task: Write downstream migration notes
    - [ ] Enumerate evidence-math and scheduler changes consumers must adopt
- [ ] Task: Final review gate and memory updates
    - [ ] Verify all acceptance criteria in spec.md
    - [ ] Update lessons-learned and tech-debt; record final approval
