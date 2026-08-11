# Official GSE Grammar Sources

> Retrieved from the Pearson GSE Teacher Toolkit on 2026-08-11.
> This record identifies the pinned grammar inventory export.

## Toolkit Source

- UI URL: <https://www.english.com/gse/teacher-toolkit/user/grammar?page=1&sort=gse;asc&gseRange=10;90&audience=GLGR&grammaticalCategories=Verb;Tags%20and%20question%20forms;Pronoun;Preposition;Phrase;Phrasal%20verb;Number;Noun;Modal%20verb;Determiner;Conjunction;Clause;Adverb;Adjective>
- Audience: `GLGR` means Adult Learners in the UI.
- Coverage: GSE 10–90, all 14 grammatical categories, ascending GSE sort, and 455 results on 2026-08-11.
- Product version: GSE Teacher Toolkit web application, no version displayed, accessed 2026-08-11.

## API Extraction

- Endpoint: `https://www.english.com/gse/teacher-toolkit/user/api/v1/descriptors`
- Resource: `descriptors`
- Pagination: `limit=50` with offsets `0,50,100,...,450` across 10 pages.
- Search mode: `search-v2=true`.
- Sort: `sortBy={"property":"gse","order":"asc","urlParamName":"gse"}`.
- Filters: GSE range 10–90 with empty results hidden, the GLGR Grammar syllabus, and published status.

## Pinned Export

| Export date | Local filename | Items | SHA-256 |
|---|---|---:|---|
| 2026-08-11 | `source-pdfs/gse-grammar-inventory-2026-08-11.json` | 455 | `99c331b8159d59e978ee4ba687a7e15817968ecbcedf9b108376e7555089c348` |

## Licensing

Source: [GSE Commercial Use policy](https://www.english.com/gse-commercial).

> If you would like to use the GSE in a non-commercial context – for example in order to plan courses of study, set learning goals or monitor progress – we are delighted that you are interested in the GSE and can't wait for you to start using it. When doing so we kindly ask that you follow our guidelines.

> For the purposes of publications and presentations please include the following copyright notice: The Global Scale of English and its components © Pearson.

> Pearson retains ownership of the GSE (including its components) and we reserve the right to update it at any time, or to refuse or withdraw permission for your use of the GSE (including where we determine the use of it is not in accordance with the above guidelines).

## Redistribution Decision

The policy grants no redistribution right. The raw export stays Git-ignored under `source-pdfs/`. Only derived identities may be tracked, following the YLE PDF precedent.

## Cache Policy

The raw export file is the local cache. Re-export only on explicit owner instruction because Pearson may update the inventory at any time. The recorded SHA-256 identifies the pinned snapshot.

## Attribution

Derived publications must carry: `The Global Scale of English and its components © Pearson`.
