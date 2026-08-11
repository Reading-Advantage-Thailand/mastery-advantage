# YLE 2025 Freeze: Phase 1 Scope And Review Rules

**Status:** Phase 1 rules approved by the curriculum/language and engineering owners; the explicit dual-owner approval is recorded in [phase1-approval.md](phase1-approval.md).
**Release authority:** Cambridge YLE 2025 only (Pre A1 Starters, A1 Movers, and
A2 Flyers). A2 Key and B1 Preliminary remain in the tracked graph solely for
structural context. Their audit and release authority are method-later work,
not part of this freeze.

This is a one-time baseline audit. It does not authorize graph regeneration, a
continuous source-refresh process, or a claim that the draft inventory has been
curriculum-approved.

## Source Identity And Draft Baseline Facts

The source registry is [SOURCES.md](../../SOURCES.md). The frozen source
identity to be reviewed is:

- Source ID: `cambridge-yle-word-list-2025`
- Official URL: https://www.cambridgeenglish.org/Images/739104-starters-movers-flyers-word-list-2025.pdf
- SHA-256: `6f7a0ad1e277bd10ae8b3bcccfb76c058f611a607c6c9947601abbd7e16a99fa`

The following labeled facts are a read-only snapshot derived from the tracked
`data/cambridge-vocabulary-inventory.json` and
`cefr-vocabulary-knowledge-space.json`. They are audit inputs, not fidelity,
quality, or approval claims.

- YLE skill count: 1405
- Starters membership: 495
- Movers membership: 399
- Flyers membership: 513
- YLE topic group count: 20
- YLE-touching supports count: 1311
- prerequisite_for count: 0

**Baseline restatement (2026-08-11).** The membership figures above were first
recorded as 1388 / 491 / 392 / 507. The Phase 2 independent source oracle
proved those figures were derived from a parser that silently dropped 17
official source rows, and the graph has since ingested all 17. The counts above
are the corrected read-only snapshot of the same tracked artifacts; no fidelity,
quality, or approval claim is implied.

The supports snapshot comprises 598 edges tagged
`same-lexical-form-support-v1` and 713 tagged
`multiword-component-support-v1`. Those derivation tags identify candidates
for review; they do not establish a pedagogical requirement.

## Relationship Classification And Freeze Rule

| Edge type | Classification | Phase 1 rule |
|---|---|---|
| `contains` | source-backed fact | Preserve source/exam or source-group membership provenance; audit membership and group findings against the official list. |
| `aligned_to_standard` | source-backed fact | Preserve the tracked source-backed alignment and review any identity or membership finding that makes it suspect. |
| `supports` | derived support signal | Review each derivation class and record a disposition; consumers may use it as an optional readiness or ranking signal, never a mandatory gate. |
| `prerequisite_for` | prohibited | Prohibit `prerequisite_for` edges in the YLE baseline; the required count is zero and a non-zero count blocks freeze. |

No curriculum stage, topic, CEFR band, frequency, similarity, unit ordering, or
support edge may be converted into a hard prerequisite. Cumulative interpretation
is a consumer rule: a Movers goal includes Starters expectations, and a Flyers
goal includes Starters plus Movers expectations. It does not create duplicate
membership or prerequisite edges.

## Durable Review Records

Phase 2+ records belong under `english/cefr-vocabulary/review/yle-2025/` and
must use a stable decision ID. Each decision record must contain:

| Field | Requirement |
|---|---|
| `decision_id` | Stable, unique identifier; later records supersede by ID rather than rewriting history. |
| `status` | `open`, `accepted`, `rejected`, `quarantined`, or `superseded`. |
| `reviewer_role` | Curriculum/language, engineering, or both; an approval also names the accountable owner. |
| `reviewed_at` | ISO-8601 date/time. |
| `source_location` | Official-list page/section and entry or group reference; never a republished PDF excerpt. |
| `graph_refs` | Affected skill IDs, group IDs, and/or edge IDs. |
| `finding_class` | `omit`, `false-include`, `bad-merge`, `group`, `support`, or `other`. |
| `finding` | Concise observed discrepancy or review question. |
| `evidence` | Source and graph evidence sufficient for another reviewer to reproduce the finding. |
| `disposition` | Accept, correct in a later phase, reject, or quarantine, with rationale and owner. |
| `supersedes` / `superseded_by` | Empty when current; otherwise the related decision ID and reason. |

### Exceptions And Quarantine

An exception is not silent acceptance: it requires a decision record and an
exception-list entry with its decision ID, severity, scope, owner, and planned
resolution or accepted limitation. High-severity omissions, false inclusions,
and bad merges are freeze blockers until corrected or explicitly resolved by
the required human owners. Quarantine removes an unresolved skill, group, or
support edge from release eligibility without deleting the evidence; the record
must state the reason, affected graph references, reviewer role, and condition
for re-review. Quarantined items must not be counted as reviewed acceptance.

## Approved One-Time Audit Sampling Rules

These are the approved rules for the one-time YLE audit. The explicit dual-owner
approval is recorded in [phase1-approval.md](phase1-approval.md). Any later
revision requires the curriculum/language owner's acceptance.

| Review population | Minimum sample / rule | Metric and disposition |
|---|---|---|
| Alphabetical YLE membership | At least 200 stratified entries, or every entry if fewer; cover Starters, Movers, and Flyers and lexical forms/POS/MWEs. | Record labeled precision and recall; target membership precision at least 99.5% and recall at least 99.0%. |
| Thematic membership | At least 100 stratified retained memberships, or every membership if fewer; cover all retained topic groups. | Record labeled thematic membership precision; target at least 98.0%. |
| Identity collisions and suspected false merges | 100% of high-severity cases. | No unresolved high-severity omission, false-include, or bad-merge finding may remain. |
| Derived support signals | Explicit sample from both `same-lexical-form-support-v1` and `multiword-component-support-v1` classes. | Every reviewed class receives a durable disposition and remains labeled as a non-mandatory derived signal. |

Thresholds may be tightened only by a written decision record. A proposed lower
threshold or a sampling exception requires written rationale and does not take
effect until the curriculum/language owner accepts it. The engineering review
is limited to the package shape, source identity, structural sanity, and
artifact consistency; it is not curriculum approval.

## Phase 1 Human Approval Record

The plan's curriculum/language and engineering approval tasks are complete.
The explicit dual-owner approval, including owner roles, date, and acceptance
of the sampling plan and sanity-only technical gate, is recorded in
[phase1-approval.md](phase1-approval.md). This scope document does not create
or replace that approval record.
