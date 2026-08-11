# YLE 2025 Progression And Next-Step Policy

**Status:** Curriculum/language relationship dispositions accepted
(`phase3-approval.md`, Decision: go, 2026-08-11).
**Generated:** 2026-08-11

## Purpose

Document how a consuming application may order or rank next vocabulary work
from the frozen YLE graph **without inventing hard prerequisites**.

## Hard Prohibitions

1. **`prerequisite_for` is forbidden** on the YLE freeze baseline.
   - Required guard: `prerequisite_for count: 0`.
   - Do not invent `prerequisite_for` edges from CEFR bands, topic order, unit
     numbers, frequency, embedding similarity, or `supports` signals.
2. **`supports` edges are never hard gates.**
   - Both `same-lexical-form-support-v1` and `multiword-component-support-v1`
     are **optional signals** for readiness hints or ranking only.
   - No support edge is **required for readiness**. Learners and teachers must
     retain an override path (explicit goals, teacher assignment, or free choice).
3. Cumulative exam expectations (Movers includes Starters; Flyers includes
   Starters + Movers) are a **consumption rule**, not duplicate membership or
   prerequisite edges.

## What Orders Next-Step Work

Next-step ranking for a YLE learner combines, in application state:

| Input | Lives in | Role |
|---|---|---|
| Stage goals (Starters / Movers / Flyers target) | learner / session state | Primary scope filter |
| Lower-level gaps (cumulative consumption) | derived from graph membership + mastery | Prefer unresolved earlier-stage items |
| SRS due work | learner card state | Time-sensitive reviews |
| Topic / group foci | graph topic groups + learner preference | Optional thematic concentration |
| Optional utility / ranking signals | app providers (frequency, supports, etc.) | Soft re-rank only |
| `supports` derived signals | graph `supports` edges | Optional readiness hint — never mandatory |

Static graph nodes must **not** store per-student fields (mastery, due dates,
review status). Those belong in learner state.

## Support-Signal Consumer Rules

- Label every support-backed recommendation as a **derived signal**, separate
  from source-backed exam membership facts.
- Same-form POS support may gently prefer practicing a related POS after one is
  known; it must not block introduction of the other POS.
- MWE component support may gently prefer components before or with an MWE; it
  must not require component mastery before the MWE appears in stage goals or
  reading targets.
- Function-word components (e.g. "of", "to") are especially low instructional
  weight even when an edge exists.

## Relationship To Later Phases

- Phase 4 documents the full static-graph vs learner-state consumption contract
  and explainability payloads.
- Phase 5 exercises reading-program matching against YLE `matchForms`.
- This policy is frozen with the YLE baseline only; A2 Key / B1 use the same
  method later under separate tracks.

## Honesty Note

Class and sample dispositions under `review/yle-2025/` were engineering audit
records; curriculum/language acceptance of the class dispositions and
progression policy is recorded in `phase3-approval.md`.
