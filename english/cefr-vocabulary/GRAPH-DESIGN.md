# English Vocabulary Graph Design

## Purpose

This graph supports per-lexical-item SRS state and article recommendation. It
does not claim that vocabulary acquisition follows a single linear order.

The intended application flow is:

1. Track recognition and productive evidence for lexical skill nodes.
2. Schedule reviews per lexical skill or practice variant through the shared
   SRS contract.
3. Rank not-yet-mastered vocabulary using learner goals, CEFR alignment,
   observed article frequency, and lexical relationships.
4. Recommend extensive-reading articles whose known-word coverage is high
   enough while exposing a bounded number of recommended-next words.

## Node Model

Each lexical entry is represented as a `skill` node keyed by:

- normalized lexical form;
- part-of-speech set.

Separate part-of-speech uses remain separate skills because a learner may know
one use without knowing another. Exact matching entries across Cambridge lists
are merged and preserve all exam and CEFR alignments.

The current parser does not create distinct sense nodes when Cambridge
constrains a word meaning through example sentences. Sense-level parsing is a
future refinement and should use a licensed or otherwise suitable lexical
source.

## Edge Model

| Edge | Meaning |
|---|---|
| `contains` | Cambridge exam list contains a lexical skill |
| `aligned_to_standard` | Lexical skill aligns to a CEFR level |
| `supports` | Same spelling used as another part of speech |
| `supports` | Known component word supports a multi-word expression |

No vocabulary `prerequisite_for` edges are generated from the current source
lists. CEFR membership, frequency, semantic similarity, thematic grouping, and
pedagogical ordering are useful ranking signals, but none prove that one word
must be mastered before another.

## Relationship Layers

The vocabulary graph should combine several distinct relationship layers
without collapsing them into one generic edge.

| Layer | Representation | Confidence | Use |
|---|---|---:|---|
| Cambridge exam membership | `contains` | high | Alignment, goals, reporting |
| CEFR alignment | `aligned_to_standard` | high | Difficulty band, goals |
| Cambridge thematic list | topic `content_group` + `contains` | high | Learning sets, article topics |
| Vocabulary in Use unit | unit `content_group` + `contains` | high | Pedagogical grouping |
| Vocabulary in Use unit order | `metadata.unitNumber` | low-medium | Loose ranking only |
| Corpus frequency | node metadata | medium | Loose default ranking |
| WordNet typed relations | Quarantined semantic layer with explicit `metadata.semanticRelation` | medium-high | Sense-aware navigation and grouping |
| Embedding similarity | Quarantined similarity layer with explicit relation metadata | low | Candidate discovery and ranking |

Semantic enrichment must never make antonymy, synonymy, hypernymy, meronymy,
morphology, similarity, and broad relatedness indistinguishable to consumers.
Until the vocabulary semantic relation contract is approved, semantic
candidates remain quarantined and are not part of the app-consumable core
graph. The contract must define explicit relation kind, directionality,
matched sense, source/model version, derivation method, score where applicable,
confidence, and review status.

### Frequency

Frequency is a scalar feature on a lexical node, not an edge. A practical
source is `wordfreq`, which combines multiple corpora and produces a Zipf
frequency estimate. Preserve the source version and calculation date:

```json
{
  "frequency": {
    "source": "wordfreq",
    "sourceVersion": "...",
    "zipf": 5.42,
    "rankWithinInventory": 137
  }
}
```

Frequency gives a useful but deliberately weak default ordering. It should not
override learner goals, article relevance, review urgency, or source-backed
pedagogical groupings.

### Thematic And Grammatical Groups

The Cambridge YLE document includes both grammatical and thematic lists.
Thematic examples include animals, colours, family and friends, food and drink,
health, the home, places and directions, sports and leisure, and time.

Represent each group as a `content_group` node with `contains` edges to lexical
skills. A lexical skill may belong to multiple groups. Do not connect every
pair of words inside a group; that produces a dense graph without adding useful
meaning.

Grammatical sets such as days of the week, months, question words, and
frequency adverbs should also be groups. Their internal sequence, when
meaningful, belongs in membership metadata such as `sequenceIndex`, not in
prerequisite edges.

### Vocabulary In Use

Vocabulary in Use tables of contents and indices can provide:

- source-backed pedagogical groups through unit membership;
- CEFR/course-band alignment;
- a very loose ordering through unit number.

Unit order must not be interpreted as mastery prerequisites. Cambridge states
that at least some books can be studied in any order. Store unit number as a
ranking feature and create group membership edges.

### Semantic Similarity And Relatedness

**Semantic similarity** measures whether terms have similar meanings.
**Semantic relatedness** is broader and includes terms associated by context.

Useful programmatic sources:

- **WordNet:** typed, sense-level relations such as synonym, antonym,
  hypernym, hyponym, and meronym.
- **Word embeddings / fastText:** vector similarity from corpus usage.
- **ConceptNet:** broad commonsense relatedness.

WordNet relations should retain the matched sense or synset ID. Embedding edges
should be sparse, low-confidence, and generated only for mutual nearest
neighbors above a calibrated threshold. Distributional embeddings often place
antonyms near each other, so similarity must never imply equivalence or
prerequisite status.

For article recommendation, word-to-article embedding similarity is often more
useful as a runtime ranking feature than permanently storing thousands of
word-to-word similarity edges. Embedding and broad-relatedness layers are
optional experiments and do not block source-backed core or coverage releases.

Reference implementations and datasets:

- `wordfreq`: <https://pypi.org/project/wordfreq/>
- Princeton WordNet: <https://wordnet.princeton.edu/>
- fastText English vectors: <https://fasttext.cc/docs/en/english-vectors.html>
- ConceptNet: <https://conceptnet.io/>

## Planned Release And Enrichment Order

1. Release the audited source-backed core with stable IDs, migration rules,
   durable review decisions, and deterministic quality evidence.
2. Independently evaluate Vocabulary in Use groups, additional coverage, and
   frequency metadata.
3. Independently evaluate typed WordNet candidates with sense identifiers and
   review status.
4. Optionally evaluate sparse embedding and broad-relatedness candidates.
5. Define and evaluate portable vocabulary/article recommendation contracts.
6. Calibrate production ranking weights only from suitable learner outcomes.

## Article Recommendation Contract

For an article, tokenize and lemmatize its text into lexical forms, then join
those forms to `metadata.matchForms`. Match longest multi-word expressions
before individual words. Classify proper names, numbers, punctuation, and
unmatched lexical tokens explicitly. Compute at least:

```text
matchedTokenCoverage = matched eligible tokens / all eligible tokens
eligibleKnownCoverage = known eligible tokens / all eligible tokens
unmatchedTokenRate = unmatched eligible tokens / all eligible tokens
targetDensity = recommended-next eligible tokens / all eligible tokens
```

Matched-token-only known coverage may be reported diagnostically, but it must
not be the primary readability measure because unmatched difficult words would
disappear from its denominator. A practical extensive-reading candidate should
generally have high eligible-token known coverage, a low unmatched-token rate,
and a small, deliberate set of repeated recommended-next words. Exact
thresholds are application configuration and should be calibrated from reading
completion and comprehension outcomes.

The graph supplies lexical identity, relationships, CEFR/exam alignment, and
student mastery state. Corpus frequency, article-specific repetition, student
interest, and content suitability are ranking features supplied by the
application.

### Recommended-Next Vocabulary

The vocabulary candidate set is the unmastered or decaying lexical skills that:

- satisfy any meaningful component-word prerequisites;
- align to the learner's current or goal CEFR/exam range;
- occur in at least one eligible article.

Applications should rank candidates with a vocabulary-specific planner:

```text
vocabularyPriority(word) =
    a * readiness
  + b * corpusFrequency
  + c * eligibleArticleFrequency
  + d * learnerInterestFit
  + e * reviewUrgency
```

This extends the shared next-skill planner rather than overloading graph
prerequisites with an invented linear vocabulary sequence.

### SRS Evidence

Recommended card grain:

```text
student x lexical skill x evidence variant
```

Useful variants include receptive recognition, meaning recall, and productive
use. Merely encountering a word in an article is exposure evidence, not proof
of mastery. Comprehension questions, explicit checks, or later successful
recall should drive SRS ratings.

## Generation

Requirements:

- Node.js
- Poppler `pdftotext`
- locally downloaded source PDFs from `./download-sources.sh`

Run:

```bash
node scripts/generate-vocabulary-graph.js
```

Generated tracked artifacts:

- `data/cambridge-vocabulary-inventory.json`
- `cefr-vocabulary-knowledge-space.json`
