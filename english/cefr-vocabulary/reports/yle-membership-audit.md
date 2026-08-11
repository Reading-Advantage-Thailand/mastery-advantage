# YLE 2025 Membership Audit

- Source-row population: **1,407** direct official alphabetical rows.
- Starters direct source rows: **495**.
- Movers direct source rows: **399**.
- Flyers direct source rows: **513**.
- YLE unique graph skills: **1,405**.
- YLE alphabetical membership precision: **1.000** (1,407/1,407 matched-row pairs; this ratio is self-referential by contract).
- YLE graph memberships justified by an official source row: **1.000** (1,407/1,407 graph membership pairs).
- YLE alphabetical membership recall: **1.000** (1,407/1,407 independent source rows).
- YLE thematic membership precision: **1.000** (100/100 reviewed source memberships).
- Unresolved high-severity blockers: **0**.
- `prerequisite_for` edges added: **0**.

The source population is derived from the hash-pinned local official PDF before
the graph is consulted, so every denominator above is independent of the graph
inventory under audit. Source cells scanned: 1,616;
cells skipped outside A-Z sections: 90.

The parser stores page and section references only; no PDF excerpt, headword,
or part of speech is written to the committed package. Rows that cannot be
reconciled are recorded as durable quarantined omission decisions rather than
aborting the audit. Movers and Flyers cumulative expectations remain a
consumption policy, not duplicate membership or prerequisite edges.
Curriculum/language approval remains the plan's separate human gate.
