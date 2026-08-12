# Phase 1 GSE Vocabulary Mapping Contract

## Scope

This contract defines the Phase 3 mapper. It does not map or mutate a graph in
Phase 1. The mapper reads only the two exports pinned in
`GSE_VOCABULARY_SOURCES.md`.

## Binding Rule

The binding rule joins one core node to one GSE entry only when all required
identity values match.

| Identity | Core node | GSE entry | Rule |
|---|---|---|---|
| Form | `metadata.normalizedForm` | `expression` | Unicode-normalize, trim, case-fold, and compare equal values. |
| POS | `metadata.partsOfSpeech` | `grammaticalCategories` | Normalize each source label with the map below. The normalized POS sets must match exactly. |
| Audience | explicit mapper input `audience` | `audience` | Run GL and YL as separate inputs. A GL input matches GL only. A YL input matches YL only. |

The core node ID is `nodeId`. The current graph uses `normalizedForm`; the
mapper must not assume a `normalizedHeadword` field exists. A form-only match
is unsafe and prohibited. The mapper must not bind an entry until it checks the
form, POS, and audience rule.

### POS Normalization Map

| Core `partsOfSpeech` | GSE `grammaticalCategories` | Normalized POS |
|---|---|---|
| `adjective` | `adjective` | `adjective` |
| `adverb` | `adverb` | `adverb` |
| `conjunction` | `conjunction` | `conjunction` |
| `determiner` | `determiner` | `determiner` |
| `interjection` | `interjection` | `interjection` |
| `noun` | `noun` | `noun` |
| `number` | `number` | `number` |
| `preposition` | `preposition` | `preposition` |
| `pronoun` | `pronoun` | `pronoun` |
| `verb` | `verb` | `verb` |
| `phrasal verb` | `phrasal verb` | `phrasal verb` |
| `phrase` | `phrase` | `phrase` |
| `prefix` | `prefix` | `prefix` |

`phrase` and `phrasal verb` are different normalized POS values. The mapper
does not convert either value to the other. An unsupported or missing label
does not match and creates queue evidence.

### GL And YL Audience Rule

The caller supplies the target audience for each run. The mapper does not
infer GL or YL from a Cambridge exam alignment, a CEFR level, age, form, or
definition. It filters the pinned export to the requested audience before the
join. A GL entry cannot substitute for a YL entry, and a YL entry cannot
substitute for a GL entry. A release input that needs both audiences records
two separate candidate results before a later approved reconciliation rule.

## Special Source Values

The 70 starred GL `gse` values are source values such as `19*`. The mapper
must preserve the raw string in `gse.rawValue`, retain the asterisk marker in
`gse.starred`, and explain that the marker came from the pinned source. It
must not drop the marker or parse the value as an invented clean score.

The 129 YL `temporaryGse` values are source boolean flags. The mapper must
preserve `temporaryGse: true` with its source meaning in the mapped source
record. It must not drop the flag or convert it into a score, certainty, or
approval state.

## Durable Queues

Phase 3 writes JSON Lines files at these explicit paths:

```text
english/cefr-vocabulary/review/gse-vocab/queues/ambiguous-node-to-entry.jsonl
english/cefr-vocabulary/review/gse-vocab/queues/unmapped-node-to-entry.jsonl
english/cefr-vocabulary/review/gse-vocab/queues/unmatched-gse-entry.jsonl
```

The ambiguous queue persists one durable row for each node with two or more
candidate entries:

```json
{"nodeId":"<string>","normalizedForm":"<string>","audience":"GL|YL","normalizedPartsOfSpeech":["<string>"],"candidateItemIds":["<itemId>"],"reason":"multiple-exact-candidates","sourceExportSha256":"<sha256>"}
```

The unmapped queue persists one durable row for each node with no candidate or
an unsupported identity value:

```json
{"nodeId":"<string>","normalizedForm":"<string>","audience":"GL|YL","normalizedPartsOfSpeech":["<string>"],"reason":"no-exact-candidate|unsupported-pos|missing-identity","sourceExportSha256":"<sha256>"}
```

The unmatched-entry queue persists each GSE `itemId` with no matching node:

```json
{"itemId":"<string>","expression":"<string>","audience":"GL|YL","normalizedGrammaticalCategories":["<string>"],"reason":"no-exact-node","sourceExportSha256":"<sha256>"}
```

## FR-8 Queue Isolation

FR-8 applies to the three queue files above. This track reads only these
explicit `review/gse-vocab/queues/` files when it builds its reports. A foreign
queue must not change this track's report. A foreign queue file must not
affect or poison this track's report. The mapper
does not glob queue directories or read queues from another track.

## No-Inference And Citations

Each mapped node records the exact GSE `itemId` citation that supplied its
data. An absent or unmapped entry creates an unmapped queue row and gives the
node no GSE data. The mapper uses no inference: it must not infer a score,
band, definition, example, POS, audience, or source entry from a similar form.
