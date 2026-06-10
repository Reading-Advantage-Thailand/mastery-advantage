# Product Guidelines - Mastery Advantage

## Decision Principles

1. **Provenance before volume:** prefer a smaller explainable graph over a
   larger graph whose relationships cannot be defended.
2. **Separate evidence types:** source membership, CEFR alignment, pedagogical
   grouping, semantic relationships, and statistical similarity must remain
   distinguishable.
3. **Avoid false prerequisites:** only use `prerequisite_for` when the source
   relationship is necessary and reviewable.
4. **Rank probabilistically:** frequency, similarity, unit order, and article
   fit are ranking features, not categorical mastery truth.
5. **Preserve uncertainty:** derived relationships carry confidence,
   derivation method, model/source version, and review status.
6. **Validate generated data:** graph generation is incomplete until structural,
   semantic, extraction-quality, and regression checks pass.
7. **Prepare stable handoffs:** app teams receive versioned contracts,
   migrations, fixtures, and quality reports rather than undocumented JSON.

## Documentation Style

- State what is source-backed, derived, inferred, proposed, and unavailable.
- Report counts and quality metrics with the command or artifact that produced
  them.
- Keep app integration requirements concrete but outside this repository's
  implementation scope.
- Do not describe draft or unreviewed relationships as approved curriculum
  truth.
