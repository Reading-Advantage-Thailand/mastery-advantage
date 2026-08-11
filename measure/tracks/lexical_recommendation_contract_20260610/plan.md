# Implementation Plan: Vocabulary And Article Recommendation Contract

> **Intent:** Portable offline contracts for article matching, extensive-reading
> metrics, and next-vocabulary ranking with explainability. No production
> runtime. Unmatched hard words stay in the coverage denominator.

## Phase 1: Matching And Ranking Contracts

- [x] Task: Define article lexical-analysis contract
  - [x] Define token eligibility, lemmatization, variants, and longest-MWE match
  - [x] Define proper-name, number, punctuation, repetition, and unmatched rules
- [x] Task: Define extensive-reading metrics
  - [x] Define matched-token coverage and eligible-token known coverage
  - [x] Define unmatched-token rate, target density, repetition, and topic fit
  - [x] Define configurable thresholds and explainability fields
- [x] Task: Define next-vocabulary candidate and ranking contract
  - [x] Define optional signals, weights, exclusions, and tie behavior
  - [x] Define SRS urgency and learner-goal precedence
- [ ] Task: Complete Phase 1 contract review gate — human-gate:both-owners

**Green evidence (2026-08-11):**

- `english/cefr-vocabulary/RECOMMENDATION-CONTRACT.md`
- Reuses YLE reading lessons: unmatched in denominator; target cap; no
  `prerequisite_for`
- Article-fit formula documented for future DomainUtilityProvider weight > 0
- Harness: `bash tests/recommendation_contract.sh`

## Phase 2: Tests And Offline Fixtures

- [x] Task: Build lexical matching fixtures
  - [x] Cover MWEs, variants, inflections, names, numbers, and unmatched words
- [x] Task: Build article metric fixtures
  - [x] Include articles where matched-token coverage would overstate readability
- [x] Task: Build learner-state and vocabulary-ranking fixtures
- [x] Task: Build layer-isolation and explainability fixtures
- [x] Task: Verify Phase 2

**Green evidence (2026-08-11):**

- `fixtures/recommendation/` — hard-unmatched, numbers-skipped, matched-trap,
  yle-compat
- Self-check via `scripts/recommendation-contract.js --self-check`

## Phase 3: Reference Evaluation Implementation

- [x] Task: Implement application-neutral lexical matching reference
- [x] Task: Implement article metric reference
- [x] Task: Implement next-vocabulary ranking reference
- [x] Task: Implement deterministic explanation payloads

**Green evidence (2026-08-11):**

- `scripts/recommendation-contract.js` — `recommendation.v1`
- Ranking signals: frequency-utility, article-repetition, srs-urgency, goal-scope
- Optional frequency overlay pin from approved coverage layer

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
