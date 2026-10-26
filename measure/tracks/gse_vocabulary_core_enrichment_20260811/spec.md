# GSE Vocabulary Core Enrichment

## Contents

- [Problem](#problem)
- [Goal](#goal)
- [Source Identity](#source-identity)
- [Functional Requirements](#functional-requirements)
- [Non-Functional Requirements](#non-functional-requirements)
- [Acceptance Criteria](#acceptance-criteria)
- [Out of Scope](#out-of-scope)

## Problem

Core lexical graph nodes carry Cambridge-derived levels but no per-word GSE
scores, and no definitions or examples. The pinned GSE vocabulary exports
(adult GL, 11,586 items; young learner YL, 3,024 items; both 2026-08-11)
provide per-word GSE score, CEFR band, definition, example, variants, and
topics. Most existing nodes map onto GSE entries. That mapping is unbuilt
today, and the exports sit unused in the local cache.

## Goal

Map core vocabulary nodes to pinned GSE vocabulary entries and write
source-backed GSE data onto those nodes in the core graph. The change ships
as a new core graph version under the same freeze discipline as the YLE
baseline. No node receives data the source does not state.

## Source Identity

Pinned 2026-08-11, recorded in `english/cefr-vocabulary/GSE_VOCABULARY_SOURCES.md`:

| Export | Items | SHA-256 (prefix) |
|---|---:|---|
| Vocabulary GL, GSE 10–67 | 11,586 | `e63298d796eecc1d…` |
| Vocabulary YL, GSE 10–59 | 3,024 | `6b8c895055ea6c24…` |

Raw exports stay Git-ignored under `source-pdfs/`. The licensing exception
for definition and example text is recorded under FR-6 and in the sources
document.

## Functional Requirements

**FR-1 — Source acquisition and provenance. (DONE 2026-08-11)** Both exports
are pinned with URL, query parameters, export date, SHA-256, licence text,
redistribution decision, and cache policy in `GSE_VOCABULARY_SOURCES.md`.

**FR-2 — Deterministic extraction.** An extractor produces canonical GSE
vocabulary records carrying `itemId`, expression, POS categories, `gse`,
CEFR band, definition, example, variants, and audience. Two consecutive runs
produce byte-identical tracked output. The 70 starred GL `gse` values and the
129 YL `temporaryGse` values are preserved and explained, not dropped.
Owner decision OI-2 (2026-10-26): preserve the raw plus band and store a separate base band.
Normalize `<A1 (10-21)` and `<A1` to `PRE-A1`, including starred forms. Phase 4 implements this change before Green.

**FR-3 — Node-to-entry mapping contract.** A specification defines how a core
node (form + POS, and audience where relevant) binds to a GSE vocabulary
entry. Ambiguous and unmapped cases persist in durable queues scoped to this
track. No mapping is inferred or guessed.
Owner decision OI-3 (2026-10-26): keep both audience values on a node, each marked with its audience.
STA and PA read YL; RA reads GL. Phase 5 defines the combined contract without audience substitution.

**FR-4 — Core mutation under a version bump.** Mapped nodes gain GSE score
and CEFR band in the core graph. The change ships as a new core version. The
frozen YLE baseline stays reproducible. A byte-level diff report with
labelled counts accompanies the new version.
Owner decision OI-1 (2026-10-26): the committed graph file stays unchanged as a version.
Each change writes a new versioned file. Regeneration never overwrites the current file.

**FR-5 — Level reconciliation.** Where the graph already carries GSE level
data, the pinned source corrects it. Where a GSE band disagrees with the
node's Cambridge-derived level, both values stay visible and the case enters
a conflict report with labelled counts. No silent overwrite.

**FR-6 — Definition and example policy. (DECIDED 2026-08-11)** Option (b):
definition and example text is committed onto nodes. Owner words: "FR-6 (b)
while we are not selling this product and it is only for the purposes they
approved -- measuring mastery levels and planning instruction." The use is
non-commercial and within the purposes the GSE policy approves: planning
courses of study, setting learning goals, and monitoring progress. This
decision is transcribed into `GSE_VOCABULARY_SOURCES.md`.

**FR-7 — Measured effect.** The release report states labelled counts:
nodes mapped, levels added, levels corrected, conflicts, unmapped GSE
entries queued, and GSE entries with no matching node.

**FR-8 — Durable queues and audit isolation.** Queues live under this
track's own directory. Audits name their own queue files explicitly,
following the `COVERAGE_QUEUES` lesson: a foreign queue file must not
change this track's reports.

**FR-9 — Dual human gates.** Separate recorded go/no-go decisions for the
mapping audit and for the core version release, each transcribing owner
words.

**FR-10 — Regression.** All harnesses exit 0. Previously approved artifacts
stay unchanged unless deliberately re-approved. The core version change is
the deliberate re-approval this track exists to make.

## Non-Functional Requirements

- Determinism: every generator is reproducible and idempotent.
- No invention: an absent GSE entry yields a queue row, never data.
- Bounded artifacts: node-mutation counts and queue growth are reported
  before approval.

## Acceptance Criteria

1. The mapping spec defines the binding rule, and every mapped node cites a
   GSE `itemId`.
2. The new core version validates and reproduces byte-identically at new versioned paths.
   The same-procedure YLE isolation proof passes. The committed graph and inventory bytes stay unchanged.
3. Labelled counts for mapped, added, corrected, conflicted, and queued
   cases appear in the release report.
4. The FR-6 decision is recorded with owner words (done 2026-08-11,
   option b).
5. Both human gates are recorded with owner words.
6. All harnesses exit 0.

## Out of Scope

- B2 vocabulary (`b2_vocabulary_source_expansion_20260611` stays parked).
- New word nodes for GSE entries with no matching core node (queue only).
- The inflection axis (`gse_grammar_inflection_levels_20260811` owns it).
- The sense axis (`sense_level_identity_spec_20260611` owns it).
- Any production runtime; this repository ships contracts and data only.
