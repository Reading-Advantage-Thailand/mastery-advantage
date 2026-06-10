# Implementation Plan: Vocabulary And Article Recommendation Contract

## Phase 1: Matching And Ranking Contracts

- [ ] Task: Define article lexical-analysis contract
  - [ ] Define token eligibility, lemmatization, variants, and longest-MWE match
  - [ ] Define proper-name, number, punctuation, repetition, and unmatched rules
- [ ] Task: Define extensive-reading metrics
  - [ ] Define matched-token coverage and eligible-token known coverage
  - [ ] Define unmatched-token rate, target density, repetition, and topic fit
  - [ ] Define configurable thresholds and explainability fields
- [ ] Task: Define next-vocabulary candidate and ranking contract
  - [ ] Define optional signals, weights, exclusions, and tie behavior
  - [ ] Define SRS urgency and learner-goal precedence
- [ ] Task: Complete Phase 1 contract review gate

## Phase 2: Tests And Offline Fixtures

- [ ] Task: Build lexical matching fixtures
  - [ ] Cover MWEs, variants, inflections, names, numbers, and unmatched words
- [ ] Task: Build article metric fixtures
  - [ ] Include articles where matched-token coverage would overstate readability
- [ ] Task: Build learner-state and vocabulary-ranking fixtures
- [ ] Task: Build layer-isolation and explainability fixtures
- [ ] Task: Verify Phase 2

## Phase 3: Reference Evaluation Implementation

- [ ] Task: Implement application-neutral lexical matching reference
- [ ] Task: Implement article metric reference
- [ ] Task: Implement next-vocabulary ranking reference
- [ ] Task: Implement deterministic explanation payloads

## Phase 4: Offline Evaluation

- [ ] Task: Define expert judgment and comparison procedure
- [ ] Task: Evaluate matching and article metrics
- [ ] Task: Evaluate ranking outputs and failure cases
- [ ] Task: Tune only against recorded fixtures and decisions
- [ ] Task: Complete recommendation/data review gate

## Phase 5: Handoff Decision

- [ ] Task: Produce recommendation contract and bounded integration fixtures
- [ ] Task: Produce application-consumption and limitations guide
- [ ] Task: Reconcile acceptance criteria and open debt
- [ ] Task: Record explicit app-handoff decision

## Completion Rule

Completion means the portable contract and offline evidence are accepted. It
does not require production runtime implementation or learner telemetry.
