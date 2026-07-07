# Specification: KST+SRS Planner & Domain Utility Extension

## Overview

The next-skill planner (§10) and daily queue (§12.7) carry structural gaps
that matter most where this engine will be used hardest. The §10 priority
terms are on incompatible scales (`readiness ∈ [0,1]` vs `unlockValue` as an
unbounded raw count), so the configured weights do not mean what they say.
More fundamentally, in prerequisite-sparse domains — the CEFR/Cambridge
vocabulary graph deliberately asserts no false prerequisites — readiness
defaults to 1 for every untouched word, `unlockValue` and `goalProximity`
collapse to 0, and the planner has literally no opinion about which of
thousands of words to teach next. This track normalizes the priority score,
adds a domain-supplied utility term with a provider contract, defines the
degenerate-domain ranking path, and adds session-level learning science
(diversity, interleaving, load smoothing, review-load budget) to the queue.

**Relationship to existing work:** the
`frequency_semantic_ranking_layer_20260611` track designs the *data layers*
(frequency, semantic similarity, article ranking) as graph extensions; this
track defines the *engine contract* that consumes such signals. The two must
be reconciled in Phase 1 so the utility-provider interface matches what the
ranking-layer track produces. Addresses open tech-debt: "No calibrated
frequency, semantic, or article-ranking layers" (High, 2026-06-10) on the
engine-contract side.

**Dependencies:** consumes the corrected readiness formula from
`kst_srs_core_correctness_20260707`; its Phase 1 must not finalize the
priority formula until that track's FR-1 decision is approved.

## Functional Requirements

### FR-1: Normalized priority score

Every term in `priority(B)` must be normalized to [0,1] before weighting so
the configured `a, b, c, d` weights are meaningful:

- `readiness(B)`: already [0,1] (v3 gated formula).
- `unlockValue(B)`: define a normative normalization (candidates: log-scaled
  count divided by log of graph max; percentile rank within the domain graph;
  decided in Phase 1). Precomputable per graph release.
- `goalProximity(B)`: define a bounded form (e.g. `1/(1+d)` over graph
  distance `d`), including `d = 0` and unreachable-goal cases; 0 when no
  goal is set.
- `weaknessFit(B)`: define the [0,1] scale and how multiple active
  misconceptions/failed areas combine.

Default weights re-derived after normalization; worked example demonstrating
the v2 dominance failure (raw `unlockValue` swamping all other terms) and
the normalized result.

### FR-2: Domain utility term and provider contract

Extend the priority score with a fifth term `e·utility(B)` where
`utility(B) ∈ [0,1]` is supplied by a **domain utility provider** — a new
adapter-pattern contract (§15 style):

- Interface: given a node and learner context, return a utility score plus
  provenance (signal sources and versions, e.g. corpus frequency list,
  goal-coverage computation).
- Providers are versioned, deterministic, and declared per domain; the
  engine defaults to `utility = 0` (weight `e` inert) when no provider is
  registered.
- Composition rule when a domain supplies multiple signals (e.g. frequency
  + curriculum-unit priority + article-coverage gain).
- The interface must be reconciled with the outputs planned by
  `frequency_semantic_ranking_layer_20260611` (Phase 1 gate).

### FR-3: Prerequisite-sparse domain ranking path

Define normative planner behavior when the fringe is degenerate: detection
rule (e.g. share of candidate nodes with no prerequisites above a threshold,
or per-node absence of prerequisite edges), and the resulting ranking path
in which utility (FR-2) and weaknessFit carry the ordering while readiness
contributes only gating. Must include a worked vocabulary example: thousands
of untouched words, frequency-based utility provider, sensible top-N output.
No change to the graph itself is permitted (no synthetic prerequisites) —
consistent with the zero-automatic-prerequisite policy in the lexical
tracks.

### FR-4: Diversity constraint on recommendedNext

Top-N by raw priority can return N near-identical skills from one lesson.
Define a diversity rule for `recommendedNext` (§9.4/§10.2): a configurable
cap per containment group (`contains` ancestry) and/or a
maximal-marginal-relevance-style reranking (decided in Phase 1), applied
after priority ranking, with deterministic tie-breaking.

### FR-5: Review-load budget

Recommending new skills creates future review debt the planner never sees.
Define a review-load budget coupling planner and SRS: a projected daily
review load (from current card stabilities and retention targets) and a
configurable budget above which the planner throttles new-skill
recommendations (surfacing "review day" guidance instead). Must specify the
projection formula, the throttle rule, and teacher/student projection
surfacing.

### FR-6: Session composition — interleaving and load smoothing

The §12.7 queue is sorted by category, producing blocked practice, and
intervals cluster reviews onto the same days. Define: (a) an interleaving
rule shuffling due items across objectives/variants within the ordering
constraints established by the core-correctness track (reviews-before-new
and caps preserved); (b) interval fuzzing (small randomized jitter on
scheduled intervals, deterministic per card+rep for reproducibility) to
smooth daily load; (c) optional load balancing that shifts due dates within
a bounded window toward lighter days.

## Non-Functional Requirements

- **Domain neutrality:** utility signals enter only through the provider
  contract; the core planner remains domain-blind.
- **Determinism:** all ranking, diversity, interleaving, and fuzzing rules
  are deterministic given (inputs, config, seed).
- **Provenance:** every utility score is explainable — provider version and
  contributing signals are recorded, consistent with the repository's
  provenance-first policy.
- **Performance:** normalization constants and `unlockValue` are
  precomputable per graph release; per-request planner cost must not grow
  superlinearly in fringe size.
- **Worked examples:** every new rule includes a worked numeric example.

## Acceptance Criteria

1. All five priority terms (including `utility`) are defined on [0,1] with
   normative normalizations; the worked example shows the unlockValue
   dominance defect and its resolution on the same graph.
2. The domain utility provider contract is specified (interface, versioning,
   provenance, composition, default-off), and its shape is explicitly
   reconciled with `frequency_semantic_ranking_layer_20260611` (recorded
   decision, both tracks referencing the same interface).
3. The prerequisite-sparse path is normative, with a vocabulary worked
   example producing a defensible top-N from a frequency utility provider
   without any synthetic prerequisite edges.
4. `recommendedNext` diversity is specified with deterministic behavior and
   a worked example (five same-lesson candidates → diversified output).
5. The review-load budget defines projection, throttle, and surfacing; a
   worked example shows new-skill recommendations throttling under review
   debt.
6. Interleaving, fuzzing, and load smoothing are specified without violating
   the core-correctness queue rules (reviews-first, caps, backlog policy).
7. Version/changelog updated (coordinated with other in-flight kst-srs
   tracks); migration notes enumerate downstream changes; the related
   tech-debt entry is updated to reference this track.

## Out of Scope

- Producing the frequency/semantic/article-ranking data layers themselves
  (→ `frequency_semantic_ranking_layer_20260611`).
- Article recommendation contracts
  (→ `lexical_recommendation_contract_20260610`).
- Core readiness/queue correctness fixes
  (→ `kst_srs_core_correctness_20260707`).
- Motivation/engagement modeling and UI presentation of recommendations.
- Runtime implementation in consuming apps (migration notes only).
