# Recommendation Contract — Phase 2 & 3 Verification

**Date:** 2026-08-11  
**Contract:** `recommendation.v1`  
**Reference:** `scripts/recommendation-contract.js`

## Phase 2 fixtures

| Case | Covers |
|---|---|
| `hard-unmatched` | Unmatched hard phrase in denominator |
| `numbers-skipped` | Digit tokens skipped |
| `matched-trap` | High matched-only coverage with non-trivial unmatched rate |
| `yle-compat` | YLE reading-style empty mastery + unmatched stress |
| `mwe-match` | Longest multi-token match (`look at`, etc.) |
| `ranking-signals` | Frequency utility, SRS-first, explainability, determinism |
| `empty-article` | Empty text → zero metrics |
| `core-mode` | `lexiconMode: core-only` isolation |
| `ignore-surface` | `ignoreSurfaceForms` skip |

Path: `fixtures/recommendation/`.

## Phase 3 reference behavior

- Longest-MWE match (window ≤ 6) on `matchForms`
- Classifications: known | unknown | unmatched | skipped
- Primary metrics: `eligibleKnownCoverage`, `unmatchedTokenRate`
- Ranking weights default: freq 0.45, article 0.35, srs 0.15, goal 0.05
- Each ranked item: 4 `UtilitySignal`-style signals + `articleFitUtility`
- Optional frequency overlay: `overlays/frequency.overlay.json`

## Verification

```bash
bash tests/recommendation_contract.sh
node scripts/recommendation-contract.js --self-check \
  cefr-vocabulary-knowledge-space.json fixtures/recommendation \
  overlays/frequency.overlay.json
```

Self-check: 9/9 cases green (2026-08-11).
