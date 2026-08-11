# GSE Grammar Inventory And Inflection-Level Identity

## Problem

Cambridge vocabulary lists are lemma-only. The graph holds `be` and `have` once
as verb (pre-A1) and once as auxiliary (A2). No inflected form appears anywhere:
`is`, `am`, `are`, `was`, `were`, and `been` are in no `matchForms`.

Recommendation matching (`RECOMMENDATION-CONTRACT.md` §2.3) matches literal
`matchForms` only. Every inflected form therefore classifies as `unmatched`,
which the contract defines as hard unmatched vocabulary. In the 9-case fixture
pack, 8 of 18 unmatched spans are inflections of a listed lemma. This inflates
the primary `unmatchedTokenRate`, depresses `eligibleKnownCoverage`, and
contradicts the source: Cambridge teaches `be` at pre-A1 Starters.

The obvious fix is unsafe. One lemma spans four CEFR bands: `is`/`am`/`are`
pre-A1, `was`/`were` about A1, `have been` about B1, `had been` about B2.
Mapping every inflection onto the lemma would report B2 constructions as
first-level material, which is the worse error.

The GSE Grammar inventory in the Pearson GSE Teacher Toolkit carries a GSE score
per structure, and this project already maps GSE scores to CEFR bands
(`english/README.md`). It is the source that resolves per-form levels in units
already in use.

## Goal

Acquire the GSE Grammar inventory, graph it as an independently gated enrichment
layer, specify inflection-level identity, and change recommendation matching so
an inflected form resolves at its own level — without rewriting the frozen core
and without inventing a level for any form.

## Source Identity

Primary source, owner-supplied 2026-08-11 (GSE Teacher Toolkit, authenticated):

```
https://www.english.com/gse/teacher-toolkit/user/grammar
  ?page=1&sort=gse;asc&gseRange=10;90&audience=GLGR
  &grammaticalCategories=Verb;Tags%20and%20question%20forms;Pronoun;Preposition
    ;Phrase;Phrasal%20verb;Number;Noun;Modal%20verb;Determiner;Conjunction
    ;Clause;Adverb;Adjective
```

- Audience `GLGR` (general grammar), GSE range 10–90, all 14 grammatical
  categories, sorted by ascending GSE score.

Adjacent sources recorded for provenance but **out of scope for this track**:

- Young-learner vocabulary — `audience=YL`, topic-filtered
- Adult vocabulary — `audience=GL`, category-filtered

Both vocabulary endpoints are documented here so the URLs are not lost. They
belong to a separate future track and must not widen this one.

## Functional Requirements

**FR-1 — Source acquisition and provenance.** `GSE_GRAMMAR_SOURCES.md` records
the Toolkit URL with its full query parameters, the product version, the export
date, the SHA-256 of the raw export, licensing and redistribution terms, and the
cache policy. If redistribution is not permitted, the raw export is Git-ignored
and only derived identities are tracked, following the YLE PDF precedent.

**FR-2 — Deterministic extraction.** An extractor produces GSE grammar
objectives carrying `gseScore`, CEFR band, grammatical category, and structure
text. Two consecutive runs produce byte-identical tracked output.

**FR-3 — Core isolation.** The inventory ships as overlay
`enrichment.gse.grammar`. The core graph file stays byte-identical, no core node
or edge is rewritten, and the layer emits `prerequisite_for` count 0.

**FR-4 — Inflection identity specification.** `INFLECTION_IDENTITY_SPEC.md`
defines when an inflected form carries its own level, how it relates to its
form+POS parent, and how periphrastic forms (`have been`, `had been`) interact
with longest-MWE matching. It states explicitly how this axis differs from
`SENSE_IDENTITY_SPEC.md`, which covers semantic senses only.

**FR-5 — Source-backed form-to-level mapping.** Every mapped inflected form
cites a GSE objective identifier. A form with no GSE-backed structure goes to a
durable queue and receives no level. No level is inferred, interpolated, or
guessed.

**FR-6 — Matching change under a version bump.** Recommendation matching
resolves a mapped inflected form to its own level instead of `unmatched`. The
change ships as a new contract version; `recommendation.v1` behaviour stays
reproducible for comparison.

**FR-7 — Independent gating.** Inflection resolution stays off by default until
both owners approve, following the layer-gating pattern used for semantic
weight.

**FR-8 — Durable review queues.** Unmapped forms and ambiguous mappings persist
in queues under the enrichment queue directory, and the coverage Phase 4 audit
allowlist (`COVERAGE_QUEUES`) is extended so the new queues do not leak into
that report.

**FR-9 — Dual human gates.** Separate recorded go/no-go decisions for the GSE
grammar layer and for the matching change, each transcribing owner words.

**FR-10 — Measured effect and regression.** The fixture pack's 8-of-18 result is
re-measured and reported, `scripts/verify-recommendation-phase4.py` re-derives
every case, and all harnesses stay green.

## Non-Functional Requirements

- Determinism: every generator is reproducible and idempotent.
- No invention: an absent GSE structure yields a queue row, never a level.
- Bounded artifacts: overlay size and queue growth are reported before approval.

## Acceptance Criteria

1. `GSE_GRAMMAR_SOURCES.md` cites the URL with query parameters, version, export
   date, SHA-256, and licence.
2. The overlay validates, and the core graph is byte-identical before and after.
3. Every mapped form cites a GSE objective ID; the unmapped queue is non-empty
   and explicit.
4. `is`, `am`, `are` resolve at pre-A1; `have been` and `had been` resolve above
   A1, each citing its GSE score.
5. The fixture-pack unmatched count drops, and the new figure is reported with
   labelled numerator and denominator.
6. Both human gates are recorded with owner words.
7. All harnesses exit 0, and previously approved artifacts are unchanged unless
   deliberately re-approved.

## Out of Scope

- GSE vocabulary inventories, young-learner and adult (URLs recorded above).
- B2 vocabulary expansion (`b2_vocabulary_source_expansion_20260611` stays
  parked).
- Sense-level identity (`sense_level_identity_spec_20260611` owns that axis).
- Any production runtime; this repository ships contracts and data only.
