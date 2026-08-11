# YLE 2025 Consumption And Next-Step Contract

**Status:** Approved for the YLE 2025 baseline freeze (dual go,
`review/yle-2025/phase4-approval.md`, 2026-08-11).
**Scope:** Cambridge YLE 2025 (Starters / Movers / Flyers) only.
**Runtime:** Offline pure functions over `(graphSnapshot, learnerState)` —
no application database, API, or production SRS runtime is required by this
contract.

## 1. Static Graph vs Dynamic Learner State

| Concern | Lives in static graph | Lives in application / learner state |
|---|---|---|
| Skill identity (form + POS) | skill node `id`, `metadata.lexicalForm`, `partsOfSpeech`, `matchForms` | — |
| Exam membership (Starters/Movers/Flyers) | `contains` edges from exam nodes | goal stage; which memberships count as “in scope” |
| CEFR alignment | `aligned_to_standard` edges | optional goal filters |
| Topic groups | topic `content_group` + `contains` | topic focus preferences |
| Derived support signals | `supports` edges (`same-lexical-form-support-v1`, `multiword-component-support-v1`) | whether to use them for soft ranking |
| Mastery / known / unknown | **never** | per-skill mastery map |
| SRS due times / stability | **never** | per-card schedule |
| Session queue / last review | **never** | session state |
| Reading progress | **never** | learner reading log |

### Hard ban: no per-student fields on graph nodes

Consumers **must not** write mastery, due dates, `reviewStatus` as student
truth, ratings, or session fields onto graph skill nodes. Graph
`reviewStatus` on tracked artifacts is inventory draft state, not a learner.

If an example mutates a graph skill to encode mastery, it **fails** this
contract.

## 2. Stage Model And Cumulative Gaps

Exam codes used in fixtures and algorithms:

| Stage code | Exam id | Cumulative expectation |
|---|---|---|
| `starters` | `pre-a1-starters` | Starters only |
| `movers` | `a1-movers` | Starters + Movers |
| `flyers` | `a2-flyers` | Starters + Movers + Flyers |

**Cumulative interpretation is a consumption rule**, not duplicate membership
or `prerequisite_for` edges. A Movers goal includes Starters expectations; a
Flyers goal includes Starters and Movers expectations.

### Lower-level gap rule

Given `learnerState.goalStage` and `learnerState.mastery`:

1. Build the **expected exam set** for the goal (cumulative table above).
2. Collect skill IDs that the static graph places in those exams via
   `contains` edges from the corresponding exam nodes.
3. A skill is a **gap** when its mastery status is not in
   `{known, mastered}` (case-insensitive).
4. A gap is a **lower-level gap** when the skill’s earliest YLE exam is
   strictly earlier than the goal stage (Starters < Movers < Flyers).

**Falsifier:** a Movers-goal profile with weak Starters mastery that yields
**zero** lower-level gaps fails the contract.

## 3. Next-Step Algorithms (Offline)

All algorithms are pure: they read a graph snapshot and a learner state object
and return JSON. They do not open a database.

### 3.1 Current stage

`currentStage = learnerState.goalStage` (must be one of `starters|movers|flyers`).
Optional: if the application tracks placement separately, expose it as
`learnerState.placementStage` but do not write it onto the graph.

### 3.2 SRS due work

Input: `learnerState.dueSkillIds: string[]` (already computed by the app’s SRS).

Output: ordered list of those IDs that are in the cumulative expected skill set
for the goal, preserving input order. Each item is tagged
`category: "srs_due"`.

### 3.3 Lower-level gaps

As in §2. Prefer gaps at the earliest stage first. Tag
`category: "lower_level_gap"`.

### 3.4 Current-stage unknowns

Gaps whose earliest YLE exam equals the goal stage. Tag
`category: "current_stage_unknown"`.

### 3.5 Topic foci

If `learnerState.topicFocusGroupIds` is non-empty, intersect unknown/gap skills
with skills `contains`-linked from those topic groups. Tag
`category: "topic_focus"`.

### 3.6 MWE readiness (optional signal)

For an MWE skill in scope:

- Collect inbound `supports` edges with
  `sourceRefs` containing `multiword-component-support-v1`.
- Components marked known/mastered raise an optional readiness score.
- Components unknown do **not** block the MWE: this is never a hard gate.
- Tag `category: "mwe_readiness_signal"` and label the support edges as
  **derived signals**, not source-backed facts.

### 3.7 Ranking merge (reference order)

When building a bounded next-step list (default cap 10):

1. All `srs_due` items (preserve due order).
2. Then `lower_level_gap` (earliest stage first, stable by skill id).
3. Then `topic_focus` unknowns.
4. Then `current_stage_unknown`.
5. Optionally annotate MWE items with readiness signals (do not drop unknowns
   solely because components are unknown).

Utility providers (frequency, etc.) may soft-rerank within a bucket only.
They must not invent `prerequisite_for`.

## 4. Explainability Payload Shape

Every next-step item **must** separate graph facts from learner-state fields
and derived signals:

```json
{
  "skillId": "english.vocabulary.skill.example.noun",
  "category": "lower_level_gap",
  "graphFacts": [
    {
      "kind": "exam_membership",
      "edgeType": "contains",
      "examId": "pre-a1-starters",
      "edgeId": "english.vocabulary.edge.contains.…",
      "classification": "source-backed fact"
    }
  ],
  "derivedSignals": [
    {
      "kind": "supports",
      "edgeType": "supports",
      "method": "multiword-component-support-v1",
      "edgeId": "english.vocabulary.edge.supports.…",
      "classification": "derived support signal",
      "mandatoryGate": false
    }
  ],
  "learnerStateFields": [
    { "field": "goalStage", "value": "movers" },
    { "field": "mastery", "skillId": "english.vocabulary.skill.example.noun", "value": "unknown" }
  ]
}
```

**Falsifiers:**

- Missing `graphFacts` or `learnerStateFields` arrays on a next-step item → fail.
- Collapsing derived supports into `graphFacts` without
  `classification: "derived support signal"` → fail.
- Payload that implies a support edge is a hard prerequisite → fail.

## 5. Reference Profiles (Fixtures)

Offline fixtures under `fixtures/yle-consumption/`:

| Profile | Intent |
|---|---|
| `starters-beginner.json` | Starters goal; mostly unknown; exercises stage + unknowns |
| `movers-with-starters-gaps.json` | Movers goal; several Starters skills unknown → **must** emit lower-level gaps |
| `flyers-mixed-due.json` | Flyers goal; mixed mastery; non-empty SRS due list; topic focus; MWE signal |

Each profile pairs with `*.expected.json` asserting categories present,
explainability shape, and the no-graph-mutation rule.

## 6. Relationship To Progression Policy

`review/yle-2025/progression-policy.md` states the pedagogical prohibitions
(no invented `prerequisite_for`, supports never hard gates). This document is
the machine-oriented contract and payload shape for the same rules.

## 7. Honesty

- This contract does not implement a production recommender.
- Dual approval is recorded in `review/yle-2025/phase4-approval.md`.
- Graph counts alone are not quality evidence of good next-step pedagogy.
