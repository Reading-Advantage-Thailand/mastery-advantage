# RELEASE-YLE-2025 — Draft Freeze Decision

**Status:** Draft package assembled; **unsigned**. Dual human go / conditional-go
/ no-go is **not** recorded here until the curriculum/language and engineering
owners explicitly sign.
**Date assembled:** 2026-08-11
**Release authority:** Cambridge YLE 2025 only (Pre A1 Starters, A1 Movers,
A2 Flyers).

## Decision Section (unsigned)

| Owner | Decision | Signature | Date |
|---|---|---|---|
| Curriculum / language | _pending_ | _unsigned_ | _—_ |
| Engineering | _pending_ | _unsigned_ | _—_ |

Allowed values for Decision: `go` | `conditional-go` | `no-go`.

This document must **not** be treated as a freeze until both owners record a
`go` or `conditional-go` with name/role/date. Anonymous or missing signatures
are a freeze blocker (anti-pattern A2).

## Labeled Baseline Metrics (sanity inputs)

These figures are read-only snapshots of the tracked graph and Phase 2–5 audit
artifacts. They are not curriculum approval by themselves.

- YLE skill count: 1405
- Starters membership: 495
- Movers membership: 399
- Flyers membership: 513
- Direct official source rows reconciled: 1407
- YLE topic group count: 20
- YLE-touching supports count: 1311
  - same-lexical-form-support-v1 count: 598
  - multiword-component-support-v1 count: 713
- prerequisite_for count: 0
- Unresolved high-severity membership blockers: 0

## Source Identity

- Source ID: `cambridge-yle-word-list-2025`
- Official URL: https://www.cambridgeenglish.org/Images/739104-starters-movers-flyers-word-list-2025.pdf
- SHA-256: `6f7a0ad1e277bd10ae8b3bcccfb76c058f611a607c6c9947601abbd7e16a99fa`
- Registry: `english/cefr-vocabulary/SOURCES.md`

## Package Index

| Artifact | Path |
|---|---|
| Phase 1 scope / rules | `review/yle-2025/phase1-scope.md` |
| Phase 1 dual-owner approval | `review/yle-2025/phase1-approval.md` |
| Membership decisions | `review/yle-2025/membership-decisions.jsonl` |
| Membership exceptions | `review/yle-2025/membership-exceptions.jsonl` |
| Collision queue | `review/yle-2025/collision-queue.jsonl` |
| Grammatical-list decision | `review/yle-2025/grammatical-list-decision.json` |
| Membership audit report | `reports/yle-membership-audit.{json,md}` |
| Support inventory | `review/yle-2025/support-inventory.json` |
| Support class dispositions | `review/yle-2025/support-class-dispositions.json` |
| Support sample decisions | `review/yle-2025/support-sample-decisions.jsonl` |
| Progression policy | `review/yle-2025/progression-policy.md` |
| Relationship audit report | `reports/yle-relationship-audit.{json,md}` |
| Consumption contract | `YLE-CONSUMPTION.md` |
| Reading fixture index | `review/yle-2025/reading-fixture-index.md` |
| Quality summary | `review/yle-2025/quality-summary.md` |
| A2 Key / B1 method appendix | `review/yle-2025/method-appendix-a2-b1.md` |
| This release draft | `review/yle-2025/RELEASE-YLE-2025.md` |

## Open Human Gates (honest status)

- Phase 2 curriculum fidelity sign-off — **go** (`phase2-approval.md`, 2026-08-11)
- Phase 3 relationship curriculum sign-off — **go** (`phase3-approval.md`, 2026-08-11)
- Phase 4 dual consumption approval — open
- Phase 5 reading-fixture plausibility — open
- Phase 6 dual freeze decision — open (this document)

## Accepted Limitations (draft, pending remaining owner acceptance)

1. Form+POS identity (not reviewed sense-level identity; same-POS sense children deferred; accepted with Phase 2 go).
2. Support edges are optional ranking signals, never hard prerequisites.
3. Grammatical lists are an accepted omission (see grammatical-list decision).
4. A2 Key / B1 are structural context only; not released by this freeze.
5. Reading fixtures are offline contract examples, not a production recommender.

## Sanity Commands (one-shot)

```bash
node english/cefr-vocabulary/scripts/validate-vocabulary-graph.js
bash tests/yle_p6_freeze.sh
```

No standing regeneration or dual-run ceremony is authorized by this freeze.
