# Plan — Sense-Level Lexical Identity Specification

> **Status: COMPLETE (spec ready, 2026-08-11).** Implementation deferred.

## Phase 1: Audit Current Identity Collisions
- [x] Task 1.1: Generate list of top 200 polysemous forms
- [x] Task 1.2: Sample 50 collisions in `samples/sense_collisions.md`
- [x] Task 1.3: Characterization of form+POS collapse (`identity-collapse-characterization.json`)

## Phase 2: Sense Inventory Research
- [x] Task 2.1: WordNet 3.1 coverage against the 50-sample
- [x] Task 2.2: Cambridge sense blocks — no bulk license; gloss overrides only
- [x] Task 2.3: Licensing / reproducibility documented in spec §3
- [x] Task 2.4: Primary = WordNet 3.1; fallback = Cambridge gloss constraints

## Phase 3: Specification Draft
- [x] Task 3.1: `SENSE_IDENTITY_SPEC.md`
- [x] Task 3.2: Additive sense-child schema
- [x] Task 3.3: Compatible with freeze + SPECIFICATION patterns
- [x] Task 3.4: tech-debt updated — sense identity spec ready

## Phase 4: Validation
- [x] Task 4.1: 50-sample walked through proposed rules (documented in sample)
- [x] Task 4.2: Additive schema — core consumers unchanged without sense children
- [x] Task 4.3: Commit, push, and close track

**Harness:** `bash tests/sense_identity_spec.sh`
