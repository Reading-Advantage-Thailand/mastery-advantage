# Plan — B2 Vocabulary Source Expansion

## Phase 1: Source Evaluation
- [ ] Task 1.1: Acquire and cache Vocabulary in Use Upper-Intermediate (4th edition) PDF
- [ ] Task 1.2: Acquire and cache Oxford 3000 B2 supplement if available
- [ ] Task 1.3: Document licensing for each source in `B2_SOURCES.md`
- [ ] Task 1.4: Write extraction pseudo-code and validate against 10 sample pages

## Phase 2: Extraction & Inventory Generation
- [ ] Task 2.1: Extract raw B2 candidate list from primary source
- [ ] Task 2.2: Deduplicate against existing A1–B1 graph nodes
- [ ] Task 2.3: Assign CEFR level B2 with provenance (page/section/unit)
- [ ] Task 2.4: Generate `b2_inventory.json` conforming to current node schema

## Phase 3: Validation & Integration
- [ ] Task 3.1: Run graph validator against merged A1–B2 node set
- [ ] Task 3.2: Generate coverage report (% new, % overlap, % ambiguous)
- [ ] Task 3.3: Review 50 random B2 entries for quality
- [ ] Task 3.4: Update `tech-debt.md` — remove B2 unavailability item

## Phase 4: Documentation & Closeout
- [ ] Task 4.1: Update graph README with B2 source provenance
- [ ] Task 4.2: Commit artifacts, inventories, and documentation
- [ ] Task 4.3: Push and archive track
