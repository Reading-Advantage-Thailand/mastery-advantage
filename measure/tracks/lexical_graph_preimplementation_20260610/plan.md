# Implementation Plan: English Lexical Graph Pre-Implementation Readiness

> Planning and graph-readiness work only. Downstream application implementation
> is explicitly blocked until Phase 10 records a go decision.

## Phase 1: Baseline, Contracts, And Quality Gates

- [ ] Task: Freeze and describe the current draft baseline
  - [ ] Record generator/source versions and current node/edge/group counts
  - [ ] Produce baseline distributions by CEFR, exam, POS, and lexical-unit type
  - [ ] Record known limitations and current open tech debt
- [ ] Task: Define the versioned vocabulary graph contract
  - [ ] Define lexical node, group node, standard node, and source-reference metadata
  - [ ] Define allowed edge types, endpoint rules, confidence, and review status
  - [ ] Define explicit no-automatic-prerequisite policy
- [ ] Task: Define graph quality metrics and release thresholds
  - [ ] Establish extraction precision/recall targets
  - [ ] Establish semantic/group relationship precision targets
  - [ ] Establish provenance, coverage, and determinism gates
- [ ] Task: Build the initial automated quality-report command
  - [ ] Emit machine-readable and Markdown reports
  - [ ] Include current-version versus baseline deltas
- [ ] Task: Complete Phase 1 review gate
  - [ ] Obtain agreement on contracts, metrics, and thresholds

## Phase 2: Source Registry And Deterministic Pipeline

- [ ] Task: Create a machine-readable source registry
  - [ ] Record source IDs, official URLs, versions, checksums, scope, and cache policy
  - [ ] Record parser and output artifacts for every source
  - [ ] Record unavailable or intentionally excluded sources
- [ ] Task: Separate source-backed, normalized, and derived artifacts
  - [ ] Define directories and schemas for each artifact layer
  - [ ] Prevent derived data from being mistaken for source truth
- [ ] Task: Make clean source refresh reliable
  - [ ] Validate download reuse, failure recovery, checksums, and PDF integrity
  - [ ] Ensure source refresh cannot silently replace valid files with partial files
- [ ] Task: Enforce byte-identical deterministic regeneration
  - [ ] Add clean-run comparison test
  - [ ] Remove ordering, locale, clock, and random-state drift
- [ ] Task: Complete Phase 2 provenance and reproducibility audit

## Phase 3: Canonical Lexical Identity And Extraction Quality

- [ ] Task: Define canonical lexical identity v1
  - [ ] Specify lemma, lexical form, match forms, POS, MWE, variant, and sense fields
  - [ ] Specify IDs and collision behavior
  - [ ] Specify treatment of names, numbers, abbreviations, and function words
- [ ] Task: Build extraction regression fixtures
  - [ ] Include headers, example sentences, wrapped columns, parenthetical labels, and punctuation
  - [ ] Include British/American variants and phrasal verbs
- [ ] Task: Audit Cambridge exam-list extraction
  - [ ] Draw stratified samples from every source and section
  - [ ] Measure precision and recall against reviewed source pages
  - [ ] Fix parser defects and record unresolved exceptions
- [ ] Task: Audit normalized merges and duplicate handling
  - [ ] Review cross-source merges and conflicting POS/level assignments
  - [ ] Report ambiguous forms and suspected false merges
- [ ] Task: Design and evaluate sense-level identity enrichment
  - [ ] Compare source examples, Vocabulary in Use labels, and WordNet senses
  - [ ] Define when forms remain merged versus split into sense skills
- [ ] Task: Complete Phase 3 lexical-identity review gate

## Phase 4: Coverage Expansion And Pedagogical Groups

- [ ] Task: Complete Cambridge topic and word-set extraction
  - [ ] Replace or validate section-text matching with column-aware extraction
  - [ ] Add YLE grammatical groups and A2/B1 Appendix 1 word sets
  - [ ] Record source section and extraction confidence per membership
- [ ] Task: Parse Vocabulary in Use unit catalogs
  - [ ] Extract course level, unit number, unit title, and category
  - [ ] Validate frontmatter parsing against all four course bands
- [ ] Task: Parse Vocabulary in Use lexical-to-unit indices
  - [ ] Match index entries to lexical identities
  - [ ] Preserve unmatched, ambiguous, and multi-unit entries for review
  - [ ] Add unit membership groups without treating unit order as prerequisite order
- [ ] Task: Evaluate remaining coverage gaps
  - [ ] Report gaps by CEFR band, POS, lexical-unit type, and application audience
  - [ ] Recommend additional sources with provenance and usage constraints
- [ ] Task: Complete Phase 4 curriculum/language-specialist review gate

## Phase 5: Frequency And Usage Signals

- [ ] Task: Select and document the frequency source
  - [ ] Evaluate source coverage, license, update age, domains, and reproducibility
  - [ ] Define frequency versioning and refresh policy
- [ ] Task: Add frequency metadata
  - [ ] Compute scores and inventory-relative ranks for words and MWEs
  - [ ] Record missing and unreliable scores explicitly
- [ ] Task: Validate frequency behavior
  - [ ] Inspect distributions by CEFR, source, POS, and child/school vocabulary
  - [ ] Review high-frequency anomalies and source-specific bias
- [ ] Task: Define frequency use in ranking
  - [ ] Set frequency as a weak configurable feature
  - [ ] Prevent frequency from overriding learner goals or SRS urgency
- [ ] Task: Complete Phase 5 frequency-quality review gate

## Phase 6: Typed Semantic Relationships

- [ ] Task: Evaluate and select lexical-semantic sources
  - [ ] Assess WordNet, ConceptNet, and alternatives for coverage and provenance
  - [ ] Define retained relation types and source priority
- [ ] Task: Build sense-aware WordNet candidate generation
  - [ ] Preserve synset/sense IDs and relation types
  - [ ] Generate synonym, antonym, hypernym, hyponym, meronym, and morphology candidates
  - [ ] Route ambiguous matches to review rather than auto-accepting
- [ ] Task: Evaluate embedding-based similarity candidates
  - [ ] Select and version an embedding model
  - [ ] Compare cosine-neighbor behavior with source-backed groups and WordNet
  - [ ] Retain only sparse mutual-neighbor candidates above calibrated thresholds
- [ ] Task: Evaluate semantic relatedness candidates
  - [ ] Compare ConceptNet-style relations with thematic groups and article use
  - [ ] Keep relatedness distinct from similarity and equivalence
- [ ] Task: Implement risk-based semantic review queues
  - [ ] Sample by relation type, score band, source, and graph impact
  - [ ] Record accepted, rejected, and ambiguous decisions durably
- [ ] Task: Calibrate and retain only accepted semantic layers
  - [ ] Meet precision thresholds per retained relation
  - [ ] Remove or quarantine underperforming layers
- [ ] Task: Complete Phase 6 semantic-review gate

## Phase 7: Graph Validation, Performance, And Governance

- [ ] Task: Implement the vocabulary domain adapter
  - [ ] Validate required lexical metadata and cross-field consistency
  - [ ] Validate allowed group and relationship endpoints
- [ ] Task: Expand structural and provenance validation
  - [ ] Validate duplicates, dangling edges, source refs, confidence, and review status
  - [ ] Detect illegal or unsupported prerequisite edges
- [ ] Task: Add distribution and anomaly validation
  - [ ] Detect oversized groups, isolated skills, suspicious degree, and alignment anomalies
  - [ ] Detect unexpected source/level count regressions
- [ ] Task: Add performance and scale validation
  - [ ] Benchmark generation and validation at current size
  - [ ] Test synthetic scale to at least 100,000 nodes and 1,000,000 sparse edges
- [ ] Task: Define graph release/version governance
  - [ ] Define semantic versioning and breaking-change rules
  - [ ] Define review-status promotion and deprecation rules
- [ ] Task: Complete Phase 7 graph-governance review gate

## Phase 8: Vocabulary And Article Recommendation Contract

- [ ] Task: Define article lexical-analysis contract
  - [ ] Specify tokenization, lemmatization, MWE longest-match, variants, and unmatched tokens
  - [ ] Specify repeated-token and proper-name handling
- [ ] Task: Define vocabulary candidate and ranking contract
  - [ ] Combine SRS urgency, goal range, frequency, article occurrence, interests, and groups
  - [ ] Define explainability payload and configurable weights
- [ ] Task: Define extensive-reading article metrics
  - [ ] Specify known coverage, unknown density, target density, repetition, and topic fit
  - [ ] Define thresholds as configurable/calibratable rather than universal constants
- [ ] Task: Create offline ranking fixtures
  - [ ] Include representative learner states and article samples
  - [ ] Include expected ranking rationales and failure cases
- [ ] Task: Evaluate ranking quality offline
  - [ ] Record ranking metrics, qualitative review, and known limitations
  - [ ] Tune only against documented fixtures and reviewer decisions
- [ ] Task: Complete Phase 8 recommendation-contract review gate

## Phase 9: Human Review, Quality Report, And App Handoff

- [ ] Task: Build durable review artifacts and reviewer workflow
  - [ ] Define queues, decision schema, reviewer guidance, and audit trail
  - [ ] Define how accepted decisions feed regeneration
- [ ] Task: Execute final stratified quality review
  - [ ] Review source extraction, identity, groups, semantic edges, and ranking outputs
  - [ ] Record precision, rejection causes, and unresolved risks
- [ ] Task: Produce graph quality report
  - [ ] Summarize sources, coverage, distributions, relationships, and validation
  - [ ] Separate accepted graph truth from experimental or quarantined layers
- [ ] Task: Produce application-consumption guide
  - [ ] Define artifact loading, version checks, IDs, fixtures, and migration expectations
  - [ ] Define the boundaries between this repository and consuming applications
- [ ] Task: Produce bounded integration fixtures
  - [ ] Include representative nodes, groups, semantic relations, learner states, and articles
- [ ] Task: Complete Phase 9 app-team handoff review gate

## Phase 10: Final Readiness Decision

- [ ] Task: Run complete clean-room regeneration and validation
  - [ ] Refresh or verify sources from the registry
  - [ ] Regenerate all tracked artifacts twice and confirm byte identity
  - [ ] Run full validation, quality, scale, and ranking suites
- [ ] Task: Reconcile all acceptance criteria and open debt
  - [ ] Link evidence for every acceptance criterion
  - [ ] Classify remaining limitations as accepted, blocking, or deferred
- [ ] Task: Record explicit app-readiness decision
  - [ ] Obtain curriculum/language, engineering, and recommendation/data approval
  - [ ] Record go, conditional-go, or no-go with rationale
- [ ] Task: Freeze the first app-consumable graph release candidate
  - [ ] Tag/version artifacts and contracts only if decision is go or conditional-go
  - [ ] Publish migration and known-limitations notes

## Completion Rule

Do not mark this track complete merely because all generators run. Completion
requires accepted quality evidence and an explicit recorded readiness decision.
