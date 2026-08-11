# Recommendation Contract: Phase 5 App Handoff Approval

**Decision:** go  
**Date:** 2026-08-11  
**Approved by:** curriculum/language owner and engineering owner (session confirmation)

## Handoff package

| Artifact | Path |
|---|---|
| Contract | `RECOMMENDATION-CONTRACT.md` |
| Reference evaluator | `scripts/recommendation-contract.js` |
| Fixtures | `fixtures/recommendation/` |
| Consumption guide | `RECOMMENDATION-CONSUMPTION.md` |
| Phase 4 judgments | `review/enrichment/recommendation-phase4-judgments.jsonl` |
| Release index | `RELEASE-RECOMMENDATION-2026-08-11.md` |

## Scope of handoff

Applications **may** implement matching, metrics, and next-vocab ranking that
conform to the contract. This repository does **not** ship a production
recommendation service, API, or UI.

## Explicit non-claims

- Not learner-outcome calibrated
- Not a guarantee of reading comprehension
- Ranking features are not prerequisites
- Semantic WordNet edges are a separate track

## Decision

**go** for application handoff of the portable offline contract and fixtures.
