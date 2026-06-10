# Specification: Vocabulary And Article Recommendation Contract

## Overview

Define portable, explainable contracts and offline evaluation fixtures for
matching lexical skills to articles, ranking next vocabulary, and evaluating
extensive-reading candidates. This track specifies and tests behavior; it does
not implement a production recommendation service.

## Dependency

This track depends on approved core lexical identity, match forms, stable IDs,
version checks, and app-consumption boundaries. Coverage and semantic layers
are optional inputs and must never be required implicitly.

## Functional Requirements

- Define tokenization, lemmatization, longest-MWE matching, variants, proper
  names, repeated tokens, punctuation, numbers, and unmatched-token handling.
- Classify unmatched tokens so unknown difficult vocabulary cannot disappear
  from readability calculations.
- Define separate matched-token coverage, eligible-token known coverage,
  unmatched-token rate, target density, repetition, and topic-fit metrics.
- Define next-vocabulary candidate generation and ranking using configurable
  SRS urgency, learner goals, article occurrence, frequency, interests, and
  approved groups.
- Define explainability payloads showing the contribution and provenance of
  each ranking signal.
- Create offline fixtures with representative learner states, articles,
  expected rationales, edge cases, and failure cases.
- Evaluate ranking behavior against documented expert judgments without
  claiming production learner-outcome calibration.

## Acceptance Criteria

- Unmatched tokens are explicit and affect appropriate coverage metrics.
- Metric denominators and token eligibility rules are unambiguous.
- Core-only, coverage-enriched, and semantic-enriched inputs are independently
  supported.
- Offline fixtures demonstrate explainable outputs and recorded failure
  analysis.
- Recommendation/data and application reviewers record an explicit handoff
  decision.

## Out Of Scope

- Production APIs, databases, UI, article ingestion, or recommendation runtime.
- Learner-outcome calibration requiring production telemetry.
- Treating ranking features as prerequisite truth.
