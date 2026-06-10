# Plan — Sense-Level Lexical Identity Specification

## Phase 1: Audit Current Identity Collisions
- [ ] Task 1.1: Generate list of top 200 polysemous forms in current graph (frequency > 1000, POS count >= 2 or known homonymy)
- [ ] Task 1.2: Sample 50 collisions and document their current grouping in `samples/sense_collisions.md`
- [ ] Task 1.3: Write characterization tests showing how current `computeNodeId(form, pos)` collapses senses

## Phase 2: Sense Inventory Research
- [ ] Task 2.1: Evaluate WordNet 3.1 synset coverage against the 50-sample set
- [ ] Task 2.2: Evaluate Cambridge dictionary sense blocks against the same set
- [ ] Task 2.3: Document licensing, reproducibility, and versioning constraints for each candidate source
- [ ] Task 2.4: Select primary and fallback sense inventory sources with justification

## Phase 3: Specification Draft
- [ ] Task 3.1: Write `SENSE_IDENTITY_SPEC.md` covering identity rules, provenance, migration path
- [ ] Task 3.2: Define sense-node schema extension (additive only, no breaking changes)
- [ ] Task 3.3: Review spec against `SPECIFICATION.md` and record gaps
- [ ] Task 3.4: Update `tech-debt.md` — mark sense-identity item as "spec ready, implementation deferred"

## Phase 4: Validation
- [ ] Task 4.1: Walk the 50-sample set through the proposed identity rules
- [ ] Task 4.2: Verify no existing consumer (Reading Advantage, Primary Advantage) breaks under additive schema
- [ ] Task 4.3: Commit, push, and close track
