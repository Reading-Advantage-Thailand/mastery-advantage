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

### 3.1 The obvious fix is unsafe (owner, 2026-08-11)

Do not map every inflection of `be` onto `be.verb`. One lemma's forms are
taught across four CEFR bands:

| Form | Approximate level |
|---|---|
| `is`, `am`, `are` | pre-A1 Starters |
| `was`, `were` | about A1 (owner uncertain; confirm against the syllabus) |
| `have been` (present perfect) | about B1 |
| `had been` (past perfect) | about B2 |

The current behavior reports `is` as hard vocabulary, which **overestimates**
difficulty. A blanket lemma mapping would report `had been` as pre-A1, which
**underestimates** it. The second error is worse: it tells an application that a
B2 construction is first-level material.

**The Cambridge word lists cannot settle this.** They are lemma-only. The whole
graph holds exactly four relevant entries:

```
english.vocabulary.skill.be.verb                 cefr=pre-a1  forms=['be']
english.vocabulary.skill.be.auxiliary-verb-verb  cefr=a2      forms=['be']
english.vocabulary.skill.have.verb               cefr=pre-a1  forms=['have']
english.vocabulary.skill.have.auxiliary-verb-verb cefr=a2     forms=['have']
```

`is`, `am`, `are`, `was`, `were`, and `been` appear nowhere, in any list. The
YLE grammatical-groups layer is organized by part of speech per stage
(31 groups: adjectives, adverbs, modals, verbs …), not by tense or structure.

The authority that does settle it is the exam **grammar and structures
syllabus**, which this repository does not hold. Until that source is acquired,
any per-form level mapping would be invented. The same rule already governs the
parked B2 track: do not invent a Cambridge list.

### 3.2 This is a third identity axis

`SENSE_IDENTITY_SPEC.md` addresses **semantic** collapse — `bank` as finance
versus river. It does not mention inflection, tense, or aspect. Inflectional
identity is a separate problem with its own shape:

- The levels differ by form, not by meaning.
- `have been` and `had been` are multiword, so they interact with longest-MWE
  matching rather than with sense children.
- The parent lemma stays legitimately pre-A1 while some of its forms do not.

It needs its own specification rather than an extension of the sense track.

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

## 5. Scope correction (owner, 2026-08-11)

An earlier draft of this review held back "are these the right words to teach"
for the curriculum owner. The owner corrected that, and the correction is right.

Every skill in the graph carries a Cambridge source reference: 3060 from the B1
Preliminary list, 1684 from A2 Key, 1405 from the YLE word list. Professional
curriculum authors set those levels and built their exams on them. Level
appropriateness is therefore source-backed, and a second local judgment adds
nothing. The freeze already treats these lists as the authority.

This also sharpens finding 1. Cambridge places `be` at **pre-A1 Starters**, the
first level they teach. The contract reports `is` as hard unmatched vocabulary.
That contradicts the source the graph is built on, so finding 1 is a
source-fidelity defect and not only a matching convenience.

What genuinely stays local, and carries no source:

- the ranking weights `w_freq=0.45`, `w_article=0.35`, `w_srs=0.15`,
  `w_goal=0.05`
- `targetVocabularyCap = 5` and the tie-break order

`RECOMMENDATION-CONTRACT.md` §4.2 already labels these defaults that an
application may override, and §5 labels the thresholds uncalibrated. No runtime
in this repository consumes them. The residual risk is therefore low, and the
tech-debt entry is lowered to Low rather than held open as a curriculum gate.
