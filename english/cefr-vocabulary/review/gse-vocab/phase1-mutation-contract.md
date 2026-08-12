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
`PRE-A1`, `A1`, `A2`, `B1`, `B2`, `C1`, or `C2`. An absent optional CEFR value
is omitted and creates no queue row. An invalid present CEFR value is omitted
and creates the defined invalid-CEFR source-data queue row.

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

### Derived Publication Contract

Each derived core publication carries this exact notice: `The Global Scale of English and its components © Pearson.` The publication places the notice in its release metadata. The notice is required even when the publication contains only derived GSE fields.

### Release Manifest Contract

The release manifest records the previous version, the new core version, both
artifact paths, and SHA-256 checksums. It also carries this exact notice: `The Global Scale of English and its components © Pearson.` A version change needs the later core release gate. Phase 1 does not create a version.

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

## Executable YLE Mutation-Isolation Proof

Run the same procedure once before the GSE mutation and once after the GSE
mutation. Each run creates a temporary comparison artifact. The pass criterion
is byte-for-byte equality of the before artifact and after artifact. This proof
shows that the GSE mutation causes no YLE regeneration drift.

RELEASE-YLE-2025 limitation 6 authorizes a one-time freeze only and no standing
regeneration pipeline. Therefore, this proof does not compare, require, assert,
or expect frozen-release artifact equality. The frozen artifact is protected
release evidence only. The proof preserves it and does not overwrite it.

The current generator has no output-path option. For each run, set `RUN_LABEL`
to `before` or `after`, and run this same procedure from the repository root.
The caller supplies one temporary `COMPARISON_ROOT` shared by both runs:

```bash
set -euo pipefail
REPO_ROOT="$PWD"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
[[ -d "$SANDBOX" ]]
[[ "$SANDBOX" != "/" ]]
mkdir -p "$SANDBOX/english/cefr-vocabulary/scripts"
cp "$REPO_ROOT/english/cefr-vocabulary/scripts/generate-vocabulary-graph.js" "$SANDBOX/english/cefr-vocabulary/scripts/"
ln -s "$REPO_ROOT/english/cefr-vocabulary/source-pdfs" "$SANDBOX/english/cefr-vocabulary/source-pdfs"
cd "$SANDBOX"
node "english/cefr-vocabulary/scripts/generate-vocabulary-graph.js"
sha256sum "$SANDBOX/english/cefr-vocabulary/cefr-vocabulary-knowledge-space.json"
cp "$SANDBOX/english/cefr-vocabulary/cefr-vocabulary-knowledge-space.json" "$COMPARISON_ROOT/yle-$RUN_LABEL-comparison.json"
```

After both same-procedure runs finish, run `cmp --silent "$COMPARISON_ROOT/yle-before-comparison.json" "$COMPARISON_ROOT/yle-after-comparison.json"`. A nonzero comparison exits at once because fail-fast behavior applies. The immediate cleanup trap removes the sandbox on every exit path. A failed setup command cannot continue outside the sandbox. The frozen YLE artifact remains unchanged throughout this proof.

node english/cefr-vocabulary/scripts/generate-vocabulary-graph.js

## Contract Closure

Contract status: complete.
