# Enrichment Layer Consumption And Exclusion

**Status:** Approved with RELEASE-ENRICHMENT-2026-08-11.  
**Depends on:** YLE core freeze + approved enrichment layers.

## 1. Core isolation

A consumer must be able to:

1. Load only `cefr-vocabulary-knowledge-space.json`.
2. Run `scripts/validate-vocabulary-graph.js`.
3. Apply `YLE-CONSUMPTION.md` without any enrichment overlay.

If enrichment is absent, identity, exam membership, and supports behavior of
the frozen core remain unchanged.

## 2. Optional merge

Overlays under `overlays/*.overlay.json` may be merged by a domain adapter:

| Rule | Requirement |
|---|---|
| Skill identity | Never create a second skill for the same form+POS |
| Edges from enrichment | `contains` (and documented supports if any) only |
| Forbidden | `prerequisite_for` from any enrichment layer |
| Frequency | Copy `metadata.frequency` onto skill nodes; create no frequency edges |
| Layer filter | Adapter may enable/disable each `enrichmentLayer` id independently |

## 3. Exclusion fixture (conceptual)

```text
GIVEN core graph G and approved overlays O1..On
WHEN consumer loads G only
THEN no overlay node id is required
AND YLE consumption contract still holds
WHEN consumer loads G ∪ {Oi}
THEN skill targets of Oi.contains reference existing G skill ids
AND count(prerequisite_for in Oi) = 0
```

Offline checks: `tests/enrichment_*` harnesses plus core validator.

## 4. Planner path

Frequency enters planning only via `DomainUtilityProvider`
(`english.cefr.frequency-utility`). See `RANKING_LAYER_SPEC.md`.
