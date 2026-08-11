# Frequency Layer Policy

**Scope:** the `enrichment.frequency.wordfreq` layer for the CEFR vocabulary
graph.
**Source:** `wordfreq`, pinned at version 3.1.1.
**Output:** node metadata in an overlay file. The layer creates no edges.
**Related:** `GRAPH-DESIGN.md`, section "Frequency".

This document records four policy decisions and the reason for each one. The
decisions are approved. This document does not open them again.

## 1. Field Shape

Each scored skill node gets one `frequency` object:

```json
{
  "frequency": {
    "source": "wordfreq",
    "sourceVersion": "3.1.1",
    "calculatedAt": "2026-08-11",
    "zipf": 5.42,
    "rankWithinInventory": 137,
    "reliable": true,
    "missing": false
  }
}
```

A node with `missing: true` carries a `missingReason`. It omits `zipf` and
`rankWithinInventory`.

The Zipf scale is logarithmic. A Zipf value of `x` means 10^x occurrences in
one billion words. A difference of 1.0 is a factor of 10 in frequency.

## 2. Inventory Figures

| Measure | Count |
|---|---:|
| Skill nodes in the core graph | 3,769 |
| `metadata.lexicalUnit == "word"` | 3,289 |
| `metadata.lexicalUnit == "multiword-expression"` (label only) | 480 |
| Whitespace in `metadata.normalizedForm` | 365 |
| Label without whitespace (gloss artifact, see 3.1) | 115 |
| **`normalizedForm` gives more than one token (excluded set)** | **393** |
| Skills that return `zipf == 0.0` | 2 |

The layer excludes the 393 multi-token forms. It does not use the 480 label
count. It does not use the 365 whitespace count. Section 3 gives the rule.
Section 3.1 gives the reason against the label.

## 3. Policy 1: Multi-Token Forms

This policy is the multi-word expression policy of the fixture. The layer
applies it to every form that gives more than one token.

**Rule.** The layer tokenizes `metadata.normalizedForm` with
`wordfreq.tokenize(form, "en")`. A form that gives more than one token gets
`missing: true` and `missingReason: "multi-token-not-comparable"`. The layer
excludes the skill from `rankWithinInventory`. This test selects 393 skills.

The token count is the only test. The layer does not test
`metadata.lexicalUnit`. Section 3.1 gives the reason. The layer does not test
whitespace alone. The classes below give that reason.

**Excluded classes.** The builder records the class in a `multiTokenKind`
field. The permitted values are `whitespace`, `hyphen`, `slash`, and `other`.

| `multiTokenKind` | Example form | Tokens | Count |
|---|---|---|---:|
| `whitespace` | `a good start` | `a`, `good`, `start` | 363 |
| `hyphen` | `no-one` | `no`, `one` | 28 |
| `slash` | `cafe/café` | `cafe`, `café` | 2 |
| `other` | — | — | 0 |

The `other` value covers any future form that the tokenizer splits for a
different reason. The current inventory holds none.

**Reason.** `wordfreq` does not hold phrase counts. For multi-token input it
combines the counts of the separate tokens. It applies an independence
assumption between the tokens. The result is an estimate under that
assumption, not a measured frequency of the item.

Two measured examples show the size of the error:

| Input | Tokens | `zipf_frequency(input, "en")` |
|---|---|---:|
| `"no-one"` | `no`, `one` | 6.10 |
| `"a good start"` | `a`, `good`, `start` | 5.45 |
| `"cat"` | `cat` | 4.78 |

The value 6.10 for "no-one" is the clearer example. A Zipf value of 6.10 is
the range of the 100 most frequent English words. "no-one" is not such a word.
The value is an artefact of the two frequent tokens "no" and "one". No
comparison is necessary to see the defect.

The phrase "a good start" shows the same failure against a control. It is not
more common than the word "cat". The value 5.45 comes from the very frequent
tokens "a" and "good". Neither number is a frequency of the lexical item.
Neither number is comparable to a single-word Zipf value.

**Consequence if the layer ignored this rule.** All 393 multi-token skills
would receive inflated values. Many of these forms contain function words such
as "a", "the", "of", "in", "no", and "up". These tokens raise the combined
estimate. The 393 skills would then rank above genuinely common single words
in any frequency-driven ranking. The ranking would put rare items before
high-utility common vocabulary.

**Why whitespace alone is not sufficient.** A hyphenated compound holds no
whitespace. The tokenizer still splits it. These measured values show the
defect:

| Form | Tokens | Zipf |
|---|---|---:|
| `no-one` | `no`, `one` | 6.10 |
| `make-up` | `make`, `up` | 5.91 |
| `part-time` | `part`, `time` | 5.66 |
| `full-time` | `full`, `time` | 5.47 |
| `old-fashioned` | `old`, `fashioned` | 3.93 |
| `cafe/café` | `cafe`, `café` | 3.59 |

A whitespace test passes all 30 of these forms into the ranking. The token
test excludes them.

**The trade.** The excluded set holds real lexical items that learners must
know. Examples are `part-time`, `full-time`, and `old-fashioned`. These
skills lose their frequency signal. The layer accepts that loss.

The alternative is worse. An included value is a wrong signal, not a weak one.
A wrong signal moves the item to the top of the ranking. A missing signal
moves it out of the frequency ordering only. `GRAPH-DESIGN.md` describes
frequency as a deliberately weak default ordering. Learner goals, article
relevance, review urgency, and source-backed groupings still rank these
skills. The loss of a weak signal is therefore the correct trade.

A future source that holds true compound and phrase frequencies could restore
these values. Such a source would need its own `source` and `sourceVersion`
values. It would not change this policy for `wordfreq`.

**Diagnostic option.** The builder may record `componentMinZipf`. This is the
lowest Zipf value of the component tokens. It is a diagnostic value only. It
must never feed `rankWithinInventory` or any ranking.

### 3.1 Count Discrepancy: 480 Versus 365

The two possible tests do not return the same set. There are 480 skills with
`lexicalUnit == "multiword-expression"`. There are 365 skills with whitespace
in `normalizedForm`. The difference is 115 skills.

A check of the core graph shows the cause:

- The whitespace set is a strict subset of the label set. No skill has
  whitespace in `normalizedForm` without the `multiword-expression` label.
- All 115 difference skills carry a parenthetical gloss in `lexicalForm`. The
  parser saw the space inside that gloss. It then applied the
  `multiword-expression` label. The lexical item itself is one word.

| `lexicalForm` | `normalizedForm` |
|---|---|
| `ad (advertisement)` | `ad` |
| `apartment (UK flat)` | `apartment` |
| `autumn (US fall)` | `autumn` |

**The discriminator is the token count of `normalizedForm`.** The label
`lexicalUnit` is not a reliable discriminator for this layer.
`normalizedForm` holds the lexical item that the layer sends to `wordfreq`.
The label holds a parser judgement about the source form.

The 115 gloss artifacts stay scored under the token rule. `ad`, `apartment`,
and `autumn` each give one token. The token rule therefore keeps the correct
result for them without any special case.

**Consequence if the layer used the label.** The layer would exclude 115
common single words from scoring and from ranking. The list holds
`apartment`, `autumn`, `backpack`, `band`, `biscuit`, `catch`, and `among`.
Each one has a valid and comparable single-word Zipf value. The layer would
remove that value without any report to the consumer. A frequency-driven
ranking would then hold no entry for 115 high-utility words. This is the exact
failure that the frequency policy must prevent.

The two errors are opposite. Section 3 prevents inflated values for 393
multi-token forms. This section prevents lost values for 115 single words.

#### Data-Quality Finding: Label Anomaly

115 skills carry `lexicalUnit == "multiword-expression"` with a single-token
`normalizedForm`. The label is incorrect for these skills.

The core graph `cefr-vocabulary-knowledge-space.json` is frozen. This layer
therefore reports the anomaly. It does not repair the core graph. The builder
writes each affected skill to
`review/enrichment/queues/frequency-label-anomalies.jsonl`.

#### Data-Quality Finding: Punctuation Leak

Some `normalizedForm` values hold punctuation from the source gloss. The
source form `candy (UK sweet(s))` produces `normalizedForm` `candy)` and
`matchForms` `["candy)", "sweet(s"]`. The nested parentheses defeated the
parser.

This anomaly is also reported, not repaired. The builder writes these skills
to the same review queue.

#### Data-Quality Finding: Alternation Forms

Two skills hold the `normalizedForm` value `at / @`. The source form is
`at / @`. The parser kept the separator and the symbol.

`wordfreq` gives one token for this form, `at`. The score is Zipf 6.70. That
value is correct for the lexical item "at". The stored form is still
malformed. These two skills are reported to the same review queue. The layer
does not repair them.

#### Confirmed Harmless: Trailing Punctuation

`wordfreq` removes punctuation at the edge of a token. A future reader does
not need to investigate this class again. The measured results:

| Form | Tokens | Zipf |
|---|---|---:|
| `candy)` | `candy` | 4.29 |
| `candy` | `candy` | 4.29 |
| `café` | `café` | 3.75 |
| `don't` | `don't` | 6.20 |
| `a.m.` | `a.m` | 4.35 |
| `cheers!` | `cheers` | 4.13 |

`candy)` returns the same value as `candy`. The other forms each give one
token and score normally. The punctuation defect therefore changes no score.
It appears only in the review queue.

## 4. Policy 2: Missing Values

**Rule.** A returned value of `zipf == 0.0` gets `missing: true` and
`missingReason: "not-in-corpus"`. The layer excludes the skill from
`rankWithinInventory`. The layer never stores 0.0 as a real score.

**Reason.** `wordfreq` returns 0.0 when the word is absent from the corpus.
The value is a sentinel for "no data". It is not a measurement of zero
frequency. A stored 0.0 is a false measurement. It would place the word at the
bottom of the ranking as if the corpus had measured it there.

**Size.** Only 2 of 3,769 skills return 0.0. The policy is therefore cheap.
The two skills keep their node and their other metadata. They lose only the
frequency score.

## 5. Policy 3: Reliability Floor

**Rule.** A value below the reliability floor keeps its `zipf` value. The node
gets `reliable: false` and `missingReason: "below-reliability-floor"`. The
layer excludes the node from `rankWithinInventory`. The floor is a named
constant in the builder. Its default value is Zipf 1.0. The report records the
floor value.

**Reason for a floor.** The Zipf estimate at the tail comes from very small
counts. A Zipf value of 1.0 is 10 occurrences in one billion words. At that
count, the difference between two words is noise from corpus selection. It is
not a difference in the language. The corpora that `wordfreq` combines have
different sizes and different subjects. The tail is where their disagreement
is largest. A rank order built from tail values is not stable between source
versions.

**Reason to keep the value.** The value is still evidence. A later consumer
can use it, or a reviewer can compare it with a different source. The layer
therefore keeps the number and marks it. It does not delete it.

**Reason to leave the ranking.** `rankWithinInventory` is an ordering claim.
The layer makes that claim only for values it can defend. A flagged node
carries data but makes no ordering claim.

## 6. Policy 4: Rank Ties

**Rule.** Equal `zipf` values share one rank. The layer uses dense equal
ranking. The overlay header records `rankTiePolicy: "dense-equal-rank"`.

**Reason.** Two skills with the same Zipf value carry the same evidence. A
strict total order would give one of them a better rank. The graph has no data
to support that order. The rank would come from the sort order of the input
file or from the identifier. This is a false measurement, and it is not
stable. A change to the input order would change the ranking without any
change in the data.

Dense equal ranking keeps the output deterministic between runs. It also keeps
the output honest: two equal values produce one rank.

## 7. Ownership Boundary

This layer produces the raw number as node metadata. Its output is `zipf`,
`rankWithinInventory`, and the missing and reliability flags.

This layer does **not** scale the value to the range 0 to 1.

The `frequency_semantic_ranking_layer` track converts the raw number to
`utility(B)` in the range 0 to 1. It does this through the provider
`english.cefr.frequency-utility`. See `SPECIFICATION.md` section 10.3 and
decision D2.

The reason for the split is the provider contract. Section 10.3 requires the
composition of signals inside the provider. The provider also holds the
version and the provenance of the composition. A scaled value in this layer
would duplicate that step. It would also fix a scale before the consumer knows
its weights.
