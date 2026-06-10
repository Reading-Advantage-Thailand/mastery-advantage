# Specification: English Lexical Graph Pre-Implementation Readiness

## Overview

Bring the English CEFR/Cambridge lexical graph from a promising generated draft
to the best defensible pre-implementation state practical before any Advantage
application adopts it for vocabulary SRS, next-vocabulary selection, or
extensive-reading article recommendation.

The current baseline contains 3,752 lexical skills, 68 Cambridge topic groups,
and source-backed CEFR/exam alignments. This track must treat those counts as a
draft inventory, not as proof of semantic or pedagogical quality.

## Goals

- Produce a reproducible, versioned lexical graph with explicit provenance and
  uncertainty.
- Maximize useful coverage from available Cambridge exam lists, Vocabulary in
  Use indices/units, frequency data, and suitable lexical-semantic sources.
- Establish defensible grouping, semantic-relationship, and ranking layers
  without inventing false prerequisites.
- Quantify extraction, coverage, relationship, and recommendation quality.
- Deliver a stable consumption contract and readiness report for downstream
  application teams.

## Functional Requirements

### FR-1: Source Registry And Reproducibility

- Maintain a machine-readable registry of every source, version/date, official
  URL, checksum, local-cache policy, parser, and permitted use.
- Separate raw/source-backed records from normalized and derived records.
- Support deterministic clean regeneration from documented inputs.
- Record unavailable coverage explicitly, including the absence of an official
  B2 First/FCE wordlist.

### FR-2: Canonical Lexical Identity

- Define a versioned lexical identity contract covering lexical form, normalized
  matching forms, lemma, part of speech, multi-word expressions, spelling
  variants, inflections, and sense distinctions.
- Preserve source-specific labels while exposing canonical matching forms.
- Establish a policy for names, numbers, abbreviations, function words, and
  source examples.
- Detect and review collisions, duplicates, malformed entries, and ambiguous
  merges.

### FR-3: Source Coverage Expansion

- Complete and validate Cambridge YLE, A2 Key, and B1 Preliminary extraction.
- Parse Vocabulary in Use frontmatter and indices into unit memberships and
  course-band alignments for A2 through C1/C2.
- Evaluate additional defensible sources needed for Pre-A1/A1 gaps, B2, general
  English coverage, or sense-level enrichment.
- Produce coverage reports by source, CEFR band, part of speech, lexical-unit
  type, and overlap.

### FR-4: Source-Backed Grouping

- Represent Cambridge thematic, grammatical, word-set, and Vocabulary in Use
  unit groupings as `content_group` nodes with membership edges.
- Preserve source, section/unit, course band, unit number, and extraction
  confidence.
- Avoid dense pairwise edges merely because words share a group.
- Validate group extraction with quantitative and human-review samples.

### FR-5: Frequency And Usage Ranking

- Select and document a reproducible corpus-frequency source.
- Add frequency and inventory-relative rank as node metadata, not graph edges.
- Handle multi-word expressions and missing-frequency records explicitly.
- Evaluate frequency behavior across CEFR bands and child/school vocabulary.

### FR-6: Lexical-Semantic Relationships

- Evaluate WordNet or equivalent typed semantic relations at sense level.
- Represent synonymy, antonymy, hypernymy/hyponymy, meronymy, morphology, and
  related typed relations without collapsing them into generic equivalence.
- Evaluate embedding-based semantic similarity and ConceptNet-style relatedness
  as sparse candidate-generation layers.
- Persist source/model version, score, derivation method, confidence, matched
  sense, and review status for every derived semantic edge.
- Do not create automatic vocabulary prerequisite edges without a separately
  accepted necessity rule.

### FR-7: Graph Contract And Validation

- Define a vocabulary-domain adapter and metadata contract conforming to
  `SPECIFICATION.md`.
- Define allowed node/edge types and endpoint rules for lexical data.
- Add schema, structural, determinism, extraction-quality, provenance,
  distribution, and regression validation.
- Add bounded fixtures and golden samples covering polysemy, spelling variants,
  phrasal verbs, thematic groups, and semantic relations.

### FR-8: Vocabulary And Article Ranking Specification

- Define a vocabulary-specific next-item planner that combines readiness/SRS
  state with frequency, learner goals, article occurrence, interests,
  pedagogical groups, and review urgency.
- Define article lexical-analysis and matching contracts, including longest
  multi-word matching, lemmatization, unmatched-token handling, and coverage
  metrics.
- Define extensive-reading candidate metrics such as known coverage, target
  density, repetition, and topic fit.
- Produce offline evaluation fixtures and ranking-quality measures before app
  implementation.

### FR-9: Human Review And Calibration

- Define risk-based review queues for source extraction, ambiguous identity,
  group membership, semantic relations, and ranking anomalies.
- Establish minimum sample sizes and acceptance thresholds by relation/source
  risk.
- Record reviewer decisions in durable machine-readable artifacts.
- Use accepted decisions to calibrate thresholds and detect regressions.

### FR-10: Versioning And App Handoff

- Version graph schema, source registry, generated graph, quality report, and
  recommendation contract.
- Define backward-compatibility and migration expectations.
- Provide bounded fixtures and an application-consumption guide.
- Produce a final readiness report with accepted limitations and explicit
  go/no-go recommendation.

## Non-Functional Requirements

- **Reproducibility:** two clean generation runs from identical inputs produce
  byte-identical tracked artifacts.
- **Traceability:** every node and edge is source-backed or records a complete
  derivation chain.
- **Honest uncertainty:** low-confidence and unreviewed relationships are never
  presented as approved truth.
- **Scalability:** generation and validation remain practical for at least
  100,000 lexical/sense nodes and 1,000,000 sparse edges.
- **Auditability:** quality metrics and review decisions are durable and
  comparable between graph versions.
- **Portability:** contracts remain application-neutral.

## Acceptance Criteria

- AC-1: Clean regeneration and full validation pass from documented inputs.
- AC-2: Extraction audits show no known sentence/header contamination and meet
  agreed precision/recall thresholds on reviewed source samples.
- AC-3: Source, CEFR, group, POS, lexical-unit, and overlap coverage reports are
  generated and reviewed.
- AC-4: No inferred `prerequisite_for` edges exist without an accepted,
  documented necessity policy and reviewed evidence.
- AC-5: All derived semantic edges carry source/model version, method, score,
  confidence, and review status.
- AC-6: Human-reviewed samples meet accepted precision thresholds for each
  retained relationship layer.
- AC-7: Ranking fixtures demonstrate explainable next-vocabulary and article
  recommendations with recorded metrics and failure analysis.
- AC-8: Graph schema/version, migration policy, fixtures, quality report, and
  app-consumption guide are complete.
- AC-9: Final readiness review records explicit go/no-go decision before any
  downstream application implementation begins.

## Out Of Scope

- Application database schemas, APIs, SRS persistence, UI, or production
  article-recommendation implementation.
- Learner-data calibration requiring production telemetry not yet available.
- Republishing publisher PDFs.
- Claiming that the completed graph is a universal or exhaustive vocabulary
  curriculum.
