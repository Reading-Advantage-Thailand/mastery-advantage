# Implementation Plan: English Lexical Semantic Enrichment

> **Intent:** Typed WordNet-style relations as independently gated optional
> layers. Never `prerequisite_for`. Form+POS identity retained until the
> sense-identity track splits skills.
>
> **Coordination:** Ranking provider keeps semantic weight 0 until at least
> one relation layer is approved (`RANKING_LAYER_SPEC.md`).

## Phase 1: Semantic Contract And Source Selection

- [x] Task: Define vocabulary semantic relation contract
  - [x] Define explicit relation kinds and directionality
  - [x] Define graph-edge representation and consumer filtering
  - [x] Define sense, provenance, model, score, confidence, and review fields
- [x] Task: Evaluate and approve candidate sources
  - [x] Assess license, coverage, versioning, reproducibility, and artifact size
  - [x] Select the first WordNet-compatible source
- [x] Task: Define per-relation review samples and precision thresholds
- [x] Task: Complete Phase 1 semantic-contract review gate — human-gate:both-owners
  - [x] Accept contract and WordNet source selection — human-gate:both-owners

**Green evidence (2026-08-11):**

- `english/cefr-vocabulary/review/enrichment/phase1-semantic-contract.md`
- `english/cefr-vocabulary/review/enrichment/phase1-semantic-sources.md`
- **Decision: go** — `phase1-semantic-approval.md` (both-owners, 2026-08-11)
- Harness: `bash tests/enrichment_semantic_p1.sh`
- First source: Princeton WordNet 3.1 offline; embeddings/ConceptNet deferred

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
