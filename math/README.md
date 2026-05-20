# Mastery Advantage — Math Domain

> **Status: Planning** — This domain is not yet implemented.

This directory will contain the knowledge graph, level mappings, and tools for the **Math Advantage** app.

---

## Planned Scope

| App | Audience | Knowledge Framework | Level System |
|-----|----------|---------------------|--------------|
| **Math Advantage** | K–12 students | Thai national math curriculum | TBD |

---

## Open Questions

- **Curriculum framework:** Thai national curriculum (สสวท), Singapore Math, or an international standard such as CCSS? A hybrid aligned to Thai standards with international benchmarking is likely.
- **Skill granularity:** How finely should skills be decomposed? Need to balance graph depth (more accurate prerequisites) against data maintenance cost.
- **Grade-level system:** Will Math Advantage use school grades (P1–M6), a custom numeric level, or CEFR-equivalent bands?
- **Prerequisite sourcing:** Unlike the GSE (which is a pre-defined framework), math prerequisite relationships will need to be defined explicitly — either manually by curriculum experts, generated from the curriculum scope & sequence, or both.

---

## Next Steps

1. Choose and document the curriculum framework
2. Extract or define the skill taxonomy (list of discrete learnable skills with IDs and difficulty scores)
3. Define prerequisite relationships
4. Build `math-knowledge-space.json` conforming to the [shared graph schema](../README.md#domain-knowledge-graph-schema)
5. Create level mapping CSV (app level → difficulty range)
6. Update this README with the completed structure

---

## References

- สสวท (IPST) — Institute for the Promotion of Teaching Science and Technology, Thailand
- Ministry of Education, Thailand — Basic Education Core Curriculum
