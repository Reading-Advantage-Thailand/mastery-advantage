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
- **Matching applies no lemmatization.** A token matches only a literal
  `metadata.matchForms` entry (contract §2.3). An inflected form whose lemma is
  in the graph still counts as `unmatched`, which is hard unmatched vocabulary
  in the primary metrics. `be` is a skill; `is`, `are`, `am`, `was`, and `were`
  are not in any `matchForms`, so they raise `unmatchedTokenRate` and lower
  `eligibleKnownCoverage`. The same holds for `has` against `have`. In the
  9-case fixture pack, 8 of 18 unmatched spans are inflections of a listed
  lemma. Expect this effect to concentrate in beginner text. See
  `review/enrichment/recommendation-phase4-independent-review.md`.
- `rankedNextVocabulary.exceededCap` means the candidate pool was truncated to
  the cap. It does **not** mean the emitted list is over the cap; the list is
  always within `cap`.
- Frequency utility requires the approved frequency overlay.
- Article-fit planner weight is optional and needs article context
  (`RANKING_LAYER_SPEC.md` §6).

## 5. Debt

See `measure/tech-debt.md` for matched-token-only risk (closed by this
contract’s primary metric choice).
