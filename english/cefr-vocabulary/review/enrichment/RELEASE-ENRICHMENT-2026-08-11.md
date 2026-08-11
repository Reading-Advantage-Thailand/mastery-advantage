# RELEASE-ENRICHMENT-2026-08-11 — Coverage Enrichment Layers

**Status:** **Approved** (Phase 4 + Phase 5 dual go, 2026-08-11).  
**Core pin:** YLE 2025 freeze (`review/yle-2025/RELEASE-YLE-2025.md`).  
**Track:** `lexical_coverage_enrichment_20260610`.

## Decision

| Owner | Decision | Date |
|---|---|---|
| Curriculum / language | go | 2026-08-11 |
| Engineering | go | 2026-08-11 |

Authoritative phase records:

- [`phase4-approval.md`](phase4-approval.md)
- [`phase5-approval.md`](phase5-approval.md)

## Approved layers

| Layer | Overlay / artifact | Harness |
|---|---|---|
| `enrichment.frequency.wordfreq` | `overlays/frequency.overlay.json` | `tests/enrichment_frequency.sh` |
| `enrichment.cambridge.a2-key-appendix` | `overlays/a2-key-appendix.overlay.json` | `tests/enrichment_a2_b1_appendix.sh` |
| `enrichment.cambridge.b1-preliminary-appendix` | `overlays/b1-preliminary-appendix.overlay.json` | `tests/enrichment_a2_b1_appendix.sh` |
| `enrichment.cambridge.grammatical-groups` | `overlays/yle-grammatical-groups.overlay.json` | `tests/enrichment_yle_grammatical.sh` |
| `enrichment.viu.unit-groups` | `overlays/viu-unit-groups.overlay.json` | `tests/enrichment_viu_layer.sh` |

## Consumption

- **Core only:** load `cefr-vocabulary-knowledge-space.json`; ignore all overlays.
- **Selective:** merge zero or more approved overlays; never invent skills that
  duplicate form+POS already in core.
- **Frequency:** node metadata under `metadata.frequency`; never edges.
- **Groups:** `content_group` + `contains` co-membership only.
- **Planner utility:** consume frequency through
  `english.cefr.frequency-utility` (`RANKING_LAYER_SPEC.md`); do not read
  overlays from the engine core.

## Explicit non-claims

- Not a dual-go freeze of A2 Key / B1 Preliminary as standalone exam packages.
- Not B2 inventory coverage.
- Not semantic relation approval (separate track).
- Not production recommender runtime.

## Regeneration

Each approved layer has a deterministic builder under `scripts/`. Rebuild
against the frozen core pin; do not rewrite the core graph file in place.
