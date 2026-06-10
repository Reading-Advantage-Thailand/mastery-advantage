# Implementation Plan: English Lexical Graph Core Release

> This track releases only the approved source-backed core. Coverage,
> semantic, and recommendation layers are independently gated follow-on tracks.

## Phase 1: Contract, Identity, And Review Schema

- [ ] Task: Freeze and report the current draft baseline
  - [ ] Generate counts and distributions from the tracked inventory and graph
  - [ ] Record generator version, source references, limitations, and open debt
  - [ ] Write `reports/core-baseline.json` and `reports/core-baseline.md`
  - [ ] Evidence: run baseline report command and record material results
- [ ] Task: Define versioned machine-readable contracts
  - [ ] Create schemas for inventory records, nodes, edges, source records,
        review decisions, and quality reports under `contracts/`
  - [ ] Define vocabulary-specific allowed node/edge endpoints and metadata
  - [ ] Define required provenance, confidence, review status, and quarantine
  - [ ] Define explicit zero-automatic-prerequisite policy
- [ ] Task: Define canonical lexical identity v1 and migration policy
  - [ ] Decide whether form-plus-POS is the v1 assessable unit
  - [ ] Define forms, POS, MWE, variants, optional senses, and special tokens
  - [ ] Define deterministic IDs and collision handling
  - [ ] Define correction, merge, split, alias, and deprecation migrations
- [ ] Task: Define durable review artifacts before audits begin
  - [ ] Create review queue and decision schemas
  - [ ] Define reviewer identity, rationale, timestamp, source location, and
        supersession fields
  - [ ] Define how accepted decisions feed deterministic regeneration
- [ ] Task: Approve Phase 1 contracts and thresholds
  - [ ] Curriculum/language reviewer approves identity and sampling policy
  - [ ] Engineering reviewer approves schemas, migration policy, and gates
  - [ ] Record decisions and unresolved issues in the track

## Phase 2: Contract And Regression Tests

- [ ] Task: Build contract and domain-adapter tests
  - [ ] Test required fields, enums, endpoint rules, and cross-field consistency
  - [ ] Test provenance, review status, quarantine, and zero-prerequisite rules
  - [ ] Test stable IDs, collisions, aliases, merges, and splits
- [ ] Task: Build extraction regression fixtures
  - [ ] Add bounded source-text fixtures for all Cambridge source layouts
  - [ ] Cover headers, examples, columns, punctuation, labels, variants, and
        phrasal verbs
  - [ ] Add expected normalized inventory and rejected-record fixtures
- [ ] Task: Build deterministic pipeline tests
  - [ ] Test source-registry checksums and parser/output declarations
  - [ ] Test partial-download rejection and valid-cache reuse
  - [ ] Test two-run byte identity without locale, clock, or random drift
- [ ] Task: Build quality-report and review-decision tests
  - [ ] Test distributions, baseline deltas, threshold failures, and quarantine
  - [ ] Test durable accepted, rejected, ambiguous, and superseded decisions
- [ ] Task: Verify Phase 2
  - [ ] Run all contract and regression tests
  - [ ] Record failing baseline behaviors before implementation changes

## Phase 3: Core Pipeline Implementation

- [ ] Task: Implement the source registry and artifact boundaries
  - [ ] Create `sources/source-registry.json`
  - [ ] Separate source-backed, normalized, derived, review, and release layers
  - [ ] Document unavailable and intentionally excluded sources
- [ ] Task: Harden source refresh
  - [ ] Download to temporary files and validate integrity before replacement
  - [ ] Verify registry checksums and PDF integrity
  - [ ] Make cache reuse and failure recovery observable
- [ ] Task: Implement canonical identity and stable IDs
  - [ ] Refactor normalization and merge behavior to the approved contract
  - [ ] Emit collision and ambiguous-merge review queues
  - [ ] Emit aliases and migrations where tracked IDs change
- [ ] Task: Implement the vocabulary domain adapter
  - [ ] Validate vocabulary metadata and allowed endpoints
  - [ ] Validate provenance, confidence, review status, and quarantine
  - [ ] Reject unsupported or unapproved `prerequisite_for` edges
- [ ] Task: Implement deterministic quality reporting
  - [ ] Emit `reports/core-quality.json` and `reports/core-quality.md`
  - [ ] Include counts, distributions, deltas, thresholds, and unresolved risks
  - [ ] Keep report ordering and serialization deterministic

## Phase 4: Extraction Audit And Remediation

- [ ] Task: Audit Cambridge alphabetical-list extraction
  - [ ] Review at least 200 stratified records per source
  - [ ] Measure precision and recall against durable source-location decisions
  - [ ] Remediate defects until every source meets release thresholds
- [ ] Task: Audit normalized merges and identity collisions
  - [ ] Review all high-severity collisions and suspected false merges
  - [ ] Review a stratified sample of cross-source merges
  - [ ] Resolve or quarantine every release-blocking ambiguity
- [ ] Task: Audit existing thematic-group memberships
  - [ ] Review at least 100 memberships per thematic-group source
  - [ ] Remove or quarantine groups that do not meet 98.0% precision
  - [ ] Record source section and extraction method for retained memberships
- [ ] Task: Verify Phase 4 quality gate
  - [ ] Regenerate quality reports and confirm all extraction thresholds
  - [ ] Obtain curriculum/language approval for retained core data

## Phase 5: Release Validation And Handoff

- [ ] Task: Run complete clean-room validation
  - [ ] Refresh or verify all registry sources
  - [ ] Regenerate tracked artifacts twice and confirm byte identity
  - [ ] Run schema, structural, provenance, extraction, and anomaly tests
  - [ ] Record current-size performance and non-blocking synthetic benchmarks
  - [ ] Run `node --check`, graph validation, and `git diff --check`
- [ ] Task: Produce bounded core integration fixtures
  - [ ] Cover words, MWEs, variants, multiple POS, alignments, groups, and aliases
  - [ ] Include valid, invalid, quarantined, and migrated examples
- [ ] Task: Produce core application-consumption guide
  - [ ] Define loading, version checks, released-layer filtering, and migrations
  - [ ] Define the boundary between this repository and consuming applications
- [ ] Task: Reconcile acceptance criteria and open debt
  - [ ] Link evidence for every acceptance criterion
  - [ ] Classify remaining limitations as accepted, blocking, or deferred
- [ ] Task: Record explicit core-release decision
  - [ ] Obtain curriculum/language and engineering approval
  - [ ] Record go, conditional-go, or no-go with rationale
  - [ ] Version release artifacts only for go or conditional-go

## Completion Rule

This track is complete when the approved source-backed core is reproducible,
audited, versioned, and safe for bounded application consumption. Follow-on
enrichment tracks do not block completion.
