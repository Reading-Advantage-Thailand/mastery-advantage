# Specification: English Lexical Graph Core Release

## Overview

Produce the first defensible, app-consumable release of the English
CEFR/Cambridge lexical graph. This track is limited to the source-backed
Cambridge inventory, lexical identity, graph contract, extraction quality,
provenance, deterministic generation, durable review artifacts, and release
governance.

Coverage expansion, semantic enrichment, and recommendation evaluation are
separate dependent tracks. They must not block a core release and must remain
quarantined until their own acceptance gates pass.

The current draft baseline contains 3,752 lexical skills and validates
structurally, but its extraction quality, identity stability, provenance
contract, and deterministic clean regeneration have not yet been accepted.

## Release Boundary

### Included In Core Release

- Cambridge YLE, A2 Key, and B1 Preliminary lexical inventory and alignments.
- Existing Cambridge exam and thematic groups that pass review.
- Versioned lexical identity, node, edge, source-reference, and review schemas.
- A vocabulary domain adapter and automated quality-report command.
- Extraction fixtures, reviewed samples, and durable reviewer decisions.
- Deterministic source refresh, generation, validation, and release artifacts.
- Stable ID and migration policy suitable for initial SRS adoption.

### Quarantined Or Deferred

- Vocabulary in Use coverage, B2+ expansion, and corpus frequency metadata.
- WordNet, ConceptNet, embedding, or other semantic relationships.
- Article lexical analysis, vocabulary ranking, and article recommendation.
- Any automatic vocabulary `prerequisite_for` edge.

## Functional Requirements

### FR-1: Versioned Core Contracts

- Define machine-readable schemas for lexical inventory records, graph nodes,
  graph edges, source registry records, review decisions, and quality reports.
- Define allowed vocabulary node kinds, edge types, endpoint rules, confidence,
  review statuses, and required provenance.
- Define an explicit policy prohibiting automatic vocabulary
  `prerequisite_for` edges in the core release.
- Define a vocabulary-domain adapter conforming to `SPECIFICATION.md`.

### FR-2: Stable Lexical Identity And Migration

- Define canonical identity fields for form, normalized form, match forms, part
  of speech, multi-word expressions, variants, and optional sense references.
- Define deterministic IDs and collision behavior.
- Decide and document whether form-plus-POS is the initial assessable unit.
- Define migration behavior for later corrections, merges, splits, and
  sense-level enrichment before any app adopts the IDs.
- Define treatment of names, numbers, abbreviations, function words, examples,
  and malformed source entries.

### FR-3: Source Registry And Reproducibility

- Maintain a machine-readable registry for every core source, including
  official URL, source version/date, checksum, scope, cache policy, parser,
  output artifacts, and permitted use.
- Separate cached source documents, normalized inventory records, derived
  records, review decisions, and release artifacts.
- Refresh sources without replacing valid cached files with partial or invalid
  files.
- Produce byte-identical tracked artifacts from two runs with identical inputs.

### FR-4: Extraction Quality

- Maintain bounded regression fixtures for headers, example sentences, wrapped
  columns, parenthetical labels, punctuation, variants, and phrasal verbs.
- Audit every Cambridge source and relevant section with stratified,
  human-reviewed samples.
- Measure precision and recall against durable review decisions.
- Detect collisions, duplicates, malformed entries, false merges, and
  suspicious group memberships.

### FR-5: Review And Quality Evidence

- Define durable, machine-readable review queues and decision records before
  extraction audits begin.
- Generate machine-readable and Markdown quality reports.
- Report counts and deltas by source, CEFR, exam, part of speech, lexical-unit
  type, group, edge type, and review status.
- Distinguish accepted graph truth from rejected, unresolved, and quarantined
  records.

### FR-6: Core Release And App Handoff

- Define semantic versioning, breaking-change rules, review-status promotion,
  deprecation, and migration requirements.
- Provide bounded integration fixtures and an application-consumption guide.
- Record an explicit core-release go, conditional-go, or no-go decision.
- Permit downstream apps to consume only approved core-release layers.

## Quality Thresholds

The first contract review may tighten these thresholds but must not weaken them
without recorded rationale.

| Measure | Core-release threshold |
|---|---:|
| Alphabetical-list extraction precision | At least 99.5% per source |
| Alphabetical-list extraction recall | At least 99.0% per source |
| Retained thematic-group membership precision | At least 98.0% per source |
| Required provenance coverage | 100% |
| Schema and structural validation | 100% pass |
| Unapproved `prerequisite_for` edges | 0 |
| Deterministic regeneration | Byte-identical twice |
| Unresolved high-severity identity collisions | 0 |

Each extraction source requires a reviewed sample of at least 200 records or
all records when the population is smaller. Each retained thematic-group source
requires at least 100 reviewed memberships, stratified across groups.

## Required Artifacts

- `english/cefr-vocabulary/contracts/`
- `english/cefr-vocabulary/sources/source-registry.json`
- `english/cefr-vocabulary/review/decisions.jsonl`
- `english/cefr-vocabulary/review/queues/`
- `english/cefr-vocabulary/fixtures/`
- `english/cefr-vocabulary/reports/core-quality.json`
- `english/cefr-vocabulary/reports/core-quality.md`
- `english/cefr-vocabulary/APP-CONSUMPTION.md`
- `english/cefr-vocabulary/RELEASE.md`

## Non-Functional Requirements

- **Reproducibility:** identical inputs produce byte-identical tracked outputs.
- **Traceability:** every released node and edge has accepted provenance or a
  complete accepted derivation chain.
- **Auditability:** review decisions and quality metrics are durable and
  comparable between versions.
- **Portability:** core contracts remain application-neutral.
- **Performance:** generation and validation performance at current graph size
  is measured and recorded. Larger synthetic-scale results are advisory and do
  not block the first core release.

## Acceptance Criteria

- AC-1: All required contracts and the vocabulary domain adapter pass tests.
- AC-2: Source refresh and two clean generations complete with byte-identical
  tracked outputs.
- AC-3: Extraction and retained thematic groups meet the defined sample sizes
  and quality thresholds.
- AC-4: Required provenance coverage is 100%, and no released record is
  unresolved or quarantined.
- AC-5: No inferred `prerequisite_for` edges exist.
- AC-6: Stable-ID, collision, merge, split, and migration policies are complete.
- AC-7: Core quality reports, bounded fixtures, consumption guide, and release
  notes are complete.
- AC-8: Curriculum/language and engineering reviewers record an explicit core
  release decision.

## Out Of Scope

- Additional lexical sources and B2+ coverage.
- Frequency, semantic, similarity, and relatedness enrichment.
- Recommendation ranking or article matching.
- Treating 100,000-node synthetic-scale performance as a first-release gate.
- Application databases, APIs, SRS persistence, UI, or production runtime.
- Republishing publisher PDFs.
