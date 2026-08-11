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

- [x] **Track: English Lexical Coverage Enrichment** *(COMPLETE 2026-08-11 — Phase 4–5 dual go)*
  *Add independently gated source-backed groups, B2+ coverage, and frequency
  metadata.*
  *Status: complete — approved layers: frequency.wordfreq, a2-key-appendix,
  b1-preliminary-appendix, yle grammatical-groups, viu.unit-groups. Release:
  `RELEASE-ENRICHMENT-2026-08-11.md`. B2 expansion deferred (not graphable for
  current customers). Full A2/B1 exam freeze remains method-later.*
  *Link: [./tracks/lexical_coverage_enrichment_20260610/](./tracks/lexical_coverage_enrichment_20260610/)*
  *Coordination: frequency node metadata consumed by [frequency_semantic_ranking_layer_20260611](./tracks/frequency_semantic_ranking_layer_20260611/) as utility provider.*

---

- [ ] **Track: English Lexical Semantic Enrichment** *(in progress — Phase 1 go)*
  *Evaluate and release independently gated typed lexical-semantic layers.*
  *Status: Phase 1 approved 2026-08-11 (WordNet 3.1 offline). Next: fixtures +
  candidate generation. Ranking semantic weight stays 0 until a relation layer
  is approved.*
  *Link: [./tracks/lexical_semantic_enrichment_20260610/](./tracks/lexical_semantic_enrichment_20260610/)*

---

- [ ] **Track: Vocabulary And Article Recommendation Contract** *(in progress)*
  *Define portable lexical matching, readability metrics, ranking contracts, and
  offline evaluation fixtures.*
  *Status: Phases 1–3 engineering done — RECOMMENDATION-CONTRACT.md, fixtures,
  recommendation-contract.js (longest-MWE, unmatched in denominator, capped
  ranking + frequency utility). Phase 1 human gate open; Phase 4 evaluation next.*
  *Link: [./tracks/lexical_recommendation_contract_20260610/](./tracks/lexical_recommendation_contract_20260610/)*

---

- [ ] **Track: Sense-Level Lexical Identity Specification**
  *Define when and how sense-level identity replaces form+POS for polysemous words; produce reviewed spec and 50-word sample.*
  *Link: [./tracks/sense_level_identity_spec_20260611/](./tracks/sense_level_identity_spec_20260611/)*

---

- [ ] **Track: B2 Vocabulary Source Expansion** *(deferred — not graphable for current product)*
  *Close the B2 gap using documented alternative sources (Vocabulary in Use, etc.) without claiming false Cambridge FCE coverage.*
  *Status: parked 2026-08-11. B2 inventory is out of scope for current customers;
  do not invent a Cambridge B2 list. Reopen only when product needs B2.*
  *Link: [./tracks/b2_vocabulary_source_expansion_20260611/](./tracks/b2_vocabulary_source_expansion_20260611/)*

---

- [x] **Track: Frequency, Semantic and Article-Ranking Utility Provider Design** *(COMPLETE 2026-08-11 — spec ready)*
  *Express the frequency, semantic, and article-fit signals as one `DomainUtilityProvider` per §10.3. Other tracks own the data layers.*
  *Status: complete design — `RANKING_LAYER_SPEC.md`; frequency live (rank→[0,1]);
  semantic and article-fit weight 0 until their tracks approve. Sample validator
  500 nodes. Engine registration remains implementation outside this track.*
  *Link: [./tracks/frequency_semantic_ranking_layer_20260611/](./tracks/frequency_semantic_ranking_layer_20260611/)*
  *Coordination: [lexical_coverage_enrichment_20260610](./tracks/lexical_coverage_enrichment_20260610/) produces frequency metadata. This track does not select the source or create frequency edges.*

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
