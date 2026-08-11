# Project Tracks

This registry tracks Mastery Advantage specification and domain-data work.

## Release Sequence

1. The core lexical graph may release after its own quality gate.
2. Coverage, semantic, and recommendation tracks depend on approved core
   contracts but do not block the core release.
3. Each enrichment layer is independently approved, quarantined, or rejected.
4. Production application implementation remains outside this repository.

---

- [x] **Track: English Lexical Graph Core Release (YLE Baseline Freeze)** *(COMPLETE 2026-08-11 — baseline frozen; unblocks coverage, semantic, recommendation)*
  *Verify and freeze the Cambridge YLE 2025 baseline of the existing lexical
  graph; define static-graph + learner-state next-step consumption; validate
  reading-program fixtures; dual human go. Not a standing regeneration
  pipeline. A2 Key/B1 use the same method later.*
  *Status: complete — dual freeze go in `phase6-approval.md` /
  `RELEASE-YLE-2025.md`. YLE skills 1405; source rows 1407; supports 1311;
  prereq 0. All phase approvals recorded.*
  *Link: [./tracks/lexical_graph_core_release_20260610/](./tracks/lexical_graph_core_release_20260610/)*

---

- [ ] **Track: English Lexical Coverage Enrichment** *(unblocked — in progress)*
  *Add independently gated source-backed groups, B2+ coverage, and frequency
  metadata.*
  *Status: in progress — ViU unit-groups + YLE grammatical-groups overlays
  live (co-taught / grammatical co-listing; core freeze untouched). Next:
  frequency layer; A2/B1 appendix extractors; Phase 1 human gate.*
  *Link: [./tracks/lexical_coverage_enrichment_20260610/](./tracks/lexical_coverage_enrichment_20260610/)*

---

- [ ] **Track: English Lexical Semantic Enrichment** *(unblocked by core freeze)*
  *Evaluate and release independently gated typed lexical-semantic layers.*
  *Link: [./tracks/lexical_semantic_enrichment_20260610/](./tracks/lexical_semantic_enrichment_20260610/)*

---

- [ ] **Track: Vocabulary And Article Recommendation Contract** *(unblocked by core freeze)*
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

- [x] **Track: KST+SRS Core Algorithm Correctness** *(engine correctness gate — COMPLETE 2026-07-07: kst-srs.v3 released; unblocks Phase 1 of the calibration and planner tracks)*
  *Fix five correctness-level defects in the kst-srs.v2 core algorithms (compensatory hard-gate readiness, miscounted calibration posterior, retention aggregation, placement seeding gap, queue ordering) and release kst-srs.v3.*
  *Link: [./archive/kst_srs_core_correctness_20260707/](./archive/kst_srs_core_correctness_20260707/)*

---

- [x] **Track: KST+SRS Calibration & Evidence Quality** *(COMPLETE 2026-07-07: kst-srs.v3.1 released — fitting loop, corrected evidence, multi-probe placement, evaluation harness)*
  *Make the engine self-calibrating and its evidence noise-robust: FSRS parameter fitting, per-priority retention targets, guess/slip correction, multi-evidence placement, normative rating mapper, ability-adjusted edge calibration, offline evaluation harness.*
  *Link: [./archive/kst_srs_calibration_evidence_20260707/](./archive/kst_srs_calibration_evidence_20260707/)*

---

- [x] **Track: KST+SRS Planner & Domain Utility Extension** *(COMPLETE 2026-07-07: kst-srs.v3.2 released — normalized priority, utility provider contract, sparse-domain mode, session composition)*
  *Normalize the planner priority score, add a domain utility provider contract (vocabulary and other prerequisite-sparse domains), and add diversity, review-load budgeting, interleaving, and load smoothing.*
  *Link: [./archive/kst_srs_planner_domain_utility_20260707/](./archive/kst_srs_planner_domain_utility_20260707/)*
  *Coordination: [frequency_semantic_ranking_layer_20260611](./tracks/frequency_semantic_ranking_layer_20260611/) must express its layers as `UtilitySignal` sources per §10.3 and ship the reference English frequency provider (decision D2).*
