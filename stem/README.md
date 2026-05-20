# Mastery Advantage — STEM Domain

> **Status: Planning** — This domain is not yet implemented.

**STEM Advantage** integrates science, technology, engineering, and mathematics into a unified knowledge graph, rather than treating them as separate domains.

---

## Brand

| Property | Value |
|----------|-------|
| Color | Indigo |
| Primary | `#818cf8` (indigo-400) |
| Light | `#a5b4fc` (indigo-300) |
| Dark | `#3730a3` (indigo-800) |
| Logo | `assets/logos/stem-advantage.png` |

---

## Planned Scope

| App | Audience | Knowledge Framework | Level System |
|-----|----------|---------------------|--------------|
| **STEM Advantage** | Upper primary and secondary students | Integrated STEM curriculum | TBD |

---

## Relationship to Math and Science Advantage

STEM Advantage is distinct from the separate Math Advantage and Science Advantage apps. It focuses on **integrated STEM thinking** — projects and challenges that require applying math, science, engineering design, and computational thinking together.

This has implications for the knowledge graph:
- Nodes span multiple disciplines (a STEM skill may have prerequisites in both math and science)
- The graph will likely import and reference skill nodes from `math/` and `science/` rather than duplicating them
- The unique nodes are the cross-disciplinary integration skills: engineering design process, data analysis, computational modeling, etc.

---

## Open Questions

- **Scope:** Is STEM Advantage project-based (students complete engineering challenges), concept-based (like Math/Science but integrated), or both?
- **Graph architecture:** Should STEM Advantage share nodes with `math/` and `science/`, or maintain its own independent graph with cross-references?
- **Framework:** Thai MOE STEM curriculum, Next Generation Science Standards engineering practices, or a custom framework?

---

## Next Steps

1. Define the scope and relationship to Math Advantage and Science Advantage
2. Decide on graph architecture (shared nodes vs. independent)
3. Define the integration skill taxonomy
4. Build `stem-knowledge-space.json` conforming to the [shared graph schema](../README.md#domain-knowledge-graph-schema)
5. Update this README with the completed structure
