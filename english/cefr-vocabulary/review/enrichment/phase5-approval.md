# Lexical Coverage Enrichment: Phase 5 Release Decision

**Decision:** go (per-layer approve / quarantine as tabled below)  
**Date:** 2026-08-11  
**Approved by:** curriculum/language owner and engineering owner (session confirmation)

## Per-layer decisions

| Layer ID | Decision | Notes |
|---|---|---|
| `enrichment.frequency.wordfreq` | **approve** | Node metadata only; wordfreq 3.1.1; core untouched |
| `enrichment.cambridge.a2-key-appendix` | **approve** | Form+POS identity; Key/Flyers share skills; A–Z match ≥0.999 |
| `enrichment.cambridge.b1-preliminary-appendix` | **approve** | Form+POS identity; A–Z match 1.0; topics ≥0.95 |
| `enrichment.cambridge.grammatical-groups` | **approve** | Optional YLE grammatical co-membership; freeze omission restored as layer |
| `enrichment.viu.unit-groups` | **approve** | Co-taught units; unit number is not a prerequisite; unmatched advanced lemmas quarantined |
| Fabricated / EVP bulk B2 lists | **reject** | Unavailable or unlicensed; see B2 deferral |
| Cambridge B2 First official list | **reject (unavailable)** | No official list to graph |

## Hard rules retained

1. No enrichment layer emits `prerequisite_for`.
2. Core freeze graph `cefr-vocabulary-knowledge-space.json` is not rewritten by enrichment.
3. Consumers may load core alone and exclude every enrichment layer.
4. Full dual-go **freeze authority** for A2 Key / B1 Preliminary as exam packages remains method-later; these approvals are for **enrichment layers**, not a second YLE-style freeze ceremony.

## B2

B2 inventory expansion is **deferred / not graphable for current product scope**.
Customer population is not at B2. Track
`b2_vocabulary_source_expansion_20260611` is parked. Do not invent a Cambridge
B2 word list.

## Provenance

Explicit user direction in session 2026-08-11: “Approve phases 4 and 5. B2 is
not graphable… customers aren't at that level yet.”
