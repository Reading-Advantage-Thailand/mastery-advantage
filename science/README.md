# Mastery Advantage — Science Domain

> **Status: Planning** — This domain is not yet implemented.

This directory will contain the knowledge graph, level mappings, and tools for the **Science Advantage** app.

---

## Planned Scope

| App | Audience | Knowledge Framework | Level System |
|-----|----------|---------------------|--------------|
| **Science Advantage** | K–12 students | Thai national science curriculum | TBD |

---

## Open Questions

- **Curriculum framework:** Thai national science curriculum (สสวท), Next Generation Science Standards (NGSS), or a hybrid? Science Advantage will likely align to Thai standards with international benchmarking.
- **Disciplinary scope:** Does the knowledge graph cover all science disciplines (physics, chemistry, biology, earth science) in a single unified graph, or in separate per-discipline graphs?
- **Prerequisite structure:** Science has strong cross-disciplinary prerequisites (e.g., energy concepts underpin both physics and chemistry). The graph design needs to handle these cross-domain edges cleanly.
- **Skill vs. concept:** Science learning objectives range from factual knowledge ("can name the planets") to procedural skills ("can design a controlled experiment") to conceptual understanding ("can explain photosynthesis"). How should these be unified in the KST model?

---

## Next Steps

1. Choose and document the curriculum framework
2. Define the skill/concept taxonomy per discipline and grade band
3. Map prerequisite relationships, including cross-discipline dependencies
4. Build `science-knowledge-space.json` conforming to the [shared graph schema](../README.md#domain-knowledge-graph-schema)
5. Create level mapping CSV
6. Update this README with the completed structure

---

## References

- สสวท (IPST) — Institute for the Promotion of Teaching Science and Technology, Thailand
- NGSS Lead States (2013) — *Next Generation Science Standards*
- Ministry of Education, Thailand — Basic Education Core Curriculum (Science strand)
