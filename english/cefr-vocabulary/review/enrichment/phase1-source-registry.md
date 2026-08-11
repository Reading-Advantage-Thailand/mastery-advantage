# Lexical Coverage Enrichment — Phase 1 Source Registry

**Status:** Draft for enrichment track Phase 1.  
**Generated:** 2026-08-11  
**Core pin:** YLE 2025 freeze (`RELEASE-YLE-2025.md`, dual go 2026-08-11).

## 1. Included / Candidate Sources

### 1.1 Cambridge YLE 2025 (core — already frozen)

| Field | Value |
|---|---|
| Source ID | `cambridge-yle-word-list-2025` |
| Local file | `source-pdfs/cambridge-yle-word-list-2025.pdf` |
| SHA-256 | `6f7a0ad1e277bd10ae8b3bcccfb76c058f611a607c6c9947601abbd7e16a99fa` |
| Scope | Starters / Movers / Flyers alphabetical + thematic (frozen); grammatical lists optional enrichment |
| Permitted use | Official published list; parser stores locations only, no bulk republication of headwords in fixtures |
| Cache policy | Hash-pinned local PDF; regenerate audits from pin |
| Layer | Core freeze (not re-opened); optional `enrichment.cambridge.grammatical-groups` |

### 1.2 Cambridge A2 Key 2025

| Field | Value |
|---|---|
| Source ID | `cambridge-a2-key-vocabulary-list-2025` |
| Local file | `source-pdfs/cambridge-a2-key-vocabulary-list-2025.pdf` |
| SHA-256 | `2abe174d067cd17ffa061cfc4bbbc0e5a55185ac696a5ef8ba49372c753a3ad6` |
| Official URL | https://www.cambridgeenglish.org/images/506886-a2-key-2020-vocabulary-list.pdf |
| Scope | A2 Key / Key for Schools preparation list; method-later for full freeze; enrichment may extract appendix/groups |
| Permitted use | Official published list; same non-republication discipline as YLE audits |
| Cache policy | Hash-pinned local PDF |
| Layer | `enrichment.cambridge.a2-key-appendix` |

### 1.3 Cambridge B1 Preliminary 2025

| Field | Value |
|---|---|
| Source ID | `cambridge-b1-preliminary-vocabulary-list-2025` |
| Local file | `source-pdfs/cambridge-b1-preliminary-vocabulary-list-2025.pdf` |
| SHA-256 | `df5e3c31bb26205c2cfc2e7a94a0171d4f4769d5c1e42a3615fe6aa1b5fdab29` |
| Official URL | https://www.cambridgeenglish.org/Images/506887-b1-preliminary-vocabulary-list.pdf |
| Scope | B1 Preliminary preparation list; not an exhaustive CEFR B1 inventory |
| Permitted use | Official published list; non-republication discipline |
| Cache policy | Hash-pinned local PDF |
| Layer | `enrichment.cambridge.b1-preliminary-appendix` |

### 1.4 Vocabulary in Use (frontmatter + index)

| Band | Source ID prefix | Local frontmatter | Local index |
|---|---|---|---|
| Elementary (A2) | `vocabulary-in-use-elementary` | `vocabulary-in-use-elementary-frontmatter.pdf` | `vocabulary-in-use-elementary-index.pdf` |
| Pre-int / Intermediate (B1) | `vocabulary-in-use-pre-intermediate` | `…-pre-intermediate-frontmatter.pdf` | `…-pre-intermediate-index.pdf` |
| Upper-intermediate (B2) | `vocabulary-in-use-upper-intermediate` | `…-upper-intermediate-frontmatter.pdf` | `…-upper-intermediate-index.pdf` |
| Advanced (C1–C2) | `vocabulary-in-use-advanced` | `…-advanced-frontmatter.pdf` | `…-advanced-index.pdf` |

| Field | Value |
|---|---|
| Official URLs | See `SOURCES.md` § English Vocabulary In Use |
| Scope | Unit titles + index lemma → unit number; pedagogical groups and B2+ coverage |
| Permitted use | Published frontmatter/index PDFs; extract unit/index structure; do not commit full expressive lemma dumps as free-standing wordlists without review |
| Cache policy | Local PDFs under `source-pdfs/`; record SHA-256 in `source-pdfs/SHA256SUMS` |
| Layer | `enrichment.viu.unit-groups` |
| Ordering rule | `unitNumber` is loose ranking metadata only — **never** `prerequisite_for` |

### 1.5 Frequency — wordfreq (selected candidate)

| Field | Value |
|---|---|
| Source ID | `wordfreq` |
| Distribution | PyPI `wordfreq`; pin package version at implementation |
| Scope | Zipf estimates for single words; MWE policy TBD (document missing for multiword if unsupported) |
| Permitted use | Library license (see package); store versioned metadata only |
| Cache policy | Pin `wordfreq` version + computation date in metadata |
| Layer | `enrichment.frequency.wordfreq` |
| Non-goals | Frequency is not an edge; not a mastery order |

## 2. Excluded Or Unavailable Sources

| Source | Decision | Rationale |
|---|---|---|
| Cambridge B2 First official vocabulary list | **Unavailable** | Cambridge states B2+ exams lack particular vocabulary lists (`cambridge-b2-first-information-for-candidates.pdf`) |
| English Vocabulary Profile bulk dump | **Excluded until licensed** | Requires confirmed company-use/redistribution rights (`englishprofile@cambridge.org`); sense-level track may use later |
| Fabricated B2 wordlists without provenance | **Rejected** | Violates source-backed enrichment rule |

## 3. Checksum And Cache Policy (summary)

1. Prefer hash-pinned local PDFs under `source-pdfs/`.
2. `./download-sources.sh` + `source-pdfs/SHA256SUMS` is the verification path.
3. Audit generators must derive denominators from pinned sources, not from draft
   inventory counts (YLE Phase 2 lesson).
4. Enrichment release artifacts must record source id + SHA-256 or package version.

## 4. Acceptance For Phase 1

Owners accept:

- included candidate set and exclusions above;
- layer IDs and isolation from the frozen core;
- no automatic `prerequisite_for` from any listed source.
