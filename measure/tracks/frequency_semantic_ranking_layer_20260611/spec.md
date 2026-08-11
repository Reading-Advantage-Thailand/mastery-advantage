# Frequency, Semantic and Article-Ranking Utility Provider Design

## Problem

The domain holds ranking signals that the planner cannot reach:

- The frequency layer is built, but no provider turns its node metadata into `utility(B)`
- The typed semantic layer is not yet approved, and no provider expresses it
- The article metrics are not yet defined, and no provider expresses them

The planner stays domain-blind by design. Without a provider, every domain signal is inert and the utility term stays 0.

## Goal

Express the domain ranking signals as one `DomainUtilityProvider`, so the planner consumes one scalar plus provenance without reading any data layer directly.

## Dependency

Other tracks own the data layers. This track owns the provider that expresses them.

- `lexical_coverage_enrichment_20260610` produces the frequency data layer. It stores frequency as versioned node metadata under layer `enrichment.frequency.wordfreq`. This track consumes that metadata and converts it to `utility(B)`. This track does not select the frequency source, and it does not create frequency edges.
- `lexical_semantic_enrichment_20260610` produces the typed relation layer. This track consumes only an approved layer. It does not define relation kinds, sources, or provenance fields.
- `lexical_recommendation_contract_20260610` produces the matching reference and the article metrics. This track consumes them. It does not define coverage formulas or exposure bounds.

## Acceptance Criteria

1. A `RANKING_LAYER_SPEC.md` document defines:
   - Frequency signal: normalization from the coverage layer's node metadata to `utility(B)` in `[0,1]`
   - Semantic signal: how an approved typed relation layer contributes a `UtilitySignal`
   - Article-fit signal: how the recommendation track's metrics contribute a `UtilitySignal`
   - Composition: the weighted mean of the declared signal weights inside the provider, per §10.3 rule 2
2. The `UtilitySignal` schema and the `DomainUtilityProvider` interface are additive to §10.3. This track changes no node schema and no edge schema.
3. A sample of 500 scored nodes returns a utility value in `[0,1]` with non-empty signals. Excluded and absent nodes return the documented missing behavior.
4. The provider ships with the frequency signal live. The semantic and article-fit signals stay inert at weight 0 until their owning layers pass their Phase 1 human review.
5. All signals document their update cadence and reproducibility requirements.

## Release Decision

The provider ships with the frequency signal live. The semantic and article-fit signals ship declared but inert at weight 0.

This is a deliberate release decision. It is not unfinished work. The frequency layer is the only one of the three whose data layer is approved and built. §10.3 rule 3 gives the pattern: no provider gives `utility = 0`, and the term stays inert. The same logic applies one level down. A declared signal with no approved layer takes weight 0 and does not disturb the composition.

Each inert signal becomes live when its owning layer passes its own Phase 1 human review. A later reader must not treat weight 0 as a defect.
