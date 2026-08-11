# Semantic WordNet Edge Review Summary

**Edges reviewed:** 1191 in 12 batches of ≤100
**Accept:** 996 (83.6%)
**Reject:** 10
**Uncertain:** 185

## By relation

| Relation | Total | Accept | Accept rate |
|---|---:|---:|---:|
| antonym | 71 | 59 | 83.1% |
| holonym | 36 | 30 | 83.3% |
| hypernym | 327 | 302 | 92.3% |
| hyponym | 411 | 333 | 81.0% |
| meronym | 53 | 45 | 84.9% |
| synonym | 293 | 227 | 77.5% |

## Outputs

- Accepted overlay: `overlays/semantic-wordnet-accepted.overlay.json`
- Rejected queue: `review/enrichment/queues/semantic-edge-rejected.jsonl`
- Uncertain queue: `review/enrichment/queues/semantic-edge-uncertain.jsonl`

Accepted edges remain optional ranking signals; never `prerequisite_for`.
Per-relation product promote still requires owner go if you want ranking weight > 0.
