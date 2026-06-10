# Frequency, Semantic and Article-Ranking Layer Design

## Problem

The current lexical graph lacks calibrated ranking signals:

- No corpus frequency layer for difficulty estimation or known-word coverage
- No semantic similarity / relatedness layer for grouping or recommendation
- No article-ranking layer to match articles to learner vocabulary profiles

These gaps block application teams from implementing adaptive difficulty, smart grouping, and extensive-reading recommendations.

## Goal

Design reproducible, source-backed ranking layers that attach to existing lexical nodes without breaking current contracts.

## Acceptance Criteria

1. A `RANKING_LAYER_SPEC.md` document defines:
   - Frequency layer: source corpus, tokenization rules, lemmatization policy, normalization
   - Semantic layer: similarity vs relatedness distinction, edge types, provenance, confidence
   - Article-ranking layer: known-word coverage formula, target-word exposure bounds, ranking score
2. Each layer has a JSON schema extension that is additive to existing node/edge schema.
3. A sample dataset of 500 nodes has frequency + semantic edges populated from a documented source.
4. A proof-of-concept article-ranking function scores 10 sample articles against 3 synthetic learner profiles.
5. All layers document their update cadence and reproducibility requirements.
