# Mastery Advantage — Tutor Domain

> **Status: Planning** — This domain is not yet implemented.

**Tutor Advantage** is the AI tutoring app in the Advantage suite. Unlike the other apps, it is likely **cross-domain** — it can tutor students in any subject that has a Mastery Advantage knowledge graph.

---

## Brand

| Property | Value |
|----------|-------|
| Color | Emerald |
| Primary | `#34d399` (emerald-400) |
| Light | `#6ee7b7` (emerald-300) |
| Dark | `#065f46` (emerald-800) |
| Logo | `assets/logos/tutor-advantage.png` |

---

## Planned Scope

| App | Audience | Function |
|-----|----------|----------|
| **Tutor Advantage** | All age groups | AI-assisted tutoring across all Advantage domains |

---

## Architecture Considerations

Tutor Advantage is unique in this repository because it may not need its own knowledge graph — instead it operates **on top of** the existing domain graphs from other Advantage apps.

The Tutor Advantage engine likely:
1. Accepts a student's current knowledge state (from any domain graph)
2. Reads the outer fringe to identify what the student is ready to learn
3. Uses an AI tutor (Claude) to explain, question, and scaffold learning at those specific nodes
4. Updates the student's knowledge state based on demonstrated mastery

This makes Tutor Advantage the **surface layer** of Mastery Advantage, while the domain graphs (English, Math, Science, etc.) are the **data layer**.

---

## Open Questions

- **Session model:** Does Tutor Advantage conduct free-form tutoring sessions, or structured exercises tied to specific knowledge graph nodes?
- **Cross-domain sessions:** Can a single tutoring session span multiple domains (e.g., science + English reading comprehension)?
- **Mastery signaling:** How does the AI tutor signal to the Mastery Advantage engine that a student has demonstrated mastery of a node?
- **This directory:** Since Tutor Advantage may not need its own KST data, this directory may evolve to contain tutoring prompt templates, session schemas, or AI configuration rather than a knowledge graph.

---

## Next Steps

1. Define the tutoring session model
2. Determine what domain-specific data (if any) Tutor Advantage needs beyond the existing domain graphs
3. Document the API contract between Tutor Advantage and the domain knowledge graphs
4. Update this README accordingly
