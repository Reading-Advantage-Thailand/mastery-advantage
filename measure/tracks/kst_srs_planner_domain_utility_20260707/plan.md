# Implementation Plan: KST+SRS Planner & Domain Utility Extension

> Deliverable is normative specification text — no runtime code. Pipeline
> form: freeze ranking/contract decisions → author worked examples (the test
> artifacts) → edit the spec → verify consistency and release.
>
> **Gates:** (1) do not finalize the priority formula until
> `kst_srs_core_correctness_20260707` FR-1 (gated readiness) is approved;
> (2) the utility-provider interface must be reconciled with
> `frequency_semantic_ranking_layer_20260611` before Phase 3.

## Phase 1: Ranking And Contract Decisions

- [x] Task: Decide priority-term normalizations (FR-1)
    - [x] Choose the `unlockValue` normalization (log-scaled vs percentile)
    - [x] Define bounded `goalProximity` and combined `weaknessFit` forms
    - [x] Re-derive default weights `a…e` on the normalized scale
    - [x] Record decisions and rationale in a Phase 1 decision log
    - Evidence: `decisions.md` D1 — log-scaled unlock, 1/(1+d) goal,
      noisy-OR weakness, weights .35/.20/.15/.10/.20
- [x] Task: Define the domain utility provider contract (FR-2)
    - [x] Specify interface, determinism, versioning, and provenance fields
    - [x] Define multi-signal composition and default-off behavior
    - Evidence: `decisions.md` D2 — DomainUtilityProvider + UtilitySignal,
      provider-internal composition, inert default
- [x] Task: Decide the prerequisite-sparse ranking path (FR-3)
    - [x] Define degeneracy detection and the utility-led ordering rule
    - [x] Confirm zero-synthetic-prerequisite constraint with lexical tracks
    - Evidence: `decisions.md` D3 — <5% in-edge detection, gate-only
      readiness, 0.7 utility / 0.3 weakness, no synthetic edges
- [x] Task: Decide diversity and review-load budget rules (FR-4, FR-5)
    - [x] Choose per-group cap vs MMR reranking; define tie-breaking
    - [x] Define review-load projection formula, budget, and throttle rule
    - Evidence: `decisions.md` D4 — cap 2 per contains-group; 7-day
      projected load vs maxReviewsPerDay×0.8, reviewLoadState
- [x] Task: Decide session composition rules (FR-6)
    - [x] Define interleaving within core-track queue constraints
    - [x] Define deterministic interval fuzzing and bounded load balancing
    - Evidence: `decisions.md` D5 — presentation-only round-robin, ±5%
      hash-deterministic fuzz, lightest-day placement
- [x] Task: Reconcile with the ranking-layer track and approve Phase 1
    - [x] Joint review with frequency_semantic_ranking_layer_20260611 scope:
          one shared utility interface, no duplicated contracts
    - [x] Pedagogy reviewer approves ranking behavior; engineering reviewer
          approves contracts and performance posture — ⚠ pedagogy by owner
          directive; constants folded into curriculum-review tech debt
    - [x] Record approvals, the reconciliation decision, and unresolved issues
    - Evidence: `decisions.md` D2 reconciliation + Approval Record (ranking
      track supplies UtilitySignal sources and reference English provider)

## Phase 2: Acceptance Examples

- [x] Task: Author normalization worked examples (FR-1)
    - [x] v2 dominance defect: raw unlockValue swamping weights
    - [x] Same graph under normalized terms with re-derived weights
    - Evidence: `examples.md` E1 (12.34 vs 0.452 on identical inputs)
- [x] Task: Author vocabulary-domain ranking examples (FR-2, FR-3)
    - [x] Degenerate fringe detection on a prerequisite-sparse graph
    - [x] Frequency utility provider producing a defensible top-N with
          provenance
    - Evidence: `examples.md` E2 (make/environment/hitherto with
      UtilitySignal provenance, no synthetic edges)
- [x] Task: Author diversity and budget examples (FR-4, FR-5)
    - [x] Five same-lesson candidates → diversified recommendedNext
    - [x] Review-debt scenario → new-skill throttling and surfaced guidance
    - Evidence: `examples.md` E3a/E3b (cap 2 per group; 25.7/day > 16 →
      saturated → review day)
- [x] Task: Author session composition examples (FR-6)
    - [x] Interleaved queue respecting reviews-first and caps
    - [x] Deterministic fuzz/load-smoothing across a clumped week
    - Evidence: `examples.md` E4a/E4b (round-robin presentation;
      hash-deterministic fuzz to lightest day)
- [x] Task: Verify Phase 2
    - [x] Check every example against Phase 1 decisions
    - [x] Confirm each FR has a paired worked example
    - Evidence: E1↔D1, E2↔D2/D3, E3↔D4, E4↔D5; log-ratio and load
      arithmetic verified

## Phase 3: Specification Edits

- [x] Task: Rewrite the priority score (FR-1, FR-2)
    - [x] §10.1 normalized terms plus `e·utility(B)`; updated defaults
    - [x] §10.2 recommendedNext referencing diversity rule
    - Evidence: §10.1 all-[0,1] table with E1 dominance example; §10.2
      diversity cap with deterministic tie-break; stale §11 weakness ref
      corrected to §13.3
- [x] Task: Add the Domain Utility Provider contract (FR-2)
    - [x] New section following the §15 adapter pattern; registration and
          provenance rules
    - Evidence: new §10.3 (interface, determinism, provider-internal
      composition, mandatory provenance, engine-never-reads-layers rule);
      §15.2 registration line
- [x] Task: Specify the prerequisite-sparse ranking path (FR-3)
    - [x] Degeneracy detection and utility-led ordering in §10
    - Evidence: new §10.4 (<5% detection, gate-only readiness, 0.7/0.3
      split, synthetic-edge prohibition, E2 vocabulary example); §10.5
      review-load budget added alongside (E3b example)
- [ ] Task: Amend queue and visualization sections (FR-4, FR-5, FR-6)
    - [ ] §12.7 interleaving, fuzzing, load balancing, review-load budget
    - [ ] §9.4 recommendedNext diversity and review-day surfacing

## Phase 4: Consistency Verification And Release

- [ ] Task: Run full cross-reference and terminology sweep
    - [ ] Verify references and config naming; no conflicts with core and
          calibration track text
- [ ] Task: Bump version and changelog
    - [ ] Coordinate version increment with other in-flight kst-srs tracks
    - [ ] Update Appendix C and affected Appendix B rows
- [ ] Task: Write downstream migration and coordination notes
    - [ ] Enumerate planner/queue changes consumers must adopt
    - [ ] Update the tech-debt registry entry to reference this track
- [ ] Task: Final review gate and memory updates
    - [ ] Verify all acceptance criteria in spec.md
    - [ ] Update lessons-learned; record final approval
