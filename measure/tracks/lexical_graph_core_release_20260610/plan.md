# Implementation Plan: English Lexical Graph Core Release (YLE Baseline Freeze)

> **Intent:** Verify and freeze the Cambridge YLE 2025 baseline in the existing
> lexical graph. This is a one-time audit/review/consumption-contract freeze —
> not a standing regeneration product pipeline.
>
> **Marker vocabulary (orchestrator):** `[x]` complete · `[~]` in-progress or
> next executable · `[b]` human-gated. Legacy `[ ]` is not used.
>
> **First remaining automatable work:** Phase 3 Task "Inventory all YLE-touching
> `supports` edges by derivation method" (marked `[~]`). Phase 2's automatable
> work is complete at `2daf568`; its curriculum sign-off stays a `[b]` human
> gate. Phase 1's explicit dual-owner approval is recorded by
> `8447a3b174210c4845f6e0fb2fea8caa0fc93f28` in
> `english/cefr-vocabulary/review/yle-2025/phase1-approval.md`.
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
- [x] Task: Approve Phase 1 rules — commit: 8447a3b174210c4845f6e0fb2fea8caa0fc93f28
  - [x] Curriculum/language owner accepts sampling and fact-vs-signal split — commit: 8447a3b174210c4845f6e0fb2fea8caa0fc93f28
  - [x] Engineering owner accepts freeze package shape and sanity-only technical gate — commit: 8447a3b174210c4845f6e0fb2fea8caa0fc93f28

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
tasks. The two approval tasks remained human-gated until the explicit owner
approval recorded below.

**Green human-approval evidence (2026-08-10):**
`8447a3b174210c4845f6e0fb2fea8caa0fc93f28` adds
`english/cefr-vocabulary/review/yle-2025/phase1-approval.md`, faithfully
transcribing the user-supplied explicit approval as curriculum/language and
engineering owners. `bash tests/yle_p1_scope.sh` exited `0` (5 checks) and
`git diff --check` exited `0` before the evidence commit.

**Approval-state prose remediation (2026-08-10):**
`056eda1a7f14abb9d776f1a9c3c91fa21be7d1ee` aligns the approval-state prose in
`english/cefr-vocabulary/review/yle-2025/phase1-scope.md` with the existing
explicit dual-owner approval record. The Phase 2 membership-fixture task
remains the next automatable work.

**A4 scope-guard remediation (2026-08-10):**
`5bc047da8e58a975aa2140d2e7b5101fcf0b18fa` updates
`tests/yle_p1_scope.sh` so every plan read honors `PLAN_OVERRIDE`, it parses
only the exact Phase 1 section, and it reports `INCOMPLETE` with a labeled
completed-task count when no substantive completed task exists. The targeted
`bash tests/yle_p1_scope.sh && bash tests/yle_p1_a4_guard.sh` command exited
`0` (6 scope checks and 3 A4 checks); `git diff --check` exited `0`; and
`node english/cefr-vocabulary/scripts/validate-vocabulary-graph.js` reported
`status: "valid"` with 3,752 inventory entries.

## Phase 2: YLE List Fidelity Audit

- [x] Task: Build YLE membership audit fixtures and check harness — commit: 26e6d1001c91b0a674d4aac9516ecdd65c55b9db
  - [x] Fixtures for Starters, Movers, Flyers alphabetical slices
  - [x] Expected skill IDs / exam membership / explicit omission decisions
  - [x] Red command must fail until audit evidence exists (see test-strategy)
- [x] Task: Audit Starters / Movers / Flyers membership against official list — commit: 26e6d1001c91b0a674d4aac9516ecdd65c55b9db
  - [x] Stratified review meeting sample minima
  - [x] Record omissions, false inclusions, POS/form errors with decisions
  - [x] Verify cumulative interpretation is documented as consumption rule
- [x] Task: Audit lexical forms, MWEs, variants, and merges — commit: 26e6d1001c91b0a674d4aac9516ecdd65c55b9db
  - [x] Review MWE and variant handling on YLE entries
  - [x] Resolve or quarantine high-severity collisions and false merges
- [x] Task: Audit thematic and grammatical groups — commit: 26e6d1001c91b0a674d4aac9516ecdd65c55b9db
  - [x] Review YLE thematic membership sample (≥100 or full set rules)
  - [x] Account for grammatical lists: represent or accept explicit omission
  - [x] Quarantine groups failing precision threshold
- [x] Task: Remediate independent YLE source-completeness and data-handling Red contract — commit: 2daf568
  - [x] Derive 495 Starters / 399 Movers / 513 Flyers rows from the hash-pinned local PDF and cross-check the combined alphabetic list — commit: 2daf568
  - [x] Detect source-to-graph omissions, false report denominators, unreachable omission decisions, and draft-count circularity — commit: 2daf568
  - [x] Keep complete source row/headword/POS/page data transient and require bounded, staged audit generation — commit: 2daf568
- [b] Task: Curriculum sign-off on YLE fidelity — human-gate:curriculum-language
  - [b] Accept retained YLE membership and group decisions — human-gate:curriculum-language

**Historical artifact evidence (2026-08-11, superseded by independent Red):** `26e6d1001c91b0a674d4aac9516ecdd65c55b9db`
adds a reproducible local-PDF source parser, all 1,390 direct source-row
fixtures (491 Starters, 392 Movers, 507 Flyers), 100 source-derived thematic
reviews across all 20 groups, 25 high-severity collision decisions, the
explicit grammatical-list omission decision, empty durable exception queue,
and labeled JSON/Markdown audit reports. The parser stores page/section
locations and lexical identity fields only; it does not commit PDF excerpts.
Its parser-derived source population and resulting alphabetical precision/recall
claim are refuted by the independent Red oracle below; the
zero `prerequisite_for` and consumption-only cumulative-policy checks remain
preserved. `bash tests/yle_p2_membership.sh` exited
`0` with `PASS=7, FAIL=0`; `git diff --check`, both existing Node syntax
checks, Python compilation for the audit parser, and
`node english/cefr-vocabulary/scripts/validate-vocabulary-graph.js` exited
`0` (valid 3,752-skill inventory). `measure/doctor.sh` is not present in this
repository. The curriculum/language approval remains the truthful `[b]`
human gate; no approval artifact was fabricated.

**Mid-Red evidence (2026-08-11):** Added the test-only
`tests/yle_p2_membership.sh`. `bash tests/yle_p2_membership.sh` exits `1` as
expected (`PASS=1`, `FAIL=6`): the local official YLE PDF identity/hash check
passes, while the non-vacuous Phase 2 marker guard reports the labeled
`Phase 2 completed task count: 0` and the source-row fixtures, durable decision
log, exception/collision queues, membership report, thematic/grammatical
artifacts, and attributable curriculum approval are absent. The harness reads
source locations from the ignored local PDF and compares the eventual full
1,388-skill / 1,390-direct-membership population; it does not commit PDF
contents or generate fixtures from the inventory. No audit artifacts, parser
fixes, graph data, or approval were changed.

**Bounded Mid-Red retry remediation (2026-08-11):** Updated only
`tests/yle_p2_membership.sh` to emit successful Python count/metric diagnostics
outside validation-error capture, check each embedded Python exit status, and
accept the absent approval artifact while the plan truthfully keeps the
curriculum task `[b]`. `bash -n tests/yle_p2_membership.sh` exits `0`.
`bash tests/yle_p2_membership.sh` exits `1` with `PASS=2`, `FAIL=5`: the
remaining failures name the absent source-row fixtures, durable decisions and
collision queues, membership report, and thematic/grammatical artifacts. The
same run prints labeled diagnostics without classifying them as failures; a
temporary `PLAN_OVERRIDE` with the approval task changed to `[x]` still exits
`1` and reports that attributable approval evidence is absent. No Green
artifacts, graph data, or Phase 2 task markers were changed.

**Phase 2 Red remediation evidence (2026-08-11):** `bash -n tests/yle_p2_membership.sh` exits `0`. `bash tests/yle_p2_membership.sh`
exits `1` with `PASS=4, FAIL=5`; the exact captured result is
`/tmp/yle-p2-source-oracle-red.txt`. The transient hash-pinned local-PDF
oracle independently derives labeled direct counts of 495 Starters, 399
Movers, 513 Flyers, and 1,407 total, then cross-checks the separate combined
alphabetic list. It names exactly 17 current source-to-graph omissions and
shows the false 1,390 denominator/recall claims, missing omission decisions,
committed expressive fixtures, draft-count circularity, unbounded PDF
subprocess, and non-atomic report publication. The source oracle itself passes,
so the Red is an expected contract failure rather than a tool or network
failure. No parser, generator, graph, report, or Green artifact was changed.

**Phase 2 Green evidence (2026-08-11):** `2daf568` closes the independent Red
without altering the committed Red contract in `tests/yle_p2_membership.sh`.
`bash tests/yle_p2_membership.sh` exits `0` with `PASS=9, FAIL=0`.

The independent oracle's population (495 Starters / 399 Movers / 513 Flyers,
1,407 direct rows) is now reproduced by the audit generator itself, which
derives its own denominator from the hash-pinned PDF instead of validating
against the removed `{starters: 491, movers: 392, flyers: 507}` draft
dictionary. Four parser defects were confirmed against the local source and
fixed: unrejoined wrapped POS cells, POS-less `a.m.`/`p.m.` rows, the missing
`title` POS alias, and an over-broad `^Page` filter that consumed the headword
`page`. All 17 previously dropped rows are ingested as skills following the
convention already used by the graph's 68 other glossed YLE skills, so
source-to-graph reconciliation is 1,407 of 1,407 with zero unresolved
omissions and zero quarantined blockers.

The committed package no longer reproduces publisher content: the four full
alphabetical/thematic fixtures are replaced by coverage files holding graph
identities, decision IDs, and labeled aggregates, and the generator stages
every artifact in ignored temporary storage before an atomic swap.

Supporting gates: `node english/cefr-vocabulary/scripts/validate-vocabulary-graph.js`
reports `status: "valid"` over 3,769 skills, 3,769 inventory entries, and
18,065 edges; `git diff --check`, `node --check`, and Python compilation for
both audit scripts exit `0`; two clean generator runs produce byte-identical
tracked output and the remediation script is idempotent. `measure/doctor.sh` is
not present in this repository.

Phase 1's baseline snapshot in `phase1-scope.md` is restated from
1388 / 491 / 392 / 507 to 1405 / 495 / 399 / 513, with the superseded figures
recorded in the document. `bash tests/yle_p1_scope.sh` returns to its prior
`PASS=5, FAIL=1` state; that single failure is a pre-existing environment gap
(`rg` is not installed, so the harness cannot count completed tasks) and
reproduces identically at `24824aa`, before any of this work. It is logged as
tech debt, not as Phase 2 evidence.

The curriculum/language sign-off below remains the truthful `[b]` human gate;
no approval artifact was fabricated.

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
