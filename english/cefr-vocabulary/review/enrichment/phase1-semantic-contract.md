# Lexical Semantic Enrichment — Phase 1 Relation Contract

**Status:** Draft complete for engineering implementation (2026-08-11).  
**Track:** `lexical_semantic_enrichment_20260610`.  
**Depends on:** YLE core freeze; coverage enrichment release (supports stay optional).

## 1. Purpose

Define typed lexical-semantic relations as optional graph layers. Relations
are **never** mastery prerequisites. Consumers may exclude every semantic
layer without breaking core or coverage enrichment.

## 2. Relation kinds (first ship set)

Each edge must set `metadata.semanticRelation` to exactly one of:

| Kind | Direction | Meaning |
|---|---|---|
| `synonym` | undirected (store both or canonical order) | Same sense family |
| `antonym` | undirected | Opposite sense family |
| `hypernym` | source → more general | Is-a parent |
| `hyponym` | source → more specific | Is-a child |
| `meronym` | source → part | Part-of |
| `holonym` | source → whole | Whole-of |

**Forbidden encodings:**

- Do not dump all kinds into generic `related_to` for release layers.
- Do not emit `prerequisite_for` for any semantic candidate.
- Do not treat existing core `supports` (same-form POS / MWE component) as
  WordNet synonymy; those remain optional ranking supports with their own
  class dispositions.

## 3. Edge shape

```json
{
  "id": "english.vocabulary.edge.semantic.…",
  "type": "supports",
  "sourceId": "english.vocabulary.skill.…",
  "targetId": "english.vocabulary.skill.…",
  "weight": 0.5,
  "confidence": "medium",
  "sourceRefs": ["wordnet-3.1"],
  "reviewStatus": "draft",
  "rationale": "WordNet hypernym candidate; optional ranking signal",
  "metadata": {
    "enrichmentLayer": "enrichment.semantic.wordnet.hypernym",
    "semanticRelation": "hypernym",
    "sourceId": "wordnet",
    "sourceVersion": "3.1",
    "method": "sense-aware-lemma-pos-match",
    "sourceSenseId": "dog.n.01",
    "targetSenseId": "canine.n.02",
    "score": null,
    "extractionConfidence": "medium",
    "matchKind": "sense-mapped"
  }
}
```

**Note:** Edge `type` stays in the existing vocabulary (`supports`) so core
validators need not learn a new edge type before the engine supports filters.
Filtering key is `metadata.semanticRelation` + `metadata.enrichmentLayer`.

## 4. Layer IDs (independently releasable)

| Layer ID | Relation |
|---|---|
| `enrichment.semantic.wordnet.synonym` | synonym |
| `enrichment.semantic.wordnet.antonym` | antonym |
| `enrichment.semantic.wordnet.hypernym` | hypernym |
| `enrichment.semantic.wordnet.hyponym` | hyponym |
| `enrichment.semantic.wordnet.meronym` | meronym |
| `enrichment.semantic.wordnet.holonym` | holonym |
| `enrichment.semantic.embedding.mutual-nn` | experimental (Phase 4) |
| `enrichment.semantic.relatedness.broad` | experimental (Phase 4) |

Each layer may be approve / quarantine / reject alone.

## 5. Sense and identity

- Graph skills are **form+POS** today. WordNet is **sense**-level.
- Candidates must record matched synset/sense ids when known.
- Ambiguous lemma+POS → multiple synsets: **do not auto-promote**; queue for
  review (`review/enrichment/queues/semantic-ambiguous.jsonl`).
- Sense-level skill ID split remains the sense-identity track; this contract
  does not rewrite core IDs.

## 6. Provenance (100% required)

Every candidate edge requires:

- `sourceRefs` or `metadata.sourceId` + `sourceVersion`
- `metadata.method`
- `metadata.semanticRelation`
- `metadata.enrichmentLayer`
- `reviewStatus`
- sense ids when the method is sense-aware

## 7. Review thresholds (per relation, before release)

| Population | Sample | Metric | Threshold |
|---|---|---|---:|
| Each relation layer | ≥100 stratified or full set | labeled precision | set before promote (default draft **≥0.90** until curriculum sets higher) |
| Ambiguous sense matches | all | resolved or quarantined | 100% |
| `prerequisite_for` from semantic | full | count | **0** |

## 8. Quarantine

Ambiguous, low-confidence, or failed-precision candidates stay in queues and
must not appear in approved layer exports.

## 9. Consumer / ranking

Approved semantic layers may later feed `UtilitySignal` `semantic` in
`RANKING_LAYER_SPEC.md` at weight > 0. Until Phase 1+ release of at least one
relation layer, ranking weight stays **0**.

## 10. Phase 1 gate

Phase 1 is complete when this contract and the source-selection record are
accepted. Candidate generation may prototype after that acceptance.
