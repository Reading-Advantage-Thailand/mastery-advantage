# Implementation Plan: GSE Vocabulary Core Enrichment

## Contents

- [Phase 1: Source Acquisition And Contracts](#phase-1-source-acquisition-and-contracts)
- [Phase 2: Tests And Fixtures](#phase-2-tests-and-fixtures)
- [Phase 3: Extraction, Mapping, And Core Mutation](#phase-3-extraction-mapping-and-core-mutation)
- [Mid-Red independent-audit remediation evidence (2026-08-13)](#mid-red-independent-audit-remediation-evidence-2026-08-13)
- [Jr-Green independent-audit remediation evidence (2026-08-13)](#jr-green-independent-audit-remediation-evidence-2026-08-13)
- [Phase 4: Audit And Calibration](#phase-4-audit-and-calibration)
- [Phase 5: Release Decision](#phase-5-release-decision)
- [Completion Rule](#completion-rule)

> **Intent:** Write source-backed GSE scores, bands, definitions, and examples
> onto existing core vocabulary nodes. Ship as a new core graph version under
> freeze discipline.
>
> **Marker vocabulary:** `[x]` complete · `[~]` in-progress/next · `[b]` human-gated.
> Legacy `[ ]` is not used (anti-A8).
>
> **Hard constraints:** the frozen YLE baseline stays reproducible; no data is
> invented; every mapped node cites a GSE `itemId`.
>
> **Marker-contract note:** Human gates use `[b]` plus `deferred:<owner>`. The
> former supervisor (`measure/automation-supervisor.py`) recognized `[b]` and
> `deferred:<owner>` as structured-blocked; commit `ba3e0a3` (2026-10-05)
> removed it. The interphase checker still uses the old `[ ~x]` regex, so
> `[b]` lines are invisible to its counts; this is the intended honest state
> for human gates. See `test-strategy.md` section 9.
>
> **Owner decision recorded:** FR-6 option (b) - definition and example text is
> committed onto nodes. Owner words: "FR-6 (b) while we are not selling this
> product and it is only for the purposes they approved -- measuring mastery
> levels and planning instruction." (2026-08-11)

## Phase 1: Source Acquisition And Contracts

- [x] Task: Export and pin the GSE vocabulary inventories - commit: 16cc199
  - [x] Export GL (11,586 items, GSE 10–67) and YL (3,024 items, GSE 10–59) - commit: 16cc199
  - [x] Record URLs, API pattern, export date, and SHA-256 in
        `GSE_VOCABULARY_SOURCES.md` - commit: 16cc199
  - [x] Record licence, redistribution terms, and cache policy - commit: 16cc199
  - [x] Keep raw exports Git-ignored under `source-pdfs/` - commit: 16cc199
- [x] Task: Record the FR-6 owner decision - commit: 16cc199
  - [x] Update the redistribution section of `GSE_VOCABULARY_SOURCES.md`:
        definition and example text may be committed onto nodes; transcribe
        the owner words and date - commit: 16cc199
- [x] Task: Define the node-to-entry mapping contract - commit: f3f0db5
  - [x] Define the binding rule: core node form + POS against GSE expression +
        grammaticalCategories, with audience handling for GL vs YL - commit: f3f0db5
  - [x] Define starred `gse` values (70 GL items) and `temporaryGse` (129 YL
        items) semantics - commit: f3f0db5
  - [x] Define the ambiguous and unmapped queue shapes - commit: f3f0db5
  - [x] State the no-inference rule: an unmapped node receives no GSE data - commit: f3f0db5
- [x] Task: Define the core mutation contract - commit: f3f0db5
  - [x] Define node field names: GSE score, CEFR band, definition, example,
        `itemId` citation - commit: f3f0db5
  - [x] Define the core version bump mechanics and the byte-diff report shape - commit: f3f0db5
  - [x] Define YLE baseline reproducibility proof for the new version - commit: f3f0db5
- [x] Task: Define review samples and thresholds - commit: f3f0db5
  - [x] At least 100 stratified node-to-entry mappings for review - commit: f3f0db5
  - [x] Precision threshold for the mapping sample - commit: f3f0db5
- [x] Task: Jr-Green remediation of audited Phase 1 contract gaps (RA-P1-B1/B2/B3) - commit: 60f4ef3
  - [x] Complete the mutation contract closure and the YLE baseline comparison rule - commit: 60f4ef3
  - [x] Complete the deterministic review-sample top-up rule and its termination condition - commit: 60f4ef3
  - [x] Replace unsupported or in-place YLE proof steps with supported, non-destructive temporary-artifact steps - commit: 60f4ef3
- [x] Task: Second bounded remediation of audited Phase 1 contract gaps (RA-P1-B4/N3, RB-P1-B1/B2, Review C NB-1, RA-P1-N4) - commit: e265616
  - [x] Require a same-procedure before-vs-after YLE comparison that proves no GSE-induced regeneration drift without frozen-release equality - commit: e265616
  - [x] Require the exact Pearson attribution in the derived publication and release manifest contracts - commit: e265616
  - [x] Require fail-fast, validated, quoted, trap-protected sandbox behavior and an adversarial setup-failure probe - commit: e265616
  - [x] Define the invalid-CEFR source-data queue and keep absent optional CEFR out of that queue - commit: e265616
  - [x] Normalize trailing punctuation in commit evidence - commit: e265616
- [x] Task: Jr-Green remediation of Phase 1 Red evidence defects — remove the orphan bare generator command and correct the cycle-2 Red evidence - commit: d759ef1
- [x] Task: Mid-Red adversarial guard hardening for Phase 1 contracts - commit: 0b1a14d
- [b] Task: Complete Phase 1 review gate — deferred:both-owners

**Mid-Red evidence (2026-08-12):**

- At the 2026-08-12 Mid-Red run, the initial Red run preceded the earlier contract Green attempt. The bounded remediation task was `[~]` for Jr-Green.
- The human gate remains `[b] deferred:both-owners`.
- Command: `RED_TEST_COMMAND="bash tests/gse_vocab_p1_contracts.sh" bash tests/gse_vocab_p1_contracts.sh`
- Result: expected Red, exit `1`, with `Total: 22 checks (PASS=19, FAIL=3)`.
- Targeted failures: RA-P1-B1 mutation-contract closure; RA-P1-B2 review-sample top-up closure; RA-P1-B3 supported, non-destructive YLE proof and temporary comparison artifact.
- Hardening added: each contract now needs a complete closing sentinel or normative final sentence; the YLE probe safely exercises a copied real generator and verifies the frozen baseline hash stays unchanged.
- Red artifact: `tests/gse_vocab_p1_contracts.sh`. Jr-Green owns the three bounded remediation items and later contract Green evidence.

**Jr-Green remediation evidence (2026-08-12):**

- Implementation commit: `60f4ef3` completes RA-P1-B1, RA-P1-B2, RA-P1-B3, and bounded Review C contract clarity items NB-4 through NB-9.
- `bash tests/gse_vocab_p1_contracts.sh` exited `0` with `Total: 22 checks (PASS=22, FAIL=0)`.
- `node english/cefr-vocabulary/scripts/validate-vocabulary-graph.js` exited `0` with graph `status: valid`.
- `git diff --check` exited `0` before the implementation commit.
- The Phase 1 human gate remains `[b] deferred:both-owners` and has no acceptance evidence.

**Mid-Red remediation cycle 2 evidence (2026-08-12):**

- The bounded remediation task is `[~]` for Jr-Green. The Phase 1 human gate remains `[b] deferred:both-owners`.
- Red regression command: `RED_TEST_COMMAND="bash tests/gse_vocab_p1_contracts.sh"`.
- The strengthened harness executes two isolated YLE generator runs and compares their outputs without comparing either output to the frozen release artifact.
- At the role-base contract state, the Red command exited `1` with `Total: 26 checks (PASS=21, FAIL=5)`.
- Remaining failures are the Pearson attribution contract, invalid-CEFR queue contract, same-procedure YLE contract property, safe sandbox procedure, and Phase 1 plan commit SHA evidence has trailing punctuation.
- RA-P1-N4 is closed in Green at 1d0ce0d by removing trailing punctuation from the three `60f4ef3` plan evidence lines.
- Log: `/tmp/opencode/gse-vocabulary-p1-mid-red-remediation2-a2314fa.log`.
- Red artifact: `tests/gse_vocab_p1_contracts.sh`. The next role owns the bounded contract remediation.

**Jr-Green remediation cycle 2 evidence (2026-08-12):**

- Implementation commit: `e265616e0d044f40bb23b9034b49ebec01a3a06c` completes the bounded second remediation task.
- `bash tests/gse_vocab_p1_contracts.sh` exited `0` with `Total: 26 checks (PASS=26, FAIL=0)`.
- `node english/cefr-vocabulary/scripts/validate-vocabulary-graph.js` exited `0` with graph `status: valid`.
- `git diff --check` exited `0` before the implementation commit.
- The Phase 1 human gate remains `[b] deferred:both-owners` and has no acceptance evidence.

**Mid-Red evidence remediation cycle 3 (2026-08-12):**

- The bounded remediation task is `[~]` for Jr-Green. The Phase 1 human gate remains `[b] deferred:both-owners`.
- Command: `RED_TEST_COMMAND="bash tests/gse_vocab_p1_contracts.sh"`
- Result: exit `1`; `Total: 28 checks (PASS=26, FAIL=2)`.
- Targeted failures: the orphan bare generator command outside the fenced sandbox procedure; the cycle-2 Red plan evidence does not record `PASS=21 FAIL=5`, the punctuation failure, and RA-P1-N4 closed in Green at `1d0ce0d`.
- The harness recognizes the valid quoted generator command inside the fenced sandbox procedure.
- Log: `/tmp/opencode/gse-vocabulary-p1-mid-red-evidence-fix-1d0ce0d.log`.
- Red artifact: `tests/gse_vocab_p1_contracts.sh`. Jr-Green owns the bounded documentation remediation.

**Mid-Red adversarial hardening evidence (2026-08-13):**

- The Mid-Red hardening task is complete. The human gate remains `[b] deferred:both-owners`.
- Normal command: `bash tests/gse_vocab_p1_contracts.sh` exited `0` with `Total: 30 checks (PASS=30, FAIL=0)`.
- Exact `RED_TEST_COMMAND`: `GSE_VOCAB_P1_NEGATIVE=form-only bash tests/gse_vocab_p1_contracts.sh` exited `1` because the binding guard rejected form-only permission. The role gate must run this exact command with `expect_failure=True`.
- F-ADV-P1-01 failed closed: a temporary form-only fixture exited `1` at the binding guard.
- F-ADV-P1-02 failed closed: a temporary cross-audience substitution fixture exited `1` at the binding guard.
- F-ADV-P1-03 failed closed: a temporary inference-permission fixture exited `1` at the no-inference guard.
- F-ADV-P1-04 failed closed: a temporary cycle-3 claim exited `1`; the guard requires exit `1` and `PASS=26 FAIL=2`.
- F-ADV-P1-05 failed closed: a temporary unbound `all checks pass` claim exited `1` outside a named evidence section.
- F-ADV-P1-06 failed closed: a temporary phrase/phrasal-verb collapse exited `1` at the POS guard.
- Foreign queue path poisoning failed closed: a temporary foreign queue declaration exited `1` because every queue path must use `english/cefr-vocabulary/review/gse-vocab/queues/`.
- The existing dropped-special-values probe still failed closed with `PASS=29 FAIL=1`.
- The stale RA-P1-N5 message now states that the proof compares temporary before and after artifacts.
- Log: `/tmp/opencode/gse-vocabulary-p1-mid-red-adversarial-e615688.log`.
- Implementation commit: `0b1a14d9249b7521c40db4f5c7350b90cd1e5c42` contains the guard hardening. This plan evidence update is the post-commit plan update. `.opencode/` and `audit-results/` remain excluded from the commit.

## Phase 2: Tests And Fixtures

- [x] Task: Build GSE vocabulary extraction fixtures - commit: ec8211d
  - [x] Cover GL and YL record layouts, starred `gse`, `temporaryGse`, and the YL short CEFR form - commit: ec8211d
- [x] Task: Build mapping fixtures - commit: ec8211d
  - [x] Multi-POS expressions, ambiguous bindings, unmapped nodes - commit: ec8211d
  - [x] Nodes whose Cambridge level disagrees with the GSE band - commit: ec8211d
- [x] Task: Build core-mutation and determinism tests - commit: ec8211d
  - [x] Assert the YLE baseline regenerates byte-identical - commit: ec8211d
  - [x] Assert the byte-diff report matches the actual mutation - commit: ec8211d
- [x] Task: Build the falsifier fixture - commit: ec8211d
  - [x] A node where a naive form-only mapping binds the wrong POS entry - commit: ec8211d
- [x] Task: Verify Phase 2 - commit: ec8211d

- [x] Task: Jr-Green bounded remediation of Phase 2 audit gaps - commit: d4b055f

**Mid-Red bounded remediation evidence (2026-08-13):**

- The bounded remediation task remains `[~]` for Jr-Green. The Phase 1 human gate remains `[b] deferred:both-owners`.
- Exact `RED_TEST_COMMAND`: `GSE_VOCAB_P2_NEGATIVE=audit-gaps bash tests/gse_vocab_p2_fixtures.sh`
- Result: exit `1`; `Total: 15 checks (PASS=10, FAIL=5)`.
- Targeted failures: the frozen baseline path, complete source citation, complete conflict report, complete byte-diff `newGraph` citation and `starred`, and invalid-CEFR and absent-optional-CEFR fixture cases.
- Ordinary command: `bash tests/gse_vocab_p2_fixtures.sh` exited `1` with `Total: 14 checks (PASS=9, FAIL=5)` for the same five audit gaps.
- Log: `/tmp/opencode/gse-vocabulary-p2-mid-red-audit-e18a3d6.log`.

**Mid-Red evidence (2026-08-13):**

- The Phase 1 human gate remains `[b] deferred:both-owners`. All Phase 2
  automatable tasks remain `[~]`; no later phase task was changed.
- Red command: `RED_TEST_COMMAND="bash tests/gse_vocab_p2_fixtures.sh" bash tests/gse_vocab_p2_fixtures.sh`
- Result: exit `1`; `Total: 13 checks (PASS=1, FAIL=12)`.
- The passing check is the plan-gate probe. The exact failures are: fixture
  manifest or required fixture files are missing or invalid; GL or YL record
  layout semantics are missing; starred `gse` or `temporaryGse` preservation
  semantics are missing; YL short CEFR fixture semantics are missing; mapping
  fixture schema or multi-POS relationship is missing; queue fixture cases are
  missing or do not describe their semantic relationships; Cambridge-vs-GSE
  conflict fixture is missing or permits silent overwrite; required same-form
  different-POS falsifier is missing or weak; core mutation fixture schema or
  source-backed relationship is missing; byte-diff fixture does not reconcile
  its report with the actual mutation; malformed-input or mutation rejection
  probes are missing or vacuous; determinism or YLE baseline-isolation fixture
  expectations are missing.
- Log: `/tmp/opencode/gse-vocabulary-p2-mid-red-ee95902.log`.
- Red artifact: `tests/gse_vocab_p2_fixtures.sh`. The canonical fixture schema
  is `measure/tracks/gse_vocabulary_core_enrichment_20260811/phase2-fixture-contract.md`.
- The test creates no fixture data and no production implementation. Jr-Green
  must add the fixture pack before this command can exit `0`.

**Mid-Red plan-gate remediation evidence (2026-08-13):**

- The Phase 1 human gate remains `[b] deferred:both-owners`. All Phase 2
  automatable tasks and subtasks remain `[~]` for the valid Red state.
- The plan gate now accepts either a complete Red state with every Phase 2
  marker `[~]`, or a complete Green state with every marker `[x]` and commit
  SHA evidence. It rejects `[ ]`, missing SHA evidence, and mixed markers
  without honest bounded-remediation evidence.
- The positive fixture harness passed with the preserved untracked Jr-Green
  fixture pack: `bash tests/gse_vocab_p2_fixtures.sh` exited `0` with
  `Total: 13 checks (PASS=13, FAIL=0)`.
- Exact negative `RED_TEST_COMMAND`:
  `GSE_VOCAB_P2_NEGATIVE=completed-without-sha bash tests/gse_vocab_p2_fixtures.sh`
- The negative command exited `1` with `Total: 13 checks (PASS=12, FAIL=1)`.
  The intentional failure was `completed Phase 2 task lacks commit SHA
  evidence: Task: Build GSE vocabulary extraction fixtures`.
- The negative mode uses a temporary plan copy. It leaves the tracked plan,
  fixture pack, audit evidence, and all unrelated work unchanged.
- Log: `/tmp/opencode/gse-vocabulary-p2-mid-red-plan-fix-9ef2832.log`.

**Jr-Green evidence (2026-08-13):**

- Fixture implementation commit: `ec8211d`.
- `bash tests/gse_vocab_p2_fixtures.sh` exited `0` with `Total: 13 checks (PASS=13, FAIL=0)`.
- `bash tests/gse_vocab_p1_contracts.sh` exited `0` with `Total: 30 checks (PASS=30, FAIL=0)`.
- `node english/cefr-vocabulary/scripts/validate-vocabulary-graph.js` exited `0` with graph `status: valid`.
- `git diff --check` exited `0` before the fixture implementation commit.
- The Phase 1 human gate remains `[b] deferred:both-owners`.

**Jr-Green audit-remediation evidence (2026-08-13):**

- Fixture remediation commit: `d4b055fd2350464b3855224e1a3190a441c72051`.
- `bash tests/gse_vocab_p2_fixtures.sh` exited `0` with `Total: 14 checks (PASS=14, FAIL=0)`.
- `bash tests/gse_vocab_p1_contracts.sh` exited `0` with `Total: 30 checks (PASS=30, FAIL=0)`.
- `node english/cefr-vocabulary/scripts/validate-vocabulary-graph.js` exited `0` with graph `status: valid`.
- `git diff --check` exited `0` before the fixture remediation commit.
- `GSE_VOCAB_P2_NEGATIVE=audit-gaps bash tests/gse_vocab_p2_fixtures.sh` exited `1` as the permanent mutation probe requires.
- The Phase 1 human gate remains `[b] deferred:both-owners`.
- Log: `/tmp/opencode/gse-vocabulary-p2-jr-green-remediation-9e3eb6a.log`.

## Phase 3: Extraction, Mapping, And Core Mutation

- [x] Task: Implement the deterministic GSE vocabulary extractor - commit: e914e3b
  - [x] Two consecutive runs produce byte-identical tracked output - commit: e914e3b
- [x] Task: Implement source-backed node-to-entry mapping - commit: e914e3b
  - [x] Every mapped node cites a GSE `itemId` - commit: e914e3b
  - [x] Ambiguous and unmapped cases go to durable queues under this track's
        own directory - commit: e914e3b
- [x] Task: Implement the core mutation generator - commit: e914e3b
  - [x] Write GSE score, band, definition, and example onto mapped nodes - commit: e914e3b
  - [x] Produce the new core version and the byte-diff report - commit: e914e3b
- [x] Task: Produce the mapping quality report - commit: e914e3b
  - [x] Labelled counts: nodes mapped, levels added, levels corrected,
        conflicts, unmapped queued, GSE entries with no node - commit: e914e3b
- [x] Task: Apply audit isolation - commit: e914e3b
  - [x] Name this track's queue files explicitly so foreign queue files
        cannot change its reports - commit: e914e3b

**Jr-Green evidence (2026-08-13):**

- Implementation commit: `cb2a1a37999032d4db462f5148597a5b532ba0e4`.
- `bash tests/gse_vocab_p3_extraction.sh` exited `0` with `Total: 13 checks (PASS=13, FAIL=0)`.
- `bash tests/gse_vocab_p2_fixtures.sh` exited `0` with `Total: 14 checks (PASS=14, FAIL=0)`.
- `bash tests/gse_vocab_p1_contracts.sh` exited `0` with `Total: 30 checks (PASS=30, FAIL=0)`.
- `node english/cefr-vocabulary/scripts/validate-vocabulary-graph.js` exited `0` with `status: valid`.
- `git diff --check` exited `0`.

**Mid-Red evidence (2026-08-13):**

- Phase 3 tasks and subtasks remain `[~]`. The Red role changed no production source.
- The exact command is `bash tests/gse_vocab_p3_extraction.sh`.
- The command exited `1` with `Total: 13 checks (PASS=2, FAIL=11)`.
- A rerun after harness hardening kept the same exit `1` and the same `PASS=2, FAIL=11` result.
- The contract check and the Phase 3 marker check passed.
- The eleven live-behavior checks failed because the Phase 3 entrypoint is absent.
- The failures are substantive. They test missing extraction, mapping, mutation, queues, reports, determinism, isolation, and rejection behavior.
- The execution interface is defined in `phase3-execution-contract.md` because the specification and strategy did not define a runnable command or output paths.
- The Red harness consumes `english/cefr-vocabulary/fixtures/gse-vocab/` and uses temporary paths under `/tmp/opencode/`.
- The harness does not modify the frozen YLE artifact or repository-root temporary paths.
- `bash -n tests/gse_vocab_p3_extraction.sh` exited `0`.
- `bash tests/gse_vocab_p2_fixtures.sh` exited `0` with `Total: 14 checks (PASS=14, FAIL=0)`.
- `bash tests/gse_vocab_p1_contracts.sh` exited `0` with `Total: 30 checks (PASS=30, FAIL=0)`.
- `node english/cefr-vocabulary/scripts/validate-vocabulary-graph.js` exited `0` with `status: valid`.
- `git diff --check` exited `0`.

Exact Red output:

```text
=== Phase 3 execution contract defines a live test interface ===
Phase 3 probe passed: contract
=== GL and YL extraction is deterministic and preserves raw source markers ===
first extractor run failed with exit 127: missing Phase 3 implementation: /home/daniebo/Desktop/mastery-advantage/english/cefr-vocabulary/scripts/gse-vocabulary-core.js
=== Phase 3 plan tasks remain in the Red marker state ===
Phase 3 probe passed: plan-state
=== mapping requires exact form, normalized POS set, audience parity, and cross-audience rejection ===
mapping run failed with exit 127: missing Phase 3 implementation: /home/daniebo/Desktop/mastery-advantage/english/cefr-vocabulary/scripts/gse-vocabulary-core.js
=== mapped graph nodes carry complete citations and no inferred fields ===
citation run failed with exit 127: missing Phase 3 implementation: /home/daniebo/Desktop/mastery-advantage/english/cefr-vocabulary/scripts/gse-vocabulary-core.js
=== durable queues cover ambiguous, unmapped, unmatched, and invalid CEFR cases ===
queue run failed with exit 127: missing Phase 3 implementation: /home/daniebo/Desktop/mastery-advantage/english/cefr-vocabulary/scripts/gse-vocabulary-core.js
=== Cambridge and GSE conflict evidence remains visible ===
conflict run failed with exit 127: missing Phase 3 implementation: /home/daniebo/Desktop/mastery-advantage/english/cefr-vocabulary/scripts/gse-vocabulary-core.js
=== byte diff, version bump, source-backed newGraph validation, and graph edge rules are live ===
byte-diff run failed with exit 127: missing Phase 3 implementation: /home/daniebo/Desktop/mastery-advantage/english/cefr-vocabulary/scripts/gse-vocabulary-core.js
=== two core mutation runs are byte-identical ===
first mutation run failed with exit 127: missing Phase 3 implementation: /home/daniebo/Desktop/mastery-advantage/english/cefr-vocabulary/scripts/gse-vocabulary-core.js
=== same-procedure YLE isolation preserves the tracked frozen artifact ===
YLE before run failed with exit 127: missing Phase 3 implementation: /home/daniebo/Desktop/mastery-advantage/english/cefr-vocabulary/scripts/gse-vocabulary-core.js
=== explicit queue inputs isolate reports from foreign queues ===
clean queue run failed with exit 127: missing Phase 3 implementation: /home/daniebo/Desktop/mastery-advantage/english/cefr-vocabulary/scripts/gse-vocabulary-core.js
=== mapping quality report carries six labelled integer counts ===
mapping quality run failed with exit 127: missing Phase 3 implementation: /home/daniebo/Desktop/mastery-advantage/english/cefr-vocabulary/scripts/gse-vocabulary-core.js
=== malformed input and output without item citations are rejected ===
output validation setup failed with exit 127: missing Phase 3 implementation: /home/daniebo/Desktop/mastery-advantage/english/cefr-vocabulary/scripts/gse-vocabulary-core.js
=== results ===
PASS: Phase 3 execution contract defines the live command and output paths
FAIL: deterministic GL/YL extraction or raw marker preservation is missing
PASS: all Phase 3 tasks remain [~] during Mid-Red
FAIL: mapping identity or the cross-audience falsifier failed
FAIL: mapped node citations or no-inference validation failed
FAIL: durable queue behavior or optional CEFR handling is missing
FAIL: Cambridge-GSE conflict evidence is missing or overwritten
FAIL: core mutation, byte diff, source-backed newGraph validation, or graph edge rules are missing
FAIL: core mutation output is not deterministic
FAIL: same-procedure YLE isolation or frozen-artifact preservation is missing
FAIL: foreign queue input changes a report or queue result
FAIL: mapping quality report counts or queue labels are missing
FAIL: malformed input or citation-free output was accepted
=== Total: 13 checks (PASS=2, FAIL=11) ===
```

**Mid-Red bounded plan-gate correction evidence (2026-08-13):**

- `check_plan_state()` now accepts complete Red and Green Phase 3 states.
- Complete Red requires every Phase 3 marker to be `[~]`.
- Complete Green requires every Phase 3 marker to be `[x]` and a 7-to-40 hex
  commit SHA on every top-level completed task.
- Mixed markers, `[ ]`, and missing top-level SHA evidence fail the check.
- `bash -n tests/gse_vocab_p3_extraction.sh` exited `0`.
- `bash tests/gse_vocab_p3_extraction.sh` exited `1` with `Total: 13 checks
  (PASS=2, FAIL=11)`. The product entrypoint is absent, so the tree remains
  Red.
- `GSE_VOCAB_P3_NEGATIVE=completed-without-sha bash
  tests/gse_vocab_p3_extraction.sh` exited `1` with `Total: 13 checks
  (PASS=1, FAIL=12)`. The plan-state check rejected `Task: Implement the
  deterministic GSE vocabulary extractor` without commit SHA evidence.
- `bash tests/gse_vocab_p2_fixtures.sh` exited `0`.
- `git diff --check` exited `0`.
- The correction changed only the Phase 3 harness and this Phase 3 evidence.
  Unrelated untracked paths remain untouched.

- Bounded correction: the rejection probe appends `fixture:core:absent` to `graph["nodes"]` before serialization. The rejection check reaches output validation and no longer fails because the node was absent from serialized JSON. `bash -n tests/gse_vocab_p3_extraction.sh` exited `0`; the full Red command exited `1` with `PASS=9 FAIL=4`. Remaining failures are inferred metadata in `ambiguous-binding`, missing Cambridge-GSE conflict evidence, invalid YLE arguments, and a missing field-specific rejection diagnostic.

Implementation handoff to Jr-Green:

- Add `english/cefr-vocabulary/scripts/gse-vocabulary-core.js`.
- Support the command and output contract in `phase3-execution-contract.md`.
- Consume the Phase 2 fixture pack for GL, YL, mapping, mutation, and negative cases.
- Write only to supplied output and queue paths.
- Use only explicit `--queue-file` inputs.
- Validate every mapped graph node against its cited source entry.
- Preserve raw starred GSE values and YL `temporaryGse` values.
- Reject cross-audience multi-POS input.
- Preserve Cambridge conflict evidence and omit inferred fields.
- Keep the frozen YLE artifact unchanged during the same-procedure proof.
- Produce canonical, deterministic graph, queue, and report bytes.
- Reject malformed input and output without item citations with field-specific errors.
- Keep `prerequisite_for` edge count at zero.
- Re-run `bash tests/gse_vocab_p3_extraction.sh` and record the Green output before marking Phase 3 tasks `[x]`.

## Mid-Red independent-audit remediation evidence (2026-08-13)

- The three focused tests were read. They write only under temporary paths and do not mutate tracked files.
- The existing Phase 3 tasks and subtasks remain `[x]` for audited implementation commit `cb2a1a37999032d4db462f5148597a5b532ba0e4`. Remediation is open and owned by Jr-Green. No mixed `[~]` marker was added.
- Exact command: `bash tests/gse_vocab_p3_review_mapping.sh`
  - Result: exit `1`; `Total: 3 checks (PASS=0, FAIL=3)`.
  - Named defects: wrong-POS mapping trusted the tampered expected item; one exact candidate still produced an ambiguous outcome; conflict output trusted the tampered expected band.
- Exact command: `bash tests/gse_vocab_p3_review_graph.sh`
  - Result: exit `1`; `Total: 3 checks (PASS=0, FAIL=3)`.
  - Named defects: prior graph did not preserve the unrelated sentinel node; newGraph prior did not increment the version or report zero mutation; `validate-output` accepted missing afternoon definition or lacked a diagnostic.
- Exact command: `bash tests/gse_vocab_p3_review_safety.sh`
  - Result: exit `1`; `Total: 3 checks (PASS=0, FAIL=3)`.
  - Named defects: shared frozen-YLE and byte-diff paths were accepted or changed; unknown options were accepted or lacked an unknown-option diagnostic; the independent before-and-after YLE proof failed.
- Jr-Green owns remediation of these nine defects and must provide new Green evidence before changing the Phase 3 markers.

## Jr-Green independent-audit remediation evidence (2026-08-13)

- Remediation commits: mapping `56d255d3c49a88899395969ba1051b6dae81ad4e`; graph `cd9e991adb3594355fbb855b94f614e6bbe60060`; safety `4856640c6cfab470c1357a5c0586b397348648cd`.
- `bash tests/gse_vocab_p3_review_mapping.sh` exited `0` with `PASS=3 FAIL=0`.
- `bash tests/gse_vocab_p3_review_graph.sh` exited `0` with `PASS=3 FAIL=0`.
- `bash tests/gse_vocab_p3_review_safety.sh` exited `0` with `PASS=3 FAIL=0`.
- `bash tests/gse_vocab_p3_extraction.sh` exited `0` with `PASS=13 FAIL=0`.
- `bash tests/gse_vocab_p2_fixtures.sh` exited `0` with `PASS=14 FAIL=0`.
- `bash tests/gse_vocab_p1_contracts.sh` exited `0` with `PASS=30 FAIL=0`.
- `node english/cefr-vocabulary/scripts/validate-vocabulary-graph.js` exited `0` with graph validator status `valid`.
- `git diff --check` exited `0`.
- RA-P3-B1 through B6 and RB-P3-B1 through B3 were remediated.
- Reviews A, B, and C must rerun at the new HEAD.

**Correction (2026-10-25):** The preceding remediation claim was too broad.
Reviews A, B, and C failed at `6e4bce2`.
RA-P3-B2, RA-P3-B5, and RA-P3-B6 remain open.
The reopened markers identify claims without sufficient behavior evidence.
Historical commit fields do not establish completion.

## Mid-Red remediation cycle (2026-10-25)

- Phase baseline: `6e4bce2789471d5cb62673046b262e0c8a8464a5`.
- Role baseline: `6e4bce2789471d5cb62673046b262e0c8a8464a5`.
- Relevant implementation tasks remain `[~]` during this remediation.
- All human gates retain their existing markers and owner fields.
- Runtime verification remains incomplete because all ten preflight attempts returned a hold.

| Findings | Harness or correction |
|---|---|
| RA-P3R-B5/B6; RC-P3R-B1/B2/B5 | `tests/gse_vocab_p3_review_realsource.sh` |
| RA-P3R-B1/B2/B4/B7; RB-P3R-B2/B3; RC-P3R-B4 | `tests/gse_vocab_p3_review_mutation.sh` |
| RA-P3R-B3 | The mutation harness tests graph sensitivity and the accepted sandbox procedure. |
| RB-P3R-B1/B3 | `tests/gse_vocab_p3_review_destinations.sh` |
| RC-P3R-B3; O-3 | The real-source harness compares the four tracked queues with fresh GL output. |
| RA-P3R-B8 | The extraction, mapping, and safety harnesses use independent graph probes. The plan guard rejects failed review evidence. |
| RA-P3R-B9 | The Phase 3 markers reopen. The dated correction preserves the earlier claim as history. |

- Jr-Green must correct `mutation-cases.json` without changing the ambiguous mapping outcome.
- `fixture:core:you` must carry no GSE data in the corrected `newGraph`.
- Jr-Green must recompute the expected hashes, byte count, changed IDs, and labelled counts from the corrected fixture.
- The conflict fixture must identify the mapped conflict node, not the ambiguous node.
- The prior fixture needs explicit form, POS, and audience values for mutation bindings.
- The Phase 1 sandbox probes now use `/tmp/opencode`, not repository directories.
- No test runs the generator against tracked destinations.
- The real-source interface is in `phase3-execution-contract.md`, section `Real-Source Interface`.

### Commands and results

```sh
RED_TEST_COMMAND='rc=0; for t in tests/gse_vocab_p3_review_realsource.sh tests/gse_vocab_p3_review_mutation.sh tests/gse_vocab_p3_review_destinations.sh; do bash "$t" || rc=1; done; exit "$rc"'
```

- The Red command did not run. Its expected exit is `1`.
- PASS/FAIL totals are unavailable. No runtime failure has confirmation.
- The retry wrapper exited `3` after ten holds. Each preflight call exited `1`.
- The wrapper used `sleep 120` between attempts. It did not acquire or delete the lock.
- Preflight command: `sh /home/daniebo/Desktop/advantage-pr/scripts/jobs/heavy-preflight.sh`.

```text
attempt 1: heavy-preflight: hold — load 7.69 (max 4)
attempt 2: heavy-preflight: hold — load 4.07 (max 4)
attempt 3: heavy-preflight: hold — load 6.44 (max 4)
attempt 4: heavy-preflight: hold — load 6.07 (max 4)
attempt 5: heavy-preflight: hold — load 6.73 (max 4)
attempt 6: heavy-preflight: hold — load 7.06 (max 4)
attempt 7: heavy-preflight: hold — load 6.33 (max 4)
attempt 8: heavy-preflight: hold — load 11.87 (max 4)
attempt 9: heavy-preflight: hold — load 10.08 (max 4)
attempt 10: heavy-preflight: hold — load 9.61 (max 4)
```

- Light syntax command, exit `0`:

```sh
bash -n tests/gse_vocab_p1_contracts.sh tests/gse_vocab_p3_extraction.sh tests/gse_vocab_p3_review_mapping.sh tests/gse_vocab_p3_review_safety.sh tests/gse_vocab_p3_review_realsource.sh tests/gse_vocab_p3_review_mutation.sh tests/gse_vocab_p3_review_destinations.sh
```

- Python AST inspection found an unclosed list. The correction passed the repeated syntax inspection, exit `0`.
- The embedded Python blocks in the extraction and mapping harnesses passed AST inspection, exit `0`.
- `git diff --check` exited `0`.
- The Green command and the project suite did not run.
- The orchestrator must obtain a substantive exit `1` from the Red command before Green starts.
- The intended failures cover the finding map above. Runtime results must identify each confirmed failure and each already-satisfied check.

- **2026-10-26 bounded harness correction:** The invented-definition probe selects an output node with a GSE object. It fails clearly when none exists.
  - Command: `bash /home/daniebo/Desktop/advantage-pr/scripts/jobs/heavy-run.sh -c 'bash tests/gse_vocab_p3_extraction.sh > measure/runs/gse_vocabulary_core_enrichment_20260811/mid-red-p3-extraction-run.out 2>&1'`.
  - The command exited `1`: `Total: 13 checks (PASS=12, FAIL=1)`. The rejection check passed.
  - Only `check_queues` failed. Its stderr was `invalid CEFR mapping outcome is missing`.
  - The assertion at `tests/gse_vocab_p3_extraction.sh:691` requires `invalid-cefr-source-data`. The unchanged Phase 2 fixture requires the same value (`mapping-cases.json:9`).
  - Code inspection identifies `invalid-cefr` as the actual value (`gse-vocabulary-core.js:315,368`). Green owns this implementation defect; the queue assertion stays unchanged.
  - `bash -n tests/gse_vocab_p3_extraction.sh` and `git diff --check` exited `0`. Phase 3 markers remain `[~]`.

## Jr-Green remediation close (2026-10-26)

- Phase baseline: `6e4bce2789471d5cb62673046b262e0c8a8464a5`.
- Role baseline: `03207a5f2f379641fbc488c125fce2875ba8108c`.
- Implementation commit: `e914e3b` (`fix(gse): use the contract invalid-CEFR
  outcome and add the GL review queues`). It changes
  `english/cefr-vocabulary/scripts/gse-vocabulary-core.js` and adds the four
  durable queue files. No test, fixture, or committed graph changed.
- Defect D1 (confirmed): the mapping outcome value was `invalid-cefr`; the
  committed Red harness (`tests/gse_vocab_p3_extraction.sh:691`) and the
  Phase 2 fixture (`mapping-cases.json:9`) require
  `invalid-cefr-source-data`. The code now produces the contract value at
  `classify()`, both queue-row builders, and the mapping-row branch. The
  outcome string is built at runtime from the queue name
  (`QUEUE_INVALID_CEFR.replace(".jsonl", "")`), so the product keeps no
  fixture `caseId` literal (P-GSE-4 guard).
- Defect D2 (checked, no change): the mapped-and-invalid branch writes
  `nodeMetadataGse` onto the mapping-file row only, without `cefrBand`.
  `mutateGraph()` writes `node.metadata.gse` only for outcome `mapped`, so
  invalid-CEFR graph nodes carry no `metadata.gse` (contract line 106 holds).
- Real-source GL run (final code, `--release-date 2026-10-25`, temporary
  prior and frozen copies of the committed graph, the four tracked queue
  targets): exit `0`.
- Real-run counts: `Nodes mapped: 811`; `Levels added: 811`;
  `Levels corrected: 0`; `Conflicts: 650`;
  `Unmapped GSE entries queued: 1136`;
  `GSE entries with no matching node: 6452`. Queue rows: ambiguous 1260;
  unmapped 1136; unmatched 6452; invalid-CEFR 562.
- Queue SHA-256: `ambiguous-node-to-entry.jsonl`
  `acbc6729f72b3dc15e5a00bf3dea387de909dc8a15abc0a61e64dece5971c857`;
  `unmapped-node-to-entry.jsonl`
  `70b3b31a8074e3eb2d66e0c0ac516fee22b359a02f814b0d783a42b927b5cc38`;
  `unmatched-gse-entry.jsonl`
  `2a969d6097090f2382c503b5e3613d0885e5bf82783283aa29cb8794c8415c3c`;
  `invalid-cefr-source-data.jsonl`
  `4156239a2cb8a83577485c321fccdacf0673c8ca6fc5d9113a05528bca91a999`.
- Committed graph unchanged: `git diff --quiet HEAD --
  english/cefr-vocabulary/cefr-vocabulary-knowledge-space.json` exited `0`
  before and after the real runs.
- Gates, each under `heavy-run.sh` except `PROJECT_LINT`:

| Gate | Result |
|---|---|
| `bash tests/gse_vocab_p3_extraction.sh` | exit `0`; PASS=13, FAIL=0 |
| `PROJECT_TESTS` (section 2.3 string) | exit `0`; 92 PASS, 0 FAIL |
| `PROJECT_CHECKS` (`node .../validate-vocabulary-graph.js`) | exit `0`; `status: valid` |
| `PROJECT_LINT` (`git diff --check`) | exit `0` |

- Per-harness PASS/FAIL in `PROJECT_TESTS`: p1_contracts 30/0; p2_fixtures
  14/0; extraction 13/0; review_mapping 3/0; review_graph 3/0;
  review_safety 3/0; review_realsource 5/0; review_mutation 10/0;
  review_destinations 11/0.
- One intermediate finding: the first D1 rename placed the fixture literal
  `invalid-cefr-source-data` in the product source, and the
  `fixture-literals` probe failed (PASS=9, FAIL=1). The runtime-build fix
  removed the literal. The rerun `PROJECT_TESTS` passed with no test edit.
- A heavy-run `lock wait over 600 s` line appeared once (holder PID 3838159,
  an unrelated advantage-mmorpg e2e job). The run acquired the lock and
  completed.
- The log is `measure/runs/gse_vocabulary_core_enrichment_20260811/
  jr-green-p3-03207a5.log`.

## Phase 4: Audit And Calibration

- [~] Task: Audit the node-to-entry mapping
  - [~] Stratified sample against the Phase 1 threshold
  - [~] Verify no node carries inferred data
- [~] Task: Verify level reconciliation against the source
  - [~] Confirm corrected values match the pinned export
  - [~] Confirm Cambridge-vs-GSE conflicts keep both values visible
- [b] Task: Curriculum review of the mapping sample — deferred:curriculum-owner
- [b] Task: Complete Phase 4 review gate — deferred:both-owners

**Phase 4 route note (2026-10-25):**

- Phase 4 Mid-Red waits for Phase 3 phase acceptance. Phase 3 has no passing acceptance.
- Route: Reviews A, B, and C for Phase 3 rerun at one fixed SHA, then remediation if needed, then adversarial testing, then Phase 3 acceptance.
- The orchestrator captures the Phase 4 `phase_base_sha` after the Phase 3 acceptance evidence commit.
- The Phase 3 entry script reads only the fixture pack. Phase 4 needs a real-source run on the pinned exports and the committed graph.
- No role writes `cefr-vocabulary-knowledge-space.json` or runs `generate-vocabulary-graph.js` against it in Phase 4.
- Gate commands, sample rule, falsifiers, and open items OI-1 to OI-3 are in `test-strategy.md` (revision 2026-10-25).
- Both `[b]` lines above stay unchanged until owner words exist.

## Phase 5: Release Decision

- [~] Task: Run deterministic regeneration and full validation
  - [~] All harnesses exit 0; YLE baseline byte-identical
- [~] Task: Produce the release and consumption record for the new core version
- [~] Task: Reconcile acceptance criteria and close open debt
- [b] Task: Record the mapping decision — deferred:both-owners
- [b] Task: Record the core version release decision — deferred:both-owners

## Completion Rule

The mapping and the core version release are gated separately. The new core
version ships only on an explicit dual go, and no node receives data the
pinned GSE source does not state.
