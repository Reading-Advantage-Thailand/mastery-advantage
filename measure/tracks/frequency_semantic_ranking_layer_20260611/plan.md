# Plan — Frequency, Semantic and Article-Ranking Layer Design

## Phase 1: Frequency Layer Design
- [ ] Task 1.1: Evaluate `wordfreq` and SUBTLEXus for corpus coverage and licensing
- [ ] Task 1.2: Define tokenization/lemmatization policy (match graph node identity rules)
- [ ] Task 1.3: Design `frequency` edge schema with source, version, rank, zipf_score
- [ ] Task 1.4: Produce sample `frequency_edges.json` for 500 nodes

## Phase 2: Semantic Layer Design
- [ ] Task 2.1: Evaluate fastText embeddings vs WordNet path similarity for coverage/cost
- [ ] Task 2.2: Define semantic edge types: `similar_to`, `related_to`, `thematic_group`
- [ ] Task 2.3: Design provenance schema: model, version, derivation_method, confidence, review_status
- [ ] Task 2.4: Produce sample `semantic_edges.json` for 500 nodes

## Phase 3: Article-Ranking Layer Design
- [ ] Task 3.1: Define known-word coverage formula (% tokens whose lemma+POS is in learner profile)
- [ ] Task 3.2: Define target-word exposure bounds (min 3, max 15 new words per 300-word article)
- [ ] Task 3.3: Write proof-of-concept ranking function in `scripts/rank_article.ts`
- [ ] Task 3.4: Validate against 10 articles × 3 synthetic profiles; document edge cases

## Phase 4: Specification & Validation
- [ ] Task 4.1: Write `RANKING_LAYER_SPEC.md` integrating all three layers
- [ ] Task 4.2: Verify additive schema against `SPECIFICATION.md`
- [ ] Task 4.3: Update `tech-debt.md` — mark ranking-layer item as "spec ready, implementation deferred"
- [ ] Task 4.4: Commit, push, and archive track
