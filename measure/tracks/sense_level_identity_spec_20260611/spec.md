# Sense-Level Lexical Identity Specification

## Problem

Current lexical identity in the English CEFR graph is **form + part-of-speech only**. This collapses distinct senses (e.g., "bank" as noun/financial vs noun/river) into a single node, which breaks:

- Accurate mastery tracking when polysemy affects skill claims
- Article recommendation precision when target-word exposure should be sense-aware
- Pedagogical grouping when thematic units rely on sense, not form

## Goal

Produce a reviewed, source-backed specification for sense-level lexical identity that the graph generation pipeline can adopt without breaking existing consumers.

## Acceptance Criteria

1. A `SENSE_IDENTITY_SPEC.md` document defines:
   - When sense-level identity is required vs form+POS sufficient
   - Sense inventory sources (e.g., WordNet synsets, Cambridge sense blocks)
   - Provenance format for sense claims
   - Migration path from current form+POS nodes
2. A sample set of 50 polysemous high-frequency words is manually reviewed and documented.
3. The specification is reviewed against `SPECIFICATION.md` for compatibility.
4. Generator pseudo-code shows how sense identity would be produced from current PDF extraction.
5. No breaking changes to existing JSON artifact schema until a follow-up track.
