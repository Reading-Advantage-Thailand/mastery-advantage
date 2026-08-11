# Semantic WordNet Edge Review Summary

**Edges reviewed:** 1191 in 12 batches of ≤100
**Accept:** 696 (58.4%)
**Reject:** 439
**Uncertain:** 56

## By relation

| Relation | Total | Accept | Accept rate |
|---|---:|---:|---:|
| antonym | 71 | 67 | 94.4% |
| holonym | 36 | 22 | 61.1% |
| hypernym | 327 | 222 | 67.9% |
| hyponym | 411 | 175 | 42.6% |
| meronym | 53 | 33 | 62.3% |
| synonym | 293 | 177 | 60.4% |

## Outputs

- Accepted overlay: `overlays/semantic-wordnet-accepted.overlay.json`
- Rejected queue: `review/enrichment/queues/semantic-edge-rejected.jsonl`
- Uncertain queue: `review/enrichment/queues/semantic-edge-uncertain.jsonl`

Accepted edges remain optional ranking signals; never `prerequisite_for`.
Per-relation product promote still requires owner go if you want ranking weight > 0.
