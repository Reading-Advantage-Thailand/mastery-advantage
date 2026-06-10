# Implementation Plan: English Lexical Semantic Enrichment

## Phase 1: Semantic Contract And Source Selection

- [ ] Task: Define vocabulary semantic relation contract
  - [ ] Define explicit relation kinds and directionality
  - [ ] Define graph-edge representation and consumer filtering
  - [ ] Define sense, provenance, model, score, confidence, and review fields
- [ ] Task: Evaluate and approve candidate sources
  - [ ] Assess license, coverage, versioning, reproducibility, and artifact size
  - [ ] Select the first WordNet-compatible source
- [ ] Task: Define per-relation review samples and precision thresholds
- [ ] Task: Complete Phase 1 semantic-contract review gate

## Phase 2: Tests And Fixtures

- [ ] Task: Build sense and relation fixtures
  - [ ] Cover polysemy, POS differences, MWEs, variants, and ambiguous matches
- [ ] Task: Build semantic contract and quarantine tests
- [ ] Task: Build deterministic candidate and review-replay tests
- [ ] Task: Build layer-isolation consumer fixtures
- [ ] Task: Verify Phase 2

## Phase 3: Typed Source-Backed Relations

- [ ] Task: Implement sense-aware WordNet candidate generation
- [ ] Task: Implement risk-based semantic review queues
- [ ] Task: Review and calibrate each WordNet relation type
- [ ] Task: Promote, quarantine, or reject each relation type independently

## Phase 4: Optional Experimental Relations

- [ ] Task: Evaluate sparse embedding similarity candidates
- [ ] Task: Evaluate broad semantic-relatedness candidates
- [ ] Task: Compare experiments with approved source-backed relations and groups
- [ ] Task: Promote, quarantine, or reject each experimental layer

## Phase 5: Release Decision

- [ ] Task: Run deterministic generation and semantic validation
- [ ] Task: Produce semantic-layer quality report and consumption guide
- [ ] Task: Reconcile acceptance criteria and open debt
- [ ] Task: Record explicit decision per relation layer

## Completion Rule

WordNet, embedding, and broad-relatedness layers are independent. Failure or
rejection of one does not block accepted semantic layers or the core graph.
