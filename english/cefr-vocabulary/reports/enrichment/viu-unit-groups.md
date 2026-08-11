# ViU Unit Groups Enrichment Report

- Layer: `enrichment.viu.unit-groups`
- Semantics: **co-taught lesson groups** (contains), not prerequisites
- Unit groups: **374**
- Membership contains edges: **4182**
- Index entries parsed: **10172**
- Matched: **2900** (rate 0.2851)
- Unmatched: **7272**
- Multi-skill same-form (accepted): **446**
- Multi-unit index rows: **962**
- prerequisite_for in overlay: **0**
- Core graph untouched: **yes** (`cefr-vocabulary-knowledge-space.json`)

## Per band

| Band | Units | Index | Matched | Unmatched | Membership edges | Match rate |
|---|---:|---:|---:|---:|---:|---:|
| elementary | 70 | 1331 | 699 | 632 | 1114 | 0.5252 |
| pre-intermediate | 75 | 2308 | 915 | 1393 | 1219 | 0.3964 |
| upper-intermediate | 83 | 3229 | 950 | 2279 | 1437 | 0.2942 |
| advanced | 88 | 3304 | 336 | 2968 | 412 | 0.1017 |

## Consumer rule

Prefer co-members of a unit for joint practice, thematic sets, and ranking.
Do **not** treat lower `unitNumber` as a hard gate for higher units.

