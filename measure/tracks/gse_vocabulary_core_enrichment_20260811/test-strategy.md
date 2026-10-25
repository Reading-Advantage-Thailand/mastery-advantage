# Test Strategy: gse_vocabulary_core_enrichment_20260811

## Contents

- [0. Orchestrator Capture Points (`phase_base_sha`)](#0-orchestrator-capture-points-phase_base_sha)
- [1. Intent And Risk Summary](#1-intent-and-risk-summary)
- [2. Configured Gate Commands](#2-configured-gate-commands)
- [3. Architecture Guardrails (all phases)](#3-architecture-guardrails-all-phases)
- [4. Applicability Matrix](#4-applicability-matrix)
- [5. Anti-Pattern Coverage (A1-A10)](#5-anti-pattern-coverage-a1-a10)
- [6. Per-Phase Strategy](#6-per-phase-strategy)
- [7. Aggregate Suite Policy](#7-aggregate-suite-policy)
- [8. Artifact Tests vs Live Behavior Tests](#8-artifact-tests-vs-live-behavior-tests)
- [9. Framework Conflict (report, not a silent product workaround)](#9-framework-conflict-report-not-a-silent-product-workaround)
- [10. What The Next Roles Do](#10-what-the-next-roles-do)
- [11. Open Items For The Owners](#11-open-items-for-the-owners)

**Track:** GSE Vocabulary Core Enrichment
**Revision:** 2026-10-25 - Phase 3 closure route and strategy for Phase 4
(Audit And Calibration)
**Revision history:**

- 2026-08-12 - strategy for Phase 1 (Source Acquisition And Contracts),
  pre-strategy baseline `79fb0a4abede4fcd8cb85b6b609047d05ec707a9`. Phase 2
  and Phase 3 used the per-phase sections of that revision.
- 2026-10-25 - this revision. Pre-strategy baseline (role_base_sha):
  `ceb728d6b317486f8622a147a9155bcb1e2dcfcd`.

**Role:** measure-strategy
**Scope of this revision:** the route that closes Phase 3, the Phase 4 audit,
and the Phase 5 open item. This revision changes no product source, no test,
no graph, and no contract outside the track directory.

---

## 0. Orchestrator Capture Points (`phase_base_sha`)

This revision has two capture points. Do not use the pre-strategy SHA
`ceb728d6b317486f8622a147a9155bcb1e2dcfcd` for either point. Do not embed a
guessed future SHA in this file.

**Capture point 1 - Phase 3 re-review base.** After the commit that contains
this `test-strategy.md`, the `plan.md` route note, and the `measure/tracks.md`
entry, the orchestrator captures:

```text
p3_review_base_sha = git rev-parse HEAD
```

Reviews A, B, and C for "Phase 3: Extraction, Mapping, And Core Mutation" all
run at this one SHA. If a remediation commit follows, the orchestrator captures
a new `p3_review_base_sha` after that commit. All three reviews then rerun at
the new SHA.

**Capture point 2 - Phase 4 `phase_base_sha`.** The orchestrator captures this
SHA only after the Phase 3 phase acceptance passes and its evidence commit
exists:

```text
phase_base_sha = git rev-parse HEAD    # after the Phase 3 acceptance evidence commit
```

If the Phase 3 remediation changes the entry interface in
`phase3-execution-contract.md`, a strategy refresh comes first. Then the
capture uses the HEAD after the refresh commit. Phase 4 Mid-Red must not start
before capture point 2. The Mid-Red gate compares `git rev-parse HEAD` with
the supplied baseline and fails when HEAD did not advance.

---

## 1. Intent And Risk Summary

| Goal | How tests prove it | Primary risk |
|---|---|---|
| Pinned source identity (GL 11,586; YL 3,024) | Provenance doc + SHA-256 + read-only count probe | Silent re-export; wrong cache file |
| Mapping contract (form + POS + audience) | Contract doc defines binding rule + no-inference | Form-only mapping binds wrong POS |
| Starred `gse` (70 GL) and `temporaryGse` (129 YL) | Contract preserves and explains both | Special values dropped silently |
| Core mutation contract | Field names, version bump, byte-diff shape, YLE reproducibility | Core version drifts from frozen baseline |
| Real-data mapping (Phase 3 closure) | The entry script reads the pinned exports and the committed graph | Fixture-bound code passes fixture tests and cannot run on real data |
| Review sample threshold (Phase 4) | >=100 stratified mappings + 98% precision, re-derived from the source | Unreviewable or self-confirmed mapping |
| CEFR band calibration (Phase 4) | Labelled counts per raw GSE band and per outcome | Plus bands and `<A1` produce false queue rows or false conflicts |
| Durable queue isolation (FR-8) | Queue files named under this track | Foreign queue changes this track's reports |
| Dual human gates (FR-9) | Two separate recorded decisions | One gate false-claimed as two |

**Overall track risk:** **high** (core mutation + curriculum truth + freeze
discipline). The change writes onto the **core** graph, not an enrichment
overlay. The frozen YLE baseline must stay reproducible.

No production auth surface and no UI. Security review is **narrow**. Browser
review is **not applicable**.

---

## 2. Configured Gate Commands

### 2.1 Heavy-job rule (all roles, from 2026-10-25)

A test run is a heavy job on this machine (rule from Daniel, 2026-10-25).
Each role applies this procedure to each test or check command `C`:

```sh
sh /home/daniebo/Desktop/advantage-pr/scripts/jobs/heavy-preflight.sh
# exit 0: run the command under the shared lock
flock ~/Desktop/primary-parity-progress/heavy.lock -c "$C"
# exit 1: do not run C; copy the printed "heavy-preflight: hold ..." line
#         into the role log and the plan evidence
```

- The heavy commands are `RED_TEST_COMMAND`, `GREEN_TEST_COMMAND`,
  `PROJECT_CHECKS`, and `PROJECT_TESTS`.
- `PROJECT_LINT` (`git diff --check`) and `bash -n <harness>` are light. Run
  them directly.
- Never delete the lock file.
- A hold is not a pass and not a fail. A role that needs a result and gets a
  hold ends with `status: blocked` or `status: partial`. It records the hold
  line. It does not reuse an older result as evidence for the current HEAD.
- `flock -c` runs the string with `sh -c`. The command strings below are
  POSIX `sh` strings.

### 2.2 Phase 1 commands (history)

The Phase 1 commands were:

```text
RED_TEST_COMMAND="bash tests/gse_vocab_p1_contracts.sh"
GREEN_TEST_COMMAND="bash tests/gse_vocab_p1_contracts.sh"
PROJECT_CHECKS="node english/cefr-vocabulary/scripts/validate-vocabulary-graph.js"
PROJECT_LINT="git diff --check"
PROJECT_TESTS="bash tests/gse_vocab_p1_contracts.sh"
PROJECT_DEV_URL=""        # no UI in this repository
UX_REQUIRED="never"       # contract and data repo; browser review not applicable
```

Phase 2 and Phase 3 roles recorded their exact Red commands in `plan.md`.

### 2.3 Phase 3 closure commands (re-review, remediation, acceptance)

```text
RED_TEST_COMMAND="<focused harness named by Mid-Red; see below>"
GREEN_TEST_COMMAND='rc=0; for t in tests/gse_vocab_p3_extraction.sh tests/gse_vocab_p3_review_mapping.sh tests/gse_vocab_p3_review_graph.sh tests/gse_vocab_p3_review_safety.sh; do bash "$t" || rc=1; done; exit "$rc"'
PROJECT_CHECKS="node english/cefr-vocabulary/scripts/validate-vocabulary-graph.js"
PROJECT_LINT="git diff --check"
PROJECT_TESTS='rc=0; for t in tests/gse_vocab_p1_contracts.sh tests/gse_vocab_p2_fixtures.sh tests/gse_vocab_p3_extraction.sh tests/gse_vocab_p3_review_mapping.sh tests/gse_vocab_p3_review_graph.sh tests/gse_vocab_p3_review_safety.sh; do bash "$t" || rc=1; done; exit "$rc"'
PROJECT_DEV_URL=""
UX_REQUIRED="never"
```

- The reviews themselves need no `RED_TEST_COMMAND`. When a rerun review
  reports a blocking finding, Mid-Red writes one focused harness
  `tests/gse_vocab_p3_review_<topic>.sh`. Then
  `RED_TEST_COMMAND="bash tests/gse_vocab_p3_review_<topic>.sh"` and the
  gate expects exit `1`.
- For the real-data gap in section 6 (Phase 3, observation O-1), the
  recommended name is `tests/gse_vocab_p3_review_realsource.sh`.
- Each new Phase 3 harness is appended to `GREEN_TEST_COMMAND` and to
  `PROJECT_TESTS` in the same commit that adds it. The orchestrator exports
  the extended strings.
- The loop form runs every harness and keeps the first failure visible. Do not
  use `&&` chains, because they hide later results.
- `PROJECT_CHECKS` must exit `0`. The Phase 3 closure changes no committed
  graph.

### 2.4 Phase 4 commands

```text
RED_TEST_COMMAND="bash tests/gse_vocab_p4_audit.sh"
GREEN_TEST_COMMAND="bash tests/gse_vocab_p4_audit.sh"
PROJECT_CHECKS="node english/cefr-vocabulary/scripts/validate-vocabulary-graph.js"
PROJECT_LINT="git diff --check"
PROJECT_TESTS='rc=0; for t in tests/gse_vocab_p1_contracts.sh tests/gse_vocab_p2_fixtures.sh tests/gse_vocab_p3_extraction.sh tests/gse_vocab_p3_review_mapping.sh tests/gse_vocab_p3_review_graph.sh tests/gse_vocab_p3_review_safety.sh tests/gse_vocab_p4_audit.sh; do bash "$t" || rc=1; done; exit "$rc"'
PROJECT_DEV_URL=""
UX_REQUIRED="never"
```

- Insert each Phase 3 remediation harness from section 2.3 before
  `tests/gse_vocab_p4_audit.sh` in `PROJECT_TESTS`.
- `RED_TEST_COMMAND` must exit `1` at `phase_base_sha` for a substantive
  reason (a missing audit artifact or a failed comparison). A syntax error or
  a missing harness file is not a valid Red.
- `GREEN_TEST_COMMAND` must exit `0` after Jr-Green. The harness then exits
  `1` again in each negative mode that Mid-Red defines (section 6, Phase 4).

### 2.5 Who runs what

| Role | Commands (each under section 2.1) |
|---|---|
| Mid-Red | `bash -n` on the new harness; `RED_TEST_COMMAND` (expect exit `1`); `PROJECT_LINT` |
| Jr-Green | `GREEN_TEST_COMMAND`; `PROJECT_CHECKS`; `PROJECT_TESTS`; `PROJECT_LINT` |
| Reviews A, B, C | Read-only. They may run `GREEN_TEST_COMMAND` and `PROJECT_TESTS` at the review SHA. They fix nothing. |
| Adversarial testing | Temporary copies and negative modes only. Tracked files stay unchanged. |
| Phase acceptance | `PROJECT_TESTS`, `PROJECT_CHECKS`, and `PROJECT_LINT` at the accepted SHA. A hold blocks acceptance. |

---

## 3. Architecture Guardrails (all phases)

1. **Core vs overlay.** This track mutates the **core** graph under a version
   bump. It is not an enrichment overlay. Tests must fail if the new version
   does not carry a version label distinct from the frozen YLE baseline.
2. **YLE baseline stays reproducible.** The frozen YLE baseline must stay
   reproducible after the core version bump. A diff report with labelled
   counts accompanies the new version. No silent overwrite of frozen data.
3. **No invention.** An absent GSE entry yields a queue row, never data. A
   mapped node must cite a GSE `itemId`. Tests fail on any mapped node without
   an `itemId`.
4. **No `prerequisite_for` edges.** The graph keeps `prerequisite_for` count at
   0. GSE data is a level and metadata signal, not a mastery ordering.
5. **Labeled integers only.** Every count and rate uses a labelled integer
   pattern (anti-A3), e.g. `GL items: 11586`, never bare `[0-9]+`.
6. **Human gates stay open.** `[b]` tasks stay `[b]` until real owner evidence
   exists. Do not mark a human decision `[x]` without a signed decision
   artifact (anti-A4, anti-A5).
7. **Artifact tests are not live behavior.** Markdown presence alone never
   satisfies extraction, mapping, or regeneration behavior. Pair doc checks
   with executable probes (section 8).
8. **Queue isolation.** This track's queue files are named explicitly. A
   foreign queue file must not change this track's reports (FR-8,
   COVERAGE_QUEUES lesson).
9. **The committed graph is the source of truth (added 2026-10-25).** The
   tech-debt row of 2026-10-06 states that
   `english/cefr-vocabulary/cefr-vocabulary-knowledge-space.json` cannot be
   rebuilt from its sources. No role runs
   `english/cefr-vocabulary/scripts/generate-vocabulary-graph.js` against the
   committed graph. No role writes the committed graph in Phase 3 or Phase 4.
   A harness reads the committed graph, or a byte-identical temporary copy.
   It checks the SHA-256 of the committed graph and of
   `english/cefr-vocabulary/data/cambridge-vocabulary-inventory.json` before
   and after the run.
10. **No fixture-bound product code (added 2026-10-25).** The product entry
    script must not contain a literal fixture node ID, a fixture `itemId`, or
    a fixture `caseId`. A test that passes only because the code knows the
    fixture is not evidence of behavior (candidate P-GSE-4 in section 5).
11. **Temporary paths stay outside the repository.** Harnesses create
    temporary directories with `mktemp -d "${TMPDIR:-/tmp}/..."`. They never
    write a temporary directory into the repository root. The untracked
    `gse-vocab-yle-*` directories in the repository root are leftovers from an
    earlier run. This strategy does not remove them; the owner decides.

### Changed-contract risks

- The core node binds on `metadata.normalizedForm` + `metadata.partsOfSpeech`
  + an explicit audience input. The GSE entry binds on `expression` +
  `grammaticalCategories` + `audience`. A naive form-only match is the primary
  falsifier.
- GL `cefr` uses the long form (`<A1 (10-21)`); YL `cefr` uses the short form
  (`<A1`). The extractor must normalize both without dropping the band.
- The 70 starred GL `gse` values and the 129 YL `temporaryGse` values must be
  preserved and explained, not dropped (FR-2).
- **CEFR band set (found 2026-10-25).** The mapping contract normalizes only
  to `PRE-A1`, `A1`, `A2`, `B1`, `B2`, `C1`, and `C2`. A read-only count of
  the pinned exports found plus bands. GL: `A2+` 723, `B1+` 2945, `B2+` 764.
  YL: `A2+` 686, `A2+*` 34. The current `band()` function returns no band
  for a plus value. A mapped entry with a plus band therefore goes to the
  invalid-CEFR queue. See open item OI-2.
- **`<A1` normalization (found 2026-10-25).** The Phase 2 fixtures expect
  `<A1 (10-21)` to normalize to `A1`. The GSE range 10-21 is below A1, and
  the Cambridge core uses `pre-a1` for 495 skill nodes. The current rule can
  report a Cambridge-versus-GSE conflict for each pre-A1 word with a GSE `<A1`
  band. GL has 383 `<A1` items; YL has 630 (`<A1` 624, `<A1*` 6). See OI-2.
- **Version location (found 2026-10-25).** The mutation contract puts the
  core version in the domain node `metadata.schemaVersion` with the format
  `gse-vocab-YYYYMMDD-rNN`. The committed graph has only `nodes` and `edges`
  at the top level. Its domain node carries `english-vocabulary.v1`. The
  current `nextVersion()` reads a top-level `schemaVersion` and needs a prior
  `gse-vocab-...` value. It cannot bump the committed graph.
- **Two audiences.** The mapping contract says a release input that needs
  both audiences records two separate candidate results before a later
  approved reconciliation rule. No reconciliation rule exists yet. Phase 4
  audits GL and YL as separate runs and does not merge them.

### Intentionally-red aggregate handling

Until a phase harness is implemented, do **not** add a green stub script. An
absent file is preferred over a vacuous `exit 0` (anti-A4). The repository has
no `measure/test-all.sh`. The `PROJECT_TESTS` strings in section 2 are the
aggregate. Do not claim `PASS` on an aggregate that does not list every
existing GSE harness.

---

## 4. Applicability Matrix

| Review type | Applicable? | When / notes |
|---|---|---|
| Security review (Review B) | **Narrow** | No auth, PII, or network service in scope. Checks: no publisher raw JSON committed (exports stay Git-ignored under `english/cefr-vocabulary/source-pdfs/`); no secret in fixtures; FR-6 licence boundary respected (non-commercial, approved purposes only); attribution string present; write scope stays inside supplied temporary paths. |
| UX / API review (Review C) | **Yes (contract API)** | The mapping contract, the mutation contract, the conflict report, and the Phase 4 audit artifacts are the integration API for downstream consumers. Not a GUI. |
| Adversarial testing | **Yes** | Attacks: form-only mapping to wrong POS; starred/temporaryGse dropped; unmapped node given inferred data; YLE baseline drift; foreign queue poisoning; human gate false-claimed; registry overstatement; fixture-bound code; tampered sample manifest. |
| Browser / WebBridge review | **Not applicable** | Spec, data, and contract repository. `PROJECT_DEV_URL=""`. `UX_REQUIRED=never`. |

### Phase 4 applicability (2026-10-25)

| Review | Phase 4 scope |
|---|---|
| Review A (correctness) | **Yes.** The sample selector, the source re-check, the precision count, the level reconciliation, and the write scope. |
| Review B (security, narrow) | **Yes, narrow.** Licence boundary (FR-6); no raw export committed (`git ls-files english/cefr-vocabulary/source-pdfs` prints nothing); tracked Phase 4 artifacts carry no full export record; the attribution `The Global Scale of English and its components © Pearson.` is in the audit report. |
| Review C (contract API) | **Yes.** The conflict report shape against `phase1-mutation-contract.md`; the sample manifest shape against `phase1-review-samples.md`; the audit report labels. |
| Adversarial testing | **Yes.** See the Phase 4 attack list in section 6. |
| Browser review | **Not applicable.** |

### Independence rule (report-only audits)

All audit and review roles are **report-only**. They must not fix audited
implementation. Findings route to the accountable implementation role
(Mid-Red or Jr-Green). A reviewer who edits audited code creates a self-audit
conflict. Each review result records this rule: blocking findings route to the
implementation owner for rework, not to the reviewer's own edit.

---

## 5. Anti-Pattern Coverage (A1-A10)

| ID | Relevance | Defense in this track |
|---|---|---|
| **A1** Substring `deferred` drops tasks | **Active framework conflict** | The interphase checker (`measure_interphase_checks.py` in the orchestrator skill) still uses `"deferred" not in task.lower()` and the regex `[ ~x]`. Human gates use `[b]` plus `deferred:<owner>`. The `[b]` marker is invisible to the old checker regex, so the `deferred` substring is moot for `[b]` lines. Guard: each phase harness asserts no `[ ]` remains and each `[b]` line carries `deferred:<owner>`. History: `measure/automation-supervisor.py` had the fixed regex until commit `ba3e0a3` (2026-10-05) removed it (section 9). |
| **A2** Consent-blind publish | Low | The core version release is a publish. The Phase 5 release gate requires dual-owner signatures before `[b]` flips to `[x]`. No anonymization needed (no named subjects). |
| **A3** Digit-only counts | **High** | Every count uses a labeled integer: `GL items: 11586`, `reviewed mappings: 100`. Tests parse the integer after the label. |
| **A4** Vacuous pass on nothing-done | **High** | Green requires >=1 substantive `[x]` with SHA evidence. A zero count is evidence only with a second probe that makes the count non-zero (section 6, Phase 4). |
| **A5** False-claim text | **High** | Plan, registry, and reports must not claim a result unless the cited command exits 0 at the cited SHA. No "released", "frozen", or "validated" wording until the dual go exists. |
| **A6** Registry overstatement | **High** | `measure/tracks.md` keeps this track `[~]` with "in progress" status words until the Phase 5 dual release decision. The Phase 1 harness rejects "complete" and "released" in the entry. |
| **A7** Over-broad filters | Medium | Exclusion filters exclude only file-path contexts and policy-disclaimer markers, not bare English words. |
| **A8** `[ ]` marker ambiguity | **High** | Plan uses `[x]/[~]/[b]` only. Guard: `rg -n '^\s*- \[ \]' plan.md` returns 0 hits. |
| **A9** Archived path drift | Low until closeout | Future tests resolve the track directory and prefer `measure/archive/<id>` when it exists. |
| **A10** Generated-facts drift | Low | No reliance on `measure/generated/` for GSE truth. The repo has no `measure/generate.sh` or `measure/doctor.sh`. |

Project-specific candidates to watch:

- **P-GSE-1:** Counting GSE export items (14,610 total) as mapped-node
  evidence. Export count is source size, not mapping coverage.
- **P-GSE-2:** Treating form-only string match as an audited mapping without a
  POS and audience check.
- **P-GSE-3:** Dropping starred `gse` or `temporaryGse` because they are not
  clean integers.
- **P-GSE-4 (new candidate, 2026-10-25):** Fixture-bound product code. The
  code names fixture IDs, so it passes the fixture harness and cannot run on
  real data. Defense: a static guard finds no fixture ID literal in the entry
  script, and a live run on the pinned exports and the committed graph must
  exit `0`. This strategy does not edit `measure/anti-patterns.md`; the
  orchestrator decides on promotion.

---

## 6. Per-Phase Strategy

### Phase 1: Source Acquisition And Contracts

**Risk:** **medium** (contract honesty + source pinning; no graph mutation yet)
**Reviews:** UX/API yes (contract API); Adversarial light (marker honesty, A8);
Security narrow (no raw export committed); Browser not applicable.
**State (2026-10-25):** phase acceptance passed at `ee95902`. The human gate
stays `[b] deferred:both-owners`.

| Gate | Command / evidence |
|---|---|
| **Red** | `bash tests/gse_vocab_p1_contracts.sh`. Failed on the pre-contract tree because the contract docs were absent. |
| **Green** | Same harness exits `0`. `PROJECT_CHECKS` exits `0` (no graph change). `git diff --check` exits `0`. |
| **Closeout** | The Phase 1 human gate (`[b] deferred:both-owners`) stays `[b]`, or becomes `[x]` only with a signed dual-owner decision artifact. |

**Contract docs:** `english/cefr-vocabulary/review/gse-vocab/`
(`phase1-mapping-contract.md`, `phase1-mutation-contract.md`,
`phase1-review-samples.md`).

**Fixtures / live proof:** read-only count probes of the pinned exports. The
harness also runs a copy of `generate-vocabulary-graph.js` twice in a
temporary sandbox and compares the two outputs. It writes no tracked file and
checks the committed graph SHA-256 before and after (see OI-1).

**Artifact vs live:** artifact and documentation tests plus read-only
source-cache probes.

**Anti-patterns defended:** A1, A3, A4, A5, A6, A8, P-GSE-3 (as in the
2026-08-12 revision).

**Falsifiers:** missing SHA-256 or FR-6 owner words; missing POS map or
audience rule; missing YLE proof; sample threshold absent or below 100; any
`[ ]` marker; a GL count other than 11,586 or a YL count other than 3,024; a
Phase 1 human gate `[x]` without a signed artifact.

---

### Phase 2: Tests And Fixtures

**Risk:** **high** (fixtures encode the falsifiers that govern Phase 3)
**Reviews:** Adversarial yes; UX/API on fixture shape; Security narrow; Browser
not applicable.
**State (2026-10-25):** phase acceptance passed at `abe7d3d`.

| Gate | Command / evidence |
|---|---|
| **Red** | `bash tests/gse_vocab_p2_fixtures.sh` failed while the fixtures were absent. |
| **Green** | Fixtures cover GL and YL layouts, starred `gse`, `temporaryGse`, YL short CEFR, multi-POS, ambiguous, unmapped, conflict, and the form-only falsifier. |
| **Closeout** | Phase 2 verification task `[x]` with SHA. |

**Anti-patterns:** A3, A4, A7, P-GSE-2.

**Falsifiers:** falsifier fixture absent; GL covered without YL; no conflict
case.

---

### Phase 3: Extraction, Mapping, And Core Mutation

**Risk:** **critical** (core graph mutation + freeze discipline)
**Reviews:** Review A yes; Review B narrow; Review C on the mutation contract;
Adversarial yes; Browser not applicable.

| Gate | Command / evidence |
|---|---|
| **Red** | `bash tests/gse_vocab_p3_extraction.sh` failed while the entry script was absent (plan evidence, 2026-08-13). |
| **Green** | The section 2.3 `GREEN_TEST_COMMAND` exits `0`: two runs byte-identical; every mapped node cites an `itemId`; queues; new version validates; YLE isolation; byte-diff matches the mutation. |
| **Closeout** | Phase 3 phase acceptance passes at one reviewed SHA. |

**Anti-patterns:** A3, A5, P-GSE-1, P-GSE-3, P-GSE-4.

**Falsifiers:** a mapped node without an `itemId`; an unmapped node with GSE
data; YLE regeneration drift; a foreign queue file changes a report; a starred
`gse` or `temporaryGse` value dropped.

#### Phase 3 state (verified 2026-10-25)

- Phase 3 has **no** passing phase acceptance.
- Review A failed at `50d524c`
  (`measure/runs/gse_vocabulary_core_enrichment_20260811/phase3-review-a-50d524c.json`).
- Review B failed at `50d524c`
  (`measure/tracks/gse_vocabulary_core_enrichment_20260811/audit-results/phase3-review-b-50d524c.json`).
- Mid-Red added three focused harnesses at `4847356`. Jr-Green remediation
  commits `56d255d`, `cd9e991`, and `4856640` followed. Evidence commit
  `27a9f45` recorded them.
- The plan says "Reviews A, B, and C must rerun at the new HEAD." No rerun
  result exists.
- Commit `1e10cf9` (2026-10-06) changed one node of the committed graph and
  `generate-vocabulary-graph.js` after the Phase 3 Green evidence.

#### Phase 3 closure route (required before Phase 4)

1. The orchestrator captures `p3_review_base_sha` (section 0, point 1).
2. Reviews A, B, and C for "Phase 3: Extraction, Mapping, And Core Mutation"
   rerun at that one SHA. They are report-only.
3. If a review reports a blocking finding: Mid-Red writes a focused failing
   harness (section 2.3). Jr-Green remediates. The orchestrator captures a new
   `p3_review_base_sha`. Step 2 repeats with all three reviews.
4. Adversarial testing runs at the final reviewed SHA.
5. Phase 3 phase acceptance runs at the same SHA with the section 2.3
   `PROJECT_TESTS`, `PROJECT_CHECKS`, and `PROJECT_LINT`.
6. Only after a passing acceptance, the orchestrator captures the Phase 4
   `phase_base_sha` (section 0, point 2). Then Phase 4 Mid-Red starts.

#### Strategy observations for the Phase 3 reruns

These are inputs for the independent reviewers, not verdicts. The reviewers
confirm or refute each one at `p3_review_base_sha`.

- **O-1 (real data).** `english/cefr-vocabulary/scripts/gse-vocabulary-core.js`
  reads only `records.json`, `mapping-cases.json`, and `mutation-cases.json`
  from `--fixture-dir`. It has no input for the pinned GL and YL exports.
  `mutationSources()` names `fixture:core:afternoon`, `fixture:core:you`, and
  one fixture `itemId`. The conflict output reads the fixture case
  `conflict-retains-cambridge`. The extractor writes the schema label
  `gse-vocab-fixture-extraction-v1`. FR-2, FR-3, and FR-4 need extraction and
  mapping of the pinned exports onto the core graph. Phase 4 cannot obtain a
  real mapped output while this stays true.
- **O-2 (version).** See "Version location" in section 3. The committed graph
  cannot pass `nextVersion()`.
- **O-3 (durable queues).** `phase1-mapping-contract.md` names tracked queue
  paths under `english/cefr-vocabulary/review/gse-vocab/queues/`. That
  directory does not exist. The plan marks the queue subtask `[x]`.
- **O-4 (field names).** The mapping contract names `gse.rawValue` and
  `gse.starred` for starred values. The script writes `gseScore` and
  `starred`. Review C decides if this is a contract deviation.
- **O-5 (CEFR bands).** See section 3 and OI-2.

If Review A confirms O-1, the Phase 3 task markers at `[x]` overstate the
work (A5). The remediation route owns the plan correction. This strategy does
not change Phase 1 to 3 markers.

#### Required real-source capability (input for the Phase 3 remediation)

Phase 4 needs the entry script to run on real inputs. The capability is:

- read the GL export and the YL export from
  `english/cefr-vocabulary/source-pdfs/` and verify their SHA-256 values
  against `GSE_VOCABULARY_SOURCES.md` before any work;
- take an explicit audience (`GL` or `YL`) for each run;
- take the committed graph (or a byte-identical temporary copy) as
  `--prior-graph`;
- take a supplied UTC release date for the version label;
- write only to supplied temporary paths, with the existing alias checks.

The Phase 3 remediation owns the exact option names. It records them in
`phase3-execution-contract.md`. The Phase 4 harness uses the recorded
interface.

---

### Phase 4: Audit And Calibration

**Risk:** **high** (curriculum truth + level reconciliation on real data; no
committed graph write)
**Reviews:** Review A yes; Review B narrow; Review C on the conflict-report
shape; Adversarial yes; Browser not applicable.
**Precondition:** Phase 3 phase acceptance passed, and the orchestrator
captured `phase_base_sha` (section 0, point 2).

| Gate | Command / evidence |
|---|---|
| **Red** | `bash tests/gse_vocab_p4_audit.sh` (Mid-Red authors it). It exits `1` at `phase_base_sha` because the tracked Phase 4 artifacts are absent. |
| **Green** | Same harness exits `0`. The section 2.4 `PROJECT_TESTS`, `PROJECT_CHECKS`, and `PROJECT_LINT` exit `0`. |
| **Closeout** | The four automatable subtasks are `[x]` with SHA. "Curriculum review of the mapping sample" stays `[b] deferred:curriculum-owner`. "Complete Phase 4 review gate" stays `[b] deferred:both-owners`. Each becomes `[x]` only with owner words in a signed artifact. |

#### Phase 4 inputs

- **Prior graph:** the committed
  `english/cefr-vocabulary/cefr-vocabulary-knowledge-space.json` at
  `phase_base_sha`. The harness copies it to a temporary path. It asserts that
  the copy SHA-256 equals the SHA-256 of `git show <HEAD>:<path>`.
- **Sources:** the pinned exports
  `source-pdfs/gse-vocabulary-gl-10-67-2026-08-11.json` (SHA-256
  `e63298d7...b90800`) and
  `source-pdfs/gse-vocabulary-yl-10-59-2026-08-11.json` (SHA-256
  `6b8c8950...784ab30`). The harness stops with exit `1` and a named
  diagnostic when a file is absent or its SHA-256 differs. An absent cache is
  a Red with a reason, never a skip that passes.
- **Entry:** the Phase 3 entry script through the real-source interface in
  `phase3-execution-contract.md`. One run for `GL` and one run for `YL`.

#### Phase 4 outputs

- **Temporary only:** the new graph, the extraction files, the mapping files,
  the queue files, and the byte-diff report. They go under
  `mktemp -d "${TMPDIR:-/tmp}/gse-vocab-p4.XXXXXX"`.
- **Tracked evidence** (Jr-Green writes it; Phase 4 only writes these names),
  all under `english/cefr-vocabulary/review/gse-vocab/`:
  - `phase4-review-sample.json` - the manifest and the selected rows;
  - `phase4-audit-report.json` and `phase4-audit-report.md` - the labelled
    counts, the precision result, the band calibration table, and the Pearson
    attribution;
  - `phase4-conflict-report.jsonl` - the rows in the
    `phase1-mutation-contract.md` conflict schema;
  - optional durable queues under `queues/` with the four contract names only.
- **Forbidden writes:** `cefr-vocabulary-knowledge-space.json`,
  `data/cambridge-vocabulary-inventory.json`, any file under `source-pdfs/`,
  and any repository-root temporary directory. No role runs
  `generate-vocabulary-graph.js` against the committed graph.
- **Licence boundary:** tracked Phase 4 artifacts carry no definition text and
  no example text. Sample rows carry only the contract fields.
- **Human artifact:** the curriculum owner writes the curriculum review. No
  automated role creates it.

#### Phase 4 sample (from `phase1-review-samples.md`)

- **Population:** accepted mappings (outcome `mapped`) from the GL run and the
  YL run on real data.
- **Strata and minimums:** POS noun 15; POS verb 15; POS adjective or adverb
  10; POS other supported POS 10; audience GL 20; audience YL 20; multi-POS
  core nodes 10; Cambridge-versus-GSE conflict cases 10.
- **Minimum size:** 100 selected rows. A count below 100 fails the audit.
- **Precision threshold:** at least 98%. The integer test is
  `correct * 100 >= 98 * reviewed`, with `reviewed >= 100`.
- **Deterministic selection rule:**
  1. Build the key `nodeId:itemId` for each population row.
  2. Sort the keys by Unicode code point, ascending.
  3. Visit the strata in the contract table order.
  4. For each stratum, count the rows already selected that belong to it.
     Add the next unused sorted rows of that stratum until the count reaches
     the minimum or the stratum has no unused row.
  5. Then add unused rows from the full sorted population until the count is
     100 or the population has no unused row.
- **Manifest fields:** the SHA-256 of each mapping output, the selection
  command, `seed` (value `none: sorted nodeId:itemId`), the labelled
  `selected rows: N`, and per stratum the labelled population and selected
  counts. A stratum with no population records `population: 0` and a reason.
- **Row fields:** `nodeId`, `itemId`, form, normalized POS set, audience,
  Cambridge CEFR value, GSE CEFR band, and mapping decision.

#### Phase 4 live-behavior proof

- The harness runs the entry script on the real inputs. It is a live run, not
  a doc check.
- The harness re-derives the sample with its own selector. The tracked
  manifest must be byte-identical to the re-derived manifest.
- The harness re-checks each sampled row against the raw export with an
  independent reader in the harness. It does not import the product script.
  This defends against evidence that consults itself (lessons-learned,
  2026-08-11).
- The automated precision proves **source fidelity** only: form, POS,
  audience, and `itemId` agree with the export. It cannot find a sense
  mismatch (for example, the same form and POS with a different meaning). The
  curriculum review owns that judgment. The audit report must label the
  result "source-fidelity precision", not "curriculum approval".

#### Phase 4 falsifiers (each probe has a fail condition)

- The real-source run exits non-zero, or the harness skips it -> fail.
- The committed graph SHA-256 or the inventory SHA-256 changes during the
  harness -> fail.
- A tracked file other than the named Phase 4 artifacts changes -> fail.
- The tracked sample manifest differs from the re-derived manifest -> fail.
- The selected row count is below 100, or a stratum is below its minimum
  without a `population: 0` record -> fail.
- `correct * 100 < 98 * reviewed` -> the audit report must say "open", and a
  report that claims the threshold -> fail.
- A labelled count in `phase4-audit-report.md` differs from the harness count
  -> fail (A5).
- A node in the new graph carries `metadata.gse` with a field that differs
  from its cited export record, or with a field the record does not state ->
  fail (no inference).
- A node in an unmapped, ambiguous, or invalid-CEFR queue carries
  `metadata.gse` -> fail.
- **Corrected values:** the committed graph has no GSE metadata today, so the
  real run must report `Levels corrected: 0`. A zero alone is not proof
  (A4). A second probe seeds one wrong GSE band onto a temporary prior copy.
  The output must carry the export band, and the count must be
  `Levels corrected: 1`. A failure of either part -> fail.
- **Conflicts visible:** for each node, `metadata.cefr`, `cefrAlignments`, and
  `examAlignments` in the new graph must equal the prior graph. The conflict
  report row set must equal the set the harness computes independently. Each
  row must carry both the Cambridge value and the GSE band. Any difference ->
  fail.
- **Band calibration:** the audit report shows labelled counts per raw GSE
  CEFR value and per outcome (mapped with band, invalid-CEFR queue, conflict).
  It shows the conflicts whose only cause is the `<A1` rule as their own
  labelled count. A report without this table -> fail.
- `Nodes mapped` is greater than the number of core skill nodes, or equals an
  export item count -> fail (P-GSE-1).
- A starred `gse` raw value or a `temporaryGse` flag in a sampled row's export
  record is missing from the mapped node -> fail (P-GSE-3).
- A GL entry binds to a YL run, or a YL entry binds to a GL run -> fail.
- The entry script contains a literal fixture node ID, fixture `itemId`, or
  fixture `caseId` -> fail (P-GSE-4).
- Plan state: Red needs each Phase 4 automatable marker `[~]`; Green needs
  each one `[x]` with a 7-to-40 hex SHA. Both `[b]` lines must stay
  byte-identical with their `deferred:<owner>` fields. A `[ ]` marker -> fail.
- The registry entry contains "complete", "released", "validated", or
  "frozen" -> fail (A6).

#### Phase 4 negative modes (for Mid-Red)

The harness exposes `GSE_VOCAB_P4_NEGATIVE=<mode>`. Each mode tampers with a
temporary copy only and must exit `1`:

- `tampered-sample` - one manifest row gets a different `itemId`;
- `inferred-field` - one mapped node gets a field its record does not state;
- `silent-overwrite` - one node's Cambridge `cefr` takes the GSE band;
- `foreign-queue` - a foreign queue file sits beside the named queues;
- `gate-flip` - the curriculum review line becomes `[x]` with no artifact;
- `count-mismatch` - one labelled count in the report changes by 1.

#### Phase 4 anti-patterns defended

- **A3** - every count is a labelled integer (`reviewed mappings: N`,
  `correct mappings: N`, `incorrect mappings: N`, `selected rows: N`,
  `Levels corrected: N`). Defense: parse the integer after the label.
- **A4** - a zero count needs the seeded probe; all-`[~]` is Red, not Green.
- **A5** - the report states no precision or count without harness output at
  the same SHA. Defense: report-versus-harness count equality.
- **A6** - registry words guard (above).
- **A8** - `[ ]` guard on `plan.md`.
- **P-GSE-1** - mapped-node counts use graph nodes as the denominator, not
  export size.
- **P-GSE-2** - each sampled row passes the form, POS, and audience re-check.
- **P-GSE-3** - starred and temporary values survive into the node.
- **P-GSE-4** - static fixture-literal guard plus the real-data run.

#### Phase 4 attack list (adversarial role)

Wrong-POS same-form substitution; cross-audience substitution; an export with
one changed byte (SHA-256 check); a manifest reorder; a precision claim in
the report without harness output; a plus band coerced to a clean band
without an owner decision; a conflict resolved by overwrite; an output path
that aliases the committed graph; a temporary directory in the repository
root; a registry entry with "validated".

#### Risk from commit `1e10cf9` (Phase 4)

- `1e10cf9` changed the `matchForms` value of the `businessman/woman` node in
  the committed graph and changed `generate-vocabulary-graph.js`. It did not
  change `normalizedForm` or `partsOfSpeech`, which the binding rule uses.
- Phase 3 evidence came from the fixture pack and did not read the committed
  graph. Its fixture results do not depend on `1e10cf9`.
- The committed graph SHA-256 at `ceb728d` is
  `4fee1cd407d86dd6c959d107e325d4918acad17984b1f23c312f76059dca3f8c`. Before
  `1e10cf9` it was
  `6a3cf1ab285e1f04cc8451164e9f2ce7ae18c41d17328b1ba162324df5240b8a`.
- Rule for Phase 4: the audit records the committed graph SHA-256 at
  `phase_base_sha`. All Phase 4 evidence cites that SHA-256. Evidence that
  cites a different graph SHA-256 is not Phase 4 evidence.
- The Phase 1 YLE probe runs a copy of the current generator. The Phase 1
  acceptance at `ee95902` ran the earlier generator. The Phase 3 closure
  `PROJECT_TESTS` run covers the current generator.

---

### Phase 5: Release Decision

**Risk:** **high** (process honesty + freeze authority)
**Reviews:** Adversarial yes (A5, A6); UX/API final read of the release and
consumption record; Security narrow; Browser not applicable.

| Gate | Command / evidence |
|---|---|
| **Red** | `bash tests/gse_vocab_p5_release.sh` (Mid-Red authors it). Fails while the release record, regeneration proof, and acceptance reconciliation are absent. |
| **Green** | All harnesses exit 0; YLE baseline reproducible; release and consumption record present; acceptance criteria reconciled; open debt recorded. |
| **Closeout (track)** | Final acceptance only after dual go for the mapping decision and the core version release decision. Both `[b]` gates flip to `[x]` only with signed owner words. |

**Anti-patterns:** A2, A4, A5, A6, A8.

**Falsifiers:** registry says released while a dual go is missing; a human
gate `[x]` without owner words; YLE regeneration drift; an unreconciled
acceptance criterion.

**Open item for the Phase 5 strategy (not decided here):** the Phase 5 task
"Run deterministic regeneration and full validation" and FR-10 conflict with
the tech-debt rule of 2026-10-06: "the committed file is the source of truth;
do not run the build before the Primary cutover." See OI-1. The Phase 5
strategy must not start before the owners answer OI-1.

---

## 7. Aggregate Suite Policy

- Before a phase harness is implemented, do not add a green stub. Prefer an
  absent file over a vacuous `exit 0`.
- The aggregate is the `PROJECT_TESTS` string of the current phase in
  section 2. It lists each existing GSE vocabulary harness by name.
- Before Phase 4 Mid-Red, `tests/gse_vocab_p4_audit.sh` is absent. Use the
  section 2.3 aggregate. The section 2.4 aggregate is intentionally red until
  Phase 4 Green, and no role claims it as "all green" before then.
- The repo has no `measure/test-all.sh`, `measure/generate.sh`, or
  `measure/doctor.sh`. Do not claim those gates run.

---

## 8. Artifact Tests vs Live Behavior Tests

| Phase | Artifact / doc tests | Live behavior tests |
|---|---|---|
| 1 | Mapping contract, mutation contract, review samples, provenance, plan markers | Read-only source-cache count probe; sandboxed generator-copy YLE probe |
| 2 | Fixture file presence and shape | None (fixtures are data) |
| 3 | Mutation report shape | Deterministic extraction, mapping with `itemId`, YLE isolation, byte-diff report (fixture inputs); real-data run after remediation |
| 4 | Sample manifest, audit report, and conflict report shape | Real-data run on the pinned exports and the committed graph; independent source re-check; seeded correction probe; conflict visibility |
| 5 | Release record | Regeneration as the owners define it (OI-1); full validation suite |

Rule: a markdown file is evidence only when an executable probe parses its
content or a live command produces the claimed numbers. A filename match is
never sufficient.

---

## 9. Framework Conflict (report, not a silent product workaround)

**Marker contract tension (history and current state):**

1. Until commit `ba3e0a3` (2026-10-05), `measure/automation-supervisor.py`
   used the regex `^- \[([~xb])\]` plus `is_task_structurally_blocked`. That
   commit removed the file. Fleet Commander and the Pi harness replace the
   supervisor. This strategy did not verify their marker handling.
2. The interphase checker
   (`~/.agents/skills/measure-orchestrator/scripts/measure_interphase_checks.py`)
   still uses `^- \[([ ~x])\]` and the substring rule
   `"deferred" not in task.lower()` (verified 2026-10-25).

**Track choice (honest docs):**

- Human gates use `[b]` plus `deferred:<owner>`. The `[b]` marker is invisible
  to the checker regex, so the `deferred` substring is moot for `[b]` lines.
- Automatable not-yet-started tasks use `[~]`, the repo convention.
- Do not mark human work `[x]` and do not convert `[b]` to `[~]` to please the
  checker.

**Orchestrator follow-up (framework, not this product track):** update the
interphase checker to `^- \[([~xb])\]` and structured `deferred:<owner>`
blocking.

---

## 10. What The Next Roles Do

1. Orchestrator: capture `p3_review_base_sha` after the strategy commit
   (section 0, point 1). Export the section 2.3 commands.
2. Reviews A, B, C: rerun for "Phase 3: Extraction, Mapping, And Core
   Mutation" at that SHA. Confirm or refute O-1 to O-5. Stay report-only.
3. Mid-Red (only on a blocking finding): write
   `tests/gse_vocab_p3_review_<topic>.sh` in `tests/` only. Run it under
   section 2.1 and expect exit `1`.
4. Jr-Green: remediate. For O-1, add the real-source capability and record
   its interface in `phase3-execution-contract.md`.
5. Adversarial testing, then Phase 3 phase acceptance, at one SHA.
6. Orchestrator: capture the Phase 4 `phase_base_sha` (section 0, point 2).
   Route OI-2 to the owners before Phase 4 Green.
7. Phase 4 Mid-Red: author `tests/gse_vocab_p4_audit.sh` from section 6. It
   writes only under `tests/`. It keeps both Phase 4 `[b]` lines unchanged.

---

## 11. Open Items For The Owners

The orchestrator routes these to the owners. This strategy decides none of
them.

- **OI-1 - Regeneration versus the do-not-rebuild rule (Phase 5).** Plan
  Phase 5 and FR-10 ask for "deterministic regeneration". The tech-debt row of
  2026-10-06 forbids the build before the Primary cutover, because the build
  drops 17 nodes and consumers carry node IDs from the committed file.
  Options: (a) regeneration means a rerun of the GSE entry script on the
  committed graph to a new versioned path, with no
  `generate-vocabulary-graph.js` run; (b) the release waits until the
  tech-debt fix makes the build reproduce the committed file; (c) another
  owner rule. Related: the Phase 1 harness runs a copy of the generator in a
  temporary sandbox. It writes no tracked file. The owners confirm whether
  that sandbox run fits the rule.
- **OI-2 - CEFR band calibration (Phase 4, before Green).** The contract band
  set has no plus bands, and the fixtures map `<A1` to `A1`. Pinned export
  counts: GL `A2+` 723, `B1+` 2945, `B2+` 764, `<A1` 383; YL `A2+` 686,
  `A2+*` 34, `<A1` 624, `<A1*` 6. Options for plus bands: (a) keep them in
  the invalid-CEFR queue; (b) store the raw plus band and a base band;
  (c) another rule. Options for `<A1`: (a) keep `A1`; (b) map to `PRE-A1`.
  Any change edits accepted Phase 1 and Phase 2 artifacts and needs a
  remediation cycle.
- **OI-3 - Two-audience reconciliation (Phase 5).** A node can map in both
  the GL run and the YL run. The mapping contract needs "a later approved
  reconciliation rule" before one value goes onto the node.
