# Mastery Advantage — Code Domain

> **Status: Planning** — This domain is not yet implemented.

This directory will contain the knowledge graph, level mappings, and tools for the **Code Advantage** app.

---

## Planned Scope

| App | Audience | Knowledge Framework | Level System |
|-----|----------|---------------------|--------------|
| **Code Advantage** | Secondary students and adults | Computational thinking / CS fundamentals | TBD |

---

## Open Questions

- **Curriculum framework:** CSTA K–12 Computer Science Standards, Google's CS First, or a custom framework? Code Advantage is likely to target secondary students in Thailand, so alignment to Thai ICT curriculum may be needed alongside international CS standards.
- **Languages and paradigms:** Does the knowledge graph cover a single language (e.g. Python), or is it language-agnostic with conceptual nodes (variables, loops, functions, data structures) that apply across languages?
- **Skill decomposition:** Programming skills are highly hierarchical and cumulative — this domain may benefit from one of the densest prerequisite graphs in the suite.
- **Assessment:** Unlike reading comprehension (passage + questions), coding assessment requires code execution. How does Code Advantage assess mastery? Auto-graded exercises, output matching, or AI code review?

---

## Next Steps

1. Define the target learner profile and curriculum framework
2. Map the skill taxonomy (language-agnostic concepts + language-specific syntax nodes)
3. Define prerequisite relationships
4. Build `code-knowledge-space.json` conforming to the [shared graph schema](../README.md#domain-knowledge-graph-schema)
5. Design the assessment model
6. Update this README with the completed structure

---

## References

- CSTA (2017) — *K–12 Computer Science Standards*
- Wing, J. M. (2006) — "Computational Thinking." *Communications of the ACM*, 49(3), 33–35.
- Ministry of Education, Thailand — Basic Education Core Curriculum (Technology strand)
