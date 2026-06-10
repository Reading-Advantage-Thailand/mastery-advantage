# B2 Vocabulary Source Expansion

## Problem

The Cambridge FCE (B2) exam vocabulary list is unavailable. The current graph only covers A1–B1 plus a partial B2 set. This leaves a gap for:

- Upper-intermediate learners using Reading Advantage and Primary Advantage
- Article recommendation systems that rely on bounded unknown-word exposure
- SRS decks targeting B2 readiness

## Goal

Close the B2 vocabulary gap using documented, license-compatible alternative sources without claiming false Cambridge FCE coverage.

## Acceptance Criteria

1. A `B2_SOURCES.md` document catalogs:
   - Evaluated sources (Vocabulary in Use Upper-Intermediate, Oxford 3000 extended, etc.)
   - Coverage overlap with A1–B1
   - Licensing and redistribution constraints
   - Source URLs, versions, and checksums
2. A generated `b2_inventory.json` contains B2 lexical nodes with the same schema as A1–B1.
3. All B2 nodes include provenance pointing to the specific source page/section, not "Cambridge FCE".
4. A coverage report shows % overlap with A1–B1 and identifies truly new B2 entries.
5. Graph validation passes (no duplicate node IDs, all edges have provenance).
