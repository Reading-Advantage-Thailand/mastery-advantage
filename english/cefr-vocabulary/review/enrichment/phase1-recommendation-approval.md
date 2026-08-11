# Vocabulary And Article Recommendation Contract: Phase 1 Approval

**Decision:** go  
**Date:** 2026-08-11  
**Approved by:** curriculum/language owner and engineering owner (session confirmation)

## Decision

Both owners record **go** for Phase 1 of
`lexical_recommendation_contract_20260610`.

### Accepted

1. `RECOMMENDATION-CONTRACT.md` — matching, eligibility, metrics, ranking
2. Unmatched lexical spans stay in the eligible known-coverage denominator
3. Matched-token-only coverage is diagnostic, not primary
4. Numbers are skipped (not hard unmatched vocabulary)
5. Next-vocabulary ranking is explainable; no `prerequisite_for`
6. Article-fit utility formula unlocked for DomainUtilityProvider when the app
   supplies an active article (weight remains product-configured; design default
   may rise above 0 after this go)

## Provenance

Explicit user direction in session 2026-08-11: “Phase 1 approval. Move on to
phases 2 and 3.”
