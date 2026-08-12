# Phase 1 GSE Vocabulary Review Sample Contract

## Sample Population And Size

Phase 4 selects a stratified review sample of at least 100 accepted
node-to-entry mappings from the Phase 3 mapping output. The sample is not a
Phase 1 mapping result. Each row must include `nodeId`, GSE `itemId`, form,
normalized POS set, audience, Cambridge CEFR value, GSE CEFR band, and the
mapping decision.

The deterministic selection uses the sorted pair `nodeId:itemId` within each
stratum. The manifest records the mapping-output SHA-256, selection command,
seed, and selected row count.

## Required Strata

The sample has these required strata. A missing applicable stratum is a review
failure. A stratum with no Phase 3 population records `population: 0` and the
reason in the manifest.

| Stratum | Minimum selected mappings |
|---|---:|
| POS: noun | 15 |
| POS: verb | 15 |
| POS: adjective or adverb | 10 |
| POS: other supported POS | 10 |
| Audience: GL | 20 |
| Audience: YL | 20 |
| Multi-POS core nodes | 10 |
| Cambridge-versus-GSE conflict cases | 10 |

Strata overlap. The selector adds deterministic general-population rows until

## Precision Threshold

The mapping precision threshold is at least 98%. Reviewers calculate
precision as accepted exact bindings divided by reviewed mappings, expressed as
a percentage. A reviewed row is correct only when its form, POS, audience, and
GSE `itemId` agree with the pinned export. An ambiguous, inferred, missing, or
wrong-POS binding is incorrect. The report shows the labelled integer counts
`reviewed mappings`, `correct mappings`, and `incorrect mappings` before it
states the precision result.

The mapping audit stays open when the final sample has fewer than 100 mappings
or its precision is below 98%. Human approval remains a separate later gate.
