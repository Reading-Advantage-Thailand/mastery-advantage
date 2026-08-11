# Semantic WordNet edge review

## Correct review kind

**Technical WordNet fidelity** only:

1. Does `semanticRelation` hold between `sourceSenseId` and `targetSenseId` in WordNet?
2. Are `sourceForm` / `targetForm` lemmas of those synsets?
3. Is skill POS compatible with the sense POS?

Do **not** score CEFR teaching fitness. That is curriculum owner work.

## History

| Path | Kind | Status |
|---|---|---|
| `pedagogical-mistaken/` | CEFR teaching fitness (incorrect process) | Archived — do not use for quality metrics |
| `judgments/` + `technical-deterministic-judgments.jsonl` | Technical fidelity | **Authoritative** (deterministic NLTK verifier) |
| Partial subagent technical re-runs | Technical | Superseded by deterministic verifier for consistency |

## Authoritative results (technical, 2026-08-11)

- Source edges: 1191
- accept: 996 (83.6%)
- uncertain: 185 (POS mismatch skill↔sense)
- reject: 10 (relation/lemma failures)
- Accepted overlay: `overlays/semantic-wordnet-accepted.overlay.json`
