# Recommendation Contract — Application Consumption Guide

**Status:** Phase 5 handoff go (2026-08-11).  
**Contract:** `RECOMMENDATION-CONTRACT.md` (`recommendation.v1`).

## 1. What the app must implement

| Capability | Contract rule |
|---|---|
| Tokenize article text | Alphabetic + numbers; normalize lexical tokens |
| Longest-MWE match | Against skill `matchForms`; window ≤ 6 |
| Classify spans | known / unknown / unmatched / skipped |
| Known coverage | **eligibleKnownCoverage** = known / (known+unknown+unmatched) |
| Unmatched rate | unmatched stays in denominator |
| Target list | Cap distinct unknowns; explainable ranking signals |
| Learner state | Mastery, due ids, goal stage live outside the graph |

## 2. Integration steps (bounded)

1. Load frozen core graph (optional: frequency overlay for ranking).
2. For each article + learner profile, call an evaluator equivalent to
   `recommendation-contract.js evaluate`.
3. Display primary metrics: eligible known coverage, unmatched rate.
4. Offer capped next-vocabulary from `rankedNextVocabulary.items`.
5. Do **not** write mastery onto graph nodes.

## 3. Offline verification

```bash
bash tests/recommendation_contract.sh
```

Fixture pack under `fixtures/recommendation/` is the regression oracle.

## 4. Limitations

- English CEFR inventory only; not general NLP.
- No production telemetry calibration.
- Proper-name detection is opt-in via `ignoreSurfaceForms`, not automatic.
- Frequency utility requires the approved frequency overlay.
- Article-fit planner weight is optional and needs article context
  (`RANKING_LAYER_SPEC.md` §6).

## 5. Debt

See `measure/tech-debt.md` for matched-token-only risk (closed by this
contract’s primary metric choice).
