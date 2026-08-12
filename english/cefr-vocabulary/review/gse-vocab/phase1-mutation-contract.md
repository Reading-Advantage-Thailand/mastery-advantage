# Phase 1 GSE Vocabulary Core Mutation Contract

## Scope And Node Fields

Phase 3 adds source-backed fields only after the mapping contract accepts one
exact entry. The mutation writes this object under `node.metadata.gse`:

```json
{
  "itemId": "<string: GSE item ID>",
  "audience": "<enum: GL|YL>",
  "gseScore": "<string: exact source gse value>",
  "starred": true,
  "temporaryGse": false,
  "cefrBand": "<enum: PRE-A1|A1|A2|B1|B2|C1|C2>",
  "definition": "<string: source definition>",
  "example": "<string: source example>",
  "sourceCitation": {
    "sourceId": "gse-vocabulary-gl-10-67-2026-08-11|gse-vocabulary-yl-10-59-2026-08-11",
    "itemId": "<GSE item ID>",
    "exportSha256": "<SHA-256>"
  }
}
```

`itemId` and `audience` are required. `gseScore` is required when the source
item has `gse`; it preserves the exact source string, including a trailing
asterisk. `starred` is required when `gseScore` is present and is a boolean.
`temporaryGse` is required when the source record has that boolean field.
`cefrBand`, `definition`, and `example` are optional and are omitted when the
source item omits them. The mutation copies a value only when the cited source
item states that value. It does not invent a value or replace the existing
Cambridge `metadata.cefr`.

The mapper normalizes a GL long CEFR value such as `<A1 (10-21)` by removing
the leading `<` and the first following space or `(` suffix, producing `A1`.
It normalizes a YL short value such as `<A1` by removing the leading `<`, also
producing `A1`. It uppercases the resulting band and accepts only
`PRE-A1`, `A1`, `A2`, `B1`, `B2`, `C1`, or `C2`; an invalid or absent value is
omitted and enters the relevant unmapped or source-data queue.

### Source-To-Node Field Mapping

| Pinned source field | Node field | Type and rule |
|---|---|---|
| `itemId` | `metadata.gse.itemId` and `metadata.gse.sourceCitation.itemId` | required string; copy exactly |
| export audience | `metadata.gse.audience` | required `GL` or `YL` enum; copy exactly |
| `gse.rawValue` | `metadata.gse.gseScore` | required string when present; copy exactly, including `*` |
| `gse.starred` | `metadata.gse.starred` | required boolean when `gseScore` is present |
| `temporaryGse` | `metadata.gse.temporaryGse` | required boolean when the source field exists |
| `cefr` | `metadata.gse.cefrBand` | optional normalized CEFR enum |
| `definition` | `metadata.gse.definition` | optional string; copy exactly |
| `example` | `metadata.gse.example` | optional string; copy exactly |
| export identifier and SHA-256 | `metadata.gse.sourceCitation.sourceId` and `.exportSha256` | required strings; copy exactly |

## Reconciliation

The mutation retains the existing Cambridge level in `metadata.cefr` and
`metadata.cefrAlignments`. It writes the GSE CEFR band separately in
`metadata.gse.cefrBand`. When an existing GSE value differs from the pinned
entry, the pinned source corrects `metadata.gse` and the diff report records a
level correction. When the Cambridge and GSE bands differ, both values remain
visible and the disagreement report receives a row. The labelled count
`Conflicts: integer` records these rows. The mutation makes no silent overwrite.

The generator writes disagreement rows to
`english/cefr-vocabulary/review/gse-vocab/reports/cambridge-gse-cefr-conflicts.jsonl`.
Each JSON Lines row has this schema:

```json
{"nodeId":"<string>","itemId":"<string>","audience":"GL|YL","cambridgeCefr":"<string>","cambridgeCefrAlignments":["<string>"],"gseCefrBand":"<enum: PRE-A1|A1|A2|B1|B2|C1|C2>","reason":"cambridge-gse-cefr-disagreement","sourceExportSha256":"<SHA-256>"}
```

The report preserves both source values. It does not change the Cambridge
fields to resolve a disagreement.

## Core Version Bump

The generator creates a new core graph version by changing the domain node
`metadata.schemaVersion` from the prior core version to a distinct new core
version. A core version has the format `gse-vocab-YYYYMMDD-rNN`, where
`YYYYMMDD` is the supplied UTC release date and `NN` is a two-digit revision
counter. The first release for a date uses `r01`; a repeated release date uses
the next counter. The new core version is separate from and different from the
frozen YLE baseline version. It writes the new graph to a new versioned
artifact path; it does not overwrite the frozen YLE baseline artifact.

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
the complete byte-level change record for the new core version.

## Executable YLE Baseline Proof

Before and after the GSE mutation, run this verification against the frozen
YLE release record `review/yle-2025/RELEASE-YLE-2025.md`. The baseline
regeneration is byte-identical when it reproduces the frozen artifact. The
current generator has no output-path option. Run it only in a copied temporary
sandbox:

```bash
SANDBOX="$(mktemp -d)"
mkdir -p "$SANDBOX/english/cefr-vocabulary/scripts"
cp english/cefr-vocabulary/scripts/generate-vocabulary-graph.js "$SANDBOX/english/cefr-vocabulary/scripts/"
ln -s "$PWD/english/cefr-vocabulary/source-pdfs" "$SANDBOX/english/cefr-vocabulary/source-pdfs"
cd "$SANDBOX"
node english/cefr-vocabulary/scripts/generate-vocabulary-graph.js
sha256sum "$SANDBOX/english/cefr-vocabulary/cefr-vocabulary-knowledge-space.json"
cmp --silent "$SANDBOX/english/cefr-vocabulary/cefr-vocabulary-knowledge-space.json" "$OLDPWD/english/cefr-vocabulary/cefr-vocabulary-knowledge-space.json"
bash "$OLDPWD/tests/yle_p6_freeze.sh"
rm -rf "$SANDBOX"
```

The proof compares the regenerated sandbox artifact byte-for-byte with the
tracked frozen YLE baseline. It hashes the sandbox artifact and leaves the
tracked frozen baseline unchanged.

## Contract Closure

Contract status: complete.
