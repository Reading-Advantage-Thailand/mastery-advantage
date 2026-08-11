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
- [ ] Task 1.1: Consume `enrichment.frequency.wordfreq` node metadata from the coverage track; do not re-evaluate the source and do not create frequency edges
- [ ] Task 1.2: Define the normalization from zipf and `rankWithinInventory` to `utility(B)` in `[0,1]`
- [ ] Task 1.3: Specify provider `english.cefr.frequency-utility` per decision D2 and §10.3, with `providerKey`, `version`, `getUtility`, and non-empty `UtilitySignal` provenance
- [ ] Task 1.4: Define provider behavior for missing scores and for scores below the reliability floor

## Phase 2: Semantic Utility Signal Design
- [ ] Task 2.1: Consume the approved typed relation layer from `lexical_semantic_enrichment_20260610`; do not define relation kinds, sources, or provenance fields
- [ ] Task 2.2: Define how an approved relation layer contributes a `UtilitySignal` with `source`, `sourceVersion`, `value`, and `weight`
- [ ] Task 2.3: Define weight 0 for a quarantined or rejected relation layer, per the §10.3 rule 3 pattern

## Phase 3: Article-Ranking Utility Signal Design
- [ ] Task 3.1: Consume the matching reference and article metrics from `lexical_recommendation_contract_20260610`; do not define coverage formulas or exposure bounds
- [ ] Task 3.2: Define how article fit contributes a `UtilitySignal` to the composition
- [ ] Task 3.3: Define weight 0 until the recommendation contract passes its Phase 1 review gate

## Phase 4: Specification & Validation
- [ ] Task 4.1: Write `RANKING_LAYER_SPEC.md` integrating all three signals and the composition
- [ ] Task 4.2: Verify the provider and `UtilitySignal` schemas are additive to §10.3, with no node or edge schema change
- [ ] Task 4.3: Update `tech-debt.md` — mark ranking-layer item as "spec ready, implementation deferred"
- [ ] Task 4.4: Commit, push, and archive track
