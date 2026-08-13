# Phase 2 GSE Vocabulary Fixture Contract

This contract defines the small fixture pack for Phase 3. It contains source
shapes and expected relationships. It does not contain the publisher exports.

## Pack Location And Manifest

The pack lives at `english/cefr-vocabulary/fixtures/gse-vocab/`.

`manifest.json` is an object with these fields:

| Field | Required value |
|---|---|
| `schemaVersion` | `1` |
| `fixturePack` | `gse-vocabulary-phase2` |
| `sourceExports.GL.file` | `gse-vocabulary-gl-10-67-2026-08-11.json` |
| `sourceExports.YL.file` | `gse-vocabulary-yl-10-59-2026-08-11.json` |
| `sourceExports.*.sha256` | full SHA-256 hex string |
| `sourceExports.*.audience` | the matching `GL` or `YL` value |

`expectedCounts` uses labelled keys: `GL items: 11586`, `YL items: 3024`,
`starred GL gse: 70`, and `YL temporaryGse: 129`.

The manifest registers these files:

- `records.json`
- `mapping-cases.json`
- `mutation-cases.json`
- `determinism.json`
- `negative-cases.json`

## Record Fixtures

`records.json` contains a non-empty `records` array. Each row has a unique
`caseId`, an `audience`, a `sourceExportSha256`, a `record` object, and an
`expected` object.

The pack has these case IDs:

- `gl-standard-layout`
- `gl-starred-gse`
- `yl-standard-layout`
- `yl-temporary-gse`

Each source record has `itemId`, `expression`, `audience`, `cefr`, `gse`, and a
non-empty `grammaticalCategories` array. GL uses a long CEFR value such as
`<A1 (10-21)`. GL does not use `expression_bre` or `temporaryGse`.

YL has a string `expression_bre` and a boolean `temporaryGse`. YL uses a short
CEFR value such as `<A1`. The expected object records the normalized CEFR band.

The starred GL row has a numeric `gse` string with `*`, such as `19*`. Its
expected object requires the same raw value and `starred: true`. The temporary
YL row has `temporaryGse: true` and requires `sourceFieldPreserved: true`.

## Mapping Fixtures

`mapping-cases.json` contains a non-empty `cases` array. Each entry contains
`itemId`, `expression`, `audience`, `grammaticalCategories`, `gse`, `cefr`, and
`sourceExportSha256`. Each node contains `nodeId`, `normalizedForm`,
`partsOfSpeech`, and `audience` unless the node is `null` for an unmatched GSE
entry.

The required case IDs and outcomes are:

| Case ID | Required relationship | Outcome |
|---|---|---|
| `multi-pos-expression` | node POS set equals one entry POS set | `mapped` |
| `ambiguous-binding` | two or more exact candidates share form, POS, and audience | `ambiguous` |
| `unmapped-core-node` | a node has no entries | `unmapped` |
| `unmatched-gse-entry` | one entry has `node: null` | `unmatched-gse-entry` |
| `cambridge-gse-level-conflict` | Cambridge and GSE bands differ | `mapped` plus conflict |
| `same-form-different-pos-falsifier` | the first form-only entry has the wrong POS | `mapped` by exact POS |

The ambiguous case cites `ambiguous-node-to-entry.jsonl`. The unmapped case
cites `unmapped-node-to-entry.jsonl`. The unmatched case cites
`unmatched-gse-entry.jsonl`. The conflict case preserves the Cambridge value,
the GSE band, node identity, item identity, and the disagreement reason.

The falsifier orders a wrong-POS entry first. Its `naiveFormOnlyItemId` must
equal that first entry. Its expected exact `itemId` must be different.

## Mutation And Byte-Diff Fixtures

`mutation-cases.json` contains these case IDs:

- `mapped-node-source-backed-fields`
- `conflict-retains-cambridge`
- `unmapped-node-no-inferred-data`
- `byte-diff-report-actual-mutation`

The mapped mutation expectation copies `itemId`, audience, raw GSE value,
normalized CEFR, definition, example, and source citation from one source
entry. The unmapped expectation leaves `metadata.gse` absent. The conflict
expectation keeps Cambridge data and records a separate GSE disagreement.

The byte-diff case has `priorGraph`, `newGraph`, `queueRows`, and `expected`.
Canonical graph bytes use sorted JSON keys, compact separators, UTF-8, and one
final newline. The expected prior SHA, new SHA, changed byte count, changed node
IDs, and labelled integer counts must equal the computed fixture values. The
new schema version matches `gse-vocab-YYYYMMDD-rNN` and differs from the prior
version.

## Determinism And YLE Isolation

`determinism.json` contains expectations for two extractor runs, two core
mutation runs, and the YLE case
`yle-same-procedure-before-after-baseline-isolation`.

The YLE case uses run labels `before` and `after`, sets `sameProcedure` and
`mutationAppliedBetweenRuns` to true, and compares temporary before and after
artifacts. It requires byte equality between those artifacts and preservation
of the frozen baseline. The frozen baseline is not the comparison target.

## Malformed And Mutation Probes

`negative-cases.json` contains these case IDs:

- `malformed-record-missing-item-id`
- `mutation-without-item-citation`
- `mutation-infers-absent-definition`

Each case has `expected.accepted: false`. The test performs the rejection
probe. It does not accept a row because it only declares an expected failure.

The fixture pack stays small and contains no raw export dump or publisher
wordlist. The Phase 2 test fails until every required file and relationship
exists.
