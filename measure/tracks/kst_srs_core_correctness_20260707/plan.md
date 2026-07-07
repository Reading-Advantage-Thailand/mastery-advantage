# Implementation Plan: KST+SRS Core Algorithm Correctness (kst-srs.v3)

> Deliverable is the normative specification (`SPECIFICATION.md`), not runtime
> code. The Contract-First pipeline is applied in its documentation-track
> form: freeze algorithm decisions → author acceptance examples (the test
> artifacts) → edit the spec → verify consistency and release.

## Phase 1: Algorithm Decision Contracts

- [x] Task: Decide the hard-gate readiness formulation (FR-1)
    - [x] Enumerate candidates: min-gate × weighted-average, noisy-AND,
          threshold-partitioned hybrid
    - [x] Compare candidates on shared example graphs, including the
          compensatory failure case and only-hard / only-soft prerequisite sets
    - [x] Define `hardGateThreshold` config semantics and default
    - [x] Record the decision and rationale in a Phase 1 decision log
    - Evidence: `decisions.md` D1 — gated weighted readiness chosen; noisy-AND
      rejected on fan-in sensitivity (GSE graph ≈13 edges/node)
- [x] Task: Decide objective-level retention aggregation (FR-3)
    - [x] Compare minimum vs stability-weighted mean across variant cards
    - [x] Define handling for never-practiced variants and single-card objectives
    - [x] Record the decision and rationale
    - Evidence: `decisions.md` D2 — minimum over cards with `reps ≥ 1`
- [x] Task: Decide placement seeding and mastery-closure semantics (FR-4)
    - [x] Define the `(masteryEstimate, confidence) → initialStability` mapping
    - [x] Take a position on surmise closure; define direct vs inferred mastery
          and revision by later evidence
    - [x] Record the decision and rationale
    - Evidence: `decisions.md` D3 — S₀ = H(confidence)×estimate; evidence
      closure along hard edges only, confidence downgraded per hop
- [x] Task: Decide queue ordering and backlog policy (FR-5)
    - [x] Choose overdue ordering (predicted retention ascending) and confirm
          reviews-before-new
    - [x] Define `newCardsPerDay` enforcement and the extended-absence backlog
          policy
    - [x] Record the decision and rationale
    - Evidence: `decisions.md` D4 — reviews first, retention-ascending,
      newCardsPerDay hard cap, backlog suppresses new cards
- [x] Task: Approve Phase 1 decisions
    - [x] Curriculum/pedagogy reviewer approves gating, closure, and backlog
          behavior — ⚠ approved by owner directive; human curriculum review
          logged as tech debt
    - [x] Engineering reviewer approves formulas, configs, and migration impact
    - [x] Record approvals and unresolved issues in the track
    - Evidence: `decisions.md` Approval Record; tech-debt entry 2026-07-07

## Phase 2: Acceptance Examples (Normative Test Artifacts)

- [ ] Task: Author hard-gate readiness worked examples (FR-1)
    - [ ] v2 failure case: unmastered w=1.0 prerequisite yields `nearly_ready`
    - [ ] Same inputs under v3 formula yield `blocked`
    - [ ] Edge cases: no prerequisites, all-hard, all-soft, mixed weights
- [ ] Task: Author edge-calibration contingency examples (FR-2)
    - [ ] Cell-`a`-dominated cohort: v2 posterior falsely confirms; v3 posterior
          remains wide/untested
    - [ ] Genuine violation cohort: v3 posterior converges to refuted
- [ ] Task: Author retention and aggregation examples (FR-3)
    - [ ] `stabilityToRetention(stability, elapsedDays)` sample values
    - [ ] Multi-variant objective aggregated under the chosen rule, including a
          never-practiced variant
- [ ] Task: Author placement-seeding and queue/backlog examples (FR-4, FR-5)
    - [ ] Seeded skill: synthesized card, initial stability, decay trajectory,
          mastery classification over time
    - [ ] 7-day-absence backlog: queue composition with `newCardsPerDay`
          enforced and reviews first
- [ ] Task: Verify Phase 2
    - [ ] Check every example against the recorded Phase 1 decisions
    - [ ] Confirm each FR-1…FR-5 defect has a v2-vs-v3 paired example

## Phase 3: Specification Edits

- [ ] Task: Rewrite readiness sections for gated formula (FR-1)
    - [ ] §1.4 weight definition, §2.4 config, §2.5 formula
    - [ ] §2.6 pseudocode and TypeScript implementation
    - [ ] §9.4 node-state computation consistency
- [ ] Task: Rewrite edge-calibration update rule (FR-2)
    - [ ] §6.4 update conditioning (¬A rows only) and confidence bucketing
    - [ ] §6.5 self-selection bias note with deferral pointer
- [ ] Task: Reconcile retention signature and aggregation (FR-3)
    - [ ] §13.5 signature fix
    - [ ] §2.1 objective-level aggregation rule
- [ ] Task: Add placement seeding contract and closure semantics (FR-4)
    - [ ] §11 seeding subsection with initial-stability mapping
    - [ ] §2.1–2.3 direct vs inferred mastery; §12.4 `createCard` note
- [ ] Task: Rewrite daily queue rules (FR-5)
    - [ ] §12.7 ordering, caps, backlog policy, preserved injection rules
- [ ] Task: Apply documentation fixes (FR-6)
    - [ ] §8.4 cross-reference to §13.3
    - [ ] §9.4 `progressTrend` symmetric thresholds

## Phase 4: Consistency Verification And Release

- [ ] Task: Run full cross-reference and terminology sweep
    - [ ] Verify all section references resolve; no v2 formula remnants
    - [ ] Verify config fields, type names, and vocabulary are consistent
    - [ ] Record the sweep checklist and results in the track
- [ ] Task: Bump versions and changelog (FR-7)
    - [ ] Spec header and v3 changelog paragraph
    - [ ] Appendix C rows; Appendix B fixture descriptions where affected
- [ ] Task: Write downstream migration notes (FR-7)
    - [ ] Enumerate behavioral changes and required implementation updates for
          ra-math-advantage and future consumers
- [ ] Task: Final review gate and memory updates
    - [ ] Verify all acceptance criteria in spec.md
    - [ ] Update lessons-learned and tech-debt entries arising from this track
    - [ ] Record final approval
