# JavaScript Style Guide

- Use Node.js-compatible JavaScript matching existing repository scripts.
- Use `const` by default and `let` only for reassignment.
- Use 2-space indentation and semicolons.
- Keep generation deterministic; never depend on unordered iteration,
  current-time values, or unseeded randomness in tracked outputs.
- Prefer small parsing and normalization functions with targeted tests.
- Preserve provenance and uncertainty in generated records.
- Reject malformed source records rather than silently producing graph noise.
- Keep source-backed data separate from derived enrichment.
