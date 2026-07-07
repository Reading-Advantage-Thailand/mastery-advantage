# Project Tracks

This registry tracks Mastery Advantage specification and domain-data work.

## Release Sequence

1. The core lexical graph may release after its own quality gate.
2. Coverage, semantic, and recommendation tracks depend on approved core
   contracts but do not block the core release.
3. Each enrichment layer is independently approved, quarantined, or rejected.
4. Production application implementation remains outside this repository.

---

- [ ] **Track: English Lexical Graph Core Release** *(critical path — gates 3 blocked tracks)*
  *Release the audited, reproducible, source-backed Cambridge lexical graph
  without blocking on optional enrichment.*
  *Status (sharpened 2026-06-21): not started — 0/95 plan tasks, metadata `new`. Note: the underlying graph **data already exists and is tracked** (`english/cefr-vocabulary/data/cambridge-vocabulary-inventory.json` 1.5MB, `english/cefr-vocabulary/cefr-vocabulary-knowledge-space.json` 13.8MB, both `9a5d4c4` 2026-06-10; `english/gse-knowledge-space.json` 17.5MB, 2026-05-20). This track is the audit / schema-validation / provenance / reproducibility / test-gate effort **over that existing data** (per plan: "generate counts from the tracked inventory and graph"; acceptance = byte-identical reproducible outputs + durable audit decisions), not a from-scratch build. It is the release gate for the three enrichment/recommendation tracks below (metadata `blocked`).*
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

---

- [ ] **Track: Sense-Level Lexical Identity Specification**
  *Define when and how sense-level identity replaces form+POS for polysemous words; produce reviewed spec and 50-word sample.*
  *Link: [./tracks/sense_level_identity_spec_20260611/](./tracks/sense_level_identity_spec_20260611/)*

---

- [ ] **Track: B2 Vocabulary Source Expansion**
  *Close the B2 gap using documented alternative sources (Vocabulary in Use, etc.) without claiming false Cambridge FCE coverage.*
  *Link: [./tracks/b2_vocabulary_source_expansion_20260611/](./tracks/b2_vocabulary_source_expansion_20260611/)*

---

- [ ] **Track: Frequency, Semantic and Article-Ranking Layer Design**
  *Design reproducible frequency, semantic similarity, and article-ranking layers as additive graph extensions.*
  *Link: [./tracks/frequency_semantic_ranking_layer_20260611/](./tracks/frequency_semantic_ranking_layer_20260611/)*

---

- [ ] **Track: KST+SRS Core Algorithm Correctness** *(engine correctness gate — fix before other kst-srs tracks build on affected formulas)*
  *Fix five correctness-level defects in the kst-srs.v2 core algorithms (compensatory hard-gate readiness, miscounted calibration posterior, retention aggregation, placement seeding gap, queue ordering) and release kst-srs.v3.*
  *Link: [./tracks/kst_srs_core_correctness_20260707/](./tracks/kst_srs_core_correctness_20260707/)*
