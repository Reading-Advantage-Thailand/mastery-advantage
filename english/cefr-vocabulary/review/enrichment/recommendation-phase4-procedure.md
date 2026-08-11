# Recommendation Contract — Phase 4 Offline Evaluation Procedure

**Track:** `lexical_recommendation_contract_20260610`  
**Date:** 2026-08-11  
**Fixtures:** `fixtures/recommendation/` (9 cases)  
**Reference:** `scripts/recommendation-contract.js`

## 1. Expert judgment procedure

1. Run `bash tests/recommendation_contract.sh` — must be green.
2. For each fixture case, run:
   ```bash
   node scripts/recommendation-contract.js evaluate \
     cefr-vocabulary-knowledge-space.json \
     fixtures/recommendation/<case> \
     overlays/frequency.overlay.json
   ```
3. Reviewer checks the case against the checklist in §2.
4. Record pass/fail in `recommendation-phase4-judgments.jsonl`.
5. No tuning of thresholds against production telemetry (out of scope).
6. Only fixture-backed changes are allowed; re-run self-check after any change.

## 2. Case checklist

| Case | Must hold |
|---|---|
| hard-unmatched | Unmatched hard phrase in eligible denominator; known coverage < 1 |
| numbers-skipped | Digit tokens classified skipped; not unmatched vocab |
| matched-trap | Matched-token coverage ≥ 0.85 while unmatched rate ≥ 0.05 |
| yle-compat | Unmatched present; targets ≤ cap |
| mwe-match | At least one span with longestMatchTokenCount ≥ 2 |
| ranking-signals | Due skill ranks first; frequency signal > 0; deterministic re-run |
| empty-article | Eligible count 0; metrics 0 |
| core-mode | lexiconMode is core-only |
| ignore-surface | ignoreSurfaceForms produces skipped span |

## 3. Failure analysis

Failures are recorded as:

```json
{"caseId":"…","check":"…","result":"fail","note":"…","reviewer":"…","date":"…"}
```

Open failures block Phase 5 handoff until fixed or accepted as known limitation
in the consumption guide.
