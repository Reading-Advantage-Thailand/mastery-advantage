# Lessons Learned

> Curated working memory. Keep at or below 50 lines.

## Architecture And Design

- (2026-06-10, lexical_graph_preimplementation) Vocabulary frequency, CEFR
  level, book unit order, semantic similarity, and thematic relatedness are
  ranking/grouping signals; none automatically establish prerequisites.
- (2026-06-10, lexical_graph_preimplementation) Semantic similarity and
  semantic relatedness are distinct. Persist typed relations and source/model
  provenance instead of collapsing both into generic similarity.

## Recurring Gotchas

- (2026-06-10, lexical_graph_preimplementation) PDF layout extraction can
  mistake example sentences and headings for lexical entries. Generated
  inventories require explicit suspicious-entry tests and human samples.
- (2026-06-10, lexical_graph_preimplementation) Topic-section text matching can
  falsely include function words from headings and can overrun the last group
  when all section boundaries are not enumerated.

## Patterns That Worked Well

- (2026-06-10, lexical_graph_preimplementation) Keep publisher PDFs in a
  reproducible Git-ignored cache while tracking source URLs, checksums,
  generators, inventories, and provenance.
- (2026-06-10, lexical_graph_preimplementation) Represent source-backed themes
  as group nodes with membership edges rather than dense pairwise word edges.
