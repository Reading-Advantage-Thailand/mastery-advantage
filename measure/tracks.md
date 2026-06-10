# Project Tracks

This registry tracks Mastery Advantage specification and domain-data work.

## Release Sequence

1. The core lexical graph may release after its own quality gate.
2. Coverage, semantic, and recommendation tracks depend on approved core
   contracts but do not block the core release.
3. Each enrichment layer is independently approved, quarantined, or rejected.
4. Production application implementation remains outside this repository.

---

- [ ] **Track: English Lexical Graph Core Release**
  *Release the audited, reproducible, source-backed Cambridge lexical graph
  without blocking on optional enrichment.*
  *Link: [./tracks/lexical_graph_core_release_20260610/](./tracks/lexical_graph_core_release_20260610/)*

---

- [ ] **Track: English Lexical Coverage Enrichment** *(blocked by core contracts)*
  *Add independently gated source-backed groups, B2+ coverage, and frequency
  metadata.*
  *Link: [./tracks/lexical_coverage_enrichment_20260610/](./tracks/lexical_coverage_enrichment_20260610/)*

---

- [ ] **Track: English Lexical Semantic Enrichment** *(blocked by core contracts)*
  *Evaluate and release independently gated typed lexical-semantic layers.*
  *Link: [./tracks/lexical_semantic_enrichment_20260610/](./tracks/lexical_semantic_enrichment_20260610/)*

---

- [ ] **Track: Vocabulary And Article Recommendation Contract** *(blocked by core contracts)*
  *Define portable lexical matching, readability metrics, ranking contracts, and
  offline evaluation fixtures.*
  *Link: [./tracks/lexical_recommendation_contract_20260610/](./tracks/lexical_recommendation_contract_20260610/)*
