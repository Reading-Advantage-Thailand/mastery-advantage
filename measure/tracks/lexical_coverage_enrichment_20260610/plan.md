# Implementation Plan: English Lexical Coverage Enrichment

> **Intent:** Expand the frozen YLE core lexical graph with independently gated
> source-backed groups, A2/B1 appendix coverage, Vocabulary in Use unit groups,
> and frequency metadata — without rewriting core IDs or inventing
> `prerequisite_for`.
>
> **Marker vocabulary:** `[x]` complete · `[~]` in-progress/next · `[b]` human-gated.
>
> **Status:** Phases 4–5 dual go (2026-08-11). Approved enrichment layers
> released under `RELEASE-ENRICHMENT-2026-08-11.md`. B2 expansion deferred
> (not graphable for current customers).

## Phase 1: Contracts And Source Decisions

- [x] Task: Define enrichment-layer contracts
  - [x] Define group, membership, frequency, ambiguity, and quarantine metadata
  - [x] Define stable references to core lexical IDs
  - [x] Define independently selectable release layers
- [x] Task: Draft source registry additions
  - [x] Record URLs, versions, checksums, scope, permitted use, and cache policy
  - [x] Record excluded or unavailable sources, including the absent B2 list
- [x] Task: Define review samples and thresholds
  - [x] Define at least 100 stratified memberships per retained source
  - [x] Define ambiguity, unmatched-entry, and frequency-anomaly queues
- [x] Task: Complete Phase 1 review gate — human-gate:both-owners
  - [x] Accept contracts and source registry — human-gate:both-owners

**Green evidence (2026-08-11):**

- `english/cefr-vocabulary/review/enrichment/phase1-contracts.md` — layer IDs,
  metadata shapes, isolation, sample thresholds, no `prerequisite_for`.
- `english/cefr-vocabulary/review/enrichment/phase1-source-registry.md` — YLE
  pin, A2 Key, B1 Preliminary, four ViU bands, wordfreq candidate; EVP bulk and
  fabricated B2 lists excluded; Cambridge B2 list unavailable.
- `bash tests/enrichment_p1_contracts.sh` exits `0`.

**Phase 1 acceptance (2026-08-11):**

- Decision: go (both-owners). Work already past contracts into live overlays;
  owner confirms contracts, source registry, and audit thresholds accepted.
- Scope accepted: independent enrichment layers; wordfreq as frequency source;
  no `prerequisite_for` from enrichment; isolation from frozen YLE core.

## Phase 2: Tests And Fixtures

- [x] Task: Build Cambridge group extraction fixtures
  - [x] Cover YLE grammatical groups and A2/B1 Appendix word sets
- [x] Task: Build Vocabulary in Use fixtures
  - [x] Cover elementary frontmatter/index structure sample
  - [x] Cover remaining three frontmatter and index layouts
  - [x] Cover unmatched, multi-unit, and variant fixture cases (schema)
- [x] Task: Build frequency metadata fixtures
  - [x] Cover words, MWEs, missing scores, unreliable scores, and rank ties
- [x] Task: Build enrichment isolation and determinism tests
- [x] Task: Verify Phase 2

**Green evidence (2026-08-11):**

- Structure fixtures under `english/cefr-vocabulary/fixtures/enrichment/` for
  Cambridge sources and all four ViU bands; frequency + isolation schemas.
- `bash tests/enrichment_p2_fixtures.sh` and `bash tests/enrichment_viu_layer.sh`.

## Phase 3: Implementation

- [x] Task: Implement Cambridge group extraction
  - [x] YLE grammatical category×stage groups (optional overlay)
  - [x] A2 Key / B1 appendix topic extractors (topics already partly in core)
- [x] Task: Implement Vocabulary in Use catalogs and index matching
- [x] Task: Implement selected frequency source integration
  - [x] Pin the `wordfreq` `sourceVersion` to `3.1.1` (replaces `PIN_AT_IMPLEMENTATION`)
  - [x] Define tokenization and lemmatization policy against node identity
  - [x] Exclude multi-token entries on the `wordfreq` token count, not on the `lexicalUnit` label and not on whitespace
  - [x] Define the missing-score and below-reliability-floor policy
  - [x] Define the `rankWithinInventory` tie policy
- [x] Task: Implement coverage and frequency quality reports
  - [x] ViU + grammatical quality reports
  - [x] Frequency quality report
  - [x] A2 Key / B1 appendix quality reports
- [x] Task: Implement durable enrichment review queues
  - [x] ViU unmatched/ambiguous + grammatical unmatched queues
  - [x] A2 Key / B1 unmatched and ambiguous queues

**Frequency layer Green evidence (2026-08-11):**

- Builder: `scripts/build-frequency-metadata.py`; source `wordfreq` pinned at
  `3.1.1`; run with `uv run --with wordfreq==3.1.1` (this machine has no `pip`)
- Overlay: `overlays/frequency.overlay.json` — `enrichment.frequency.wordfreq`;
  frequency stored as node metadata; `edges` empty; `prerequisite_for` count 0
- Counts: 3769 skills = 3374 scored/ranked + 393 multi-token + 2 not-in-corpus;
  multi-token subtypes whitespace 363, hyphen 28, slash 2, other 0
- Exclusion keys on the `wordfreq` token count. The `lexicalUnit` label is
  wrong for 117 single-token skills; whitespace alone misses 30 inflated
  hyphen and slash forms (`no-one` 6.10, `make-up` 5.91, `cafe/café` 3.59)
- Policy: `FREQUENCY-POLICY.md`; `GRAPH-DESIGN.md` Frequency section updated
- Reliability floor 1.0 retained as a guard; 0 skills fall below it
  (lowest scored zipf 1.64), so the policy is untested against real data
- Queues: `review/enrichment/queues/frequency-missing.jsonl` (395),
  `frequency-unreliable.jsonl` (0), `frequency-label-anomalies.jsonl` (148)
- Report: `reports/enrichment/frequency.{json,md}`
- Harness: `bash tests/enrichment_frequency.sh` — 14/14 pass
- Determinism: rebuilt twice, overlay byte-identical; core graph byte-identical
  to `git HEAD` before and after
- Core-data findings recorded, not repaired (core is frozen): 115 mislabelled
  `multiword-expression` skills, 31 punctuation-leak forms, 2 `at / @` forms,
  377 duplicate normalized forms across 828 skills

**ViU layer Green evidence (2026-08-11):**

- Builder: `scripts/build-viu-unit-groups.py`
- Overlay: `overlays/viu-unit-groups.overlay.json` — unit `content_group`s +
  `contains` co-membership; `unitNumberIsNotPrerequisite: true`;
  `prerequisite_for` count 0
- Semantics: co-taught lesson groups (GRAPH-DESIGN ViU rule)
- Core graph file untouched; optional regenerable extended merge gitignored
- Queues: `review/enrichment/queues/viu-unmatched.jsonl`,
  `viu-ambiguous.jsonl`
- Report: `reports/enrichment/viu-unit-groups.{json,md}`
- Harness: `bash tests/enrichment_viu_layer.sh`

**YLE grammatical layer Green evidence (2026-08-11):**

- Builder: `scripts/build-yle-grammatical-groups.py`
- Overlay: `overlays/yle-grammatical-groups.overlay.json`
- Restores freeze-omitted grammatical groups as selectable enrichment
  (`enrichment.cambridge.grammatical-groups`); match rate ≥ 0.98 on tokens
- Harness: `bash tests/enrichment_yle_grammatical.sh`
- Freeze decision YLE-2025-GRAMMATICAL-001 remains valid for core package

**A2 Key / B1 Preliminary appendix Green evidence (2026-08-11):**

- Builder: `scripts/build-a2-b1-appendix-groups.py`
- Overlays: `overlays/a2-key-appendix.overlay.json`,
  `overlays/b1-preliminary-appendix.overlay.json`
- Layers: `enrichment.cambridge.a2-key-appendix`,
  `enrichment.cambridge.b1-preliminary-appendix`
- Contents: A–Z exam membership (POS-aware) + Appendix 2 topic groups
- Identity: form+POS only; no new skill nodes; Key/Flyers share skills
  (351 shared skill IDs observed)
- A2 Key A–Z: 1679/1680 matched (0.9994), 1765 skills; topics 1116/1137 (0.9815)
- B1 Preliminary A–Z: 3057/3057 matched (1.0), 3139 skills; topics 1804/1907
  (0.946)
- `prerequisite_for` count 0; core freeze byte-identical
- Queues: `a2-key-{unmatched,ambiguous}.jsonl`,
  `b1-preliminary-{unmatched,ambiguous}.jsonl`
- Reports: `reports/enrichment/{a2-key,b1-preliminary}-appendix.{json,md}`
- Harness: `bash tests/enrichment_a2_b1_appendix.sh` — 8/8 pass
- YLE decisions reused: form+POS identity, contains-only membership, no hard
  prerequisites, core isolation, durable queues. Full A2/B1 dual-go freeze
  remains method-later (`method-appendix-a2-b1.md`); these are enrichment layers.

## Phase 4: Audit And Calibration

- [x] Task: Audit and remediate Cambridge group memberships
  - [x] Automatable provenance, isolation, stratified samples (100/source)
  - [x] Curriculum precision ≥0.980 on stratified samples — human-gate
- [x] Task: Audit and remediate Vocabulary in Use matches
  - [x] Automatable sample + queue quarantine status
  - [x] Curriculum precision on ViU sample — human-gate
- [x] Task: Validate frequency distributions and anomalies
- [x] Task: Evaluate remaining coverage gaps and candidate sources
- [x] Task: Complete curriculum/language review gate — human-gate

**Phase 4 automatable Green evidence (2026-08-11):**

- Builder: `scripts/build-enrichment-phase4-audit.py`
- Report: `reports/enrichment/phase4-audit.{json,md}`
- Gaps: `reports/enrichment/coverage-gaps.json`
- Samples: `review/enrichment/phase4-samples/*-membership-sample.jsonl`
  (a2-key, b1-preliminary, grammatical-groups, unit-groups)
- Gates green: core freeze untouched; all layers `prerequisite_for`=0;
  frequency silent nulls=0 (zipf 1.64–7.73, p50=4.63); provenance completeness
  1.0 on membership layers; ambiguous rows quarantined in queues
- Harness: `bash tests/enrichment_p4_audit.sh` — 5/5 pass
- Pre-existing p2 fixture gap fixed: `labeledCategoryDetectCount` on YLE
  grammatical structure fixture

**Phase 4 acceptance (2026-08-11):**

- Decision: go (both-owners). Record: `review/enrichment/phase4-approval.md`.

## Phase 5: Release Decision

- [x] Task: Run deterministic regeneration and full enrichment validation
- [x] Task: Produce enrichment consumption and exclusion fixtures
- [x] Task: Reconcile acceptance criteria and open debt
- [x] Task: Record approve, quarantine, or reject decision per enrichment layer

**Phase 5 acceptance (2026-08-11):**

- Decision: go (both-owners). Record: `review/enrichment/phase5-approval.md`,
  `RELEASE-ENRICHMENT-2026-08-11.md`, `ENRICHMENT-CONSUMPTION.md`.
- Approved: frequency.wordfreq, a2-key-appendix, b1-preliminary-appendix,
  yle grammatical-groups, viu.unit-groups.
- Rejected/unavailable: fabricated B2 lists; Cambridge B2 First official list.
- B2 inventory expansion **deferred** (not graphable for current customers).

## Completion Rule

Completion requires accepted evidence per layer. Rejected or quarantined
sources do not block approved coverage layers.

**Track completion (2026-08-11):** Phases 1–5 closed for approved layers.
Follow-on ranking/semantic tracks consume these layers.
