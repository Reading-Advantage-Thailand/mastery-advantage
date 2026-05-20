# Mastery Advantage — English Domain

This directory contains the knowledge graph data, level mappings, and tools for the English reading domain. It powers **Mastery Advantage** in two apps:

| App | Audience | GSE Framework | Level System | GSE Range |
|-----|----------|---------------|--------------|-----------|
| **Reading Advantage** | Secondary students, ages 11–18 | Adult Learners | RA levels 1–18 | GSE 10–90 |
| **Primary Advantage** | Primary students, ages 6–11 | Young Learners | PA levels 1–14 | GSE 10–70 |

Both apps share the same underlying GSE knowledge graph. The level mapping CSVs translate between the shared GSE score space and each app's internal level system.

---

## Knowledge Framework

The English domain uses the **Pearson Global Scale of English (GSE)** as its skill taxonomy. The GSE is a granular extension of the CEFR framework, providing ~2,000 discrete "Can Do" learning objectives across four skills (reading, listening, speaking, writing) for two age groups (adult learners, young learners).

For Mastery Advantage, we use **reading objectives only** as the primary skill axis, with listening, speaking, and writing objectives included as supporting nodes in the graph.

CEFR alignment:

| CEFR Level | GSE Range | Apps |
|------------|-----------|------|
| Pre-A1 | 10–21 | Primary Advantage |
| A1 | 22–29 | Both |
| A2 | 30–40 | Both |
| B1 | 41–51 | Both |
| B2 | 52–60 | Reading Advantage |
| C1 | 61–75 | Reading Advantage |
| C2 | 76–90 | Reading Advantage |

---

## Files

```
english/
├── README.md                          ← This file
│
├── gse-md/                            ← Human-readable GSE objective data
│   ├── adult-learners/
│   │   ├── reading.md                 ← Adult reading objectives by GSE range
│   │   ├── listening.md
│   │   ├── speaking.md
│   │   └── writing.md
│   ├── young-learners/
│   │   ├── reading.md                 ← Young learner reading objectives
│   │   ├── listening.md
│   │   ├── speaking.md
│   │   └── writing.md
│   └── gse-all.json                   ← All objectives as a single JSON array
│                                         (canonical source for generation scripts)
│
├── gse-knowledge-space.json           ← Full KST graph: nodes + prerequisite edges
│
├── gse-to-reading-advantage.csv       ← GSE score (10–90) → RA level (1–18)
├── gse-to-primary-advantage.csv       ← GSE score (10–70) → PA level (1–14)
│
├── scripts/
│   ├── generate-knowledge-space.js    ← Builds gse-knowledge-space.json from gse-all.json
│   └── build-standalone-viz.js        ← Inlines JSON into standalone HTML visualization
│
├── index.html                         ← GSE Learning Objectives Explorer (browse/search/filter)
├── knowledge-space-viz.html           ← Interactive D3 knowledge graph visualization
└── knowledge-space-viz-standalone.html ← Same viz, data inlined (works from file://)
```

---

## Level Mappings

### Reading Advantage (Adult GSE, RA Levels 1–18)

| RA Level | GSE Range | CEFR |
|----------|-----------|------|
| 1 | 10–16 | Pre-A1 |
| 2 | 17–23 | Pre-A1 / A1 |
| 3 | 24–29 | A1 |
| 4 | 30–33 | A2 |
| 5 | 34–38 | A2 |
| 6 | 39–42 | A2 / B1 |
| 7 | 43–47 | B1 |
| 8 | 48–53 | B1 |
| 9 | 54–58 | B1 / B2 |
| 10 | 59–64 | B2 |
| 11 | 65–70 | B2 |
| 12 | 71–75 | C1 |
| 13 | 76–78 | C1 |
| 14 | 79–81 | C1 |
| 15 | 82–84 | C2 |
| 16 | 85–86 | C2 |
| 17 | 87–88 | C2 |
| 18 | 89–90 | C2 |

**File:** `gse-to-reading-advantage.csv` — format: `gse,ra_level` (one row per GSE score)

### Primary Advantage (Young Learner GSE, PA Levels 1–14)

| PA Level | GSE Range | CEFR |
|----------|-----------|------|
| 1 | 10–13 | Pre-A1 |
| 2 | 14–17 | Pre-A1 |
| 3 | 18–21 | Pre-A1 |
| 4 | 22–23 | A1 |
| 5 | 24–26 | A1 |
| 6 | 27–29 | A1 |
| 7 | 30–33 | A2 |
| 8 | 34–38 | A2 |
| 9 | 39–42 | A2 / B1 |
| 10 | 43–47 | B1 |
| 11 | 48–53 | B1 |
| 12 | 54–58 | B1 |
| 13 | 59–64 | B1 / B2 |
| 14 | 65–70 | B2 |

**File:** `gse-to-primary-advantage.csv` — format: `gse,pa_level` (one row per GSE score)

---

## Knowledge Graph

`gse-knowledge-space.json` is a directed graph that models the English reading domain.

### Node Types

| Kind | Description |
|------|-------------|
| `domain` | Root node: "Pearson GSE" |
| `content_group` | An (age group, skill) pair — e.g. "Adults — Reading" |
| `standard` | A CEFR level — e.g. "B1" |
| `instructional_unit` | A GSE score band within a content group |
| `skill` | An individual "Can Do" objective (~2,000+ nodes) |

### Edge Types

| Type | Meaning |
|------|---------|
| `contains` | Structural hierarchy: domain → group → unit → skill |
| `prerequisite_for` | Skill A must be mastered before Skill B is reachable |
| `supports` | Co-competency: skills at the same GSE score that reinforce each other |
| `aligned_to_standard` | Skill is mapped to a CEFR level |

### Generating the Graph

```bash
node scripts/generate-knowledge-space.js
```

Reads `gse-md/gse-all.json` → outputs `gse-knowledge-space.json`.

Prerequisite edges are generated using deterministic seeded sampling:
- For each skill at score X, candidates are drawn from the same (age, skill) track at scores X-4 to X-1.
- 3–5 predecessors are selected, weighted toward closer scores.
- At least one predecessor from X-1 is always included.
- Edge confidence is rated `high` / `medium` / `low` based on score distance.

The script validates for cycles and dangling edges before writing output.

---

## Visualizations

Open `index.html` to browse and search all GSE objectives — useful for content teams and curriculum designers.

Open `knowledge-space-viz-standalone.html` in any browser (no server required) to explore the full prerequisite graph interactively.

To rebuild the standalone viz after updating the graph:

```bash
node scripts/build-standalone-viz.js
```

---

## Source Data

All objectives are sourced from Pearson's Global Scale of English Learning Objectives:
- **Adult Learners** — 2019 edition
- **Young Learners** — 2022 edition

The markdown files in `gse-md/` were transcribed from these PDFs. `gse-all.json` is the machine-readable compilation used by the generation scripts.
