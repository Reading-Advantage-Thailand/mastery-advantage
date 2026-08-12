# Test Strategy: gse_vocabulary_core_enrichment_20260811

**Track:** GSE Vocabulary Core Enrichment
**Revision:** 2026-08-12 - strategy for Phase 1 (Source Acquisition And Contracts)
**Role:** measure-strategy
**Pre-strategy baseline (role_base_sha):** `79fb0a4abede4fcd8cb85b6b609047d05ec707a9`
**Scope:** contract documents, source provenance, and read-only source-cache
probes. Phase 1 ships **no** graph mutation and **no** live extraction.

---

## 0. Orchestrator Capture Point (`phase_base_sha`)

After this `test-strategy.md` plus the companion `plan.md` marker normalization
are **committed**, the orchestrator must capture:

```text
phase_base_sha = git rev-parse HEAD
```

at that post-strategy-commit HEAD.

Do **not** treat the pre-strategy SHA `79fb0a4abede4fcd8cb85b6b609047d05ec707a9`
as `phase_base_sha`. Do not embed a guessed future SHA in this file.

Until that commit exists, Mid-Red for Phase 1 must not start. The Mid-Red gate
compares `git rev-parse HEAD` against the supplied baseline and fails when HEAD
did not advance.

---

## 1. Intent And Risk Summary

| Goal | How tests prove it | Primary risk |
|---|---|---|
| Pinned source identity (GL 11,586; YL 3,024) | Provenance doc + SHA-256 + read-only count probe | Silent re-export; wrong cache file |
| Mapping contract (form + POS + audience) | Contract doc defines binding rule + no-inference | Form-only mapping binds wrong POS |
| Starred `gse` (70 GL) and `temporaryGse` (129 YL) | Contract preserves and explains both | Special values dropped silently |
| Core mutation contract | Field names, version bump, byte-diff shape, YLE reproducibility | Core version drifts from frozen baseline |
| Review sample threshold | >=100 stratified mappings + precision threshold | Unreviewable mapping shipped |
| Durable queue isolation (FR-8) | Queue files named under this track | Foreign queue changes this track's reports |
| Dual human gates (FR-9) | Two separate recorded decisions | One gate false-claimed as two |

**Overall track risk:** **high** (core mutation + curriculum truth + freeze
discipline). The change writes onto the **core** graph, not an enrichment
overlay. The frozen YLE baseline must regenerate byte-identical.

No production auth surface and no UI. Security review is **narrow**. Browser
review is **not applicable**.

---

## 2. Configured Gate Commands (Phase 1)

The environment had no configured commands. The commands below fit this
repository (static data and contracts; Node.js, Python, and shell harnesses).
The orchestrator must export them before running Mid-Red and Jr-Green.

```text
RED_TEST_COMMAND="bash tests/gse_vocab_p1_contracts.sh"
GREEN_TEST_COMMAND="bash tests/gse_vocab_p1_contracts.sh"
PROJECT_CHECKS="node english/cefr-vocabulary/scripts/validate-vocabulary-graph.js"
PROJECT_LINT="git diff --check"
PROJECT_TESTS="bash tests/gse_vocab_p1_contracts.sh"
PROJECT_DEV_URL=""        # no UI in this repository
UX_REQUIRED="never"       # contract and data repo; browser review not applicable
```

Notes:

- `RED_TEST_COMMAND` and `GREEN_TEST_COMMAND` use the **same** harness. The
  harness must exit `1` on the current tree (contract docs absent) and `0`
  after Jr-Green writes the contracts. This satisfies the Mid-Red
  `expect_failure=True` gate and the Jr-Green `expect_failure=False` gate.
- `PROJECT_CHECKS` stays green in Phase 1 because Phase 1 changes **no** graph
  file. It guards against accidental graph edits.
- `PROJECT_LINT` is `git diff --check` because this repository has no JS or
  Python lint configured. It catches whitespace and conflict-marker faults.
- `PROJECT_TESTS` is Phase 1-local for now. Later phases append their own
  harnesses. Final acceptance uses the aggregate (see section 7).

---

## 3. Architecture Guardrails (all phases)

1. **Core vs overlay.** This track mutates the **core** graph under a version
   bump. It is not an enrichment overlay. Tests must fail if the new version
   does not carry a version label distinct from the frozen YLE baseline.
2. **YLE baseline stays reproducible.** The frozen YLE baseline must regenerate
   byte-identical after the core version bump. A diff report with labelled
   counts accompanies the new version. No silent overwrite of frozen data.
3. **No invention.** An absent GSE entry yields a queue row, never data. A
   mapped node must cite a GSE `itemId`. Tests fail on any mapped node without
   an `itemId`.
4. **No `prerequisite_for` edges.** The graph keeps `prerequisite_for` count at
   0. GSE data is a level and metadata signal, not a mastery ordering.
5. **Labeled integers only.** Every count and rate uses a labelled integer
   pattern (anti-A3), e.g. `GL items: 11586`, never bare `[0-9]+`.
6. **Human gates stay incomplete.** `[b]` tasks remain incomplete until real
   owner evidence exists. Do not mark a human decision `[x]` without a signed
   decision artifact (anti-A4, anti-A5).
7. **Artifact tests are not live behavior.** Markdown presence alone never
   satisfies extraction, mapping, or regeneration behavior. Pair doc checks
   with executable probes (section 8).
8. **Queue isolation.** This track's queue files live under its own directory
   and are named explicitly. A foreign queue file must not change this track's
   reports (FR-8, COVERAGE_QUEUES lesson).

### Changed-contract risks

- The core node is keyed by `normalizedHeadword` + `partsOfSpeech` set +
  `exams`/`cefrLevels`. The GSE entry is keyed by `expression` +
  `grammaticalCategories[]` + `audience` (`GL` vs `YL`). POS naming differs
  (e.g. GSE `phrasal verb`, `phrase`). The mapping contract must define a POS
  normalization map and audience handling. A naive form-only match is the
  primary falsifier.
- GL `cefr` uses the long form (`<A1 (10-21)`); YL `cefr` uses the short form
  (`<A1`). The extractor must normalize both without dropping the band.
- The 70 starred GL `gse` values (e.g. `19*`) and the 129 YL `temporaryGse`
  values must be preserved and explained, not dropped (FR-2).

### Intentionally-red aggregate handling

Until a phase harness is implemented, do **not** add a green stub script. An
absent file is preferred over a vacuous `exit 0` (anti-A4). When
`measure/test-all.sh` exists, not-yet-built `tests/gse_vocab_p*.sh` files must
either:

- carry a `## skip-aggregate: not implemented until Phase N` header, or
- be expected-red and excluded from any "all green" claim (anti-A5).

Do not claim `PASS` on an aggregate that still contains unimplemented GSE
harnesses.

---

## 4. Applicability Matrix

| Review type | Applicable? | When / notes |
|---|---|---|
| Security review (Review B) | **Narrow** | No auth, PII, or network service in scope. Checks: no publisher raw JSON committed (exports stay Git-ignored under `english/cefr-vocabulary/source-pdfs/`); no secret in fixtures; FR-6 licence boundary respected (non-commercial, approved purposes only); attribution string present. |
| UX / API review (Review C) | **Yes (contract API)** | The mapping contract and the core mutation contract are the integration API for downstream consumers. Review field names, version bump mechanics, and the byte-diff report shape. Not a GUI. |
| Adversarial testing | **Yes** | Attacks: form-only mapping to wrong POS; starred/temporaryGse dropped; unmapped node given inferred data; YLE baseline drift; foreign queue poisoning; human gate false-claimed; registry overstatement. |
| Browser / WebBridge review | **Not applicable** | Spec, data, and contract repository. No `PROJECT_DEV_URL`. `UX_REQUIRED=never`. |

### Independence rule (report-only audits)

All audit and review roles are **report-only**. They must not fix audited
implementation. Findings route to the accountable implementation role
(Mid-Red or Jr-Green). This preserves audit independence. A reviewer who edits
audited code creates a self-audit conflict. Record this rule in each review
result: blocking findings route to the implementation owner for rework, not to
the reviewer's own edit.

---

## 5. Anti-Pattern Coverage (A1-A10)

| ID | Relevance | Defense in this track |
|---|---|---|
| **A1** Substring `deferred` drops tasks | **Active framework conflict** | The interphase checker (`measure_interphase_checks.py`) still uses `"deferred" not in task.lower()` and regex `[ ~x]`. The supervisor (`measure/automation-supervisor.py`) is fixed (`[~xb]` + `is_task_structurally_blocked`). Human gates use `[b]` plus `deferred:<owner>`. The `[b]` marker is invisible to the old checker regex, so the `deferred` substring is moot for `[b]` lines. Guard: Phase 1 Red asserts no `[ ]` remains and `[b]` lines carry `deferred:`. |
| **A2** Consent-blind publish | Low | The core version release is a publish. The Phase 5 release gate requires dual-owner signatures before `[b]` flips to `[x]`. No anonymization needed (no named subjects). |
| **A3** Digit-only counts | **High** | Every baseline assertion uses a labeled integer: `GL items: 11586`, `YL items: 3024`, `starred GL gse: 70`, `YL temporaryGse: 129`. Red test parses the integer after the label. |
| **A4** Vacuous pass on nothing-done | **High** | Phase 1 Green requires >=1 substantive `[x]` with SHA evidence. All-`[~]` is incomplete. The human gate stays `[b]` and cannot Green the phase. |
| **A5** False-claim text | **High** | Plan and registry must not say "all checks pass" unless the cited command exits 0. No "released" or "frozen" wording until the dual go exists. |
| **A6** Registry overstatement | **High** | `measure/tracks.md` keeps this track as `new` / in-progress until the Phase 5 dual release decision. No "complete" or "resolved" wording early. |
| **A7** Over-broad filters | Medium | Ban-term or exclusion filters (if any) exclude only file-path contexts and policy-disclaimer markers, not bare English words. |
| **A8** `[ ]` marker ambiguity | **High** | Plan normalized to `[x]/[~]/[b]` only. Guard: `rg -n '^- \[ \]' plan.md` returns 0 hits. This is a Phase 1 Red assertion. |
| **A9** Archived path drift | Low until closeout | Future tests use track-dir resolve. No tests point at archive yet. |
| **A10** Generated-facts drift | Low | No reliance on `measure/generated/` for GSE truth. The repo has no `measure/generate.sh` or `measure/doctor.sh`. Contract docs are hand-authored. |

Project-specific candidates to watch:

- **P-GSE-1:** Counting GSE export items (14,610 total) as mapped-node evidence.
  Export count is source size, not mapping coverage.
- **P-GSE-2:** Treating form-only string match as an audited mapping without a
  POS and audience check.
- **P-GSE-3:** Dropping starred `gse` or `temporaryGse` because they are not
  clean integers.

---

## 6. Per-Phase Strategy

### Phase 1: Source Acquisition And Contracts

**Risk:** **medium** (contract honesty + source pinning; no graph mutation yet)
**Reviews:** UX/API yes (contract API); Adversarial light (marker honesty, A8);
Security narrow (no raw export committed); Browser not applicable.

| Gate | Command / evidence |
|---|---|
| **Red** | `bash tests/gse_vocab_p1_contracts.sh` (Mid-Red authors this). Fails on the current tree because the contract docs are absent. Encodes the spec requirements: mapping binding rule, starred/temporaryGse semantics, queue shapes, no-inference rule, mutation field names, version bump, byte-diff shape, YLE reproducibility proof, review sample threshold, source provenance, and plan marker hygiene. |
| **Green** | Same harness exits `0` after Jr-Green writes the contract docs and normalizes plan markers. Plus `node english/cefr-vocabulary/scripts/validate-vocabulary-graph.js` exits `0` (no graph change) and `git diff --check` exits `0`. |
| **Closeout** | The Phase 1 human gate (`[b] deferred:both-owners`) either stays `[b]` with no false complete, or becomes `[x]` only with a signed dual-owner decision artifact present. |

**Recommended contract doc location:**
`english/cefr-vocabulary/review/gse-vocab/`

- `phase1-mapping-contract.md` - binding rule (core `normalizedHeadword` +
  `partsOfSpeech` against GSE `expression` + `grammaticalCategories` + audience),
  POS normalization map, starred `gse` (70 GL) and `temporaryGse` (129 YL)
  semantics, ambiguous and unmapped queue shapes, no-inference rule.
- `phase1-mutation-contract.md` - node field names (GSE score, CEFR band,
  definition, example, `itemId` citation), core version bump mechanics, byte-diff
  report shape, YLE baseline reproducibility proof.
- `phase1-review-samples.md` - >=100 stratified node-to-entry mappings, precision
  threshold, stratification axes (POS, audience, multi-POS, conflict cases).

**Fixtures / mocks:** none live in Phase 1. The harness reads the pinned export
JSONs from `english/cefr-vocabulary/source-pdfs/` for read-only count probes
only. No extraction or mapping runs.

**Live-behavior proof:** none in Phase 1. The only executable probe is a
read-only count of the pinned exports (GL 11,586; YL 3,024; 70 starred; 129
`temporaryGse`). Live behavior (deterministic extraction, byte-identical
mapping, YLE regeneration) begins in Phase 2-3.

**Artifact vs live:** Phase 1 tests are **artifact and documentation tests**
plus read-only source-cache probes. They are **not** live behavior tests.
Markdown presence is insufficient: the harness must parse labelled integers and
specific contract clauses, not just match a filename.

**Anti-patterns defended:**

- **A3** - labelled integers: `GL items: 11586`, `YL items: 3024`,
  `starred GL gse: 70`, `YL temporaryGse: 129`. Defense: the Red test parses the
  integer after each label; a bare `[0-9]+` match fails.
- **A5** - no "approved" or "complete" claim without a signed artifact. Defense:
  the Phase 1 human gate stays `[b]`; the test fails if the plan marks the gate
  `[x]` without a decision file.
- **A8** - no `[ ]` markers. Defense: `rg -n '^- \[ \]' plan.md` must return 0
  hits. The test fails on any deprecated space marker.
- **A1** - human gate uses `[b]` plus `deferred:both-owners`. Defense: the test
  asserts the Phase 1 gate line matches `^- \[b\] .*deferred:both-owners`.
- **A4** - Phase 1 is not Green on zero `[x]`. Defense: Green requires >=3
  automatable `[x]` tasks with SHAs (mapping contract, mutation contract, review
  samples).
- **A6** - registry honesty. Defense: the test fails if `measure/tracks.md`
  calls this track "complete" or "released" while Phase 1 is open.
- **P-GSE-3** - starred and temporary values preserved. Defense: the test
  asserts the mapping contract doc names both the 70 starred GL `gse` values and
  the 129 YL `temporaryGse` values.

**Falsifiers (each test has a falsification condition):**

- Fails if `GSE_VOCABULARY_SOURCES.md` lacks either SHA-256 or the FR-6 owner
  words.
- Fails if the mapping contract omits the POS normalization map or the audience
  handling for GL vs YL.
- Fails if the mutation contract omits the YLE baseline reproducibility proof.
- Fails if the review sample threshold is absent or below 100.
- Fails if any `^- \[ \]` remains in `plan.md`.
- Fails if the read-only probe reads a GL count other than 11,586 or a YL count
  other than 3,024.
- Fails if the plan marks the Phase 1 human gate `[x]` without a signed decision
  artifact path.

---

### Phase 2: Tests And Fixtures

**Risk:** **high** (fixtures encode the falsifiers that govern Phase 3)
**Reviews:** Adversarial yes (falsifier design); UX/API on fixture shape;
Security narrow; Browser not applicable.

| Gate | Command / evidence |
|---|---|
| **Red** | `bash tests/gse_vocab_p2_fixtures.sh` (Mid-Red authors this). Fails while extraction, mapping, falsifier, and determinism fixtures are absent. |
| **Green** | Fixtures exist and cover GL and YL record layouts, starred `gse`, `temporaryGse`, YL short CEFR form, multi-POS expressions, ambiguous bindings, unmapped nodes, Cambridge-vs-GSE conflicts, and the form-only falsifier. |
| **Closeout** | Phase 2 verification task `[x]` with SHA, or stays `[~]`. |

**Fixtures:** GL and YL record samples (including starred and temporaryGse
rows); mapping fixtures for multi-POS, ambiguous, unmapped, and conflict cases;
the falsifier fixture (a node where naive form-only mapping binds the wrong POS
entry); determinism expectations for the YLE baseline.

**Live-behavior proof:** fixtures are data, not behavior. Live behavior begins
when Phase 3 code consumes them. The determinism fixture asserts the YLE
baseline regenerates byte-identical (a live regeneration probe, Phase 3).

**Anti-patterns:** A3 (labelled fixture counts), A4 (no green stub), A7
(refutation filter excludes only path/disclaimer markers), P-GSE-2 (form-only
falsifier must be present).

**Falsifiers:**

- Falsifier fixture absent -> fail.
- Fixture covers GL but not YL -> fail.
- No conflict case (Cambridge level disagrees with GSE band) -> fail.

---

### Phase 3: Extraction, Mapping, And Core Mutation

**Risk:** **critical** (core graph mutation + freeze discipline)
**Reviews:** Adversarial yes (inferred data, wrong POS); UX/API on mutation
contract; Security narrow (no raw export committed); Browser not applicable.

| Gate | Command / evidence |
|---|---|
| **Red** | `bash tests/gse_vocab_p3_extraction.sh` (Mid-Red authors this). Fails while the extractor, mapper, and mutation generator are absent. |
| **Green** | Two consecutive extractor runs produce byte-identical tracked output; every mapped node cites a GSE `itemId`; ambiguous and unmapped cases go to durable queues under this track's directory; the new core version validates; the YLE baseline regenerates byte-identical; the byte-diff report matches the actual mutation. |
| **Closeout** | Mapping quality report present with labelled counts, or stays `[~]`. |

**Fixtures:** Phase 2 fixtures consumed live. Queue files named under this
track's own directory (FR-8).

**Live-behavior proof:** this is the first phase with real live behavior. The
determinism check (two runs, byte-identical) and the YLE baseline regeneration
are executable proofs, not doc checks.

**Anti-patterns:** A3 (labelled counts: mapped, added, corrected, conflicted,
queued), A5 (no "all checks pass" unless the harness exits 0), P-GSE-1 (export
count is not mapping coverage), P-GSE-3 (starred/temporary preserved).

**Falsifiers:**

- A mapped node without an `itemId` -> fail.
- An unmapped node carries GSE data -> fail (no invention).
- YLE baseline regenerates with a diff -> fail.
- A foreign queue file changes this track's report -> fail (FR-8).
- Starred `gse` or `temporaryGse` dropped -> fail.

---

### Phase 4: Audit And Calibration

**Risk:** **high** (curriculum truth + level reconciliation)
**Reviews:** Adversarial yes (inferred data, silent overwrite); UX/API on
conflict report shape; Security narrow; Browser not applicable.

| Gate | Command / evidence |
|---|---|
| **Red** | `bash tests/gse_vocab_p4_audit.sh` (Mid-Red authors this). Fails while the audit harness is absent. |
| **Green** | Stratified sample meets the Phase 1 threshold; no node carries inferred data; corrected values match the pinned export; Cambridge-vs-GSE conflicts keep both values visible. |
| **Closeout** | Curriculum review and Phase 4 dual gate either signed `[x]` or stay `[b] deferred:<owner>`. |

**Fixtures:** the Phase 1 stratified sample (>=100 mappings) executed against
the mapped graph.

**Live-behavior proof:** the audit reads the mapped graph and the pinned
exports and compares values. This is a live comparison, not a doc check.

**Anti-patterns:** A3 (labelled precision), A5 (no precision claim without
harness output), A6 (no "validated" wording while conflicts remain),
P-GSE-2 (form-only mappings flagged).

**Falsifiers:**

- A corrected value does not match the pinned export -> fail.
- A conflict case overwrites the Cambridge level silently -> fail.
- A node with inferred data passes the audit -> fail.

---

### Phase 5: Release Decision

**Risk:** **high** (process honesty + freeze authority)
**Reviews:** Adversarial yes (A5, A6); UX/API final read of the release and
consumption record; Security narrow; Browser not applicable.

| Gate | Command / evidence |
|---|---|
| **Red** | `bash tests/gse_vocab_p5_release.sh` (Mid-Red authors this). Fails while the release record, regeneration proof, and acceptance reconciliation are absent. |
| **Green** | All harnesses exit 0; YLE baseline byte-identical; release and consumption record present; acceptance criteria reconciled; open debt recorded. |
| **Closeout (track)** | Final acceptance only after dual go for the mapping decision and the core version release decision. Both `[b]` human gates flip to `[x]` only with signed owner words. |

**Fixtures:** the full Phase 2-4 harness set run as an aggregate.

**Live-behavior proof:** deterministic regeneration and full validation are
executable. The release decision itself is human.

**Anti-patterns:** A2 (unsigned publish), A5, A6, A4 (no false complete), A8.

**Falsifiers:**

- `measure/tracks.md` says released while a dual go is missing -> fail (A6).
- A human gate marked `[x]` without owner words -> fail.
- YLE baseline regenerates with a diff -> fail.
- An acceptance criterion unreconciled -> fail.

---

## 7. Aggregate Suite Policy

```text
## skip-aggregate: unset means included when the file exists
```

- Before a phase harness is implemented, do not add a green stub. Prefer an
  absent file over a vacuous `exit 0`.
- When `measure/test-all.sh` exists, GSE vocab scripts participate only after
  their phase Mid-Red introduces them. Document expected-red phases in plan
  evidence notes (anti-A5).
- The repo has no `measure/test-all.sh`, `measure/generate.sh`, or
  `measure/doctor.sh` today. Do not claim those gates run.

---

## 8. Artifact Tests vs Live Behavior Tests

| Phase | Artifact / doc tests | Live behavior tests |
|---|---|---|
| 1 | Mapping contract, mutation contract, review samples, provenance, plan markers | Read-only source-cache count probe (no extraction, no mapping) |
| 2 | Fixture file presence and shape | None (fixtures are data) |
| 3 | Mutation report shape | Deterministic extraction (two runs byte-identical), live mapping with `itemId`, YLE baseline regeneration, byte-diff report |
| 4 | Audit report shape | Live graph-vs-source comparison, conflict visibility |
| 5 | Release record | Deterministic regeneration, full validation suite |

Rule: a markdown file is evidence only when an executable probe parses its
content or a live command produces the claimed numbers. A filename match is
never sufficient.

---

## 9. Framework Conflict (report, not a silent product workaround)

**Marker contract tension:**

1. The supervisor (`measure/automation-supervisor.py`) is fixed: regex
   `^- \[([~xb])\]` plus `is_task_structurally_blocked` (recognizes `[b]` and
   `deferred:<owner>`).
2. The interphase checker (`measure_interphase_checks.py` in the orchestrator
   skill) still uses the old regex `^- \[([ ~x])\]` and the substring rule
   `"deferred" not in task.lower()`.

**Track choice (honest docs):**

- Human gates use `[b]` plus `deferred:<owner>`. The `[b]` marker is invisible
  to the old checker regex, so the `deferred` substring is moot for `[b]` lines.
  The supervisor recognizes `[b]` as structured-blocked.
- Automatable not-yet-started tasks use `[~]` (in-progress / next executable),
  the repo convention. There is no "not started" canonical marker.
- Do not mark human work `[x]` and do not convert `[b]` to `[~]` to please the
  checker.

**Orchestrator follow-up (framework, not this product track):** update the
interphase checker to `^- \[([~xb])\]` and structured `deferred:<owner>`
blocking, so the checker matches the supervisor.

---

## 10. What Mid-Red Does Next

1. Wait for the strategy commit plus the orchestrator `phase_base_sha` capture.
2. Author `tests/gse_vocab_p1_contracts.sh` as the Phase 1 Red harness. It must
   exit `1` on the current tree (contract docs absent).
3. The harness may only touch `tests/` (the Mid-Red gate rejects non-test,
   non-Measure file changes). Do not write the contract docs; that is Jr-Green
   work.
4. Keep the Phase 1 human gate `[b]` untouched. Do not mark it `[~]` or `[x]`.
5. Export `RED_TEST_COMMAND="bash tests/gse_vocab_p1_contracts.sh"` before the
   Mid-Red gate runs.
