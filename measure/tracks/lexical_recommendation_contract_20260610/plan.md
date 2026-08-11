# Implementation Plan: Vocabulary And Article Recommendation Contract

> **Status: COMPLETE (2026-08-11).** Phases 1–5 dual go. Portable offline
> contract handed to applications.

## Phase 1: Matching And Ranking Contracts

- [x] Task: Define article lexical-analysis contract — commit: f104489
- [x] Task: Define extensive-reading metrics — commit: f104489
- [x] Task: Define next-vocabulary candidate and ranking contract — commit: f104489
- [x] Task: Complete Phase 1 contract review gate — human-gate:both-owners — commit: 42623d1

**Evidence:** `RECOMMENDATION-CONTRACT.md`; `phase1-recommendation-approval.md` (go).

## Phase 2: Tests And Offline Fixtures

- [x] All fixture tasks complete (9 cases under `fixtures/recommendation/`). — commit: f104489 (4 cases), 42623d1 (5 cases)

## Phase 3: Reference Evaluation Implementation

- [x] `scripts/recommendation-contract.js` (`recommendation.v1`). — commit: f104489, 42623d1

## Phase 4: Offline Evaluation

- [x] Task: Define expert judgment and comparison procedure — commit: 8920998
- [x] Task: Evaluate matching and article metrics — commit: 8920998
- [x] Task: Evaluate ranking outputs and failure cases — commit: 8920998
- [x] Task: Tune only against recorded fixtures and decisions — commit: 8920998
- [x] Task: Complete recommendation/data review gate — commit: 8920998

**Evidence:** `recommendation-phase4-procedure.md`; judgments **9/9 pass**;
`phase4-recommendation-approval.md` (go); harness `tests/recommendation_phase45.sh`.

**Independent technical review (2026-08-11):**
`recommendation-phase4-independent-review.md`. `scripts/verify-recommendation-phase4.py`
re-derives every section 2 verdict from the fixtures — **67 checks, 67 pass** —
and three mutated fixtures confirm the checks can fail. All 9 recorded
judgments hold. Two gaps sit outside the checklist: matching applies no
lemmatization, so 8 of 18 unmatched spans are inflections of listed lemmas
(tech debt, High); and `exceededCap` is undocumented (tech debt, Low).
Teaching fitness remains an owner decision.

## Phase 5: Handoff Decision

- [x] Task: Produce recommendation contract and bounded integration fixtures — commit: 8920998
- [x] Task: Produce application-consumption and limitations guide — commit: 8920998
- [x] Task: Reconcile acceptance criteria and open debt — commit: 8920998
- [x] Task: Record explicit app-handoff decision — commit: 8920998

**Evidence:** `RECOMMENDATION-CONSUMPTION.md`;
`RELEASE-RECOMMENDATION-2026-08-11.md`; `phase5-recommendation-approval.md` (go).
Matched-token-only tech-debt **closed**.

## Completion Rule

Portable contract and offline evidence accepted. No production runtime required.
