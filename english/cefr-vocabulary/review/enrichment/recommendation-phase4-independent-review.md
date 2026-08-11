# Recommendation Contract — Phase 4 Independent Technical Review

**Date:** 2026-08-11
**Reviewer:** assistant, acting as independent technical reviewer at owner direction
**Scope:** technical conformance only. Curriculum fitness stays with the owner.
**Verdict:** the 9 recorded judgments are correct. Two gaps sit outside the
checklist that produced them.

## 1. Why this review exists

`recommendation-phase4-judgments.jsonl` recorded 9 of 9 pass, and every row
named `reviewer: engineering-owner (session procedure)`. The assistant produced
those rows. `tests/recommendation_phase45.sh` then read the same file and
confirmed that it said "pass". No step recomputed a verdict, so the evidence
was a transcription checked against itself.

This review separates the two halves of Phase 4, following the rule that commit
`b6413f3` established for the semantic track:

- **Technical fidelity** — does the evaluator obey the written contract? The
  assistant can decide this, because each answer is computable.
- **Teaching fitness** — are the ranked words the right words to teach next?
  The owner decides this. The assistant must not.

Commit `b6413f3` archived a 12 × 100 subagent review that confused the two. That
review scored teaching fitness and produced a 41% non-accept rate that meant
nothing. This review does not repeat that error.

## 2. Method

`scripts/verify-recommendation-phase4.py` implements section 2 of
`recommendation-phase4-procedure.md` directly against the evaluator output. It
never reads the judgments file. It adds four invariants the checklist omits:

- eligible spans equal known + unknown + unmatched
- the coverage denominator equals the eligible span count
- span classifications agree with the reported counts
- a second run is byte-identical

**Result: 67 checks, 67 pass, 0 fail.** All 9 recorded judgments hold.

### Non-vacuity

A verifier that only confirms proves nothing. Three mutated fixtures show the
checks fail when the input is wrong:

| Mutation | Effect | Check result |
|---|---|---|
| Remove `quantum telescope` from `hard-unmatched` | unmatched 4 → 1 | correctly fails |
| Give `empty-article` real text | eligible 0 → 5 | correctly fails |
| Set `core-mode` profile to `yle-only` | lexiconMode changes | correctly fails |

## 3. Finding 1 — inflected forms count as hard unmatched vocabulary

**Severity: high. Not an evaluator defect.**

`be` exists as two skills. `is`, `are`, `am`, `was`, and `were` appear in no
`matchForms`. The evaluator therefore classifies `is` as `unmatched`, which
means "no lexicon hit for a lexical token". `has` behaves the same way against
`have`.

Across the 9 fixtures, **8 of 18 unmatched spans (44%) are inflections of a
lemma that is already in the graph.**

| Fixture | Unmatched | Inflections of a listed lemma |
|---|---|---|
| hard-unmatched | 4 | `is`, `is` |
| yle-compat | 5 | `has`, `is` |
| ranking-signals | 3 | `has`, `has`, `is` |
| core-mode | 1 | `is` |

This matters because `unmatchedTokenRate` is a **primary** metric and unmatched
spans stay in the coverage denominator. Copulas and auxiliaries are frequent in
beginner text, so the effect concentrates on the learner level this contract
serves. The primary readability signal reads those texts as harder than they are.

The evaluator is correct. Contract section 2.3 matches surface windows against
`metadata.matchForms` and defines no lemmatization step, so the behavior
conforms. The gap sits one level up:

- The Phase 1 plan task reads "Define token eligibility, **lemmatization**,
  variants, and longest-MWE match". The contract defines eligibility, variants,
  and longest-MWE match. It defines no lemmatization rule.
- `RECOMMENDATION-CONSUMPTION.md` section 4 lists three limitations. None of
  them tells an application that inflected forms count as hard unmatched
  vocabulary.

The checklist in section 2 of the procedure never tested inflection handling, so
9 of 9 pass and this gap are consistent.

**Recorded as tech debt.** Fixing it changes an approved contract and touches
the frozen core, so it is an owner decision, not a review action.

## 4. Finding 2 — `exceededCap` is undocumented and reads backwards

**Severity: low.**

`rankedNextVocabulary.exceededCap` is `true` whenever the candidate pool was
larger than the cap, so the list was truncated. It is `true` while `size` equals
`cap` and the emitted list is within bounds.

The field appears in neither `RECOMMENDATION-CONTRACT.md` nor
`RECOMMENDATION-CONSUMPTION.md`. The name reads as "the list exceeds the cap",
which is the opposite of the guarantee the evaluator enforces. This reviewer
misread it on first contact, which is the evidence that the name misleads.

`candidatesTruncated` would state the meaning. Renaming a field in a
handed-off contract is an owner decision.

## 5. What this review does not cover

- Whether the ranked words are pedagogically the right next words.
- Whether the ranking weights (frequency 0.45, article 0.35, SRS 0.15, goal
  0.05) suit real learners.
- Whether the fixture texts represent real reading material.

These need the curriculum owner. The tech-debt entry stays open for them.
