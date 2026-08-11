# Ranking Layer Spec — Domain Utility Provider (English CEFR)

**Status:** Design complete for frequency-live release (2026-08-11).  
**Track:** `frequency_semantic_ranking_layer_20260611`.  
**Engine contract:** SPECIFICATION.md §10.3 Domain Utility Provider.  
**Data layers owned elsewhere:** frequency (coverage track, **approved**);
semantic (semantic track, **not yet approved**); article-fit (recommendation
track, **not yet approved**).

## 1. Purpose

The planner is domain-blind. Ranking signals enter as one scalar `utility(B)`
plus provenance. This document defines provider
`english.cefr.frequency-utility` and how three domain signals compose.

## 2. Provider interface (additive to §10.3)

No change to node or edge schema. The provider is an adapter-registered
object:

```typescript
// SPECIFICATION.md §10.3 — restated for this domain
interface DomainUtilityProvider {
  providerKey: string;  // "english.cefr.frequency-utility"
  version: string;      // "1.0.0" at first ship; bump on formula or weight change
  getUtility(nodeId: string, ctx: LearnerContext): {
    utility: number;            // [0,1]
    signals: UtilitySignal[];   // non-empty when utility is explained
  };
}

interface UtilitySignal {
  source: string;
  sourceVersion: string;
  value: number;
  weight: number;
}
```

**providerKey:** `english.cefr.frequency-utility`  
**version:** `1.0.0`  
**Domain adapter:** English CEFR vocabulary domain only.

## 3. Declared signals

| Signal key | Data owner | Live weight at ship | Becomes live when |
|---|---|---:|---|
| `frequency` | `enrichment.frequency.wordfreq` (coverage, approved) | **1.0** | now |
| `semantic` | typed relation layer (semantic track) | **0.0** | Phase 1+ approve on that track |
| `articleFit` | recommendation contract metrics | **0.0** | Phase 1+ approve on that track |

Weight 0 is deliberate (§10.3 rule 3 pattern one level down). It is not a
defect. Composition ignores zero-weight signals.

### 3.1 Composition

Let S be the set of signals with `weight > 0` and a defined value for this
node.

```
utility = sum(value_i * weight_i) / sum(weight_i)   for i in S
```

If S is empty (all live signals missing for this node), `utility = 0` and
`signals` still lists each declared signal with its weight and a documented
missing sentinel (see §4.3).

## 4. Frequency signal (live)

### 4.1 Input

Read only approved node metadata:

```json
"metadata": {
  "frequency": {
    "source": "wordfreq",
    "sourceVersion": "3.1.1",
    "zipf": 5.42,
    "rankWithinInventory": 137,
    "reliable": true,
    "missing": false
  }
}
```

Do not re-query wordfreq at plan time. Do not create frequency edges.

### 4.2 Normalization → value in [0,1]

Use **inventory rank**, not raw zipf alone. Rank is already dense-equal for
ties (`rankTiePolicy: dense-equal-rank`).

Let `R = rankWithinInventory` (1 = most frequent in inventory).  
Let `Rmax = maxRank` from the frequency layer stats (397 for the 2026-08-11 build).

```
value_frequency = 1 - (R - 1) / (Rmax - 1)    // Rmax > 1
```

Clamped to [0,1]. Rank 1 → 1.0; rank Rmax → 0.0.

**Why rank, not min-max zipf:** rank is stable under the published inventory,
matches “how common among our skills,” and avoids re-deriving zipf bounds in
the planner. Zipf remains in provenance (`value` may optionally store zipf in
an extended diagnostic field; the UtilitySignal `value` field is the
normalized [0,1] contribution).

**UtilitySignal for frequency:**

| Field | Value |
|---|---|
| `source` | `enrichment.frequency.wordfreq` |
| `sourceVersion` | `3.1.1` (must match overlay pin) |
| `value` | normalized rank utility in [0,1] |
| `weight` | `1.0` at ship |

### 4.3 Missing and unreliable

| Case | Behavior |
|---|---|
| No `metadata.frequency` block | Frequency signal omitted from S; if S empty → utility 0 |
| `missing: true` | Frequency omitted from S (MWEs, not-in-corpus); do not invent zipf |
| `reliable: false` or below reliability floor | Treat as missing for ranking |
| `rankWithinInventory` absent while scored | Treat as missing (builder bug) |

Multi-token forms are missing by FREQUENCY-POLICY. They are not scored as
independent single-token rarity.

### 4.4 LearnerContext

Frequency utility does not depend on learner state in v1.0.0. `ctx` is
accepted for interface stability and ignored for this signal.

## 5. Semantic signal (inert at weight 0)

### 5.1 Ownership

`lexical_semantic_enrichment_20260610` defines relation kinds, sources, and
provenance. This track does not invent synonym/antonym edges.

### 5.2 When live

After an approved typed relation layer exists, a later provider version may
set `weight_semantic > 0` and define `value_semantic` from, for example:

- count of approved support/semantic neighbors already known to the learner
- normalized relatedness to current goal set

Until then:

```
weight_semantic = 0
```

Quarantined or rejected relation layers never contribute (weight stays 0).

### 5.3 UtilitySignal shape (declared)

| Field | Value when inert |
|---|---|
| `source` | `enrichment.semantic.pending` |
| `sourceVersion` | `none` |
| `value` | `0` |
| `weight` | `0` |

## 6. Article-fit signal (unlocked; weight 0 without article context)

### 6.1 Ownership

`lexical_recommendation_contract_20260610` defines coverage formulas and
exposure bounds (Phase 1 **go**, 2026-08-11). This track does not redefine them.

### 6.2 When live

```text
value_articleFit =
    0.5 * 1[B occurs in active article A as unknown]
  + 0.5 * min(1, count(B in A) / 3)
```

Default composition weight for `articleFit` is **0** when `LearnerContext` has
no active article. When the app passes article evaluation results, a provider
version may set `weight_articleFit > 0` (product choice; not required for core
frequency ranking).

Reference computation: `rankedNextVocabulary.items[].articleFitUtility` from
`scripts/recommendation-contract.js`.

## 7. Worked examples (illustrative)

Using Rmax = 397:

| Skill (illustrative) | Rank | value_frequency | utility (freq only) |
|---|---:|---:|---:|
| very common word, rank 1 | 1 | 1.00 | 1.00 |
| mid inventory | 199 | 0.50 | 0.50 |
| rarest ranked | 397 | 0.00 | 0.00 |
| multi-token MWE (missing) | — | omitted | 0.00 |

SPECIFICATION §10.4 qualitative example (Zipf-based story) remains valid as
intuition; implementation uses rank normalization for determinism against the
approved overlay.

## 8. Determinism and reproducibility

| Requirement | Rule |
|---|---|
| Inputs | Frozen core + approved frequency overlay pin (sourceVersion 3.1.1) |
| Network | Forbidden at `getUtility` time |
| Cadence | Rebuild frequency overlay when inventory or wordfreq pin changes; bump provider `version` if formula or weights change |
| Validation | Sample ≥500 scored skills → utility in [0,1]; missing skills → documented behavior |

Offline check: `scripts/validate-frequency-utility-sample.py` (500-node sample).

## 9. Non-goals

- Creating `prerequisite_for` or frequency edges
- Selecting or re-pinning wordfreq (coverage track owns that)
- Defining WordNet relation kinds (semantic track)
- Defining article coverage formulas (recommendation track)
- Production TypeScript engine registration (implementation may follow this spec)

## 10. Release decision

**Ship** provider design with frequency live (weight 1.0) and semantic +
article-fit declared at weight 0.

This is complete design work for the ranking track’s frequency path, not a
half-finished three-signal product.
