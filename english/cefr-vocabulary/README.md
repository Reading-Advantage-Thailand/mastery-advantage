# CEFR Vocabulary Graph Research

This directory contains an English vocabulary knowledge graph aligned to CEFR
and the Cambridge English Qualifications used by Advantage apps.

## Target Exam Alignment

| Cambridge qualification | Current name | CEFR | Published official vocabulary list |
|---|---|---:|---|
| YLE Starters | Pre A1 Starters | Pre-A1 | Yes |
| YLE Movers | A1 Movers | A1 | Yes |
| YLE Flyers | A2 Flyers | A2 | Yes |
| KET for Schools | A2 Key for Schools | A2 | Yes |
| PET for Schools | B1 Preliminary for Schools | B1 | Yes |
| FCE for Schools | B2 First for Schools | B2 | No |

Cambridge publishes Starters, Movers, and Flyers in one cumulative wordlist.
The A2 Key and B1 Preliminary lists each cover both the standard exam and the
For Schools variant. Cambridge explicitly states that exams at B2 and above do
not have particular vocabulary lists.

## Source Documents

Exact source URLs, retrieval metadata, and local checksums are recorded in
[`SOURCES.md`](SOURCES.md).

The downloaded PDFs are kept in `source-pdfs/` for local research and are
ignored by Git. They are copyrighted Cambridge University Press & Assessment
materials and should not be redistributed from this repository without
permission.

To refresh the local source cache:

```bash
./download-sources.sh
```

## Generated Graph

The generated graph currently contains:

- 3,752 lexical `skill` nodes;
- explicit CEFR and Cambridge exam alignments;
- 68 source-backed Cambridge thematic topic groups;
- same-form part-of-speech support edges;
- component-word support edges for multi-word expressions;
- no inferred vocabulary prerequisite edges.

See [`GRAPH-DESIGN.md`](GRAPH-DESIGN.md) for the model and article
recommendation contract.

Generate and validate:

```bash
node scripts/generate-vocabulary-graph.js
node scripts/validate-vocabulary-graph.js
```

Generated tracked artifacts:

- `data/cambridge-vocabulary-inventory.json`
- `cefr-vocabulary-knowledge-space.json`

## CEFR Versus English Vocabulary

CEFR itself is language-independent and does not define a canonical English
vocabulary list. The Council of Europe describes language-specific Reference
Level Descriptions (RLDs) as the resources that identify words, grammar, and
other forms associated with each CEFR level.

## Broader English Vocabulary Source

The Cambridge English Vocabulary Profile (EVP) remains a useful source for
extending this graph beyond exam lists and improving sense-level distinctions.
It is the English RLD vocabulary resource and assigns CEFR levels to individual
meanings of words and phrases rather than only to headwords.

The EVP is available as an online lookup resource, but its data is not included
here. Cambridge directs users seeking the underlying data to contact
`englishprofile@cambridge.org`. Company use and redistribution rights should be
confirmed before importing EVP data into a production graph.

## Graph Design Implications

- Model a lexical **sense**, not only a spelling, as the assessable vocabulary
  unit. The same word can have meanings at different CEFR levels.
- Preserve exam alignment separately from CEFR alignment. A word can appear in
  both the cumulative YLE list and the A2 Key list for different audiences.
- Treat YLE levels as cumulative: Movers candidates also need Starters words,
  and Flyers candidates also need Starters and Movers words.
- Treat the published A2 Key and B1 Preliminary lists as preparation guides,
  not exhaustive definitions of CEFR vocabulary.
- Use a non-Cambridge source or a licensed EVP dataset to fill the B2 gap.
