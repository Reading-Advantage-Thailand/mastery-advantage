# Tech Debt Registry

> Curated working memory. Keep at or below 50 lines.

| Date | Track | Item | Severity | Status | Notes |
|---|---|---|---|---|---|
| 2026-06-10 | lexical_graph_core_release | PDF topic membership extraction uses section-text matching | Medium | Open | Replace or verify with column-aware extraction and reviewed samples. |
| 2026-06-10 | lexical_graph_core_release | Current lexical identity is form plus part-of-speech, not reviewed sense-level identity | High | Open | Resolve before application adoption where polysemy affects mastery or article matching. |
| 2026-06-10 | lexical_coverage_enrichment | B2 exam list unavailable | Medium | Open | Use Vocabulary in Use/other documented sources; do not imply FCE source coverage. |
| 2026-06-10 | lexical_graph_core_release | No calibrated frequency, semantic, or article-ranking layers | High | Open | Address in independently gated follow-on tracks. |
| 2026-06-10 | lexical_graph_core_release | Current lexical IDs can gain numeric collision suffixes and lack an accepted merge/split migration policy | High | Open | Resolve in the core release before app adoption. |
| 2026-06-10 | lexical_recommendation_contract | Matched-token-only article coverage can hide unmatched difficult vocabulary | High | Open | Use explicit unmatched-token classification and eligible-token denominators. |
