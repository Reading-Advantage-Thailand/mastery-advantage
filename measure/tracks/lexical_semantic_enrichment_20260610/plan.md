# Implementation Plan: English Lexical Semantic Enrichment

> **Intent:** Typed WordNet-style relations as independently gated optional
> layers. Never `prerequisite_for`.

## Phase 1: Semantic Contract And Source Selection

- [x] All Phase 1 tasks — **go** (`phase1-semantic-approval.md`) — commit: df950d1 (contract and sources), f104489 (both-owners go)

**Evidence:** `review/enrichment/phase1-semantic-contract.md`,
`review/enrichment/phase1-semantic-sources.md` (WordNet 3.1 offline);
`review/enrichment/phase1-semantic-approval.md`; harness
`tests/enrichment_semantic_p1.sh`.

## Phase 2: Tests And Fixtures

- [x] Task: Build sense and relation fixtures — commit: 8920998
  - [x] Cover polysemy, POS differences, MWEs, variants, and ambiguous matches
- [x] Task: Build semantic contract and quarantine tests — commit: 8920998
- [x] Task: Build deterministic candidate and review-replay tests — commit: 8920998
- [x] Task: Build layer-isolation consumer fixtures — commit: 8920998
- [x] Task: Verify Phase 2 — commit: 8920998

**Evidence:** `fixtures/enrichment/semantic-relation-fixtures.json`,
`semantic-wordnet-structure.json`; harness `tests/enrichment_semantic_wordnet.sh`.

## Phase 3: Typed Source-Backed Relations

- [x] Task: Implement sense-aware WordNet candidate generation — commit: 8920998
- [x] Task: Implement risk-based semantic review queues — commit: 8920998
- [x] Task: Review and calibrate each WordNet relation type — human-gate — commit: b6413f3
  - [x] Technical fidelity review (deterministic NLTK) of all 1191 candidates — commit: b6413f3
  - [x] Incorrect CEFR-fitness subagent review archived under pedagogical-mistaken/ — commit: 6c3e816 (review), b6413f3 (archived)
- [x] Task: Promote, quarantine, or reject each relation type independently — human-gate — commit: b6413f3
  - [x] Accept overlay from **technical** review; reject/uncertain queues filled — commit: b6413f3
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
