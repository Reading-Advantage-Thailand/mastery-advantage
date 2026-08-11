# Lexical Semantic Enrichment — Phase 1 Source Selection

**Status:** Draft complete (2026-08-11).  
**Track:** `lexical_semantic_enrichment_20260610`.

## 1. Selected first source: Princeton WordNet 3.1

| Field | Value |
|---|---|
| Source ID | `wordnet` |
| Version | `3.1` (or NLTK/Open English WordNet pin recorded at implement) |
| License | WordNet 3.0 license (permissive; retain notice) |
| Scope | English open-class lemmas; sense-linked relations |
| Access | Offline package (e.g. NLTK `wordnet` corpus or `wn` DB); **no live network** at generate or plan time |
| Layer family | `enrichment.semantic.wordnet.*` |
| Reproducibility | Pin package + corpus version in builder metadata |

### Why first

- Typed relations match the contract (synonym, antonym, hypernym, …).
- Sense ids support quarantine of ambiguous matches.
- Offline and versionable.
- Aligns with GRAPH-DESIGN semantic section.

## 2. Mapping to graph skills

1. Take skill `normalizedForm` + primary POS.
2. Map POS to WordNet POS (`n/v/a/r`).
3. Look up synsets; if 0 → unmatched queue.
4. If >1 synset without disambiguation → ambiguous queue (no auto edge).
5. If 1 synset (or reviewed choice) → emit typed candidates to neighbor lemmas
   that exist as skills in the core inventory (form+POS match).
6. Never create new skill nodes for WordNet-only lemmas in this track’s first
   ship (coverage/B2 owns inventory growth; B2 is deferred).

## 3. Deferred / experimental sources

| Source | Decision | Rationale |
|---|---|---|
| fastText mutual nearest neighbors | Phase 4 experiment only | Distributional; antonyms collide; sparse mutual-NN only |
| ConceptNet broad relatedness | Phase 4 experiment only | Relatedness ≠ similarity; separate layer |
| EVP sense inventory bulk | Excluded until licensed | Same company-use constraint as coverage track |
| Live web APIs | Forbidden | Non-reproducible |

## 4. Artifact size policy

- Prefer sparse edges: only pairs where **both** endpoints are inventory skills.
- Cap experimental embedding degree (e.g. ≤5 mutual neighbors per node) if
  promoted later.
- WordNet typed layers: no hard degree cap in Phase 1; audit in Phase 3.

## 5. Acceptance for Phase 1

Owners accept:

- WordNet 3.1 as first source;
- experimental sources deferred;
- offline pin + no live network;
- no inventory expansion from semantic alone in first ship.
