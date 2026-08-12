# Implementation Plan: GSE Vocabulary Core Enrichment

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
> supervisor (`measure/automation-supervisor.py`) recognizes `[b]` and
> `deferred:<owner>` as structured-blocked. The interphase checker still uses
> the old `[ ~x]` regex, so `[b]` lines are invisible to its counts; this is the
> intended honest state for human gates. See `test-strategy.md` section 9.
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
- [~] Task: Jr-Green remediation of Phase 1 Red evidence defects — remove the orphan bare generator command and correct the cycle-2 Red evidence
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
- At the role-base contract state, the Red command exited `1` with `Total: 26 checks (PASS=22, FAIL=4)`.
- Remaining failures are the Pearson attribution contract, invalid-CEFR queue contract, same-procedure YLE contract property, and safe sandbox procedure.
- RA-P1-N4 is closed in Red by removing trailing punctuation from the three `60f4ef3` plan evidence lines.
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

## Phase 2: Tests And Fixtures

- [~] Task: Build GSE vocabulary extraction fixtures
  - [~] Cover GL and YL record layouts, starred `gse`, `temporaryGse`, and
        the YL short CEFR form
- [~] Task: Build mapping fixtures
  - [~] Multi-POS expressions, ambiguous bindings, unmapped nodes
  - [~] Nodes whose Cambridge level disagrees with the GSE band
- [~] Task: Build core-mutation and determinism tests
  - [~] Assert the YLE baseline regenerates byte-identical
  - [~] Assert the byte-diff report matches the actual mutation
- [~] Task: Build the falsifier fixture
  - [~] A node where a naive form-only mapping binds the wrong POS entry
- [~] Task: Verify Phase 2

## Phase 3: Extraction, Mapping, And Core Mutation

- [~] Task: Implement the deterministic GSE vocabulary extractor
  - [~] Two consecutive runs produce byte-identical tracked output
- [~] Task: Implement source-backed node-to-entry mapping
  - [~] Every mapped node cites a GSE `itemId`
  - [~] Ambiguous and unmapped cases go to durable queues under this track's
        own directory
- [~] Task: Implement the core mutation generator
  - [~] Write GSE score, band, definition, and example onto mapped nodes
  - [~] Produce the new core version and the byte-diff report
- [~] Task: Produce the mapping quality report
  - [~] Labelled counts: nodes mapped, levels added, levels corrected,
        conflicts, unmapped queued, GSE entries with no node
- [~] Task: Apply audit isolation
  - [~] Name this track's queue files explicitly so foreign queue files
        cannot change its reports

## Phase 4: Audit And Calibration

- [~] Task: Audit the node-to-entry mapping
  - [~] Stratified sample against the Phase 1 threshold
  - [~] Verify no node carries inferred data
- [~] Task: Verify level reconciliation against the source
  - [~] Confirm corrected values match the pinned export
  - [~] Confirm Cambridge-vs-GSE conflicts keep both values visible
- [b] Task: Curriculum review of the mapping sample — deferred:curriculum-owner
- [b] Task: Complete Phase 4 review gate — deferred:both-owners

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
