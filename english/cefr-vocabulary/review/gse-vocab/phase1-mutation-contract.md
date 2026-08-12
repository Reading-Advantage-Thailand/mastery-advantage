# Phase 1 GSE Vocabulary Core Mutation Contract

## Scope And Node Fields

Phase 3 adds source-backed fields only after the mapping contract accepts one
exact entry. The mutation writes this object under `node.metadata.gse`:

```json
{
  "itemId": "<GSE item ID>",
  "audience": "GL|YL",
  "gseScore": "<source gse value>",
  "starred": "<boolean>",
  "temporaryGse": "<boolean>",
  "cefrBand": "<normalized CEFR band>",
  "definition": "<source definition>",
  "example": "<source example>",
  "sourceCitation": {
    "sourceId": "gse-vocabulary-gl-10-67-2026-08-11|gse-vocabulary-yl-10-59-2026-08-11",
    "itemId": "<GSE item ID>",
    "exportSha256": "<SHA-256>"
  }
}
```

`gseScore`, `cefrBand`, `definition`, and `example` are source-backed values.
`itemId` is the required source citation. The mutation copies a value only when
the cited source item states that value. It omits an absent optional value. It
does not invent a value or replace the existing Cambridge `metadata.cefr`.

## Reconciliation

The mutation retains the existing Cambridge level in `metadata.cefr` and
`metadata.cefrAlignments`. It writes the GSE CEFR band separately in
`metadata.gse.cefrBand`. When an existing GSE value differs from the pinned
entry, the pinned source corrects `metadata.gse` and the diff report records a
level correction. When the Cambridge and GSE bands differ, both values remain
visible and the disagreement report receives a row. The mutation makes no
silent overwrite.

## Core Version Bump

The generator creates a new core graph version by changing the domain node
`metadata.schemaVersion` from the prior core version to a distinct new core
version. The new core version is separate from and different from the frozen
YLE baseline version. It writes the new graph to a new versioned artifact path;
it does not overwrite the frozen YLE baseline artifact.

The release manifest records the previous version, the new core version, both
artifact paths, and SHA-256 checksums. A version change needs the later core
release gate. Phase 1 does not create a version.

## Byte-Level Diff Report

The generator writes a byte-level diff report beside the new version. The
report compares the prior core bytes and new core bytes by SHA-256 and records
the following labelled counts. Each value is a non-negative integer.

| Labelled count | Type |
|---|---|
| Nodes mapped: integer | count |
| Levels added: integer | count |
| Levels corrected: integer | count |
| Conflicts: integer | count |
| Unmapped GSE entries queued: integer | count |
| GSE entries with no matching node: integer | count |

The report also records `prior SHA-256`, `new SHA-256`, `bytes changed:
integer`, and a deterministic sorted list of changed `nodeId` values. This is

## Executable YLE Baseline Proof

Before and after the GSE mutation, run this verification against the frozen
YLE release record `review/yle-2025/RELEASE-YLE-2025.md`:

```bash
node english/cefr-vocabulary/scripts/generate-vocabulary-graph.js --source=yle-2025 --output=/tmp/yle-baseline-regenerated.json
sha256sum /tmp/yle-baseline-regenerated.json
cmp --silent /tmp/yle-baseline-regenerated.json english/cefr-vocabulary/cefr-vocabulary-knowledge-space.json
bash tests/yle_p6_freeze.sh
```

The proof compares the regenerated YLE baseline byte-identical artifact with
