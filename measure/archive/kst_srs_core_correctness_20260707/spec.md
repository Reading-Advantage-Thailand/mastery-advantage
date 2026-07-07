# Specification: KST+SRS Core Algorithm Correctness (kst-srs.v3)

## Overview

An algorithmic evaluation of `SPECIFICATION.md` (kst-srs.v2) on 2026-07-07
identified five correctness-level defects in the core KST+SRS algorithms, plus
two documentation defects. Each produces wrong learner-facing behavior in any
consuming application, independent of domain. This track fixes all of them in
the normative specification, backs every changed formula with worked numeric
examples, and releases the result as `kst-srs.v3`.

**Release rationale:** every Advantage app inherits these defects through the
spec. This track is the correctness gate for engine adoption and should
complete before the calibration/evidence and planner/domain-utility tracks
build on the affected formulas.

## Functional Requirements

### FR-1: Non-compensatory hard-gate readiness

**Defect:** §1.4 defines `weight: 1.0` as a "hard gate", but §2.5 computes
readiness as a weighted average, which is compensatory by construction. A node
with an unmastered hard-gate prerequisite (m = 0, w = 1.0) and several
mastered soft prerequisites can still classify `nearly_ready` or `ready`,
recommending learners into material they structurally cannot do.

**Required change:** Replace the §2.5 formula with a non-compensatory
formulation in which hard-gate prerequisites gate readiness multiplicatively
and soft prerequisites remain compensatory. Candidate formulations to be
decided in Phase 1 (e.g. `readiness(B) = min(m_i : w_i ≥ hardGateThreshold) ×
weightedAvg(m_j : w_j < hardGateThreshold)`, or a noisy-AND). The chosen form
must define: (a) a configurable `hardGateThreshold` (default 1.0) added to
`MasteryConfig` (§2.4); (b) semantics of weights just below the threshold;
(c) behavior when a node has only hard-gate or only soft prerequisites.

**Sections affected:** §1.4, §2.4, §2.5, §2.6 (pseudocode and TypeScript),
§9.4 (node-state computation).

### FR-2: Edge-calibration Bayesian update conditioned on the wrong rows

**Defect:** Necessity is defined in §6.3 as `1 − c/(c+d)` — a property of the
not-proficient-in-A rows only — but the §6.4 update increments `α` for cell
`a` (proficient in both). Under normal curriculum sequencing nearly all
students land in cell `a`, so `α` balloons, posterior variance collapses, and
authored edges are falsely "confirmed" with high confidence. The §6.5
guardrail catches structurally empty cells but not this inflation.

**Required change:** Condition the Beta-Bernoulli update on ¬A rows only:
cell `d` → `α`, cell `c` → `β`. Cells `a`/`b` feed informativeness only.
Update the `confidence` bucketing description to reflect the (much smaller)
effective sample size. Add a note to §6.5 that self-selection of students who
reach B without A biases necessity estimates, with ability adjustment deferred
to the calibration-and-evidence-quality track.

**Sections affected:** §6.4, §6.5.

### FR-3: Retention signature inconsistency and undefined objective-level aggregation

**Defect (a):** §2.1 computes decaying mastery as
`stabilityToRetention(cardStability, elapsedDays)`; §13.5 declares
`stabilityToRetention(stability: number): number`. Retention is undefined
without elapsed time; the §13.5 signature is wrong.

**Defect (b):** §2.1 references a singular "cardStability", but an objective
has one card per practice variant (§12.1). The aggregation of per-card
retention into one objective-level mastery value is unspecified, and every
downstream number (readiness, fringe, planner) depends on it.

**Required change:** Fix the §13.5 signature to include elapsed days. Define
a normative objective-level retention aggregation rule (decision in Phase 1;
the conservative candidate is minimum retention across variant cards, with
stability-weighted mean as the alternative), including handling of objectives
where some variants have never been practiced.

**Sections affected:** §2.1, §13.5; consistency check across §2, §12, §13.

### FR-4: Placement seeding contract and mastery-closure semantics

**Defect (a):** Placement (§11) outputs `{nodeId, masteryEstimate,
confidence}`, but the knowledge state (§2.1–2.3) is computed exclusively from
proficiency verdicts and SRS card stability. A placement-seeded skill has
neither, so there is no defined path for it to enter `mastered`/`decaying`,
and no retention function for it to decay along.

**Defect (b):** The spec never states whether the mastered set is closed
under prerequisites (surmise closure): whether passing a node implies mastery
of its ancestors, and how directly evidenced mastery differs from inferred
mastery.

**Required change:** Define a placement-seeding contract: placement
synthesizes SRS cards with initial stability derived from a normative
`(masteryEstimate, confidence) → initialStability` mapping so seeded skills
immediately enter the standard decay/review lifecycle. Take an explicit
position on surmise closure (Phase 1 decision), distinguishing direct vs
inferred mastery and specifying the confidence each carries and how inferred
mastery is revised by later evidence.

**Sections affected:** §11 (new subsection), §2.1–2.3, §12.4 (`createCard`
initial-state note).

### FR-5: Daily queue ordering and new-card cap enforcement

**Defect:** §12.7 orders new cards before reviews and caps only the total at
`maxReviewsPerDay`; `newCardsPerDay` exists in `SrsSessionConfig` but is
referenced by no rule. Under review backlog (routine for school-age learners
after absences), new cards crowd out the most-decayed reviews.

**Required change:** Rewrite the queue ordering rules: (1) enforce
`newCardsPerDay` as a hard cap on new-card injection; (2) schedule due and
overdue reviews before new cards; (3) order overdue reviews by predicted
current retention ascending (most-forgotten first) rather than raw days
overdue; (4) define an explicit backlog policy for extended absence (e.g.
cap, spread, or reprioritize); (5) preserve the misconception-remediation
injection rule and the `triaged` exclusion.

**Sections affected:** §12.7.

### FR-6: Documentation defects

1. §8.4's misconception cap cites §6 (edge calibration); the correct target
   is §13.3 (misconception lifecycle).
2. §9.4 `progressTrend` is ambiguous about whether a small decrease (e.g. −1
   mastered skill) is `declining` or `stable`. Define symmetric thresholds.

### FR-7: Version bump and release artifacts

Bump the spec header and Appendix C to `kst-srs.v3` with a v3 changelog
paragraph mirroring the existing v2 one. Update Appendix B fixture
descriptions where changed formulas invalidate fixture expectations. Add a
downstream migration-notes section (or companion doc) enumerating the
behavioral changes `ra-math-advantage` and other implementations must adopt.

## Non-Functional Requirements

- **Domain neutrality preserved:** no fix may introduce domain-specific
  behavior into the core algorithms.
- **Worked examples are normative test artifacts:** every changed formula
  must include a worked numeric example demonstrating the v2 defect and the
  v3 result on the same inputs.
- **Determinism:** all revised algorithms remain deterministic given the same
  inputs and configuration.
- **Backward-compatibility notes:** every behavioral change carries an
  explicit migration note; silent semantic drift is prohibited.

## Acceptance Criteria

1. All five algorithmic defects (FR-1…FR-5) have normative fixes with worked
   v2-vs-v3 numeric examples embedded in the spec.
2. The compensatory hard-gate failure case (unmastered w=1.0 prerequisite
   classifying `nearly_ready`) is impossible under the v3 formula, as shown
   by its worked example.
3. The edge-calibration example shows cell-`a` observations no longer
   affecting the necessity posterior.
4. A placement-seeded skill demonstrably enters the standard §2 lifecycle
   (has a card, a retention function, and a defined mastery level) in the
   worked example.
5. A backlog scenario (e.g. 7-day absence) in the §12.7 worked example shows
   reviews scheduled before new cards and `newCardsPerDay` enforced.
6. A full cross-reference sweep of `SPECIFICATION.md` passes: no dangling
   section references, no remaining v2 formula statements contradicting v3
   sections, terminology consistent.
7. Appendix C lists `kst-srs.v3`; migration notes exist for downstream
   implementations.
8. Curriculum/engineering approval recorded for the Phase 1 decisions
   (hard-gate formulation, retention aggregation, closure semantics, backlog
   policy).

## Out of Scope

- Runtime implementation changes in `ra-math-advantage` or any consuming app
  (migration notes only).
- FSRS parameter fitting, guess/slip correction, rating-mapper thresholds,
  ability-adjusted calibration (→ `kst_srs_calibration_evidence_20260707`).
- Planner term normalization, domain utility extension, interleaving
  (→ `kst_srs_planner_domain_utility_20260707`).
- `transfers_to` / `equivalent_to` propagation semantics (documented as
  reserved; full contracts deferred).
