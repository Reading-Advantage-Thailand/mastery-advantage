# Implementation Plan: English Lexical Coverage Enrichment

> **Intent:** Expand the frozen YLE core lexical graph with independently gated
> source-backed groups, A2/B1 appendix coverage, Vocabulary in Use unit groups,
> and frequency metadata — without rewriting core IDs or inventing
> `prerequisite_for`.
>
> **Marker vocabulary:** `[x]` complete · `[~]` in-progress/next · `[b]` human-gated.
>
> **First remaining work:** Phase 1 human review gate (contracts/registry);
> frequency layer; A2/B1 appendix topic extractors. ViU unit groups and YLE
> grammatical groups are implemented as overlays.

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

- [x] Task: Build Cambridge group extraction fixtures
  - [x] Cover YLE grammatical groups and A2/B1 Appendix word sets
- [x] Task: Build Vocabulary in Use fixtures
  - [x] Cover elementary frontmatter/index structure sample
  - [x] Cover remaining three frontmatter and index layouts
  - [x] Cover unmatched, multi-unit, and variant fixture cases (schema)
- [x] Task: Build frequency metadata fixtures
  - [x] Cover words, MWEs, missing scores, unreliable scores, and rank ties
- [x] Task: Build enrichment isolation and determinism tests
- [x] Task: Verify Phase 2

**Green evidence (2026-08-11):**

- Structure fixtures under `english/cefr-vocabulary/fixtures/enrichment/` for
  Cambridge sources and all four ViU bands; frequency + isolation schemas.
- `bash tests/enrichment_p2_fixtures.sh` and `bash tests/enrichment_viu_layer.sh`.

## Phase 3: Implementation

- [x] Task: Implement Cambridge group extraction
  - [x] YLE grammatical category×stage groups (optional overlay)
  - [ ] A2 Key / B1 appendix topic extractors (topics already partly in core)
- [x] Task: Implement Vocabulary in Use catalogs and index matching
- [ ] Task: Implement selected frequency source integration
- [x] Task: Implement coverage and frequency quality reports
  - [x] ViU + grammatical quality reports (frequency still pending)
- [x] Task: Implement durable enrichment review queues
  - [x] ViU unmatched/ambiguous + grammatical unmatched queues

**ViU layer Green evidence (2026-08-11):**

- Builder: `scripts/build-viu-unit-groups.py`
- Overlay: `overlays/viu-unit-groups.overlay.json` — unit `content_group`s +
  `contains` co-membership; `unitNumberIsNotPrerequisite: true`;
  `prerequisite_for` count 0
- Semantics: co-taught lesson groups (GRAPH-DESIGN ViU rule)
- Core graph file untouched; optional regenerable extended merge gitignored
- Queues: `review/enrichment/queues/viu-unmatched.jsonl`,
  `viu-ambiguous.jsonl`
- Report: `reports/enrichment/viu-unit-groups.{json,md}`
- Harness: `bash tests/enrichment_viu_layer.sh`

**YLE grammatical layer Green evidence (2026-08-11):**

- Builder: `scripts/build-yle-grammatical-groups.py`
- Overlay: `overlays/yle-grammatical-groups.overlay.json`
- Restores freeze-omitted grammatical groups as selectable enrichment
  (`enrichment.cambridge.grammatical-groups`); match rate ≥ 0.98 on tokens
- Harness: `bash tests/enrichment_yle_grammatical.sh`
- Freeze decision YLE-2025-GRAMMATICAL-001 remains valid for core package

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
