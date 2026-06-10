# Implementation Plan: English Lexical Coverage Enrichment

## Phase 1: Contracts And Source Decisions

- [ ] Task: Define enrichment-layer contracts
  - [ ] Define group, membership, frequency, ambiguity, and quarantine metadata
  - [ ] Define stable references to core lexical IDs
  - [ ] Define independently selectable release layers
- [ ] Task: Approve source registry additions
  - [ ] Record URLs, versions, checksums, scope, permitted use, and cache policy
  - [ ] Record excluded or unavailable sources, including the absent B2 list
- [ ] Task: Define review samples and thresholds
  - [ ] Define at least 100 stratified memberships per retained source
  - [ ] Define ambiguity, unmatched-entry, and frequency-anomaly queues
- [ ] Task: Complete Phase 1 review gate

## Phase 2: Tests And Fixtures

- [ ] Task: Build Cambridge group extraction fixtures
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
