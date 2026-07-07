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

- [x] Task: Define the FSRS parameter-fitting loop contract (FR-1)
    - [x] Decide population keys, fitting cadence, and minimum log volume
    - [x] Define fitted-artifact versioning, provenance fields, and the
          release-review step
    - [x] Define fallback-to-defaults and card parameter-version stamping
    - [x] Record decisions and rationale in a Phase 1 decision log
    - Evidence: `decisions.md` D1 — (domain, ageBand) keys, 10k/100 gate,
      holdout log-loss, human-reviewed release
- [x] Task: Decide per-priority retention targets (FR-2)
    - [x] Set defaults per `ObjectivePriority` and document queue-load impact
    - [x] Define interaction with `maximumInterval`
    - Evidence: `decisions.md` D2 — requestRetentionByPriority overlay,
      0.95/0.90/0.80
- [x] Task: Decide the guess/slip correction method (FR-3)
    - [x] Choose Wilson score vs Beta posterior lower bound and its confidence
          level
    - [x] Define adapter-declared per-format guess floors and rescaling rule
    - [x] Define small-sample evidence-confidence limits
    - Evidence: `decisions.md` D3 — one-sided 95% Wilson, guess-floor
      rescaling, n<3/n<6 confidence caps
- [x] Task: Decide the placement decision rule (FR-4)
    - [x] Choose k-probes vs posterior-over-frontier; set probe budgets and
          stopping criteria
    - [x] Define DAG-aware traversal for wide levels and multiple parents
    - [x] Align output confidence semantics with the core-track seeding contract
    - Evidence: `decisions.md` D4 — 2-probe + tie-break, frontier-set
      traversal, budget 24, medium confidence cap
- [x] Task: Decide rating-mapper thresholds (FR-5)
    - [x] Set hint-usage and reveal-step capping rules
    - [x] Choose recency weighting (decay vs last-k) and timing z-score bounds
    - Evidence: `decisions.md` D5 — hint 0/1–2/≥3 tiers, reveal caps,
      half-life-10 recency, z −1/+2 timing
- [x] Task: Decide ability adjustment for edge calibration (FR-6)
    - [x] Choose stratification vs covariate model; set per-stratum minimums
    - [x] Define mapping to confirmed/refuted/untested statuses
    - Evidence: `decisions.md` D6 — tercile stratification, ≥2 bands with
      c+d≥5, confounded_by_ability reason
- [x] Task: Approve Phase 1 decisions
    - [x] Pedagogy reviewer approves evidence and placement behavior — ⚠ by
          owner directive; constants folded into curriculum-review tech debt
    - [x] Engineering/data reviewer approves estimators, loops, and artifacts
    - [x] Record approvals and unresolved issues in the track
    - Evidence: `decisions.md` Approval Record; tech-debt row updated

## Phase 2: Acceptance Examples And Evaluation Fixtures

- [x] Task: Author corrected-evidence worked examples (FR-3, FR-5)
    - [x] Multiple-choice guess-floor case: chance performer not proficient
    - [x] Small-sample 100% case: confidence capped
    - [x] Recency weighting: early-failure learner recovering
    - [x] Hint/reveal capping cases across rating boundaries
    - Evidence: `examples.md` E1a–E1c (Wilson 0.127→0, 0.541→0.388, 0.649
      capped medium), E2 (0.60 vs 0.50), E3 rating table
- [x] Task: Author fitting-loop and placement worked examples (FR-1, FR-4)
    - [x] Population fitting lifecycle: below-volume fallback → fit → release →
          card stamping
    - [x] Placement: lucky single pass no longer seeding a subtree; probe-budget
          stop
    - Evidence: `examples.md` E5 (gate/fit/release/stamp + fallback), E4
      (guess P 0.25 → 0.06, 2-of-3 walk, budget stop)
- [x] Task: Define synthetic-learner fixtures and invariants (FR-7)
    - [x] Simulator parameterization (ability, forgetting, guess/slip,
          compliance)
    - [x] Invariant list: gating, queue caps, placement convergence
    - Evidence: `examples.md` E7 invariants; D7 generative rule
- [x] Task: Define replay metrics and thresholds (FR-7)
    - [x] Retention prediction error and calibration-curve definitions
    - [x] Placement accuracy, fringe stability, posterior-quality metrics
    - [x] Reporting format and release regression thresholds
    - Evidence: `examples.md` E7 metrics with thresholds (+0.02 MAE, 0.10
      max bin gap, ×1.10 flap rate)
- [x] Task: Verify Phase 2
    - [x] Check every example and fixture against Phase 1 decisions
    - [x] Confirm each FR has at least one paired worked example or fixture
    - Evidence: E1↔D3, E2/E3↔D5, E4↔D4, E5↔D1, E6↔D6, E7↔D7; FR-2 covered
      by D2 config example in Phase 3 §12.3 edit; Wilson arithmetic verified

## Phase 3: Specification Edits

- [x] Task: Add the FSRS calibration loop section (FR-1)
    - [x] New section mirroring §6 architecture; Appendix C entry
    - Evidence: new §12.10 with population keys, gate, holdout objective,
      release review, stamping, E5 lifecycle example (Appendix C in Phase 4)
- [x] Task: Amend scheduler configuration (FR-2)
    - [x] §12.3 per-priority `requestRetention` with defaults and notes
    - Evidence: requestRetentionByPriority overlay (0.95/0.90/0.80),
      backward-compatible, load note with planner-track deferral
- [x] Task: Amend proficiency evidence math (FR-3)
    - [x] §13.1–13.2 lower-bound estimator, guess floors, small-sample rules
    - [x] §15 adapter responsibility for format guess floors
    - Evidence: §13.1 corrected-correctness pipeline (recency → Wilson →
      guess floor) with E1/E2 examples; §13.2 algorithm steps 3/5/6 updated;
      §15.2 adapter declarations (guess floors, age bands, probe instruments)
- [x] Task: Rewrite placement decision rule (FR-4)
    - [x] §11.2 multi-evidence rule, DAG traversal, stopping criteria
    - Evidence: §11.2 "Adaptive Frontier Walk" — 2-probe + tie-break with
      guess correction, frontier-set DAG traversal, budget/stability
      stopping, medium confidence cap
- [x] Task: Specify the rating mapper normatively (FR-5)
    - [x] §8.4 thresholds, reveal cap, recency weighting, timing bounds
    - Evidence: §8.4 five-stage mapper with numeric hint/reveal/timing
      thresholds (E3 table); recency weighting specified in §13.1 (FR-3 task)
- [x] Task: Add ability adjustment to edge calibration (FR-6)
    - [x] §6 strata/covariate method, minimums, status mapping
    - Evidence: new §6.7 tercile stratification with E6 worked example and
      confounded_by_ability status reason
- [x] Task: Add the offline evaluation harness section (FR-7)
    - [x] Synthetic-learner contract, replay metrics, Appendix B fixture rows
    - Evidence: new §17 (simulators, 5 invariants, gated replay metrics,
      release rule); TOC entry; 2 Appendix B fixture rows

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
