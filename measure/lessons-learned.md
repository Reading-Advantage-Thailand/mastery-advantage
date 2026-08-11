# Lessons Learned

> Curated working memory. Keep at or below 50 lines.

## Architecture And Design

- (2026-06-10, lexical_graph_core_release) Frequency, level, unit order, and
  similarity are ranking signals; none establishes a prerequisite. Persist typed
  relations with provenance, not generic similarity.
- (2026-07-07, kst_srs_core_correctness) Weighted averages cannot express hard
  prerequisites — non-compensatory requirements need min/product forms. Keep
  compensatory averaging only for genuinely soft signals.
- (2026-07-07, kst_srs_core_correctness) Bayesian calibration must condition on
  observations that actually test the hypothesis (¬A rows for edge necessity);
  confirming-but-uninformative cells manufacture false certainty.
- (2026-07-07, kst_srs_calibration_evidence) Raw correctness rates are not
  evidence: correct guess floors, bound with Wilson limits, recency-weight.
  Fitted artifacts ship through human review, never auto-applied.
- (2026-07-07, kst_srs_planner_domain_utility) Normalize all terms to one scale
  before weighting; domain signals enter the engine only through a
  provenance-carrying provider contract, never as synthetic graph structure.
- (2026-08-11, lexical_recommendation_contract) A lemma is not one teaching
  unit. `be` spans pre-A1 (`is`) to about B2 (`had been`), so lemmatizing onto
  the headword moves a token four CEFR bands. Confirm the source lists inflected
  forms before adding lemmatization.

## Recurring Gotchas

- (2026-08-11, all tracks) Evidence that consults itself proves nothing: a
  generator validated its parse against its own parser's count; a harness read
  back a judgments file. Derive denominators and verdicts from the source.
- (2026-08-11, all tracks) A harness that parses a document breaks on edits far
  from the assertion: compressing a phase deleted an evidence path a gate
  grepped for; a zero-width lookahead let `.*` scan past its section.
- (2026-08-11, lexical_recommendation_contract) A checklist bounds what a review
  finds. All 9 Phase 4 cases passed while 44% of unmatched spans were inflections
  of listed lemmas, untested. Ask what a checklist omits before trusting it.
- (2026-08-11, lexical_coverage_enrichment) An audit that globs a shared
  directory is not isolated: a later track added 2478 queue rows to an approved
  coverage report. Scope audits to their own layer IDs.
- (2026-06-10, lexical_graph_core_release) PDF extraction invents entries and
  drops real ones — `-layout` loses cells whose POS wraps. Require
  suspicious-entry tests, samples, and a cross-check against a second list.

## Patterns That Worked Well

- (2026-06-10, lexical_graph_core_release) Keep publisher sources in a
  Git-ignored cache while tracking URLs, checksums, generators, and provenance.
- (2026-06-10, lexical_graph_core_release) Represent source-backed themes as
  group nodes with membership edges, not dense pairwise word edges.
