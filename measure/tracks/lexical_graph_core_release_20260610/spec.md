# Specification: English Lexical Graph Core Release (YLE Baseline Freeze)

## Overview

Verify, review, and freeze the **Cambridge YLE 2025** portion of the existing
English CEFR/Cambridge lexical graph as a one-time, app-consumable baseline.

This track does **not** rebuild the graph from scratch and does **not** create
an ongoing product process of repeated source refresh or regeneration. The
tracked inventory and knowledge-space already exist. The work is audit,
pedagogical review, consumption-contract definition, reading-program
validation, human go/no-go, and a **bounded** final technical sanity check.

A2 Key and B1 Preliminary remain in the tracked multi-exam graph for
structural context, but **release authority in this track is YLE only**. The
approved YLE method is recorded so A2 Key / B1 Preliminary can be audited and
frozen later under separate work—without making regeneration a standing
product pipeline.

Dependent enrichment and recommendation tracks stay blocked until this YLE
baseline is accepted.

### Known Draft Baseline (pre-audit facts, not acceptance)

These counts describe the current tracked draft and are starting points for
verification, not proof of quality:

| Fact | Current draft value |
|---|---:|
| YLE-aligned lexical skills (`cambridge-yle-word-list-2025`) | 1,388 |
| Pre A1 Starters exam membership | 491 |
| A1 Movers exam membership | 392 |
| A2 Flyers exam membership | 507 |
| Full multi-exam inventory (YLE + A2 Key + B1) | 3,752 skills |
| YLE thematic topic groups | 20 |
| `prerequisite_for` edges in graph | 0 |
| YLE source PDF (official 2025 list) SHA-256 | `6f7a0ad1e277bd10ae8b3bcccfb76c058f611a607c6c9947601abbd7e16a99fa` |

## Release Boundary

### In Scope

1. **YLE list fidelity** — Confirm the frozen graph correctly represents the
   official Cambridge YLE 2025 lists: all current YLE-aligned skills, separate
   Starters / Movers / Flyers membership, cumulative interpretation, lexical
   forms, POS, MWEs, variants, thematic and grammatical groups, omissions,
   false inclusions, and incorrect merges.
2. **Relationship and progression review** — Judge whether edge types and
   progression signals are pedagogically reasonable. Separate **source-backed
   facts** (`contains`, `aligned_to_standard`, exam/topic membership) from
   **derived support signals** (`supports` for same-form POS and MWE
   components). Explicitly review every support-edge class that touches YLE
   skills. **Fabricated hard prerequisites are prohibited.**
3. **Consumption and next-step contract** — Define how consuming applications
   combine the **static** graph with **dynamic learner state** to track
   progress and choose next work (SRS due items, lower-level gaps, current
   stage, reading targets, MWE readiness, topics). Per-student state must not
   live in the static graph.
4. **Reading-program validation** — Exercise representative Starters, Movers,
   and Flyers texts and learner profiles for lexical matching,
   known / unknown / unmatched tokens, known-word coverage, bounded target
   vocabulary, explainable recommendations, and progress evidence.
5. **Human review and freeze package** — Curriculum/language and engineering
   review, exception resolution, final audit/release package, and YLE baseline
   freeze. Record how the same method extends later to A2 Key / B1 Preliminary.

### Bounded Technical Sanity Only

The only required automated engineering gate at freeze is a **one-shot** check
of:

- YLE source hash / registry identity for the frozen baseline;
- structural integrity (IDs, dangling edges, skill/inventory consistency);
- final freeze-artifact consistency with review decisions.

This is **not** a standing regeneration, dual-run byte-identity, or continuous
source-refresh product process.

### Out Of Scope

- Application databases, APIs, SRS persistence, UI, or production runtimes.
- Implementing recommendation services (contracts and offline fixtures only).
- Frequency, WordNet, embedding, ConceptNet, or other enrichment layers.
- Treating CEFR band, topic membership, unit order, frequency, or similarity
  as hard prerequisites.
- Republishing Cambridge PDFs.
- Claiming complete English vocabulary coverage from exam lists alone.
- Making repeated PDF refresh / graph regeneration an ongoing product process.
- Full A2 Key / B1 Preliminary release authority (method note only).

## Functional Requirements

### FR-1: YLE Source Truth And Membership

- Bind the freeze to the official Cambridge YLE 2025 combined word list
  documented in `english/cefr-vocabulary/SOURCES.md`.
- Verify every YLE-aligned skill against Starters, Movers, and Flyers list
  membership as represented in the graph.
- Document cumulative interpretation: Movers assumes Starters; Flyers assumes
  Starters + Movers. Cumulative need is a **consumption rule**, not extra
  duplicated membership edges unless the source itself lists the word at
  multiple levels.
- Record omissions (in source, missing from graph), false inclusions (in
  graph, not in source), and incorrect merges/splits with durable decisions.

### FR-2: Lexical Identity Fidelity

- Verify headwords, normalized forms, match forms, parts of speech, multi-word
  expressions, parenthetical variants, and special tokens for YLE entries.
- Record identity collisions, suspicious entries, and merge decisions that
  affect YLE skills.
- Keep form+POS as the v1 assessable unit unless a reviewed decision changes
  it; sense-level identity remains a separate track.

### FR-3: Groups

- Verify the 20 YLE thematic topic groups and their membership quality.
- Account for YLE grammatical lists (days, months, question words, etc.):
  either represent them as reviewed groups with provenance, or record an
  explicit accepted omission / deferred representation with rationale.
- Do not densify groups into pairwise word-word edges.

### FR-4: Relationship Types And Progression

- Classify each YLE-touching edge type as **source-backed fact** or **derived
  support signal**.
- Review pedagogical reasonableness of derived `supports` edges (same-form POS
  and MWE component support). Promote, demote, quarantine, or reject with
  durable decisions—never silently treat them as prerequisites.
- Enforce **zero** `prerequisite_for` edges on the YLE baseline (and do not
  add any).
- Progression / next-step ordering must use learner state, stage goals, SRS
  urgency, groups, and optional utility signals—not invented hard gates.

### FR-5: Static Graph Plus Dynamic Learner State

Define an application-neutral consumption contract that states:

| Concern | Lives in |
|---|---|
| Lexical skills, exam/topic membership, CEFR alignment, approved support edges, match forms | Static graph release |
| Per-student mastery, SRS card state, due dates, exposure counts, goals, interests | Application learner state |
| Next-step ranking inputs combining both | Application planner using published contract |

Required next-step outputs (contract-level, not app UI):

1. SRS-due YLE skills (from learner schedule state).
2. Lower-level gaps (e.g. Starters gaps for a Movers-goal learner) using
   cumulative interpretation.
3. Current stage estimate (Starters / Movers / Flyers band) from evidence.
4. Reading targets: articles/texts with high known-word coverage and bounded
   unknown/target density.
5. MWE readiness from component-word support + learner mastery.
6. Topic foci from group membership and learner goals.

### FR-6: Reading-Program Validation

Provide offline fixtures (not a production service) that demonstrate:

- Tokenization / longest-MWE matching against YLE `matchForms`.
- Classification of known, unknown, and unmatched tokens.
- Eligible-token known-word coverage (unmatched difficult tokens must not
  vanish from the denominator).
- Bounded target-vocabulary sets for Starters, Movers, and Flyers profiles.
- Explainable recommendation rationales (which graph facts and which learner
  state fields contributed).
- Progress evidence snapshots before/after simulated study.

### FR-7: Review Governance And Freeze Package

- Durable review queues and decision records for YLE audits.
- Named human gates: **curriculum/language owner** and **engineering owner**.
- Final package: baseline inventory snapshot reference, decision log, quality
  summary, consumption contract, reading fixtures summary, exception list,
  go / conditional-go / no-go decision, and freeze tag/notes.
- Method appendix: how to repeat the audit for A2 Key and B1 Preliminary later
  without productizing continuous regeneration.

## Quality Thresholds

Thresholds may be tightened at Phase 1 approval; they must not be weakened
without written rationale in the decision log.

| Measure | Freeze threshold |
|---|---:|
| YLE alphabetical membership precision (reviewed sample or full pass) | ≥ 99.5% |
| YLE alphabetical membership recall | ≥ 99.0% |
| YLE thematic membership precision (retained groups) | ≥ 98.0% |
| Unresolved high-severity omissions / false inclusions / bad merges | 0 |
| `prerequisite_for` edges touching released YLE baseline | 0 |
| Derived support edges without explicit fact-vs-signal labeling in contract | 0 classes unlabeled |
| Required freeze-package artifacts present | 100% |
| Final sanity: source identity + structural integrity + artifact consistency | Pass |
| Human go / conditional-go / no-go recorded by both owners | Required |

Minimum review depth unless the population is smaller:

- ≥ 200 stratified YLE alphabetical entries (or all if fewer).
- ≥ 100 stratified YLE thematic memberships.
- 100% of high-severity identity collisions and suspected false merges.
- Explicit sample of YLE-touching `supports` edges by derivation method.

## Required Artifacts

Paths may be adjusted in-plan if the directory layout is standardized, but the
freeze package must include equivalents of:

- `english/cefr-vocabulary/review/yle-2025/` — queues, decisions, exceptions
- `english/cefr-vocabulary/reports/yle-baseline-freeze.json`
- `english/cefr-vocabulary/reports/yle-baseline-freeze.md`
- `english/cefr-vocabulary/YLE-CONSUMPTION.md` — static graph + learner state
  next-step contract (may live beside or supersede sections of a broader
  app-consumption guide)
- `english/cefr-vocabulary/fixtures/yle-reading/` — texts, profiles, expected
  matching/coverage/recommendation traces
- `english/cefr-vocabulary/RELEASE-YLE-2025.md` — freeze decision and method
  appendix for later A2/B1

## Non-Functional Requirements

- **One-time freeze mindset:** audit and lock; do not institutionalize endless
  refresh.
- **Traceability:** every accepted YLE node/edge class has provenance or an
  explicit derived-signal label.
- **Auditability:** decisions are durable, attributable, and supersedable.
- **Portability:** contracts stay application-neutral.
- **Honesty:** draft graph counts are not quality evidence by themselves.

## Acceptance Criteria (plain language, falsifiable)

- **AC-1 Membership:** A reviewer can pick any Starters, Movers, or Flyers
  source entry from the official list and find the correct graph skill and
  exam membership, or find a durable decision explaining omission. Fails if
  silent misses or silent extras remain above thresholds.
- **AC-2 Cumulative rule:** The consumption contract states how Movers/Flyers
  learners inherit lower-level expectations, and a fixture demonstrates a
  lower-level gap appearing for a higher-stage goal learner.
- **AC-3 Forms:** YLE MWEs, variants, and POS splits in the freeze sample match
  the source or have decisions; fails on undocumented false merges.
- **AC-4 Groups:** Each retained YLE thematic group meets membership precision;
  grammatical-list handling is either represented or explicitly accepted as
  omitted with rationale.
- **AC-5 No hard prereqs:** Released YLE baseline has zero `prerequisite_for`
  edges; support edges are documented as non-mandatory signals.
- **AC-6 Next steps:** Given static graph + example learner state, the contract
  yields explainable SRS-due work, stage, gaps, reading targets, MWE
  readiness, and topics—without reading or writing per-student fields on
  graph nodes.
- **AC-7 Reading program:** Offline fixtures for Starters, Movers, and Flyers
  texts show known/unknown/unmatched classification, eligible known coverage,
  bounded targets, and rationale payloads.
- **AC-8 Freeze:** Both curriculum/language and engineering owners record
  go, conditional-go, or no-go; freeze package is complete; bounded sanity
  check passes; A2/B1 extension is method-only.

## Human-Gated Owners

| Gate | Owner role | Artifact |
|---|---|---|
| Audit thresholds & sampling plan | Curriculum/language | Phase 1 decision record |
| YLE list fidelity & groups | Curriculum/language | YLE decision log |
| Support-edge pedagogy | Curriculum/language | Relationship review record |
| Consumption/next-step contract | Engineering + curriculum/language | `YLE-CONSUMPTION.md` |
| Reading fixture plausibility | Curriculum/language | Fixture review notes |
| Structural sanity & package integrity | Engineering | Freeze sanity report |
| Final freeze decision | Both owners | `RELEASE-YLE-2025.md` |

## Relationship To Other Tracks

- **Blocks** coverage, semantic, and recommendation tracks until YLE baseline
  contracts and freeze decision are accepted (or those tracks explicitly
  narrow to non-YLE work with their own gates).
- **Does not implement** the full portable recommendation service track; it
  supplies YLE reading fixtures and the consumption boundary those tracks
  must respect.
- **Sense-level identity**, B2 expansion, and frequency/semantic layers remain
  separate.
