# Implementation Plan: GSE Grammar Inventory And Inflection-Level Identity

> **Intent:** Give inflected forms their own source-backed level. Ship GSE
> grammar as an independently gated enrichment layer, then make recommendation
> matching inflection-aware under a new contract version.
>
> **Marker vocabulary:** `[x]` complete · `[~]` in-progress/next · `[b]` human-gated.
>
> **Hard constraints:** the frozen core stays byte-identical; no level is ever
> inferred; `prerequisite_for` count stays 0.

## Phase 1: Source Acquisition And Contracts

- [x] Task: Export and pin the GSE Grammar inventory
  - [x] Export the full grammar objective set from the Teacher Toolkit URL in
        `spec.md` (audience `GLGR`, GSE 10–90, all 14 grammatical categories)
  - [x] Record URL with query parameters, product version, export date, and
        SHA-256 in `GSE_GRAMMAR_SOURCES.md`
  - [x] Record licence, redistribution terms, and cache policy
  - [x] Git-ignore the raw export if redistribution is not permitted
- [ ] Task: Define the grammar-layer contract
  - [ ] Define layer ID `enrichment.gse.grammar`, node kind, and metadata shape
  - [ ] Define `gseScore`, CEFR band, category, and objective-ID provenance
  - [ ] Define the GSE-score to CEFR-band mapping, citing `english/README.md`
  - [ ] Define core isolation and the `prerequisite_for` ban
- [ ] Task: Define the form-to-structure mapping contract
  - [ ] Define how an inflected surface form binds to a GSE structure
  - [ ] Define the unmapped and ambiguous queue shapes
  - [ ] State the no-inference rule: an unmapped form receives no level
- [ ] Task: Define review samples and thresholds
  - [ ] At least 100 stratified form-to-structure mappings for review
  - [ ] Precision threshold for the mapping sample
- [ ] Task: Complete Phase 1 review gate — human-gate:both-owners

## Phase 2: Tests And Fixtures

- [ ] Task: Build GSE grammar structure fixtures
  - [ ] Cover the export layout, objective IDs, and score ranges
- [ ] Task: Build inflection fixtures spanning CEFR bands
  - [ ] `is`/`am`/`are` (pre-A1), `was`/`were`, `have been`, `had been`
  - [ ] Irregular forms whose surface diverges from the lemma
  - [ ] Periphrastic multiword forms that exercise longest-MWE matching
- [ ] Task: Build core-isolation and determinism tests
  - [ ] Assert the core graph is byte-identical after layer generation
- [ ] Task: Build the falsifier fixture
  - [ ] A text where naive lemma mapping would report a B2 form as pre-A1
- [ ] Task: Verify Phase 2

## Phase 3: Extraction, Layer, And Mapping

- [ ] Task: Implement the deterministic GSE grammar extractor
  - [ ] Two consecutive runs produce byte-identical tracked output
- [ ] Task: Build the `enrichment.gse.grammar` overlay
  - [ ] Structures as nodes with GSE score, band, and objective provenance
  - [ ] Core graph untouched; `prerequisite_for` count 0
- [ ] Task: Implement source-backed form-to-structure mapping
  - [ ] Every mapped form cites a GSE objective ID
  - [ ] Unmapped and ambiguous forms go to durable queues
- [ ] Task: Produce the grammar-layer quality report
  - [ ] Labelled counts: structures, mapped forms, unmapped, ambiguous
- [ ] Task: Extend the coverage Phase 4 audit allowlist
  - [ ] Add the new queues to `COVERAGE_QUEUES` so no report absorbs them

## Phase 4: Audit And Calibration

- [ ] Task: Audit the form-to-structure mapping
  - [ ] Stratified sample against the Phase 1 threshold
  - [ ] Verify no form carries an inferred level
- [ ] Task: Verify band boundaries against the source
  - [ ] Confirm `is`/`am`/`are` land at pre-A1 and perfect forms land above A1
- [ ] Task: Measure the effect on the recommendation fixture pack
  - [ ] Re-measure the 8-of-18 unmatched result with labelled numerator and
        denominator
- [ ] Task: Curriculum review of the mapping sample — human-gate
- [ ] Task: Complete Phase 4 review gate — human-gate:both-owners

## Phase 5: Inflection-Aware Matching

- [ ] Task: Specify inflection identity
  - [ ] Write `INFLECTION_IDENTITY_SPEC.md`
  - [ ] Define the relation between an inflected form and its form+POS parent
  - [ ] Define longest-MWE interaction for `have been` and `had been`
  - [ ] State how this axis differs from `SENSE_IDENTITY_SPEC.md`
- [ ] Task: Implement inflection resolution in the matching reference
  - [ ] A mapped inflected form resolves at its own level, not as `unmatched`
  - [ ] Resolution is off by default until the Phase 6 gate
  - [ ] `recommendation.v1` behaviour stays reproducible for comparison
- [ ] Task: Version the contract
  - [ ] Bump the contract version and document the behaviour change
  - [ ] Update `RECOMMENDATION-CONTRACT.md` §2.3 and the consumption limitations
- [ ] Task: Re-derive the Phase 4 checklist
  - [ ] `scripts/verify-recommendation-phase4.py` passes under both versions
- [ ] Task: Verify Phase 5

## Phase 6: Release Decision

- [ ] Task: Run deterministic regeneration and full validation
  - [ ] All harnesses exit 0; approved artifacts unchanged unless re-approved
- [ ] Task: Produce the release and consumption record
- [ ] Task: Reconcile acceptance criteria and close open debt
  - [ ] Close the lemmatization and inflection-axis tech-debt items
- [ ] Task: Record approve, quarantine, or reject per layer — human-gate:both-owners
- [ ] Task: Record the matching-change decision — human-gate:both-owners

## Completion Rule

The grammar layer and the matching change are gated separately. The layer may
ship while inflection resolution stays off. Matching changes only on an explicit
dual go, and no form receives a level the GSE source does not state.
