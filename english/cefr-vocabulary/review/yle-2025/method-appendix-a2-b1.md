# Method Appendix: A2 Key / B1 Preliminary (Later Freezes)

**Status:** Method note only. **Not** release authority for A2 Key or B1.
**Parent freeze:** Cambridge YLE 2025 baseline (`RELEASE-YLE-2025.md`).

## What This Freeze Does Not Claim

- A2 Key and B1 Preliminary skills may appear in the tracked multi-exam graph
  for structural context.
- Those bands are **out of release authority** for the YLE freeze.
- No A2/B1 quality claim, membership fidelity claim, or app-consumable freeze
  is made here.

## Approved Method To Reuse Later

When a later track freezes A2 Key or B1 Preliminary, reuse this sequence:

1. **Scope lock** — single source identity (URL + SHA-256) and labeled baseline
   counts; fact-vs-signal catalog; prohibit fabricated `prerequisite_for`.
2. **List fidelity** — independent source oracle (not inventory-derived
   denominators); durable decisions for omissions, false inclusions, merges;
   curriculum sign-off.
3. **Relationships** — inventory `supports` (and any future derived classes);
   class dispositions as optional signals only; progression policy without hard
   gates.
4. **Consumption** — static graph vs learner state contract; explainability
   with separate `graphFacts` / `derivedSignals` / `learnerStateFields`.
5. **Reading fixtures** — offline matching with unmatched tokens in the
   coverage denominator; bounded targets; progress traces.
6. **Freeze package** — quality summary, decision log, unsigned draft decision
   until dual human go/conditional-go.

## Differences Expected For A2/B1

- Distinct official source PDFs and SHA-256 registry rows.
- Different exam codes, cumulative rules, and thematic inventories.
- Possibly larger collision/polysemy pressure — coordinate with the sense-level
  identity track before app adoption where polysemy matters.

## Reference Artifacts From The YLE Freeze

- `phase1-scope.md` — fact-vs-signal and sampling rules pattern
- `YLE-CONSUMPTION.md` — payload and boundary pattern
- `progression-policy.md` — hard-gate prohibitions
- Phase harnesses `tests/yle_p1_*.sh` … `tests/yle_p6_freeze.sh` as templates
