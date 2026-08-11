# Implementation Plan: English Lexical Coverage Enrichment

> **Intent:** Expand the frozen YLE core lexical graph with independently gated
> source-backed groups, A2/B1 appendix coverage, Vocabulary in Use unit groups,
> and frequency metadata — without rewriting core IDs or inventing
> `prerequisite_for`.
>
> **Marker vocabulary:** `[x]` complete · `[~]` in-progress/next · `[b]` human-gated.
>
> **First remaining work:** Phase 1 human review gate after contract + registry
> drafts. Core dependency satisfied by YLE freeze dual go (2026-08-11).

## Phase 1: Contracts And Source Decisions

- [x] Task: Define enrichment-layer contracts
  - [x] Define group, membership, frequency, ambiguity, and quarantine metadata
  - [x] Define stable references to core lexical IDs
  - [x] Define independently selectable release layers
- [x] Task: Draft source registry additions
  - [x] Record URLs, versions, checksums, scope, permitted use, and cache policy
  - [x] Record excluded or unavailable sources, including the absent B2 list
- [x] Task: Define review samples and thresholds
  - [x] Define at least 100 stratified memberships per retained source
  - [x] Define ambiguity, unmatched-entry, and frequency-anomaly queues
- [b] Task: Complete Phase 1 review gate — human-gate:both-owners
  - [b] Accept contracts and source registry — human-gate:both-owners

**Green evidence (2026-08-11):**

- `english/cefr-vocabulary/review/enrichment/phase1-contracts.md` — layer IDs,
  metadata shapes, isolation, sample thresholds, no `prerequisite_for`.
- `english/cefr-vocabulary/review/enrichment/phase1-source-registry.md` — YLE
  pin, A2 Key, B1 Preliminary, four ViU bands, wordfreq candidate; EVP bulk and
  fabricated B2 lists excluded; Cambridge B2 list unavailable.
- `bash tests/enrichment_p1_contracts.sh` exits `0`.

## Phase 2: Tests And Fixtures

- [~] Task: Build Cambridge group extraction fixtures
  - [ ] Cover YLE grammatical groups and A2/B1 Appendix word sets
- [ ] Task: Build Vocabulary in Use fixtures
  - [ ] Cover all four frontmatter and index layouts
  - [ ] Cover unmatched, ambiguous, variant, and multi-unit entries
- [ ] Task: Build frequency metadata fixtures
  - [ ] Cover words, MWEs, missing scores, unreliable scores, and rank ties
- [ ] Task: Build enrichment isolation and determinism tests
- [ ] Task: Verify Phase 2

## Phase 3: Implementation

- [ ] Task: Implement Cambridge group extraction
- [ ] Task: Implement Vocabulary in Use catalogs and index matching
- [ ] Task: Implement selected frequency source integration
- [ ] Task: Implement coverage and frequency quality reports
- [ ] Task: Implement durable enrichment review queues

## Phase 4: Audit And Calibration

- [ ] Task: Audit and remediate Cambridge group memberships
- [ ] Task: Audit and remediate Vocabulary in Use matches
- [ ] Task: Validate frequency distributions and anomalies
- [ ] Task: Evaluate remaining coverage gaps and candidate sources
- [ ] Task: Complete curriculum/language review gate

## Phase 5: Release Decision

- [ ] Task: Run deterministic regeneration and full enrichment validation
- [ ] Task: Produce enrichment consumption and exclusion fixtures
- [ ] Task: Reconcile acceptance criteria and open debt
- [ ] Task: Record approve, quarantine, or reject decision per enrichment layer

## Completion Rule

Completion requires accepted evidence per layer. Rejected or quarantined
sources do not block approved coverage layers.
