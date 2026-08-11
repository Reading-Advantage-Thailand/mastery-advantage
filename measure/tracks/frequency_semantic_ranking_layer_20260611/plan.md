# Plan — Frequency, Semantic and Article-Ranking Utility Provider Design

> **Intent:** Express the domain ranking signals as one `DomainUtilityProvider`
> per decision D2 and §10.3. Other tracks own the data layers. This track owns
> the provider and the composition.
>
> **Release decision:** the provider ships with the frequency signal live. The
> semantic and article-fit signals ship declared but inert at weight 0 until
> their owning layers pass their Phase 1 human review. Weight 0 is deliberate,
> not unfinished work.

## Phase 1: Frequency Utility Provider Design
- [x] Task 1.1: Consume `enrichment.frequency.wordfreq` node metadata from the coverage track; do not re-evaluate the source and do not create frequency edges
- [x] Task 1.2: Define the normalization from zipf and `rankWithinInventory` to `utility(B)` in `[0,1]`
- [x] Task 1.3: Specify provider `english.cefr.frequency-utility` per decision D2 and §10.3, with `providerKey`, `version`, `getUtility`, and non-empty `UtilitySignal` provenance
- [x] Task 1.4: Define provider behavior for missing scores and for scores below the reliability floor

**Green evidence (2026-08-11):**

- `english/cefr-vocabulary/RANKING_LAYER_SPEC.md` §§3–4
- Rank normalization: `1 - (R-1)/(Rmax-1)`; missing → omit signal
- Coverage frequency layer approved in RELEASE-ENRICHMENT-2026-08-11

## Phase 2: Semantic Utility Signal Design
- [x] Task 2.1: Consume the approved typed relation layer from `lexical_semantic_enrichment_20260610`; do not define relation kinds, sources, or provenance fields
- [x] Task 2.2: Define how an approved relation layer contributes a `UtilitySignal` with `source`, `sourceVersion`, `value`, and `weight`
- [x] Task 2.3: Define weight 0 for a quarantined or rejected relation layer, per the §10.3 rule 3 pattern

**Green evidence:** RANKING_LAYER_SPEC.md §5 — weight 0 until semantic approve.

## Phase 3: Article-Ranking Utility Signal Design
- [x] Task 3.1: Consume the matching reference and article metrics from `lexical_recommendation_contract_20260610`; do not define coverage formulas or exposure bounds
- [x] Task 3.2: Define how article fit contributes a `UtilitySignal` to the composition
- [x] Task 3.3: Define weight 0 until the recommendation contract passes its Phase 1 review gate

**Green evidence:** RANKING_LAYER_SPEC.md §6 — weight 0 until recommendation Phase 1.

## Phase 4: Specification & Validation
- [x] Task 4.1: Write `RANKING_LAYER_SPEC.md` integrating all three signals and the composition
- [x] Task 4.2: Verify the provider and `UtilitySignal` schemas are additive to §10.3, with no node or edge schema change
- [x] Task 4.3: Update `tech-debt.md` — mark ranking-layer item as "spec ready, implementation deferred"
- [x] Task 4.4: Commit, push, and archive track

**Green evidence (2026-08-11):**

- Spec: `english/cefr-vocabulary/RANKING_LAYER_SPEC.md`
- Sample validator: `scripts/validate-frequency-utility-sample.py` (500 nodes)
- Harness: `bash tests/enrichment_ranking_utility.sh`
- No node/edge schema changes; additive §10.3 only
