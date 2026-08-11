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
- [ ] Task: Review and calibrate each WordNet relation type — human-gate
- [ ] Task: Promote, quarantine, or reject each relation type independently — human-gate

**Green evidence (2026-08-11):**

- Builder: `scripts/build-wordnet-semantic.py` (NLTK WordNet 3.1 via `uv run --with nltk`)
- Overlay: `overlays/semantic-wordnet.overlay.json` — draft candidates
- Policy: unique synset only; ambiguous → `semantic-ambiguous.jsonl`; no skills created
- Counts (build): ~3214 single-token skills considered; ~636 unique-sense mapped;
  ~2478 ambiguous quarantined; ~1191 candidate edges across 6 relations
- Report: `reports/enrichment/semantic-wordnet.{json,md}`
- Harness: `bash tests/enrichment_semantic_wordnet.sh`
- Status: **draft candidates** — per-relation precision review still open

## Phase 4: Optional Experimental Relations

- [ ] Embedding / broad relatedness (deferred)

## Phase 5: Release Decision

- [ ] Per-relation approve/quarantine/reject after human precision review

## Completion Rule

Layers are independent. Draft candidates do not auto-approve relation layers.
Ranking semantic weight stays 0 until at least one relation layer is approved.
