# Mastery Advantage — Code Domain

> **Status: Initial reviewed release** — `code-knowledge-space.json` is the
> normative Codecamp graph for release `1.0.0`.

This directory owns the versioned knowledge graph and governance source for the
**Codecamp Advantage** consumer. Runtime schemas and validation live in the shared
`@reading-advantage/codecamp-knowledge` adapter package; this repository remains the
normative curriculum authority.

---

## Planned Scope

| App | Audience | Knowledge Framework | Level System |
|-----|----------|---------------------|--------------|
| **Code Advantage** | Secondary students and adults | Computational thinking / CS fundamentals | TBD |

---

## Authoring policy

- Language-agnostic concepts have one stable objective; technology applications
  reference those concepts instead of duplicating them.
- `prerequisite_for` edges marked `hard` are approved, high-confidence, and weighted
  exactly `1.0`, matching the imported engine's executable hard-gate threshold.
  Non-gating relationships use `supports` with `gate: soft`.
- CSTA 2017 and Thailand Basic Education Core Curriculum mappings are projections.
  They do not replace Codecamp product objectives.
- IDs are permanent once published. Graph changes require a semantic version bump and
  a migration impact note before consumer snapshots update.
- The graph, curriculum, technical, and standards reviewer roles are recorded in every
  release envelope.

---

## Release workflow

1. Edit `code-knowledge-space.json` and bump its version.
2. Run the consumer package validator and deterministic report.
3. Review hard/soft relationships and the migration impact.
4. Commit the normative release here.
5. Copy the exact bytes into the consumer package and record this source commit plus
   the SHA-256 digest. A digest mismatch fails publication.

---

## References

- CSTA (2017) — *K–12 Computer Science Standards*
- Wing, J. M. (2006) — "Computational Thinking." *Communications of the ACM*, 49(3), 33–35.
- Ministry of Education, Thailand — Basic Education Core Curriculum (Technology strand)
