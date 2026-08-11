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
  - [x] Subagent batch review: 12 × ≤100 edges (all 1191 candidates)
- [x] Task: Promote, quarantine, or reject each relation type independently — human-gate
  - [x] Accept overlay built; reject/uncertain queues filled
  - [ ] Optional: curriculum dual-go to raise ranking semantic weight > 0

**Green evidence (2026-08-11):**

- Builder: `scripts/build-wordnet-semantic.py` (NLTK WordNet 3.1 via `uv run --with nltk`)
- Draft overlay: `overlays/semantic-wordnet.overlay.json` — 1191 candidates
- Policy: unique synset only; ambiguous → `semantic-ambiguous.jsonl`; no skills created
- Counts (build): ~3214 single-token skills considered; ~636 unique-sense mapped;
  ~2478 ambiguous quarantined; ~1191 candidate edges across 6 relations
- **Batch review (12 subagents × 100):** accept **696** (58.4%), reject **439**,
  uncertain **56** — `review/enrichment/semantic-edge-review/`
- Accepted overlay: `overlays/semantic-wordnet-accepted.overlay.json`
- Accept rates by relation: antonym 94%, hypernym 68%, synonym 60%, meronym 62%,
  holonym 61%, hyponym 43%
- Report: `reports/enrichment/semantic-edge-review.md`
- Harness: `bash tests/enrichment_semantic_wordnet.sh`
- Status: **reviewed candidates**; ranking semantic weight still 0 until product go

## Phase 4: Optional Experimental Relations

- [ ] Embedding / broad relatedness (deferred)

## Phase 5: Release Decision

- [ ] Per-relation approve/quarantine/reject after human precision review

## Completion Rule

Layers are independent. Draft candidates do not auto-approve relation layers.
Ranking semantic weight stays 0 until at least one relation layer is approved.
