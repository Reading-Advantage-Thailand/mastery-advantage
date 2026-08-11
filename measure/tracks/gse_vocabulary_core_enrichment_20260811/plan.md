# Implementation Plan: GSE Vocabulary Core Enrichment

> **Intent:** Write source-backed GSE scores, bands, definitions, and examples
> onto existing core vocabulary nodes. Ship as a new core graph version under
> freeze discipline.
>
> **Marker vocabulary:** `[x]` complete · `[~]` in-progress/next · `[b]` human-gated.
>
> **Hard constraints:** the frozen YLE baseline stays reproducible; no data is
> invented; every mapped node cites a GSE `itemId`.
>
> **Owner decision recorded:** FR-6 option (b) — definition and example text is
> committed onto nodes. Owner words: "FR-6 (b) while we are not selling this
> product and it is only for the purposes they approved -- measuring mastery
> levels and planning instruction." (2026-08-11)

## Phase 1: Source Acquisition And Contracts

- [x] Task: Export and pin the GSE vocabulary inventories
  - [x] Export GL (11,586 items, GSE 10–67) and YL (3,024 items, GSE 10–59)
  - [x] Record URLs, API pattern, export date, and SHA-256 in
        `GSE_VOCABULARY_SOURCES.md`
  - [x] Record licence, redistribution terms, and cache policy
  - [x] Keep raw exports Git-ignored under `source-pdfs/`
- [x] Task: Record the FR-6 owner decision
  - [x] Update the redistribution section of `GSE_VOCABULARY_SOURCES.md`:
        definition and example text may be committed onto nodes; transcribe
        the owner words and date
- [ ] Task: Define the node-to-entry mapping contract
  - [ ] Define the binding rule: core node form + POS against GSE expression +
        grammaticalCategories, with audience handling for GL vs YL
  - [ ] Define starred `gse` values (70 GL items) and `temporaryGse` (129 YL
        items) semantics
  - [ ] Define the ambiguous and unmapped queue shapes
  - [ ] State the no-inference rule: an unmapped node receives no GSE data
- [ ] Task: Define the core mutation contract
  - [ ] Define node field names: GSE score, CEFR band, definition, example,
        `itemId` citation
  - [ ] Define the core version bump mechanics and the byte-diff report shape
  - [ ] Define YLE baseline reproducibility proof for the new version
- [ ] Task: Define review samples and thresholds
  - [ ] At least 100 stratified node-to-entry mappings for review
  - [ ] Precision threshold for the mapping sample
- [ ] Task: Complete Phase 1 review gate — human-gate:both-owners

## Phase 2: Tests And Fixtures

- [ ] Task: Build GSE vocabulary extraction fixtures
  - [ ] Cover GL and YL record layouts, starred `gse`, `temporaryGse`, and
        the YL short CEFR form
- [ ] Task: Build mapping fixtures
  - [ ] Multi-POS expressions, ambiguous bindings, unmapped nodes
  - [ ] Nodes whose Cambridge level disagrees with the GSE band
- [ ] Task: Build core-mutation and determinism tests
  - [ ] Assert the YLE baseline regenerates byte-identical
  - [ ] Assert the byte-diff report matches the actual mutation
- [ ] Task: Build the falsifier fixture
  - [ ] A node where a naive form-only mapping binds the wrong POS entry
- [ ] Task: Verify Phase 2

## Phase 3: Extraction, Mapping, And Core Mutation

- [ ] Task: Implement the deterministic GSE vocabulary extractor
  - [ ] Two consecutive runs produce byte-identical tracked output
- [ ] Task: Implement source-backed node-to-entry mapping
  - [ ] Every mapped node cites a GSE `itemId`
  - [ ] Ambiguous and unmapped cases go to durable queues under this track's
        own directory
- [ ] Task: Implement the core mutation generator
  - [ ] Write GSE score, band, definition, and example onto mapped nodes
  - [ ] Produce the new core version and the byte-diff report
- [ ] Task: Produce the mapping quality report
  - [ ] Labelled counts: nodes mapped, levels added, levels corrected,
        conflicts, unmapped queued, GSE entries with no node
- [ ] Task: Apply audit isolation
  - [ ] Name this track's queue files explicitly so foreign queue files
        cannot change its reports

## Phase 4: Audit And Calibration

- [ ] Task: Audit the node-to-entry mapping
  - [ ] Stratified sample against the Phase 1 threshold
  - [ ] Verify no node carries inferred data
- [ ] Task: Verify level reconciliation against the source
  - [ ] Confirm corrected values match the pinned export
  - [ ] Confirm Cambridge-vs-GSE conflicts keep both values visible
- [ ] Task: Curriculum review of the mapping sample — human-gate
- [ ] Task: Complete Phase 4 review gate — human-gate:both-owners

## Phase 5: Release Decision

- [ ] Task: Run deterministic regeneration and full validation
  - [ ] All harnesses exit 0; YLE baseline byte-identical
- [ ] Task: Produce the release and consumption record for the new core version
- [ ] Task: Reconcile acceptance criteria and close open debt
- [ ] Task: Record the mapping decision — human-gate:both-owners
- [ ] Task: Record the core version release decision — human-gate:both-owners

## Completion Rule

The mapping and the core version release are gated separately. The new core
version ships only on an explicit dual go, and no node receives data the
pinned GSE source does not state.
