# Storytime Advantage phonics knowledge space (v1)

Domain `english.phonics`. It holds the phonemic awareness, letters, grapheme-phoneme
correspondences (GPC), patterns, and tricky words of Storytime Advantage Levels 1 to 4
(128 weeks). Status: draft, built by script from the Storytime design track
(`storytime_advantage_program_20261021`, design section 5). Decision S3 sets this location.
v1 fixes the Graph session review of v0.

## Files

| File | Content |
|---|---|
| `phonics-knowledge-space.json` | Nodes and edges. Same shape as `../gse-knowledge-space.json`. Self-contained. |
| `phonics-gse-links.json` | `meta` header and 835 edges from phonics nodes into the GSE Young Learner nodes (25 distinct targets). |
| `storytime-levels.csv` | Level map: level, label, grade, reader_bands, elements, weeks. |
| `sequence.json` | Copy of the 128-week table (level, week, element, phonemic awareness, tricky words) and the Level 1 letter order. |
| `build-phonics-graph.py` | The builder. The data tables are in the script. |

The links are in a second file because a document may not hold an edge to a node outside it.
The links header records the GSE file and commit (`7344a27`) that the targets come from.

## Id patterns

`english.phonics.` followed by: `domain` | `standard.storytime-v1` | `group.level-N` |
`group.pa.<module>` | `phoneme.<slug>` | `gpc.<grapheme>.<phoneme>` | `pattern.<slug>` |
`pa.<module>.<skill>` | `letter.<x>.<name|sound|form-lower|form-upper>` | `tricky.<word>`.
Every GPC id ends with its phoneme slug (`gpc.ee.long-e`, `gpc.x.k-s`, `gpc.th.th-voiced`).
Edge ids come from content: `english.phonics.edge.<type-kebab>.<source-tail>--<target-tail>`.

## Counts

440 nodes: 1 domain, 1 standard, 16 content_group (4 levels, 12 PA modules), 44 phoneme
(concept), 378 skill (80 gpc, 49 pattern, 45 pa, 104 letter, 100 tricky).
1288 edges: 438 contains, 346 prerequisite_for (31 high, 178 medium, 137 low), 82 supports,
422 aligned_to_standard. Link file: 834 supports, 1 equivalent_to.
Every gpc, pattern, pa, letter, tricky, and phoneme node aligns to the standard node.

## Rebuild

    python3 -I english/phonics/build-phonics-graph.py

The script reads `sequence.json` only. It does not import anything from a worktree.
`sequence.json` was generated once from `gen_sequence.py` of the Storytime track at commit
`b55009f2d`. That commit id is in `sequence.json` (`meta.source_sequence_commit`) and in the
domain node metadata. The script writes all four generated files, so the files on disk equal the script output.

## Self-checks (in the build script)

The script re-implements the SPECIFICATION 4 checks in Python and stops on any error. It runs them on the
phonics file alone and on phonics + links + GSE merged: duplicate node and edge ids, dangling edges, duplicate
triples, endpoint pairing, missing alignment, cycles in high and medium edges. It also checks:

- a cycle check that includes the low teaching-order edges (0 cycles);
- every low edge goes from an earlier week to a later week and carries a string sourceRef that names its derivation;
- no medium or high prerequisite edge goes backward in time;
- no low edge is the reverse of a medium or high edge;
- the only `equivalent_to` link is `pa.initial-sound.identify` to the Listening L10.1 node.

## Validate

The TypeScript validator is `@reading-advantage/knowledge-space-core` in the monorepo
(`validateKnowledgeSpace` and `knowledgeSpaceSchema`, built in `dist/`). Run it on the phonics file alone, and on
phonics + links + GSE merged. Result on 2026-10-22: schema pass and 0 errors for both.

## Rules used

- `prerequisite_for` with `confidence: "low"` and `metadata.edgeRole: "teaching-order"` is the pedagogical order
  (design 5.4). It comes only from the week table: in each chain (teaching-order elements, PA skills, Level 1 letter
  sounds) the last node of a week points to the first node of the next week. The sourceRef is the string
  `english.phonics teaching-order-v1: derived from the 128-week table, earlier week -> later week`.
- Medium and high edges are real dependencies only: letter sound before its GPC, a single-letter GPC before a
  grapheme that contains it, short-vowel GPC before the CVC pattern, blending and segmenting before the CVC patterns,
  CVC before rimes, cluster blending before the blend patterns, Thai-contrast skills before the Thai weeks, Level N
  before Level N+1. The PA skills have no medium or high edges between them.
- Level and week come from the 128-week table. Level 3 starts with element 29.

## Tricky words and decodability

A word is decodable at week W when every grapheme-phoneme pair of its parse is taught at or before W. The build parses
each word by greedy longest match over the graph graphemes (default sound = the earliest GPC for the grapheme).
A manual parse table in the script covers irregular words. The open-vowel pattern supplies e, o, y as long vowels,
and the plural -s pattern supplies s = /z/. A tricky node exists only for words that are not decodable at the
introduction week. `metadata.decodable_from_week` is the program week at which the word becomes decodable, or null
when a pair is not in the graph (for example schwa, `ore`, `ere`, wr).

Result: 115 words in the table, 100 tricky nodes kept (65 decodable later, 35 never in v1), 15 dropped.

Decodable high-frequency words (dropped from the tricky nodes, with the introduction program week):
stop (52), went (65), help (69), asks (116), looks (117), am (117), yes (118), or (119), say (119), white (121),
red (121), blue (121), teacher (122), draw (122), sit (122).

## Deferred on purpose

Phonemes without a GPC in v1: /ɪə/ (ear), /ʊə/ (ure), /ʒ/, schwa.

Graphemes not yet in the sequence: c = /s/, g = /dʒ/, y = /aɪ/, y = /iː/, ie = /aɪ/, ear = /ɪə/, tch, dge, ph, kn,
wr, -le.

These belong to the Level 4 exit weeks or to the Primary catch-up. The Storytime track decides.

## Open items

- The design counts 92 sight words and 41 PA skills. The sequence table gives 115 words (names excluded) and the
  5.2 table lists 45 skills. After the decodability trim the graph keeps 100 tricky words.
- Design 5.3 puts v y qu x z, ck, and 4 rimes in Level 2. The week table puts them in Level 3.
  The graph follows the week table. Floss GPCs ss ff ll zz sit at element 35.
- Capital letter forms (`form-upper`) have no scheduled week (5.3 says Level 2, 1.2 says Level 3).
- Decodable text nodes (`text.<level>.<n>.<slug>`) and their `contains` edges are not built yet.
- Thai F1.1 Gr2/2 and Gr3/2 indicator text is not in sources.md. The standard node cites codes only.
- Level 4 band names `Bud|Flower` (Flower is for D, P2) need a check by Daniel.
- `reviewStatus` is `draft` on every node and edge. The Graph session reviews.
