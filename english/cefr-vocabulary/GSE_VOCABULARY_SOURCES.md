# Official GSE Vocabulary Sources

> Retrieved from the Pearson GSE Teacher Toolkit on 2026-08-11.
> Audience: `GL` means Adult Learners in the UI.
> This record covers two pinned vocabulary inventory exports: adult (GL) and young learner (YL).

## Toolkit Source

- UI URL: <https://www.english.com/gse/teacher-toolkit/user/vocabulary?page=1&sort=gse;asc&gseRange=10;67&audience=GL&grammaticalCategories=adjective;adverb;conjunction;determiner;interjection;noun;number;phrasal%20verb;phrase;prefix;preposition;pronoun;verb>
- Coverage: GSE 10–67, 13 grammatical categories, ascending GSE sort, and 11,586 results on 2026-08-11.
- Product version: GSE Teacher Toolkit web application, no version displayed, accessed 2026-08-11.

## API Extraction

- Endpoint: `https://www.english.com/gse/teacher-toolkit/user/api/v1/vocabulary/search`
- Access: Public access, no authentication required, verified 2026-08-11.
- Pagination: `page` with `size=2000`; page count was computed from the `count` field of page 1.
- Query: `query_string=*`.
- Sort: `sort=gse`.

## Pinned Export

| Export date | Local filename | Items | SHA-256 |
|---|---|---:|---|
| 2026-08-11 | `source-pdfs/gse-vocabulary-gl-10-67-2026-08-11.json` | 11,586 | `e63298d796eecc1d9ed68cd5bde28d01912cfe3312a1381d2b074cdbe9b90800` |

The owner's preliminary estimate was 11,568. The live API count on 2026-08-11 is 11,586, and the export matches the live count.

---

## Young Learner (YL) Export

## Toolkit Source

- UI URL: <https://www.english.com/gse/teacher-toolkit/user/vocabulary?page=1&sort=gse;asc&gseRange=10;59&audience=YL&grammaticalCategories=adjective;adverb;conjunction;determiner;interjection;noun;number;phrase;preposition;pronoun;verb>
- Audience: `YL` means Young Learners (6-14) in the UI.
- Coverage: GSE 10–59, 11 grammatical categories (the YL filter set omits `phrasal verb` and `prefix`), ascending GSE sort, and 3,024 results on 2026-08-11.
- Product version: GSE Teacher Toolkit web application, no version displayed, accessed 2026-08-11.

## API Extraction

- Endpoint: `https://www.english.com/gse/teacher-toolkit/user/api/v1/vocabulary/search`
- Access: Public access, no authentication required, verified 2026-08-11.
- Pagination: `page` with `size=2000`; page count was computed from the `count` field of page 1.
- Query: `query_string=*`.
- Sort: `sort=gse`.
- Filters: GSE 10–59, audience `YL`, no topics, and the 11 grammatical categories listed above.

## Pinned Export

| Export date | Local filename | Items | SHA-256 |
|---|---|---:|---|
| 2026-08-11 | `source-pdfs/gse-vocabulary-yl-10-59-2026-08-11.json` | 3,024 | `6b8c895055ea6c24c8f29b9e2999676444ffe3507a61725a9595f6eab784ab30` |

YL items add `expression_bre` and `temporaryGse` fields compared to GL items. YL `cefr` values use the short form, such as `<A1`.

## Licensing

These licensing terms apply to both exports.

Source: [GSE Commercial Use policy](https://www.english.com/gse-commercial).

> If you would like to use the GSE in a non-commercial context – for example in order to plan courses of study, set learning goals or monitor progress – we are delighted that you are interested in the GSE and can't wait for you to start using it. When doing so we kindly ask that you follow our guidelines.

> For the purposes of publications and presentations please include the following copyright notice: The Global Scale of English and its components © Pearson.

> Pearson retains ownership of the GSE (including its components) and we reserve the right to update it at any time, or to refuse or withdraw permission for your use of the GSE (including where we determine the use of it is not in accordance with the above guidelines).

## Redistribution Decision

The policy grants no redistribution right. The raw exports stay Git-ignored under `source-pdfs/`. Only derived identities may be tracked, following the YLE PDF precedent.

**Owner decision 2026-08-11** (track `gse_vocabulary_core_enrichment_20260811`, FR-6 option b): definition and example text from the pinned exports may be committed onto core graph nodes. Owner words: "FR-6 (b) while we are not selling this product and it is only for the purposes they approved -- measuring mastery levels and planning instruction." The use is non-commercial and within the purposes the policy approves: planning courses of study, setting learning goals, and monitoring progress.

## Cache Policy

The raw export files are the local cache. Re-export only on explicit owner instruction because Pearson may update the inventory at any time. The recorded SHA-256 values identify the pinned snapshots.

## Attribution

Derived publications from the exports must carry: `The Global Scale of English and its components © Pearson`.
