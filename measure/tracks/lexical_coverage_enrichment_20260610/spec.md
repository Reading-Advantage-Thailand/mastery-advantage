# Specification: English Lexical Coverage Enrichment

## Overview

Expand the approved core lexical graph with additional source-backed
pedagogical groups, defensible B2+ coverage, and reproducible frequency
metadata. Every enrichment layer is independently reviewable and remains
quarantined until it passes its own quality gate.

## Dependency

This track may begin design work after the core graph contracts are approved.
It may not publish release-layer records until the English Lexical Graph Core
Release defines stable IDs, provenance, review decisions, and artifact
boundaries.

## Functional Requirements

- Parse Cambridge grammatical groups and Appendix word sets with source
  locations and extraction confidence.
- Parse Vocabulary in Use unit catalogs and lexical indices for A2 through
  C1/C2 without treating unit order as prerequisite order.
- Preserve unmatched, ambiguous, and multi-unit index entries for review.
- Evaluate additional coverage sources for licensing, permitted use,
  reproducibility, scope, and pedagogical value before adoption.
- Select a reproducible frequency source and store frequency as versioned node
  metadata, never as graph edges.
- Report coverage, overlap, missing data, and anomalies by source, CEFR, POS,
  lexical-unit type, and audience.

## Quality Gates

- Source-backed membership precision is at least 98.0% per retained source.
- Required provenance and source-location coverage is 100%.
- All ambiguous matches are resolved or quarantined.
- Frequency source, version, missing-score policy, and reliability limitations
  are documented.
- No enrichment creates automatic `prerequisite_for` edges.

## Acceptance Criteria

- Contracts, fixtures, parsers, review queues, and quality reports pass.
- Every retained enrichment layer has an explicit approve, quarantine, or
  reject decision.
- Approved enrichment regenerates deterministically against the core release.
- Core graph consumers can exclude all enrichment without breaking.

## Out Of Scope

- Semantic relationships and embedding similarity.
- Article matching and recommendation ranking.
- Production application integration.
