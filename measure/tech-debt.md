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
| 2026-08-11 | lexical_graph_core_release | `tests/yle_p1_scope.sh` and `tests/yle_p1_a4_guard.sh` require `rg` with no availability check | Medium | Open | `rg` is absent on this machine, so both harnesses fail with "command not found" and silently report `Completed Phase 1 tasks: 0`. Replace with `grep -c` or gate on `command -v rg`. |
| 2026-08-11 | lexical_graph_core_release | Sense identity is carried as publisher gloss text inside `lexicalForm`/`sourceNormalizedForm` | High | Open | 85 YLE skills now key identity on strings like `catch (e.g. a ball)`. Works, but it embeds publisher wording in the graph and makes identity brittle. Resolve with [sense_level_identity_spec_20260611](./tracks/sense_level_identity_spec_20260611/). |
| 2026-07-07 | kst_srs_core_correctness | kst-srs.v3/v3.1/v3.2 decisions self-approved under owner directive without human curriculum review | Medium | Open | Ratify before app adoption: H seeding constants, trendThreshold, backlog policy (v3); retention targets, hint/reveal caps, recency half-life, tercile banding (v3.1); planner weights, 0.7/0.3 sparse split, diversity cap, loadBudgetFactor, fuzz range (v3.2). |
