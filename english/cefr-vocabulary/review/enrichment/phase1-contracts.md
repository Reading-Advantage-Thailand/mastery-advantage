# Lexical Coverage Enrichment — Phase 1 Contracts

**Status:** Accepted (Phase 1 go, both-owners, 2026-08-11).  
**Depends on:** YLE 2025 baseline freeze
(`review/yle-2025/RELEASE-YLE-2025.md`, dual go 2026-08-11).  
**Generated:** 2026-08-11

## 1. Purpose

Define independently selectable **enrichment layers** that attach to the frozen
core lexical graph without rewriting core skill IDs, membership edges, or the
YLE freeze package.

Core consumers must be able to load the frozen graph and **exclude every
enrichment layer** without breaking identity, exam membership, or consumption
contracts (`YLE-CONSUMPTION.md`).

## 2. Stable Core References

| Core object | Stable key | Enrichment rule |
|---|---|---|
| Lexical skill | `skill.id` (form+POS, e.g. `english.vocabulary.skill.blue.adjective`) | Reference only; never invent a second core ID for the same form+POS |
| Exam membership | `contains` from exam nodes | Read-only for YLE freeze; new exams use separate layers |
| Topic groups (YLE) | existing topic `content_group` IDs | Do not mutate freeze groups; add new groups under enrichment namespaces |
| Supports | existing `supports` edges | Out of scope for this track (semantic track owns new relation kinds) |

**Migration:** If a future sense-level split creates
`…blue.adjective.color`, enrichment memberships must re-point via an explicit
migration map; silent re-keying of frozen IDs is forbidden.

## 3. Enrichment Layers (independently releasable)

Each layer is a named package with its own approve / quarantine / reject
decision. Layers may ship alone.

| Layer ID | Content | Release unit |
|---|---|---|
| `enrichment.cambridge.grammatical-groups` | YLE grammatical lists as `content_group` + `contains` (currently accepted omission in freeze) | optional add-on |
| `enrichment.cambridge.a2-key-appendix` | A2 Key appendix / list memberships | optional add-on |
| `enrichment.cambridge.b1-preliminary-appendix` | B1 Preliminary appendix / list memberships | optional add-on |
| `enrichment.viu.unit-groups` | Vocabulary in Use unit `content_group`s + index matches | per book band or combined |
| `enrichment.frequency.wordfreq` | Zipf frequency metadata on skill nodes | metadata-only layer |

No layer may emit `prerequisite_for` edges.

## 4. Node, Edge, And Metadata Shapes

### 4.1 Content groups (source-backed)

```json
{
  "id": "english.vocabulary.group.viu.upper-intermediate.unit-12",
  "kind": "content_group",
  "title": "ViU Upper-Intermediate Unit 12",
  "metadata": {
    "enrichmentLayer": "enrichment.viu.unit-groups",
    "sourceId": "vocabulary-in-use-upper-intermediate",
    "unitNumber": 12,
    "cefrBandHint": "B2",
    "reviewStatus": "draft"
  }
}
```

`contains` edges from group → skill must carry:

| Field | Required | Notes |
|---|---|---|
| `sourceRefs` | yes | source id + locator (page/section/index lemma) |
| `metadata.extractionConfidence` | yes | `high` \| `medium` \| `low` |
| `metadata.matchKind` | yes | `exact` \| `normalized` \| `ambiguous` \| `unmatched-pending` |
| `metadata.enrichmentLayer` | yes | layer id |

### 4.2 Frequency metadata (not edges)

On skill nodes only:

```json
{
  "frequency": {
    "source": "wordfreq",
    "sourceVersion": "<pinned>",
    "zipf": 5.42,
    "rankWithinInventory": 137,
    "computedAt": "2026-08-11",
    "missing": false,
    "enrichmentLayer": "enrichment.frequency.wordfreq"
  }
}
```

Missing scores: `missing: true`, omit or null `zipf`, never invent zeros that
look like real ranks.

### 4.3 Ambiguity And Quarantine

| Finding class | Queue | Default disposition path |
|---|---|---|
| unmatched index lemma | `review/enrichment/queues/unmatched.jsonl` | quarantine or manual map |
| multi-skill form match | `…/ambiguous.jsonl` | resolve to one skill or split decision |
| multi-unit index hit | `…/multi-unit.jsonl` | allow multi-membership with provenance |
| frequency anomaly | `…/frequency-anomaly.jsonl` | investigate / exclude |

Quarantined items **must not** appear in consumer-facing approved layer exports.

## 5. Isolation Contract

1. Enrichment artifacts live under distinct paths (reports, review queues,
   optional overlay JSON), not by rewriting
   `cefr-vocabulary-knowledge-space.json` in place for unapproved layers.
2. Approved layers may be merged into a published overlay or a regenerable
   extended graph **only** with a deterministic build script and pin to the
   frozen core commit/hash.
3. Validators must accept core-only graphs; enrichment checks are opt-in.
4. Core `YLE-CONSUMPTION.md` rules remain valid when enrichment is absent.

## 6. Review Samples And Thresholds

| Population | Minimum sample | Metric | Threshold |
|---|---|---:|---|
| Each retained source’s group memberships | 100 stratified, or full set if fewer | labeled membership precision | ≥ 0.980 |
| Provenance / source-location fields | full retained membership set | field completeness | 1.000 |
| Ambiguous matches | all | resolved or quarantined | 100% closed |
| Frequency coverage (if layer retained) | all skills in inventory | documented missing-score rate | no silent nulls |
| Hard prerequisites | full graph after merge | `prerequisite_for` count from enrichment | 0 |

Sampling must cover POS variety, MWEs, and multi-unit cases when present.

## 7. Phase 1 Gate

Phase 1 is complete when:

1. This contract is accepted (engineering + curriculum/language as applicable).
2. Source registry additions in `phase1-source-registry.md` are accepted.
3. Thresholds above are accepted for later audit phases.

**Decision (2026-08-11):** go (both-owners). Contracts, source registry, and
thresholds accepted. Implementation already proceeded with live overlays under
this acceptance.
