# Phase 3 GSE Vocabulary Execution Contract

## Contents

- [Purpose](#purpose)
- [Entry Command](#entry-command)
- [Real-Source Interface](#real-source-interface)
- [Required Output Files](#required-output-files)
- [Queue Files](#queue-files)
- [Reports](#reports)
- [Determinism And YLE Isolation](#determinism-and-yle-isolation)

## Purpose

The specification defines required source values and graph effects. The strategy does not define a command or output path. This contract defines the Phase 3 test interface.

The interface is test-only. It does not authorize a production release or a frozen graph rewrite.

## Entry Command

The implementation provides this Node entry point:

```text
english/cefr-vocabulary/scripts/gse-vocabulary-core.js
```

The Phase 3 harness runs this command with absolute paths:

```bash
node english/cefr-vocabulary/scripts/gse-vocabulary-core.js \
  --fixture-dir <phase2-fixture-directory> \
  --prior-graph <temporary-prior-graph.json> \
  --output-dir <temporary-output-directory> \
  --queue-file ambiguous-node-to-entry.jsonl=<temporary-queue-path> \
  --queue-file unmapped-node-to-entry.jsonl=<temporary-queue-path> \
  --queue-file unmatched-gse-entry.jsonl=<temporary-queue-path> \
  --queue-file invalid-cefr-source-data.jsonl=<temporary-queue-path> \
  --byte-diff-report <temporary-byte-diff-report.json> \
  --mapping-quality-report <temporary-mapping-quality-report.json> \
  --conflict-report <temporary-conflict-report.jsonl> \
  --yle-output <temporary-yle-output.json> \
  --frozen-yle <tracked-frozen-yle-path> \
  [--run-label before|after] \
  [--mutation-applied-between-runs]
```

The command reads the Phase 2 fixture pack. The test harness provides a copy of `priorGraph` from `mutation-cases.json`.

The command writes only to the supplied temporary paths. It does not write the tracked frozen YLE artifact.

The optional run label identifies a YLE proof run. The mutation flag records the required between-run placement.

The same command supports output validation:

```bash
node english/cefr-vocabulary/scripts/gse-vocabulary-core.js \
  --validate-output <temporary-graph.json> \
  --fixture-dir <phase2-fixture-directory>
```

Invalid input and invalid output return a nonzero status. The diagnostic names the rejected field.

## Real-Source Interface

This interface supports separate GL and YL runs on the pinned exports.
It does not authorize a release or a committed graph write.

```bash
node english/cefr-vocabulary/scripts/gse-vocabulary-core.js \
  --gl-export <absolute-GL-export-path> \
  --yl-export <absolute-YL-export-path> \
  --audience GL \
  --release-date 2026-10-25 \
  --prior-graph <absolute-prior-graph-path> \
  --output-dir <absolute-output-directory> \
  --queue-file ambiguous-node-to-entry.jsonl=<absolute-queue-path> \
  --queue-file unmapped-node-to-entry.jsonl=<absolute-queue-path> \
  --queue-file unmatched-gse-entry.jsonl=<absolute-queue-path> \
  --queue-file invalid-cefr-source-data.jsonl=<absolute-queue-path> \
  --byte-diff-report <absolute-report-path> \
  --mapping-quality-report <absolute-report-path> \
  --conflict-report <absolute-report-path> \
  --yle-output <absolute-comparison-path> \
  --frozen-yle <absolute-protected-baseline-path>
```

`--audience` requires `GL` or `YL`. The command never merges the two audiences.
`--release-date` requires a valid UTC calendar date in `YYYY-MM-DD` format.
`--fixture-dir` and the export options are mutually exclusive.
Both export options are required for a real run.
The command verifies both SHA-256 values against `GSE_VOCABULARY_SOURCES.md` before any write.
A changed export fails with a diagnostic that names the audience and SHA-256.

The prior graph can be a byte-identical temporary copy of the committed graph.
The domain node `english.vocabulary.domain` carries the version in `metadata.schemaVersion`.
The first revision for the supplied date is `gse-vocab-YYYYMMDD-r01`.
The next revision for the same date increments the counter.
The byte-diff report hashes the actual input bytes and output bytes.

Real extraction uses the existing `extraction/gl.json` and `extraction/yl.json` paths.
Each `records` array contains all records from its pinned export, including variants and topics when present.
The mapping output uses `cases`, with one row per core skill node for the selected audience.
A real row uses `nodeId` and the existing mapping fields. It needs no fixture `caseId`.
The mapper accepts core `phrasal-verb` as the spelling of contract POS `phrasal verb`.
Other unsupported labels produce `unsupported-pos`. Missing identity values produce `missing-identity`.
Ambiguous, unmapped, and invalid-CEFR nodes carry no `metadata.gse`.
Plus bands enter the invalid-CEFR queue. The accepted `<A1` rule still produces `A1`.

The mapping quality report stores its six labelled integers under `counts`.
The byte-diff report stores them under `diffCounts`.
Conflict rows copy `metadata.cefrAlignments` without changes.
The same computed conflict rows supply both `Conflicts` counts.

Fixture runs supply temporary queue paths.
A durable GL run supplies the four tracked paths from the Phase 1 mapping contract.
Those tracked queue bytes equal a fresh GL run on the committed prior graph.
YL runs remain separate and use temporary queue paths until the owners approve reconciliation.
This route does not decide OI-1, OI-2, or OI-3.

Output validation supports the same source options and explicit audience:

```bash
node english/cefr-vocabulary/scripts/gse-vocabulary-core.js \
  --validate-output <absolute-graph-path> \
  --gl-export <absolute-GL-export-path> \
  --yl-export <absolute-YL-export-path> --audience GL
```

All source entries validate before any destination write.
Every generated leaf receives the same alias checks as the supplied report paths.
The checks reject symlinks, hard links, protected inputs, and tracked graph destinations.
Rejected input leaves existing output bytes unchanged.

The YLE comparison uses the same graph procedure before and after a GSE-only change.
The comparison reads Cambridge and YLE fields from the graph produced by the run.
A Cambridge or YLE change alters the comparison bytes. A GSE-only change preserves them.
Any generator probe uses the accepted Phase 1 sandbox procedure, never tracked destinations.

## Required Output Files

For a successful run, `<temporary-output-directory>` contains these files:

```text
extraction/gl.json
extraction/yl.json
mapping/mappings.json
graph/new-graph.json
```

The extractor writes canonical JSON. Canonical JSON uses sorted keys, compact separators, UTF-8, and one final newline.

Each extraction file is an object with `schemaVersion`, `audience`, `sourceExportSha256`, and a non-empty `records` array.

Each extracted record keeps `itemId`, `expression`, `audience`, `grammaticalCategories`, raw `gse`, and raw `cefr` when present.

Each extracted starred GL record keeps `gse: "19*"` and `starred: true`. Each YL record keeps the source `temporaryGse` boolean when that field exists.

The mapping file is an object with `schemaVersion`, `queueFiles`, and a `cases` array. Each case uses the Phase 2 `caseId`.

Each mapped case records exact form, normalized POS-set, audience, `itemId`, and `nodeMetadataGse`.

Each mapped `nodeMetadataGse` contains a complete `sourceCitation` with `sourceId`, `itemId`, and `exportSha256`.

Each mapped value equals its cited source value. An absent source value stays absent. The mapper does not infer a score, CEFR band, definition, example, POS, audience, or source entry.

The graph file contains a distinct `schemaVersion` and the mutated `nodes` and `edges` arrays. It contains no `prerequisite_for` edge.

## Queue Files

The four `--queue-file` arguments are the only queue inputs and outputs. The implementation does not glob a queue directory.

The logical queue names are exactly:

```text
ambiguous-node-to-entry.jsonl
unmapped-node-to-entry.jsonl
unmatched-gse-entry.jsonl
invalid-cefr-source-data.jsonl
```

Each queue path is a regular JSON Lines file. The ambiguous, unmapped, unmatched, and invalid-CEFR fixture cases each produce their defined row.

An absent optional CEFR value produces no invalid-CEFR row. A present invalid CEFR value produces the complete six-field row.

A foreign queue file must not change any report or graph output.

## Reports

The byte-diff report contains `priorSha256`, `newSha256`, `bytesChanged`, `changedNodeIds`, and `diffCounts`.

The `diffCounts` object contains these labelled integer keys:

```text
Nodes mapped
Levels added
Levels corrected
Conflicts
Unmapped GSE entries queued
GSE entries with no matching node
```

The mapping quality report contains the same six labelled integer keys. It records the exact four logical queue names.

The conflict report keeps Cambridge fields and GSE fields in separate values. Each conflict row cites the node, `itemId`, audience, and export SHA-256.

## Determinism And YLE Isolation

Two runs with the same fixture pack produce byte-identical GL extraction, YL extraction, mapping, graph, queues, and reports.

The same command runs before and after a source-backed GSE fixture change. Its temporary YLE outputs remain byte-identical.

The harness compares temporary YLE outputs. It uses the tracked frozen YLE path only for a before-and-after SHA-256 preservation check.

The frozen YLE artifact remains unchanged. The harness never compares it as the YLE output target.
