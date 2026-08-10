# Implementation Plan: English Lexical Graph Core Release (YLE Baseline Freeze)

> **Intent:** Verify and freeze the Cambridge YLE 2025 baseline in the existing
> lexical graph. This is a one-time audit/review/consumption-contract freeze —
> not a standing regeneration product pipeline.
>
> **Marker vocabulary (orchestrator):** `[x]` complete · `[~]` in-progress or
> next executable · `[b]` human-gated. Legacy `[ ]` is not used.
>
> **First remaining automatable work:** Phase 2 Task "Build YLE membership audit
> fixtures and check harness" (marked `[~]`). Phase 1's two owner approvals
> remain human-gated.
>
> **Marker-contract note:** Skill vocabulary wants human gates as
> `[b] … deferred:<owner>`. The repo checker still (1) matches only
> `[ ~x]` so `[b]` lines are invisible to its counts, and (2) drops any task
> text containing substring `deferred` (anti-pattern A1). Human gates therefore
> use `[b] … human-gate:<owner>` and automatable work stays `[~]` so the first
> executable task remains discoverable without false completion. See
> `test-strategy.md` §9.

## Phase 1: Freeze Scope, Facts Inventory, And Review Rules

- [x] Task: Lock freeze scope and baseline facts — commit: c8e344761411836d55b392deb542960f0f12daee
  - [x] Confirm release authority is YLE-only; A2 Key/B1 are method-later only — commit: c8e344761411836d55b392deb542960f0f12daee
  - [x] Snapshot labeled baseline counts from tracked artifacts (YLE skills, Starters/Movers/Flyers membership, topic groups, support edges, prerequisite count) into a draft freeze facts section — commit: c8e344761411836d55b392deb542960f0f12daee
  - [x] Cite official YLE 2025 source identity from `SOURCES.md` (URL + SHA-256) — commit: c8e344761411836d55b392deb542960f0f12daee
  - [x] Evidence: labeled integers in the draft facts section; no digit-only claims — commit: c8e344761411836d55b392deb542960f0f12daee
- [x] Task: Separate source-backed facts from derived signals — commit: c8e344761411836d55b392deb542960f0f12daee
  - [x] Catalog edge types touching YLE: `contains`, `aligned_to_standard`, `supports` (and confirm `prerequisite_for` = 0) — commit: c8e344761411836d55b392deb542960f0f12daee
  - [x] Label each class as source-backed fact vs derived support signal — commit: c8e344761411836d55b392deb542960f0f12daee
  - [x] Prohibit fabricated hard prerequisites in the written freeze rules — commit: c8e344761411836d55b392deb542960f0f12daee
- [x] Task: Define durable YLE review records — commit: c8e344761411836d55b392deb542960f0f12daee
  - [x] Decision fields: reviewer role, timestamp, source location, finding class (omit / false-include / bad-merge / group / support / other), disposition, supersession — commit: c8e344761411836d55b392deb542960f0f12daee
  - [x] Define exception and quarantine handling for freeze blockers — commit: c8e344761411836d55b392deb542960f0f12daee
- [x] Task: Define sampling plan and plain-language thresholds — commit: c8e344761411836d55b392deb542960f0f12daee
  - [x] Alphabetical, thematic, collision/merge, and support-edge samples — commit: c8e344761411836d55b392deb542960f0f12daee
  - [x] Map samples to spec quality thresholds (labeled metrics only) — commit: c8e344761411836d55b392deb542960f0f12daee
- [b] Task: Approve Phase 1 rules — human-gate:curriculum-language
  - [b] Curriculum/language owner accepts sampling and fact-vs-signal split — human-gate:curriculum-language
  - [b] Engineering owner accepts freeze package shape and sanity-only technical gate — human-gate:engineering

**Mid-Red evidence (2026-08-10, resumed after harness crash):** Added
`tests/yle_p1_scope.sh`. `bash tests/yle_p1_scope.sh` exits `1` as expected
(`PASS=2`, `FAIL=3`): the dedicated `phase1-scope.md` artifact is absent, so
labeled baseline/source facts, the fact-vs-signal catalog, and the explicit
zero-`prerequisite_for` rule are not yet present. No Green artifacts or graph
files were changed.

**Green evidence (2026-08-10):** `c8e344761411836d55b392deb542960f0f12daee`
adds `english/cefr-vocabulary/review/yle-2025/phase1-scope.md`. The targeted
`bash tests/yle_p1_scope.sh` exited `0` (5 checks); `git diff --check` exited
`0`; both requested `node --check` commands exited `0`; and
`node english/cefr-vocabulary/scripts/validate-vocabulary-graph.js` exited `0`
with a valid 3,752-skill inventory. `bash measure/doctor.sh` is unavailable in
this repository (exit `127`: file does not exist), so the documented Phase 1
Green gate and requested project gates are the evidence for these automatable
tasks. The two approval tasks remain human-gated and incomplete.

## Phase 2: YLE List Fidelity Audit

- [~] Task: Build YLE membership audit fixtures and check harness
  - [~] Fixtures for Starters, Movers, Flyers alphabetical slices
  - [~] Expected skill IDs / exam membership / explicit omission decisions
  - [~] Red command must fail until audit evidence exists (see test-strategy)
- [~] Task: Audit Starters / Movers / Flyers membership against official list
  - [~] Stratified review meeting sample minima
  - [~] Record omissions, false inclusions, POS/form errors with decisions
  - [~] Verify cumulative interpretation is documented as consumption rule
- [~] Task: Audit lexical forms, MWEs, variants, and merges
  - [~] Review MWE and variant handling on YLE entries
  - [~] Resolve or quarantine high-severity collisions and false merges
- [~] Task: Audit thematic and grammatical groups
  - [~] Review YLE thematic membership sample (≥100 or full set rules)
  - [~] Account for grammatical lists: represent or accept explicit omission
  - [~] Quarantine groups failing precision threshold
- [b] Task: Curriculum sign-off on YLE fidelity — human-gate:curriculum-language
  - [b] Accept retained YLE membership and group decisions — human-gate:curriculum-language

## Phase 3: Relationship And Progression Review

- [~] Task: Inventory all YLE-touching `supports` edges by derivation method
  - [~] Same-form POS support vs MWE component support counts (labeled)
  - [~] Produce review queue stratified by method
- [~] Task: Pedagogical review of support signals
  - [~] Judge reasonableness; promote / demote / quarantine / reject
  - [~] Ensure no support edge is documented as a hard prerequisite
- [~] Task: Confirm progression policy
  - [~] Write that next-step order uses learner state + stage goals + SRS +
        groups + optional utility — never invented `prerequisite_for`
  - [~] Guard test: zero `prerequisite_for` on freeze baseline
- [b] Task: Curriculum sign-off on relationships — human-gate:curriculum-language
  - [b] Accept fact-vs-signal labeling and support dispositions — human-gate:curriculum-language

## Phase 4: Consumption And Next-Step Contract

- [~] Task: Draft `YLE-CONSUMPTION.md` (static graph + dynamic learner state)
  - [~] Table of what lives in graph vs application state
  - [~] Algorithms/rules for: SRS due work, lower-level gaps, current stage,
        reading targets, MWE readiness, topic foci
  - [~] Explicit ban on storing per-student fields on graph nodes
- [~] Task: Define explainability payload shape
  - [~] Each next-step item cites graph fact IDs and learner-state fields
  - [~] Derived signals labeled separately from source-backed facts
- [~] Task: Contract tests for consumption rules (offline, no app runtime)
  - [~] Profile fixtures: Starters learner, Movers goal with Starters gaps,
        Flyers reader with mixed mastery
  - [~] Assert gap, stage, and due-work outputs from contract examples
- [b] Task: Approve consumption contract — human-gate:engineering
  - [b] Engineering accepts boundary and payload shape — human-gate:engineering
  - [b] Curriculum/language accepts pedagogical next-step rules — human-gate:curriculum-language

## Phase 5: Reading-Program Validation

- [~] Task: Assemble representative texts and learner profiles
  - [~] At least one Starters, one Movers, one Flyers text fixture
  - [~] Profiles with known/unknown mixes and MWE cases
- [~] Task: Offline matching and coverage evaluation
  - [~] Longest-MWE match against YLE matchForms
  - [~] known / unknown / unmatched classification
  - [~] Eligible-token known coverage; unmatched tokens remain in denominator
  - [~] Bounded target-vocabulary set with explicit cap
- [~] Task: Explainable recommendation and progress evidence traces
  - [~] Rationale payload per target skill and per reading candidate
  - [~] Before/after progress snapshot under simulated reviews
- [b] Task: Curriculum plausibility review of reading fixtures — human-gate:curriculum-language
  - [b] Accept or request fixture revisions — human-gate:curriculum-language

## Phase 6: Freeze Package, Sanity Check, And Decision

- [~] Task: Assemble YLE freeze package
  - [~] Decision log, exception list, quality summary with labeled metrics
  - [~] Consumption contract, reading fixture index, method appendix for A2/B1
  - [~] `RELEASE-YLE-2025.md` draft decision section (unsigned)
- [~] Task: Bounded final technical sanity check (one-shot, not a pipeline)
  - [~] Verify frozen YLE source identity (hash/registry citation)
  - [~] Structural integrity: unique IDs, no dangling edges, YLE skill count
        consistency, zero `prerequisite_for`
  - [~] Freeze artifacts consistent with accepted decisions
  - [~] Commands limited to validation/report checks — not recurring dual-run
        regeneration ceremony
- [b] Task: Dual human freeze decision — human-gate:curriculum-language
  - [b] Curriculum/language records go / conditional-go / no-go — human-gate:curriculum-language
  - [b] Engineering records go / conditional-go / no-go — human-gate:engineering
  - [b] Only on go or conditional-go: mark baseline frozen and note accepted
        limitations — human-gate:both-owners

## Completion Rule

This track is complete only when the YLE 2025 baseline is human-accepted,
consumption/next-step rules are documented and fixture-proven, reading-program
checks pass, the freeze package exists, and the bounded sanity check passes.
Follow-on A2 Key / B1 Preliminary freezes and enrichment tracks are separate.
No phase may be marked complete without the evidence named in its tasks and in
`test-strategy.md`.
