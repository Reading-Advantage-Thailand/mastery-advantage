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

- (2026-06-10, lexical_graph_core_release) PDF extraction both invents entries
  (example sentences, headings) and drops real ones — `-layout` silently loses
  cells whose POS wraps to the next line. Require suspicious-entry tests, human
  samples, and a cross-check against a second independent list in the document.
- (2026-06-10, lexical_graph_core_release) Topic-section text matching can
  falsely include function words from headings and can overrun the last group
  when all section boundaries are not enumerated.
- (2026-08-11, lexical_graph_core_release) A generator that asserts its parse
  against a stored draft count validates nothing: the count came from the same
  parser. Derive the denominator from the source on every run, or the audit
  reports perfect recall over the rows it already dropped.
- (2026-08-11, lexical_semantic_enrichment) A phase harness can read the plan
  document itself. Compressing a completed phase section to one summary line
  removed the evidence path the harness greps for, so an approved Phase 1 gate
  failed while every artifact still existed. Keep the evidence pointers when
  you shorten a phase section, or the harness reports a false red.
- (2026-08-11, lexical_recommendation_contract) A judgments file that the
  harness only reads back is not evidence. `recommendation_phase45.sh` checked
  that 9 rows said "pass" without recomputing one verdict, so the record was
  checked against itself. Re-derive each verdict from the fixtures, then compare
  the record to the computed result.
- (2026-08-11, lexical_recommendation_contract) A review checklist bounds what a
  review can find. The 9 Phase 4 cases all passed while 44% of unmatched spans
  were inflections of listed lemmas, because no checklist row tested inflection
  handling. Ask what the checklist omits before trusting a clean pass.
- (2026-08-11, lexical_graph_core_release) A lookahead consumes no text, so
  `^## Phase 1:.*?(?=^## Phase 2:).*\[x\]` keeps scanning past Phase 2 and
  reports markers from every later phase. The A4 guard passed only while the
  later phases held no completed task. Slice the section first, then search
  the slice.
- (2026-08-11, lexical_coverage_enrichment) An audit that scans a shared
  directory is not isolated from other tracks. The coverage Phase 4 audit
  counts every file in `review/enrichment/queues/`, so the later semantic
  track added 2478 ambiguous rows to an approved coverage report on the next
  run. Scope each audit to its own layer IDs, not to a directory listing.

## Patterns That Worked Well

- (2026-06-10, lexical_graph_core_release) Keep publisher PDFs in a
  reproducible Git-ignored cache while tracking source URLs, checksums,
  generators, inventories, and provenance.
- (2026-06-10, lexical_graph_core_release) Represent source-backed themes
  as group nodes with membership edges rather than dense pairwise word edges.
