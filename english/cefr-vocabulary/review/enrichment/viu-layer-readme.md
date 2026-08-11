# Vocabulary in Use unit-group layer

**Layer ID:** `enrichment.viu.unit-groups`  
**What it encodes:** *co-taught* vocabulary — words that appear in the same ViU
lesson/unit are linked through a unit `content_group` with `contains` edges.

## Why this matters

ViU teaches related words together. That is a **strong pedagogical grouping
signal** for the graph: joint practice sets, lesson packs, and soft ranking
among co-members — **not** a mastery order.

| Graph object | Meaning |
|---|---|
| Unit `content_group` | One lesson / unit |
| `contains` unit → skill | Skill is taught in that lesson |
| `metadata.unitNumber` | Loose book order only |
| `prerequisite_for` | **Never** created from ViU |

## Build

```bash
python3 english/cefr-vocabulary/scripts/build-viu-unit-groups.py
bash tests/enrichment_viu_layer.sh
```

## Artifacts

| Path | Role |
|---|---|
| `overlays/viu-unit-groups.overlay.json` | Layer nodes + edges (load with core) |
| `cefr-vocabulary-extended-viu.json` | Regenerable core∪overlay (gitignored) |
| `reports/enrichment/viu-unit-groups.{json,md}` | Match rates and counts |
| `review/enrichment/queues/viu-unmatched.jsonl` | Index lemmas not in core graph |
| `review/enrichment/queues/viu-ambiguous.jsonl` | Same-form multi-POS (accepted) |
| `fixtures/enrichment/viu-*-structure.json` | Per-band structure fixtures |

## Core freeze

The YLE-frozen `cefr-vocabulary-knowledge-space.json` is **not** rewritten.
Consumers that want ViU groups merge the overlay (or use the regenerable
extended graph).

## Match honesty

Many advanced ViU lemmas are outside the Cambridge YLE/A2/B1 core inventory;
they remain unmatched until coverage expansion adds those skills. Elementary
and intermediate bands match substantially better against the frozen core.
