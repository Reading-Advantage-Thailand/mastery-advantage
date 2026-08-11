# RELEASE-YLE-2025 — Freeze Decision

**Status:** **Frozen.** Dual human **go** recorded 2026-08-11.
**Date assembled:** 2026-08-11
**Date frozen:** 2026-08-11
**Release authority:** Cambridge YLE 2025 only (Pre A1 Starters, A1 Movers,
A2 Flyers).

## Decision Section

| Owner | Decision | Signature | Date |
|---|---|---|---|
| Curriculum / language | go | Approved by: curriculum/language owner (session confirmation) | 2026-08-11 |
| Engineering | go | Approved by: engineering owner (session confirmation) | 2026-08-11 |

Allowed values for Decision: `go` | `conditional-go` | `no-go`.

Authoritative dual-owner record: [`phase6-approval.md`](phase6-approval.md).

## Labeled Baseline Metrics

These figures are read-only snapshots of the tracked graph and Phase 2–5 audit
artifacts at freeze.

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
| Phase 2 curriculum fidelity approval | `review/yle-2025/phase2-approval.md` |
| Phase 3 relationship approval | `review/yle-2025/phase3-approval.md` |
| Phase 4 dual consumption approval | `review/yle-2025/phase4-approval.md` |
| Phase 5 reading plausibility approval | `review/yle-2025/phase5-approval.md` |
| Phase 6 dual freeze decision | `review/yle-2025/phase6-approval.md` |
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
| This release record | `review/yle-2025/RELEASE-YLE-2025.md` |

## Human Gates (closed)

- Phase 2 curriculum fidelity — **go** (`phase2-approval.md`)
- Phase 3 relationships — **go** (`phase3-approval.md`)
- Phase 4 dual consumption — **go** (`phase4-approval.md`)
- Phase 5 reading plausibility — **go** (`phase5-approval.md`)
- Phase 6 dual freeze decision — **go** (`phase6-approval.md`)

## Accepted Limitations

1. Form+POS identity (not reviewed sense-level identity; same-POS sense children deferred).
2. Support edges are optional ranking signals, never hard prerequisites.
3. Grammatical lists are an accepted omission (see grammatical-list decision).
4. A2 Key / B1 are structural context only; not released by this freeze.
5. Reading fixtures are offline contract examples, not a production recommender.
6. One-time freeze ceremony only — no standing regeneration pipeline.

## Sanity Commands (one-shot)

```bash
node english/cefr-vocabulary/scripts/validate-vocabulary-graph.js
bash tests/yle_p6_freeze.sh
```

No standing regeneration or dual-run ceremony is authorized by this freeze.
