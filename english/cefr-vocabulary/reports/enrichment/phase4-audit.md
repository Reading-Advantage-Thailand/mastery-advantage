# Enrichment Phase 4 Audit

**Generated:** 2026-08-11
**Track:** `lexical_coverage_enrichment_20260610`

## Automatable gates

| Gate | Result |
|---|---|
| Core freeze untouched | True |
| All layers `prerequisite_for` = 0 | True |
| Frequency no silent nulls | True |
| Provenance complete (membership layers) | True |
| Stratified samples written | True |
| Ambiguous rows quarantined | True |
| Membership precision ≥0.980 | pending-human |

## Layers

### `enrichment.cambridge.a2-key-appendix`
- Membership edges: 3139
- Provenance completeness: 1.0 (pass=True)
- Stratified sample: 100 → `review/enrichment/phase4-samples/a2-key-appendix-membership-sample.jsonl`
- `prerequisite_for`: 0
- Hard prohibitions pass: True

### `enrichment.cambridge.b1-preliminary-appendix`
- Membership edges: 5242
- Provenance completeness: 1.0 (pass=True)
- Stratified sample: 100 → `review/enrichment/phase4-samples/b1-preliminary-appendix-membership-sample.jsonl`
- `prerequisite_for`: 0
- Hard prohibitions pass: True

### `enrichment.cambridge.grammatical-groups`
- Membership edges: 2102
- Provenance completeness: 1.0 (pass=True)
- Stratified sample: 100 → `review/enrichment/phase4-samples/grammatical-groups-membership-sample.jsonl`
- `prerequisite_for`: 0
- Hard prohibitions pass: True

### `enrichment.viu.unit-groups`
- Membership edges: 4182
- Provenance completeness: 1.0 (pass=True)
- Stratified sample: 100 → `review/enrichment/phase4-samples/unit-groups-membership-sample.jsonl`
- `prerequisite_for`: 0
- Hard prohibitions pass: True

### `enrichment.frequency.wordfreq`
- Nodes: 3769; edges: 0
- Scored: 3374; missing flagged: 395; silent nulls: 0
- Zipf range: 1.64 … 7.73 (p50=4.63)
- Hard prohibitions pass: True

## Coverage gaps

- Core skills: 3769
- Core exam memberships: `{"pre-a1-starters": 495, "a2-key-for-schools": 1684, "a2-flyers": 513, "b1-preliminary-for-schools": 3060, "a1-movers": 399}`
- ViU match rate: 0.2851

- YLE freeze authority remains Pre-A1–A2 Flyers only.
- A2 Key / B1 Preliminary enrichment layers add membership overlays; full dual-go freeze is method-later.
- Cambridge B2 First official vocabulary list is unavailable (see source registry).
- ViU advanced unmatched volume is expected: many C1–C2 index lemmas are absent from the YLE/A2/B1 inventory.
- B2 coverage expansion is owned by track b2_vocabulary_source_expansion_20260611.

## Queues

```
{
  "a2-key-ambiguous.jsonl": 38,
  "a2-key-unmatched.jsonl": 22,
  "b1-preliminary-ambiguous.jsonl": 34,
  "b1-preliminary-unmatched.jsonl": 93,
  "frequency-label-anomalies.jsonl": 148,
  "frequency-missing.jsonl": 395,
  "frequency-unreliable.jsonl": 0,
  "viu-ambiguous.jsonl": 446,
  "viu-unmatched.jsonl": 7272,
  "yle-grammatical-unmatched.jsonl": 23
}
```

## Next

Curriculum/language: label stratified samples under review/enrichment/phase4-samples/ for precision ≥0.980 per source, then record Phase 4 review decision.
