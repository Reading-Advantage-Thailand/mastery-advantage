# Implementation Plan: English Lexical Semantic Enrichment

> **Intent:** Typed WordNet-style relations as independently gated optional
> layers. Never `prerequisite_for`.

## Phase 1: Semantic Contract And Source Selection

- [x] All Phase 1 tasks — **go** (`phase1-semantic-approval.md`)

## Phase 2: Tests And Fixtures

- [x] Task: Build sense and relation fixtures
  - [x] Cover polysemy, POS differences, MWEs, variants, and ambiguous matches
- [x] Task: Build semantic contract and quarantine tests
- [x] Task: Build deterministic candidate and review-replay tests
- [x] Task: Build layer-isolation consumer fixtures
- [x] Task: Verify Phase 2

**Evidence:** `fixtures/enrichment/semantic-relation-fixtures.json`,
`semantic-wordnet-structure.json`; harness `tests/enrichment_semantic_wordnet.sh`.

## Phase 3: Typed Source-Backed Relations

- [x] Task: Implement sense-aware WordNet candidate generation
- [x] Task: Implement risk-based semantic review queues
- [x] Task: Review and calibrate each WordNet relation type — human-gate
  - [x] Technical fidelity review (deterministic NLTK) of all 1191 candidates
  - [x] Incorrect CEFR-fitness subagent review archived under pedagogical-mistaken/
- [x] Task: Promote, quarantine, or reject each relation type independently — human-gate
  - [x] Accept overlay from **technical** review; reject/uncertain queues filled
  - [ ] Curriculum dual-go for teaching fitness / ranking weight > 0 (owner job)

**Green evidence (2026-08-11):**

- Builder: `scripts/build-wordnet-semantic.py` (NLTK WordNet 3.1)
- Draft overlay: `overlays/semantic-wordnet.overlay.json` — 1191 candidates
- Policy: unique synset only; ambiguous lemmas queued separately (2478)
- **Technical review (authoritative):** accept **996** (83.6%), uncertain **185**
  (skill POS ≠ sense POS), reject **10** (relation/lemma failures)
- Accepted overlay: `overlays/semantic-wordnet-accepted.overlay.json`
- README: `review/enrichment/semantic-edge-review/README.md`
- Report: `reports/enrichment/semantic-edge-review.md` (technical)
- Prior CEFR-fitness batch review was **wrong process** and must not be cited as
  error rate for WordNet edges
- Ranking semantic weight still 0 until product/curriculum go

## Phase 4: Optional Experimental Relations

- [ ] Embedding / broad relatedness (deferred)

## Phase 5: Release Decision

- [ ] Per-relation approve/quarantine/reject after human precision review

## Completion Rule

Layers are independent. Draft candidates do not auto-approve relation layers.
Ranking semantic weight stays 0 until at least one relation layer is approved.
