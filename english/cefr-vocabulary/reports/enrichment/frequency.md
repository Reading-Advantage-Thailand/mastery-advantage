# Corpus Frequency Enrichment Report

- Layer: `enrichment.frequency.wordfreq`
- Source: `wordfreq` version `3.1.1` (language `en`)
- Calculated: **2026-08-11**
- Semantics: **scalar node metadata**, not an edge, not a prerequisite
- Skills processed: **3769**
- Scored (numeric zipf stored): **3374**
- Ranked (`rankWithinInventory` assigned): **3374**
- Missing, multi-token: **393**
- Missing, not in corpus: **2**
- Below reliability floor: **0**
- Max rank (dense): **397** over 397 distinct zipf values
- Zipf range: **1.64 .. 7.73**
- Core-data findings (reported, not repaired): **115** MWE label anomalies, **31** punctuation-leak forms, **2** whitespace forms scoring as one token, **377** duplicated forms
- Overlay edges: **0** — `prerequisite_for` in output: **0**
- Core graph untouched: **yes** (`cefr-vocabulary-knowledge-space.json`)

## Multi-token forms are excluded from scoring and ranking

`zipf_frequency("a good start", "en") == 5.45`
vs `zipf_frequency("cat", "en") == 4.78`.

wordfreq scores "a good start" at zipf 5.45, above "cat" at 4.78. That is not a phrase frequency: wordfreq combines the component token frequencies under an independence assumption, so a phrase of common words outranks a common noun. Multi-token scores are therefore not comparable to single-word zipf and must not enter the ranking.

A four-word phrase is not more frequent than the word *cat*. wordfreq has
no entry for the phrase at all; it tokenizes, looks up each token, and
combines the probabilities assuming independence. The result is a
well-formed number in the wrong unit — usable for nothing that compares
phrases with words.

### The rule is token count, not whitespace and not `lexicalUnit`

    exclude when len(wordfreq.tokenize(normalizedForm, "en")) > 1

Whitespace is the wrong test in both directions. It **misses** hyphenated
compounds and slash alternations that carry the identical defect:

| form | tokens | combined zipf |
|---|---|---:|
| `no-one` | `['no', 'one']` | 6.10 |
| `make-up` | `['make', 'up']` | 5.91 |
| `part-time` | `['part', 'time']` | 5.66 |
| `full-time` | `['full', 'time']` | 5.47 |
| `old-fashioned` | `['old', 'fashioned']` | 3.93 |
| `cafe/café` | `['cafe', 'café']` | 3.59 |

`no-one` at 6.10 sits in top-100-word territory, which is plainly wrong;
it is really `no` + `one` recombined. Whitespace also **over-fires**: the
2 `at / @` skills tokenize to `['at']` and are
correctly scored 6.70, because the lexical item is *at*.

`metadata.lexicalUnit` is not used either.
**115** skills carry
`lexicalUnit == "multiword-expression"` while `normalizedForm` is a
single token: the core parser applied the label whenever
`lexicalForm` held a parenthetical gloss ("ad (advertisement)", "apartment
(UK flat)", "autumn (US fall)", "catch (e.g. a ball)") while
`normalizedForm` is correctly a single token. Those words are scored.

Excluding hyphenated compounds loses a signal; including them injects a
wrong one. Losing a weak signal is the correct trade — GRAPH-DESIGN.md
already calls frequency "a deliberately weak default ordering".

Policy: any skill whose `normalizedForm` tokenizes to more than one token
gets `missing: true`, `missingReason: "multi-token-not-comparable"`, no `zipf`,
and no `rankWithinInventory`. `diagnostics.componentMinZipf` (the minimum
zipf over component tokens) and `diagnostics.combinedTokenEstimate` (the
rejected number itself) are recorded as **diagnostics only** and never feed
ranking; they exist so a reviewer can judge whether a phrase's rarest
component is itself rare.

### Excluded subtypes (`multiTokenKind`)

| kind | skills | example |
|---|---:|---|
| whitespace | 363 | `a good start`, `as ... as` |
| hyphen | 28 | `no-one`, `old-fashioned` |
| slash | 2 | `cafe/café` |
| other | 0 | — |

Precedence is whitespace, then hyphen, then slash, so a form with several
separators (`all right/alright`) is counted exactly once.

## Reliability floor

`RELIABILITY_FLOOR_ZIPF = 1.0` (named constant in `scripts/build-frequency-metadata.py`).

Zipf is `log10(occurrences per billion tokens)`, so zipf 1.0 is exactly
10 occurrences per billion tokens (relative frequency 1e-8). That is the
magnitude at which wordfreq truncates its merged wordlists: below it an
estimate rests on a handful of observations, usually contributed by a
single sub-corpus, and is dominated by OCR noise, tokenization artifacts,
and one-off spikes. Such a value is not a defensible ordering signal.

Policy: keep the number for inspection, set `reliable: false` and
`missingReason: "below-reliability-floor"`, and exclude the node from
`rankWithinInventory`. Rows land in
`review/enrichment/queues/frequency-unreliable.jsonl`.

In this build **0** skills fell below the floor (lowest scored zipf observed: 1.64). The floor is kept as an explicit guard for future inventory growth, not as dead code: any added rare or misspelled headword trips it instead of silently entering the rank.

## Rank tie policy

`rankTiePolicy: "dense-equal-rank"`. Zipf is reported to 2 decimals, so
3374 ranked skills collapse onto 397 distinct
values. **336** of those values are shared by more than one
skill, covering **3313** skills; the largest single tie holds
**35** skills.

Tied skills receive the *same* rank and the next distinct value receives
the next integer (dense, no gaps), so ranks run 1..397.
Sorting by rank never implies an ordering that the corpus does not support.

| zipf | rank | tied skills |
|---:|---:|---:|
| 4.72 | 188 | 35 |
| 4.85 | 175 | 27 |
| 4.75 | 185 | 27 |
| 4.42 | 218 | 27 |
| 5.19 | 141 | 26 |

## Core-data findings (reported, not repaired)

The core graph is frozen. These are findings for the coverage track,
queued in `review/enrichment/queues/frequency-label-anomalies.jsonl`.

1. **MWE label anomaly — 115 skills.** `lexicalUnit == "multiword-expression"` with a single-token `normalizedForm`, caused by a parenthetical gloss in `lexicalForm`. Note `mwe-label-single-token-form`. These skills are scored normally.
2. **Punctuation leak — 31 skills.** `normalizedForm` contains characters outside `[a-z0-9 '-]`, e.g. `english.vocabulary.skill.candy-uk-sweet-s.noun` has `"candy)"` (matchForms `["candy)", "sweet(s"]`). Note `unexpected-characters-in-normalized-form`. Forms are left untouched; the wordfreq tokenizer strips the stray punctuation, so `candy)` scores as *candy* (4.29), but the stored form itself is wrong.
3. **Whitespace form, single token — 2 skills.** Both are `at / @`, which tokenizes to `['at']` and scores 6.70. The score is right because the lexical item is *at*, but the form is malformed source data. Note `whitespace-form-scores-as-single-token`.
4. **Duplicate forms — 377 `normalizedForm` values shared by 828 skills.** Distinct senses of one word ("catch (e.g. a ball)" / "catch (e.g. a bus)", likewise "biscuit") receive identical zipf by construction. The dense equal-rank tie policy already gives them one shared rank; no special handling is applied.

## Consumer rule

This layer stores the raw corpus number only. Normalization to a
`utility(B)` score in [0,1] belongs to the
`frequency_semantic_ranking_layer_20260611` track via provider
`english.cefr.frequency-utility` (SPECIFICATION.md §10.3, decision D2).

Frequency is a **weak default ordering**. It must not override learner
goals, article relevance, review urgency, or source-backed pedagogical
grouping, and it must never be read as a prerequisite relation. Nodes
with `missing: true` have no ordering signal at all — rank them by other
features rather than assuming they are rare.

