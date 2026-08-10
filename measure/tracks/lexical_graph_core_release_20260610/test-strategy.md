# Test Strategy: lexical_graph_core_release_20260610

**Track:** English Lexical Graph Core Release (YLE Baseline Freeze)  
**Revision:** 2026-08-10 — strategy/track revision for approved YLE freeze intent  
**Role:** measure-strategy  
**Baseline at strategy start:** `e967243c340e75b95bdce6a3babb7558cbc6d191`  
**Scope of tests:** audit harnesses, contract/fixture checks, freeze-package
structure, and one-shot sanity — **not** application runtime, and **not** a
standing dual-run regeneration pipeline.

---

## 0. Orchestrator Capture Point (`phase_base_sha`)

After this `test-strategy.md` (and the companion track-doc revision) is
**committed**, the orchestrator must capture:

```text
phase_base_sha = git rev-parse HEAD
```

at that post-strategy-commit HEAD.

Do **not** treat the pre-strategy SHA `e967243c340e75b95bdce6a3babb7558cbc6d191`
as `phase_base_sha`. Do not embed a guessed future SHA in this file.

Until that commit exists, Mid-Red for Phase 1 must not start.

---

## 1. Intent And Risk Summary

| Goal | How tests prove it | Primary risk |
|---|---|---|
| YLE list fidelity (1,388 skills, S/M/F membership) | Membership fixtures + labeled audit metrics vs decisions | Silent omissions / false inclusions |
| Cumulative interpretation | Consumption fixtures (not duplicate edges) | Encoding cumulative need as fake prereqs |
| Forms / POS / MWE / variants / merges | Identity fixtures + collision queue completeness | False merges; missing MWEs |
| Groups (thematic + grammatical handling) | Group membership samples + explicit omission records | Topic false-includes; ignored grammatical lists |
| Fact vs derived support; no hard prereqs | Edge-class catalog + zero-prereq guard + support review | Support treated as mandatory |
| Static graph + dynamic learner next steps | Contract example profiles (offline) | Student state written into graph |
| Reading program | Offline text/profile fixtures | Unmatched tokens dropped from coverage |
| Freeze package + sanity | Artifact presence + one-shot structural/hash checks | Ceremony without human decision |

**Overall track risk:** **high** (curriculum truth + freeze authority).  
No production auth surface; security review is **narrow**. Browser UX review is
**not applicable**.

---

## 2. Global Guardrails

### Architecture

1. **Static vs dynamic:** Tests fail if any freeze contract or fixture stores
   per-student mastery, due dates, or SRS card state on graph nodes/edges.
2. **No fabricated hard prerequisites:** Any `prerequisite_for` edge in the
   freeze baseline fails the gate. Support edges must be labeled derived.
3. **YLE release authority:** Freeze metrics and go/no-go apply to YLE.
   Full-graph multi-exam counts may appear as context only, with labels.
4. **One-shot sanity, not endless pipeline:** Phase 6 forbids requiring
   recurring dual-run regeneration or continuous source refresh as a product
   process. A single structural/hash/consistency check is enough.
5. **Counts are labeled:** Every metric assertion uses a labeled integer
   pattern (anti-A3), e.g. `YLE skill count: 1388`, never bare `[0-9]+`.
6. **Human gates stay incomplete:** `[b]` tasks must remain incomplete until
   real owner evidence exists (anti-A4 / anti-A5).
7. **Artifact tests ≠ live behavior:** Markdown presence alone never satisfies
   membership, coverage, or zero-prereq behavior. Pair doc checks with
   executable fixture or graph queries.

### Changed-contract risks

- Spec/plan shift from “full Cambridge core regeneration release” to “YLE
  freeze + consumption contract” invalidates old dual-run / full-source
  ceremony as a blocking gate.
- `supports` edges remain in data but change **semantic contract** (signal,
  not requirement).
- Reading metrics must use eligible-token denominators (aligns with
  recommendation-track debt on unmatched tokens).

### Intentionally-red aggregate handling

Until Phase 2+ harnesses exist, phase-local Red commands are the authority.
If a future `measure/test-all.sh` or repo aggregate includes not-yet-built
`tests/yle_*.sh`, those files must either:

- carry `## skip-aggregate: not implemented until Phase N`, or
- be expected-red and excluded from “all green” claims (anti-A5).

Do not claim `PASS` on an aggregate that still contains unimplemented YLE
gates.

---

## 3. Applicability Matrix

| Review type | Applicable? | When / notes |
|---|---|---|
| Security review (Review B) | **Narrow / mostly N/A** | No auth, PII store, or network service in-scope. Only check: no publisher PDF commit; no secret in fixtures; learner-state examples are synthetic. |
| UX / API review (Review C) | **Yes (contract API)** | Review `YLE-CONSUMPTION.md` payloads and explainability fields as the integration API — not a GUI. |
| Adversarial testing | **Yes** | Attack: fake prereqs, unmatched-token erasure, vacuous labeled counts, marking human gates complete without signatures, treating support as hard gate, overstating freeze in `tracks.md`. |
| Browser / WebBridge review | **Not applicable** | Spec/data/contract repo; no `PROJECT_DEV_URL` UI for this track. |

---

## 4. Anti-Pattern Coverage (A1–A10)

| ID | Relevance to this track | Defense |
|---|---|---|
| **A1** Substring `deferred` drops tasks | **Active conflict:** skill wants `deferred:<owner>`; repo checker still substring-matches `deferred`. | Plan uses `human-gate:<owner>` on `[b]` tasks. Strategy handoff reports framework conflict. Guard: incomplete count for this track must stay > 0 while work remains. |
| **A2** Consent-blind publish | Low (no case-study publish) | If any “publish freeze” wording appears, require named owner signatures in `RELEASE-YLE-2025.md`, not anonymous flip. |
| **A3** Digit-only counts | **High** | All baseline/quality assertions use labeled integers (`YLE skill count:`, `Starters membership:`, `prerequisite_for count:`). |
| **A4** Vacuous pass on nothing-done | **High** | Phase Green requires ≥1 substantive `[x]` with evidence for automatable work; all-`[~]` is incomplete. Human-only phases cannot Green via empty automatable set without explicit human evidence files. |
| **A5** False-claim text | **High** | Plan/registry must not say “all checks pass” unless cited command exits 0. Freeze “go” forbidden without dual signatures. |
| **A6** Registry overstatement | **High** | `measure/tracks.md` stays not-started/in-progress until freeze decision exists; no “released/resolved” wording early. |
| **A7** Over-broad filters | Medium | Ban-term filters (if any) exclude only path/disclaimer markers, not bare “never/not”. |
| **A8** `[ ]` marker ambiguity | **High** | Plan normalized to `[x]/[~]/[b]` only. Guard: `rg -n '^- \[ \]' plan.md` → 0 hits. |
| **A9** Archived path drift | Low until closeout | Future tests use track-dir resolve; no tests yet point at archive. |
| **A10** Generated-facts drift | Low | No reliance on `measure/generated` for YLE truth; freeze reports are hand-authored/audited artifacts. |

Project-specific extensions to watch (candidates if violated):

- **P-YLE-1:** Counting multi-exam inventory (3752) as YLE release evidence.
- **P-YLE-2:** Treating topic text-match membership as audited without sample.
- **P-YLE-3:** Encoding cumulative YLE as `prerequisite_for` chains.

---

## 5. Per-Phase Strategy

### Phase 1: Freeze Scope, Facts Inventory, And Review Rules

**Risk:** medium  
**Reviews:** UX/API N/A; Security N/A; Adversarial light (marker honesty); Browser N/A

| Gate | Command / evidence |
|---|---|
| **Red** | `bash tests/yle_p1_scope.sh` (to be authored Mid-Red) — fails if plan still has legacy `[ ]`, if freeze facts section lacks labeled YLE counts, if fact-vs-signal catalog missing, or if `prerequisite_for` prohibition absent from Phase 1 artifacts |
| **Green** | Same script exits 0 after scope/facts/review-rules docs exist with labeled integers and edge-class labels |
| **Closeout** | Phase 1 human-gate tasks either still `[b]` with no false complete, or `[x]` only with signed decision files present |

**Fixtures / mocks:** none live; read tracked JSON for count snapshots only.  
**Live behavior:** optional read-only graph count probe (not regeneration).  
**Artifact vs live:** presence of `plan.md`/`spec.md` text is insufficient without labeled count section derived from artifacts.

**Anti-patterns defended:** A3 (labeled counts), A5 (no false “approved” without human file), A8 (no `[ ]`), A1 (human-gate marker form), A4 (Phase not green on zero `[x]`).

**Falsifiers:**

- Fails if `YLE skill count:` label missing or value not parsed as integer.
- Fails if any `^- \[ \]` remains in `plan.md`.
- Fails if Phase 1 claims curriculum approval without
  `review/yle-2025/phase1-approval.md` (or equivalent) containing owner + date.

---

### Phase 2: YLE List Fidelity Audit

**Risk:** critical  
**Reviews:** Adversarial yes (false membership); Security N/A; Browser N/A; UX N/A

| Gate | Command / evidence |
|---|---|
| **Red** | `bash tests/yle_p2_membership.sh` — fails while membership fixtures/decisions incomplete; must encode expected Starters/Movers/Flyers samples |
| **Green** | Membership harness passes against decisions + graph; labeled precision/recall lines meet thresholds or explicit failing exceptions are quarantine-listed (not silent) |
| **Closeout** | Curriculum fidelity sign-off artifact present **or** task remains `[b]` |

**Fixtures:**

- `fixtures/yle-audit/starters-sample.jsonl`
- `fixtures/yle-audit/movers-sample.jsonl`
- `fixtures/yle-audit/flyers-sample.jsonl`
- Decision log entries for every sample miss/extra

**Live behavior proof:** graph query resolves each fixture row to skill ID +
exam `contains` membership (or decision id). PDF republication not required in
CI if durable source-location references exist; human audit may use local PDF
cache.

**Anti-patterns:** A3 (precision labeled), A5 (no “99.5%” claim without harness
output), A7 (don’t filter real omission lines), P-YLE-1, P-YLE-3.

**Falsifiers:**

- Silent missing Starters entry in sample → fail.
- Graph extra not in decision log → fail.
- Cumulative rule implemented as new `prerequisite_for` → fail.
- Report says `PASS=… FAIL=0` while script exit ≠ 0 → fail (A5).

---

### Phase 3: Relationship And Progression Review

**Risk:** high  
**Reviews:** Adversarial yes; UX/API on labeling language; Security N/A; Browser N/A

| Gate | Command / evidence |
|---|---|
| **Red** | `bash tests/yle_p3_relationships.sh` — fails if support inventory missing, if any edge class unlabeled, or if `prerequisite_for count:` ≠ 0 |
| **Green** | Zero prereq; every YLE-touching support derivation method has disposition; progression policy text forbids hard gates |
| **Closeout** | Curriculum relationship sign-off or still `[b]` |

**Fixtures:** stratified support-edge ID lists by
`same-lexical-form-support-v1` and MWE component method.  
**Live behavior:** scan `cefr-vocabulary-knowledge-space.json` edges.

**Anti-patterns:** A3, A5, A6 (don’t call support “validated prerequisites”),
P-YLE-3.

**Falsifiers:**

- Any `prerequisite_for` edge → hard fail.
- Support edge documented as required for readiness without learner-state
  override path → fail.
- Unreviewed derivation method class remains → fail.

---

### Phase 4: Consumption And Next-Step Contract

**Risk:** high  
**Reviews:** **UX/API yes** (contract is the API); Adversarial yes; Security
narrow (synthetic learners only); Browser N/A

| Gate | Command / evidence |
|---|---|
| **Red** | `bash tests/yle_p4_consumption.sh` — fails if `YLE-CONSUMPTION.md` missing sections or profile fixtures don’t assert gap/stage/due/MWE/topic outputs |
| **Green** | Offline contract examples pass; graph nodes in fixtures show no student fields written |
| **Closeout** | Dual human-gate approvals or remain `[b]` |

**Fixtures:**

- Learner profiles (JSON): Starters beginner; Movers goal with Starters gaps;
  Flyers mixed mastery + due SRS cards
- Expected next-step traces (explainability payloads)

**Live behavior:** pure functions / documented algorithms over
`(graphSnapshot, learnerState)` — no DB. May be JS or golden JSON compare.

**Anti-patterns:** A3, A4, A5; architecture guardrail 1 (no student state on
graph).

**Falsifiers:**

- Output omits lower-level gap for Movers-goal + weak Starters profile → fail.
- Payload lacks separate `graphFacts[]` vs `learnerStateFields[]` → fail.
- Example mutates graph skill `reviewStatus` to encode mastery → fail.

---

### Phase 5: Reading-Program Validation

**Risk:** high  
**Reviews:** Adversarial yes (coverage denominator); UX/API on rationale shape;
Browser N/A; Security N/A

| Gate | Command / evidence |
|---|---|
| **Red** | `bash tests/yle_p5_reading.sh` — fails until S/M/F text fixtures and expected token classifications exist |
| **Green** | Matching + coverage + bounded targets + rationales match goldens; unmatched tokens counted in eligible denominator |
| **Closeout** | Curriculum plausibility note or still `[b]` |

**Fixtures:**

- `fixtures/yle-reading/starters-text.txt` + profile + expected trace
- `fixtures/yle-reading/movers-text.txt` + …
- `fixtures/yle-reading/flyers-text.txt` + …
- Deliberate unmatched hard word in at least one text

**Artifact vs live:** listing fixture files is artifact-only; Green requires
executable compare of classification and coverage numbers (labeled).

**Anti-patterns:** A3, A5, A7; recommendation unmatched-token debt.

**Falsifiers:**

- Known coverage ignores unmatched eligible token → fail.
- Target set exceeds documented bound without warning → fail.
- No rationale citing matchForms / exam membership → fail.
- Only Starters fixture present → fail (need all three stages).

---

### Phase 6: Freeze Package, Sanity Check, And Decision

**Risk:** high (process / honesty)  
**Reviews:** Adversarial yes (A5/A6); Security narrow (no PDF in git);
UX/API final read of consumption doc; Browser N/A

| Gate | Command / evidence |
|---|---|
| **Red** | `bash tests/yle_p6_freeze.sh` — fails if freeze package files missing, sanity metrics unlabeled, or decision signatures absent while plan marks complete |
| **Green** | Package complete; sanity passes; decision recorded; track completion markers honest |
| **Closeout (track)** | Final acceptance only after dual go/conditional-go and no non-deferred incomplete automatable tasks; `[b]` human tasks either signed `[x]` or remain blocked with evidence path |

**Bounded sanity command set (concrete later-phase gates):**

```bash
# Structural / consistency (authoritative for freeze engineering gate)
node english/cefr-vocabulary/scripts/validate-vocabulary-graph.js
bash tests/yle_p6_freeze.sh

# Optional read-only probes inside yle_p6_freeze.sh:
# - labeled YLE skill count vs inventory filter
# - prerequisite_for count == 0
# - SOURCES.md YLE SHA-256 citation present
# - freeze report metrics match decision log tallies
```

**Explicitly not required as product ceremony:**

- Recurring `download-sources.sh` in CI every commit
- Mandatory dual clean regeneration byte-identity loop as ongoing gate
- Full multi-exam re-extraction to “pass” YLE freeze

(If engineers voluntarily re-run generator for a fix, that is a one-off repair,
not a standing process.)

**Anti-patterns:** A2-style unsigned publish, A5, A6, A4, A8, A3.

**Falsifiers:**

- `tracks.md` says released while decision is missing → fail (A6).
- Sanity script uses `rg -q '[0-9]+'` for counts → fail (A3).
- Plan marks dual human decision `[x]` without signature block → fail.
- Freeze package omits A2/B1 method appendix → fail AC method note.

---

## 6. Suggested Test File Map

| Phase | Test entry | Kind |
|---|---|---|
| 1 | `tests/yle_p1_scope.sh` | artifact + labeled graph counts |
| 2 | `tests/yle_p2_membership.sh` | live graph membership vs fixtures |
| 3 | `tests/yle_p3_relationships.sh` | live edge scan + policy text |
| 4 | `tests/yle_p4_consumption.sh` | offline contract goldens |
| 5 | `tests/yle_p5_reading.sh` | offline matching/coverage goldens |
| 6 | `tests/yle_p6_freeze.sh` | package + sanity + honesty |

Shared helpers (inline until `tests/_lib` exists): labeled-int parse, track dir
resolve, marker consistency (A4), refutation filter (A7).

---

## 7. Aggregate Suite Policy

```text
## skip-aggregate: unset means included when file exists
```

- Before a phase harness is implemented, do **not** add a green-stub script.
- Prefer absent file over vacuous `exit 0`.
- When `measure/test-all.sh` exists, YLE scripts participate only after their
  phase Mid-Red introduces them; document expected-red phases in plan evidence
  notes (anti-A5).

---

## 8. Evidence Standards (all phases)

1. **Labeled integers** for every count and rate.
2. **Decision IDs** for every accepted exception.
3. **Owner + date** for every `[b]` → `[x]` transition.
4. **Command + exit code** in plan evidence notes when claiming pass.
5. **No copyrighted PDF contents** committed; cite source location only.

---

## 9. Framework Conflict (blocked concern for orchestrator)

**Marker contract tension (report, do not guess a silent product workaround):**

1. **A1 / `deferred` substring:** Skill wants human gates as
   `[b] … deferred:<owner>` with structured blocking. Repo
   `measure_interphase_checks.py` still uses
   `"deferred" not in task.lower()`, which would hide incomplete work if we
   put `deferred:` in task text.
2. **`[b]` invisible to checker regex:** The same checker matches tasks with
   `^- \[([ ~x])\]` only — it does **not** recognize `[b]`. Human-gate tasks
   are omitted from phase totals (status currently shows Phase 1 as 4/4 from
   `[~]` lines only, ignoring the `[b]` approval task).

**Track choice (honest docs, not a silent false-complete):**

- Use `[b] … human-gate:<owner>` (no `deferred:` substring) so A1 does not
  drop tasks if a future regex starts matching `b` while still substring-scanning.
- Keep automatable work as `[~]` so the first executable Phase 1 task remains
  discoverable even under the current `[ ~x]`-only regex.
- Do **not** mark human work complete and do **not** convert `[b]` to `[~]`
  just to please the checker.

**Orchestrator follow-up (framework, not this product track):** update
`measure_interphase_checks.py` to `^- \[([~xb])\]` and structured
`deferred:<owner>` / `[b]` blocking (A1 fix), then optionally rename
`human-gate:` → `deferred:` in a docs-only cleanup.

**Strategy role status impact:** product strategy revision can complete; the
**framework marker contract remains an open conflict** and must be reported in
the agent result as blocked-for-framework (not blocked-for-missing-product-docs).

---

## 10. What Mid-Red Does Next

1. Wait for strategy commit + orchestrator `phase_base_sha` capture.
2. Author `tests/yle_p1_scope.sh` as Phase 1 Red (must fail on current tree
   where freeze facts section / review paths are still absent).
3. Do not implement product graph generator changes under strategy scope.
4. Keep human-gate tasks `[b]` untouched.
