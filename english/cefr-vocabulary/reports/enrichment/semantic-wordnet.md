# WordNet Semantic Candidates

**Generated:** 2026-08-11  
**Source:** WordNet 3.1 (NLTK corpus)  
**Status:** draft candidates (not relation-layer approved)

## Counts

| Measure | Value |
|---|---:|
| Skills considered (single-token + mappable POS) | 3214 |
| Unique synset mapped | 636 |
| Ambiguous (quarantined) | 2478 |
| Unmatched in WordNet | 100 |
| Candidate edges | 1191 |

## Edges by relation

| Relation | Edges |
|---|---:|
| synonym | 293 |
| antonym | 71 |
| hypernym | 327 |
| hyponym | 411 |
| meronym | 53 |
| holonym | 36 |

## Policy

- Ambiguous lemma+POS never auto-promotes
- No `prerequisite_for`
- Core graph untouched
- Promote/quarantine/reject per `enrichment.semantic.wordnet.*` layer after review
