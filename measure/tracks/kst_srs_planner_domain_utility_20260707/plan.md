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
