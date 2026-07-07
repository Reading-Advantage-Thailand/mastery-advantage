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

- [ ] Task: Decide priority-term normalizations (FR-1)
    - [ ] Choose the `unlockValue` normalization (log-scaled vs percentile)
    - [ ] Define bounded `goalProximity` and combined `weaknessFit` forms
    - [ ] Re-derive default weights `a…e` on the normalized scale
    - [ ] Record decisions and rationale in a Phase 1 decision log
- [ ] Task: Define the domain utility provider contract (FR-2)
    - [ ] Specify interface, determinism, versioning, and provenance fields
    - [ ] Define multi-signal composition and default-off behavior
- [ ] Task: Decide the prerequisite-sparse ranking path (FR-3)
    - [ ] Define degeneracy detection and the utility-led ordering rule
    - [ ] Confirm zero-synthetic-prerequisite constraint with lexical tracks
- [ ] Task: Decide diversity and review-load budget rules (FR-4, FR-5)
    - [ ] Choose per-group cap vs MMR reranking; define tie-breaking
    - [ ] Define review-load projection formula, budget, and throttle rule
- [ ] Task: Decide session composition rules (FR-6)
    - [ ] Define interleaving within core-track queue constraints
    - [ ] Define deterministic interval fuzzing and bounded load balancing
- [ ] Task: Reconcile with the ranking-layer track and approve Phase 1
    - [ ] Joint review with frequency_semantic_ranking_layer_20260611 scope:
          one shared utility interface, no duplicated contracts
    - [ ] Pedagogy reviewer approves ranking behavior; engineering reviewer
          approves contracts and performance posture
    - [ ] Record approvals, the reconciliation decision, and unresolved issues

## Phase 2: Acceptance Examples

- [ ] Task: Author normalization worked examples (FR-1)
    - [ ] v2 dominance defect: raw unlockValue swamping weights
    - [ ] Same graph under normalized terms with re-derived weights
- [ ] Task: Author vocabulary-domain ranking examples (FR-2, FR-3)
    - [ ] Degenerate fringe detection on a prerequisite-sparse graph
    - [ ] Frequency utility provider producing a defensible top-N with
          provenance
- [ ] Task: Author diversity and budget examples (FR-4, FR-5)
    - [ ] Five same-lesson candidates → diversified recommendedNext
    - [ ] Review-debt scenario → new-skill throttling and surfaced guidance
- [ ] Task: Author session composition examples (FR-6)
    - [ ] Interleaved queue respecting reviews-first and caps
    - [ ] Deterministic fuzz/load-smoothing across a clumped week
- [ ] Task: Verify Phase 2
    - [ ] Check every example against Phase 1 decisions
    - [ ] Confirm each FR has a paired worked example

## Phase 3: Specification Edits

- [ ] Task: Rewrite the priority score (FR-1, FR-2)
    - [ ] §10.1 normalized terms plus `e·utility(B)`; updated defaults
    - [ ] §10.2 recommendedNext referencing diversity rule
- [ ] Task: Add the Domain Utility Provider contract (FR-2)
    - [ ] New section following the §15 adapter pattern; registration and
          provenance rules
- [ ] Task: Specify the prerequisite-sparse ranking path (FR-3)
    - [ ] Degeneracy detection and utility-led ordering in §10
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
