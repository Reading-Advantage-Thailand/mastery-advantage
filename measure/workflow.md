# Project Workflow

## Principles

1. The active track plan is the source of truth.
2. Primary/source-backed data is preserved separately from derived enrichment.
3. Generated artifacts must be deterministic and validated before review.
4. Graph counts are not quality evidence by themselves.
5. Human review samples scale with derivation risk and graph impact.
6. App implementation begins only after the readiness gate is accepted.

## Task Workflow

1. Read the track specification and plan plus relevant source/design docs.
2. Mark the next plan task `[~]`.
3. Define or update the contract and expected validation before generator work.
4. Write failing regression or validation tests where behavior changes.
5. Implement the smallest source-backed or explicitly derived change.
6. Regenerate bounded artifacts.
7. Run structural, extraction-quality, semantic, and determinism checks.
8. Update quality reports, provenance, and documentation in the same task.
9. Mark the task complete only when its acceptance evidence is recorded.

## Required Validation

### Generator Or Parser Changes

- `node --check` for changed scripts.
- Targeted parser tests and malformed-input cases.
- Deterministic regeneration: two clean runs produce identical tracked output.
- `node english/cefr-vocabulary/scripts/validate-vocabulary-graph.js`.
- `git diff --check`.

### Graph Data Changes

- No duplicate node IDs or edge triples.
- No dangling edges.
- No unapproved prerequisite cycles.
- Every skill has required alignment/provenance.
- Derived edges include method, confidence, source/model version, and review
  status.
- Quality report records node/edge counts and deltas by source and relation.

### Phase Completion

- Run the full validation suite defined by the phase.
- Produce or update the phase quality report.
- Review unresolved risks and update `tech-debt.md`.
- Obtain explicit approval at curriculum/semantic/app-handoff gates.

## Commit Guidelines

- Use Conventional Commits.
- Keep generated artifact changes with the generator/source change that caused
  them.
- Do not include unrelated working-tree changes.
- Record verification commands and material results in the track plan.

## Definition Of Done

A track is complete only when its acceptance criteria, quality thresholds,
provenance requirements, reproducibility checks, review gates, and handoff
artifacts all pass. A large generated graph without accepted quality evidence is
not complete.
