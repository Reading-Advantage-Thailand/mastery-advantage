# Lessons Learned

> Curated working memory. Keep at or below 50 lines.

## Architecture And Design

- (2026-06-10, lexical_graph_core_release) Vocabulary frequency, CEFR
  level, book unit order, semantic similarity, and thematic relatedness are
  ranking/grouping signals; none automatically establish prerequisites.
- (2026-06-10, lexical_graph_core_release) Semantic similarity and
  semantic relatedness are distinct. Persist typed relations and source/model
  provenance instead of collapsing both into generic similarity.

- (2026-07-07, kst_srs_core_correctness) Weighted averages cannot express
  hard prerequisites — non-compensatory requirements need min/product forms.
  Keep compensatory averaging only for genuinely soft signals.
- (2026-07-07, kst_srs_core_correctness) Bayesian calibration must condition
  on the observations that actually test the hypothesis (¬A rows for edge
  necessity); counting confirming-but-uninformative cells manufactures false
  certainty under curriculum sequencing.
- (2026-07-07, kst_srs_calibration_evidence) Raw correctness rates are not
  evidence: correct for guess floors, bound with Wilson lower limits, and
  recency-weight before comparing to thresholds. Fitted/calibrated artifacts
  always ship through a human-reviewed release, never auto-applied.
- (2026-07-07, kst_srs_planner_domain_utility) Composite scores require all
  terms normalized to one scale before weighting; domain ranking signals
  enter the engine only through a provenance-carrying provider contract,
  never as synthetic graph structure.

## Recurring Gotchas

- (2026-06-10, lexical_graph_core_release) PDF layout extraction can
  mistake example sentences and headings for lexical entries. Generated
  inventories require explicit suspicious-entry tests and human samples.
- (2026-06-10, lexical_graph_core_release) Topic-section text matching can
  falsely include function words from headings and can overrun the last group
  when all section boundaries are not enumerated.

## Patterns That Worked Well

- (2026-06-10, lexical_graph_core_release) Keep publisher PDFs in a
  reproducible Git-ignored cache while tracking source URLs, checksums,
  generators, inventories, and provenance.
- (2026-06-10, lexical_graph_core_release) Represent source-backed themes
  as group nodes with membership edges rather than dense pairwise word edges.
