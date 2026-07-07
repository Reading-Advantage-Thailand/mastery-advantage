# Phase 1 Decision Log — KST+SRS Planner & Domain Utility Extension

> Decisions frozen 2026-07-07, building on kst-srs.v3.1. Normative input to
> Phase 2 examples and Phase 3 edits. Released as kst-srs.v3.2.

## D1: Priority-Term Normalizations (FR-1)

**Decision:** every term in `priority(B)` is on [0,1] before weighting:

- `readiness(B)`: already [0,1] (v3 gated formula, §2.5).
- `unlockValue(B) = ln(1 + reach(B)) / ln(1 + maxReach)` where `reach(B)` is
  the count of skills downstream via `prerequisite_for` and `maxReach` is
  the graph maximum. Log-scaled (chosen over percentile rank: stable under
  graph edits, no re-ranking of unaffected nodes) and precomputed per graph
  release.
- `goalProximity(B) = 1 / (1 + d)` with `d` = shortest prerequisite-path
  distance to any goal node; `d = 0` → 1; no goal or unreachable → 0.
- `weaknessFit(B) = 1 − Π(1 − s_i)` (noisy-OR) over links from B to active
  weaknesses: `s = 0.5` per active-misconception link
  (`common_misconception_with`/`remediated_by`), `s = 0.3` per
  recently-failed `supports` link.
- **New fifth term** `utility(B) ∈ [0,1]` from the Domain Utility Provider
  (D2); 0 when no provider is registered.

**Re-derived default weights:** `a=0.35` readiness, `b=0.20` unlock,
`c=0.15` goal, `d=0.10` weakness, `e=0.20` utility. No renormalization when
a term is inert — ranking is within-domain, so a constant shift cannot
change order.

**Dominance defect (v2/v3.1):** with raw counts, node P (readiness 0.85,
reach 40) scored `0.4·0.85 + 0.3·40 = 12.34` — unlock count alone dwarfed
every other term by ~30×. Normalized: `u_P = ln(41)/ln(121) = 0.774`,
priority `0.35·0.85 + 0.20·0.774 = 0.452` vs Q (readiness 1.0, reach 2):
`0.35 + 0.20·0.229 = 0.396`. Reach still matters; readiness matters again.

## D2: Domain Utility Provider Contract (FR-2)

**Decision:** one provider per domain, adapter-registered, following the
§15 pattern:

```typescript
interface DomainUtilityProvider {
  providerKey: string;          // e.g. "english.cefr.frequency-utility"
  version: string;              // bump on any signal-source or formula change
  getUtility(nodeId: string, ctx: LearnerContext): {
    utility: number;            // [0,1]
    signals: UtilitySignal[];   // provenance, non-empty
  };
}

interface UtilitySignal {
  source: string;               // e.g. "wordfreq-en", "goal-coverage"
  sourceVersion: string;
  value: number;                // raw signal value
  weight: number;               // contribution weight in the composition
}
```

- Deterministic given `(nodeId, ctx, version)`; composition of multiple
  signals happens **inside** the provider (weighted mean of declared
  weights); the engine consumes one scalar plus provenance.
- No provider → `utility = 0` (term inert); the engine core stays
  domain-blind.

**Reconciliation with `frequency_semantic_ranking_layer_20260611`
(recorded decision):** that track produces the *data layers* (frequency
metadata, typed semantic edges, article-ranking scores) as additive graph
extensions; the engine consumes those layers **only** through this provider
interface. Its `RANKING_LAYER_SPEC.md` deliverable must define its layers'
signal schemas as `UtilitySignal` sources and ship the reference English
lexical provider. One shared interface; no duplicated contracts.

## D3: Prerequisite-Sparse Ranking Path (FR-3)

**Decision:**

- **Detection (per graph release, static):** a domain is
  *prerequisite-sparse* when < 5% of its `skill` nodes have any
  `prerequisite_for` in-edge. (The CEFR/Cambridge lexical graph, which
  deliberately asserts no false prerequisites, qualifies by construction.)
- **Utility-led mode:** readiness acts as a gate only (candidates require
  `readiness ≥ readyThreshold`; in a sparse domain nearly all pass at 1.0);
  ranking uses renormalized `0.7·utility + 0.3·weaknessFit`; unlock and
  goal terms drop (structurally ≈ 0).
- **No synthetic prerequisites, ever** — consistent with the lexical
  tracks' zero-automatic-prerequisite policy; ranking hunger is satisfied by
  utility signals, not fake graph edges.

## D4: Diversity And Review-Load Budget (FR-4, FR-5)

**Diversity (chosen: per-group cap; MMR rejected — needs a similarity
metric this spec doesn't otherwise require):**

- `recommendedNext` allows at most 2 nodes per nearest `contains` ancestor
  (instructional_unit, else content_group) among the top-N; overflow slots
  go to the next-highest-priority nodes from other groups.
- Deterministic tie-break: priority desc, then `nodeId` asc.

**Review-load budget:**

- Projected daily load = (cards due within the next 7 days) / 7.
- Budget = `maxReviewsPerDay × loadBudgetFactor` (new engine constant,
  default 0.8).
- Projected load > budget → planner recommends **0 new skills** and surfaces
  "review day" guidance; `reviewLoadState: normal | elevated | saturated`
  (elevated ≥ 60% of budget) appears in student/teacher projections.

## D5: Session Composition (FR-6)

**Decision (selection is untouched — v3 §12.7 rules pick *which* cards;
these rules affect presentation and scheduling only):**

- **Interleaving:** the day's selected review set is presented round-robin
  across objectives (deterministic order: objective priority, then
  objectiveId), avoiding blocked runs of one objective. New cards follow
  reviews unchanged.
- **Interval fuzz:** scheduled intervals get deterministic jitter in
  ±5%: `fuzz = hash(cardId, reps) → uniform[−0.05, +0.05]`; reproducible,
  no RNG state.
- **Load balancing:** within the fuzz window, the due date lands on the day
  with the lowest projected load. Bounded by the window; never violates
  `maximumInterval`.

## Approval Record

- **Engineering review:** D1–D5 recorded with alternatives; approved under
  the project owner's 2026-07-07 directive to fully implement this track.
- **Ranking-layer reconciliation:** recorded in D2 against the
  `frequency_semantic_ranking_layer_20260611` spec (its acceptance criteria
  1–2 align: additive schema extensions = signal sources for the provider).
  That track should adopt the `UtilitySignal` schema in its
  `RANKING_LAYER_SPEC.md`.
- **Pedagogy review:** ⚠ constants (term weights, 0.7/0.3 sparse split,
  diversity cap 2, loadBudgetFactor 0.8, ±5% fuzz) folded into the existing
  curriculum-review tech-debt row — ratify before app adoption.
