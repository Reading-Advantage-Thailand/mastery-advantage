# YLE Reading Fixture Index

Offline Phase 5 fixtures for the YLE freeze consumption/reading contracts.

| Stage | Text | Profile | Expected |
|---|---|---|---|
| Starters | `fixtures/yle-reading/starters/text.txt` | `…/profile.json` | `…/expected.json` |
| Movers | `fixtures/yle-reading/movers/text.txt` | `…/profile.json` | `…/expected.json` |
| Flyers | `fixtures/yle-reading/flyers/text.txt` | `…/profile.json` | `…/expected.json` |

## Shared Properties

- Evaluator: `scripts/yle-reading-contract.js`
- Longest multi-token match against YLE `matchForms`
- Classifications: `known` | `unknown` | `unmatched`
- Eligible-token known coverage **includes unmatched** in the denominator
- Deliberate unmatched hard phrase in every text: `quantum telescope`
- Target vocabulary hard cap: 5 (profile field `targetVocabularyCap`)
- Progress: before/after known coverage under one simulated review of the first target

## Example Labeled Coverages (self-check run)

- Starters eligible-token known coverage: 0.571429 (unmatched span count: 5)
- Movers eligible-token known coverage: 0.428571 (unmatched span count: 4)
- Flyers eligible-token known coverage: 0.541667 (unmatched span count: 4)

Curriculum plausibility accepted 2026-08-11 (`phase5-approval.md`, Decision: go).
