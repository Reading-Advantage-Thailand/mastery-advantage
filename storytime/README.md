# Mastery Advantage — Storytime Domain

> **Status: Planning** — This domain is not yet implemented.

**Storytime Advantage** is the English reading program for **lower primary students (ages 5–8)**. It is the earliest tier of the Advantage reading suite:

| App | Audience | Focus |
|-----|----------|-------|
| Storytime Advantage | Lower primary (ages 5–8) | Early literacy, phonics, simple stories |
| Primary Advantage | Upper primary (ages 8–11) | Structured reading, GSE Young Learners |
| Reading Advantage | Secondary (ages 11–18) | Extensive reading, GSE Adult Learners |

All three share the same English reading continuum and Mastery Advantage engine, but Storytime Advantage targets the earliest stage of literacy development.

---

## Brand

| Property | Value |
|----------|-------|
| Color | Amber |
| Primary | `#fbbf24` (amber-400) |
| Light | `#fcd34d` (amber-300) |
| Dark | `#92400e` (amber-800) |
| Logo | `assets/logos/storytime-advantage.png` |

---

## Knowledge Framework Considerations

Storytime Advantage operates at a different cognitive level than the other reading apps. The skill taxonomy needs to cover:

- **Pre-literacy:** letter recognition, phonemic awareness, print concepts
- **Phonics:** letter-sound correspondence, blending, segmenting
- **Early reading:** sight words, simple sentence comprehension, story sequencing
- **Early GSE:** Pre-A1 and early A1 objectives from the Young Learner framework

**Open questions:**
- Does Storytime use the GSE Young Learner framework (same as Primary Advantage at the lower end), or a separate phonics/early literacy framework?
- What is the appropriate prerequisite granularity for phonics skills? These prerequisites are very fine-grained compared to the GSE.
- How does the knowledge graph transition students from Storytime into Primary Advantage? Should there be a shared lower boundary?

---

## Next Steps

1. Define the skill taxonomy (phonics + early literacy + lower GSE Young Learner objectives)
2. Determine how the graph connects downward to pre-literacy and upward into Primary Advantage
3. Build `storytime-knowledge-space.json` conforming to the [shared graph schema](../README.md#domain-knowledge-graph-schema)
4. Create level mapping CSV
5. Update this README with the completed structure
