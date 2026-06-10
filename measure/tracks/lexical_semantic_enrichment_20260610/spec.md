# Specification: English Lexical Semantic Enrichment

## Overview

Evaluate typed lexical-semantic relationships as optional, independently
selectable graph layers. WordNet-style typed, sense-aware relations are the
first candidate. Embedding similarity and broad relatedness remain experiments
unless they independently meet accepted precision and utility thresholds.

## Dependency

This track depends on core stable lexical IDs, durable review decisions,
quarantine behavior, and a vocabulary semantic relation contract.

## Functional Requirements

- Represent semantic relation kind explicitly; do not encode antonymy,
  synonymy, hypernymy, meronymy, morphology, similarity, and relatedness as
  indistinguishable generic edges.
- Preserve source/model version, method, score where applicable, matched sense,
  confidence, and review status.
- Generate WordNet-style candidates using sense-aware matching and route
  ambiguity to review.
- Evaluate embedding similarity only as sparse, versioned mutual-neighbor
  candidates.
- Evaluate broad relatedness independently from semantic similarity.
- Maintain risk-based review queues stratified by relation type, score band,
  ambiguity, source, and graph impact.
- Permit each relation layer to be approved, quarantined, or rejected
  independently.

## Quality Gates

- Required provenance and derivation fields are present on 100% of candidates.
- No semantic candidate creates a `prerequisite_for` edge.
- Human-reviewed precision thresholds are defined per relation before release.
- Ambiguous sense matches never auto-promote to an approved layer.
- Consumers can exclude semantic layers without breaking core graph use.

## Acceptance Criteria

- The vocabulary semantic relation contract is approved before candidates are
  persisted as release artifacts.
- Every retained relation type meets its accepted precision threshold.
- Experimental or underperforming layers remain quarantined or are removed.
- Deterministic generation, review replay, and layer filtering pass.

## Out Of Scope

- Claiming semantic edges are mastery prerequisites.
- Recommendation runtime implementation.
- Requiring embeddings or broad relatedness for core graph release.
