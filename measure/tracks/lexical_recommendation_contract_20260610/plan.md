# Implementation Plan: Vocabulary And Article Recommendation Contract

> **Status: COMPLETE (2026-08-11).** Phases 1–5 dual go. Portable offline
> contract handed to applications.

## Phase 1: Matching And Ranking Contracts

- [x] Task: Define article lexical-analysis contract
- [x] Task: Define extensive-reading metrics
- [x] Task: Define next-vocabulary candidate and ranking contract
- [x] Task: Complete Phase 1 contract review gate — human-gate:both-owners

**Evidence:** `RECOMMENDATION-CONTRACT.md`; `phase1-recommendation-approval.md` (go).

## Phase 2: Tests And Offline Fixtures

- [x] All fixture tasks complete (9 cases under `fixtures/recommendation/`).

## Phase 3: Reference Evaluation Implementation

- [x] `scripts/recommendation-contract.js` (`recommendation.v1`).

## Phase 4: Offline Evaluation

- [x] Task: Define expert judgment and comparison procedure
- [x] Task: Evaluate matching and article metrics
- [x] Task: Evaluate ranking outputs and failure cases
- [x] Task: Tune only against recorded fixtures and decisions
- [x] Task: Complete recommendation/data review gate

**Evidence:** `recommendation-phase4-procedure.md`; judgments **9/9 pass**;
`phase4-recommendation-approval.md` (go); harness `tests/recommendation_phase45.sh`.

## Phase 5: Handoff Decision

- [x] Task: Produce recommendation contract and bounded integration fixtures
- [x] Task: Produce application-consumption and limitations guide
- [x] Task: Reconcile acceptance criteria and open debt
- [x] Task: Record explicit app-handoff decision

**Evidence:** `RECOMMENDATION-CONSUMPTION.md`;
`RELEASE-RECOMMENDATION-2026-08-11.md`; `phase5-recommendation-approval.md` (go).
Matched-token-only tech-debt **closed**.

## Completion Rule

Portable contract and offline evidence accepted. No production runtime required.
