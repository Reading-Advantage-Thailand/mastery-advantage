# Vocabulary And Article Recommendation Contract

**Status:** Phase 1 **go** (2026-08-11); Phases 2–3 reference + fixtures green.  
**Track:** `lexical_recommendation_contract_20260610`.  
**Runtime:** Offline pure functions over `(graphSnapshot, articleText, learnerState)` — no production API or DB.  
**Approval:** `review/enrichment/phase1-recommendation-approval.md`.

This contract generalizes the YLE reading fixtures (`yle-reading-contract.js`)
to the full inventory while remaining application-neutral.

## 1. Dependencies

| Input | Required? | Notes |
|---|---|---|
| Core graph skills + `matchForms` | yes | Frozen core |
| Learner mastery map | yes | Application state; never written onto graph |
| Frequency overlay | optional | Ranking signal only |
| Semantic layers | optional | Weight 0 in planner until approved relations ship |
| Coverage exam/topic groups | optional | Scope filters |

## 2. Tokenization And Eligibility

### 2.1 Tokenize

1. Scan text left-to-right.
2. Emit tokens matching `[A-Za-z][A-Za-z'-]*` or `[0-9]+`.
3. Normalize lexical tokens: lowercase; strip outer quotes; keep internal
   apostrophes/hyphens that survive `normalizeToken`.

### 2.2 Eligibility classes

| Class | Rule | In coverage denominator? |
|---|---|---|
| `lexical` | alphabetic token (after normalize non-empty) | **yes** |
| `number` | pure digits | no |
| `non_lexical` | empty after normalize | no |

Proper names are **not** auto-excluded in v1 (too error-prone offline). Apps
may pass `learnerState.ignoreSurfaceForms: string[]` to force non-match
without counting as hard unmatched.

### 2.3 Longest-MWE match

Against the active lexicon built from skill `metadata.matchForms`:

1. At each token index, try windows from length 6 down to 1.
2. Join normalized window tokens with a single space.
3. First hit wins (longest first).
4. Prefer multiword-expression unit when ties remain; then stable `skillId`.

### 2.4 Span classification

| Classification | Meaning |
|---|---|
| `known` | matched skill and mastery ∈ {known, mastered} |
| `unknown` | matched skill and mastery not known/mastered |
| `unmatched` | no lexicon hit for a **lexical** token/window |
| `skipped` | number / ignoreSurfaceForms / non_lexical |

**Hard rule:** unmatched lexical spans **remain in the eligible denominator**.
Matched-token-only known coverage may be reported as a diagnostic only; it
must not be the primary readability metric.

## 3. Article Metrics

Let E = count of eligible spans (`known` + `unknown` + `unmatched`).

| Metric | Formula | Primary? |
|---|---|---|
| `eligibleKnownCoverage` | known / E | **yes** |
| `unmatchedTokenRate` | unmatched / E | **yes** |
| `matchedTokenCoverage` | (known+unknown) / E | diagnostic |
| `unknownTokenRate` | unknown / E | secondary |
| `targetDensity` | recommendedNext spans / E | secondary |
| `repetitionScore` | mean occurrences of each unknown skill in article | secondary |

Default **advisory** thresholds (application may override; not calibrated on
production outcomes):

| Metric | Prefer |
|---|---|
| `eligibleKnownCoverage` | ≥ 0.90 for extensive reading |
| `unmatchedTokenRate` | ≤ 0.05 |
| `targetDensity` | ≤ 0.05 with cap on distinct targets |

Explainability: each metric carries `numerator`, `denominator`, and label.

## 4. Next-Vocabulary Candidates

### 4.1 Candidate set

Unmastered skills that:

1. Appear as `unknown` in the article evaluation (article-grounded), **or**
2. Are in the learner goal scope (exam cumulative / CEFR) when ranking without
   an article (catalog mode).

v1 reference implements **article-grounded** candidates first (same spirit as
YLE reading targets).

### 4.2 Ranking (reference)

```text
score(skill) =
    w_freq   * frequencyUtility(skill)     // RANKING_LAYER_SPEC, optional
  + w_article * articleRepetitionNorm(skill)
  + w_srs     * srsUrgency(skill)          // from learnerState.dueSkillIds
  + w_goal    * goalScopeBoost(skill)      // in cumulative goal exams
```

Default weights (sum 1.0): `w_freq=0.45`, `w_article=0.35`, `w_srs=0.15`,
`w_goal=0.05`.

Missing frequency → `frequencyUtility = 0` (does not invent zipf).

**Hard ban:** ranking never emits `prerequisite_for`. Readiness from false
prerequisites is not used (prerequisite-sparse domain).

### 4.3 Cap And ties

- `targetVocabularyCap` (default 5) hard-caps distinct targets.
- Tie-break: higher article count, then higher frequency utility, then
  `skillId` ascending.

### 4.4 Explainability payload

Each ranked item includes:

```json
{
  "skillId": "…",
  "score": 0.0,
  "signals": [
    { "source": "frequency-utility", "value": 0.0, "weight": 0.45 },
    { "source": "article-repetition", "value": 0.0, "weight": 0.35 },
    { "source": "srs-urgency", "value": 0.0, "weight": 0.15 },
    { "source": "goal-scope", "value": 0.0, "weight": 0.05 }
  ],
  "graphFacts": [],
  "learnerStateFields": []
}
```

## 5. Article-fit utility (for DomainUtilityProvider later)

When the ranking track turns on `articleFit` weight > 0, the recommended
scalar for a skill B relative to an active article A is:

```text
value_articleFit =
    0.5 * 1[B occurs in A as unknown]
  + 0.5 * min(1, count(B in A) / 3)
```

Phase 1 is dual-owner **go**. The planner may set `weight_articleFit > 0` when
an active article is in `LearnerContext`. Without an article, weight stays 0
(RANKING_LAYER_SPEC §6).

## 6. Layer isolation

| Mode | Lexicon scope |
|---|---|
| `core-only` | All skills in core graph `matchForms` |
| `yle-only` | Skills with YLE exam alignments only (compat with freeze fixtures) |
| `core+frequency` | Same lexicon; ranking may use frequency metadata |

Semantic edges are not required for matching.

## 7. Failure cases (must be fixture-covered)

1. Hard unmatched phrase remains in denominator (e.g. `quantum telescope`).
2. Matched-only coverage would look fine while unmatched rate is high.
3. Target list never exceeds cap.
4. Empty article → zero denominators handled (metrics 0).
5. Number tokens do not count as unmatched vocabulary.

## 8. Phase 1 gate

Phase 1 is complete when this contract is accepted. Fixtures and the offline
reference implementation may proceed under that acceptance.
