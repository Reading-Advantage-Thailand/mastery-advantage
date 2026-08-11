#!/usr/bin/env python3
"""Apply the one-time YLE 2025 source-to-graph omission remediation.

The independent Phase 2 source oracle (``tests/yle_p2_membership.sh``) derives
1,407 direct YLE source rows (495 Starters / 399 Movers / 513 Flyers) from the
hash-pinned local PDF and found 17 rows with no YLE skill in the graph.  All 17
were dropped by the original ingestion parser, which could not read cells whose
part of speech wrapped onto the next extracted line, cells with no part of
speech at all (``a.m.``/``p.m.``), the ``title`` part of speech, or the
headword ``page`` (an over-broad page-header filter consumed it).

Each missing row is created here using the identity convention the graph
already applies to its 68 other glossed YLE skills -- ``catch (e.g. a ball)``
and ``catch (e.g. a bus)`` are distinct skills, and ``centre (US center)``
keeps its regional variant in the lexical form while exposing both spellings
through ``matchForms``.  No existing skill is merged, re-pointed, or given a
part of speech it did not have.

This is a one-time remediation, not a standing regeneration pipeline, and it is
idempotent.
"""

from __future__ import annotations

import json
import os
import re
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GRAPH = ROOT / "cefr-vocabulary-knowledge-space.json"
INVENTORY = ROOT / "data" / "cambridge-vocabulary-inventory.json"
SOURCE_REF = "cambridge-yle-word-list-2025"

DIFFICULTY = {"pre-a1": 0.1, "a1": 0.3, "a2": 0.5}
STAGE_CEFR = {"starters": "pre-a1", "movers": "a1", "flyers": "a2"}
STAGE_EXAM = {"starters": "pre-a1-starters", "movers": "a1-movers", "flyers": "a2-flyers"}

# (source_row_id, stage, source headword, parts of speech) for the 17 rows the
# independent oracle proved present in the official list and absent from the
# graph.  Headwords and parts of speech are the source's own; no gloss text is
# invented and no part of speech is remapped.
MISSING_ROWS = (
    ("yle-2025-starters-279", "starters", "Miss", ["title"]),
    ("yle-2025-starters-288", "starters", "Mr", ["title"]),
    ("yle-2025-starters-289", "starters", "Mrs", ["title"]),
    ("yle-2025-starters-317", "starters", "page", ["noun"]),
    ("yle-2025-movers-067", "movers", "city/town centre (US center)", ["noun"]),
    ("yle-2025-movers-082", "movers", "could (as in past of can for ability)", ["verb"]),
    ("yle-2025-movers-131", "movers", "floor (e.g. ground, 1st, etc.)", ["noun"]),
    ("yle-2025-movers-297", "movers", "shopping centre (US center)", ["noun"]),
    ("yle-2025-movers-314", "movers", "sports centre (US center)", ["noun"]),
    ("yle-2025-movers-333", "movers", "take off (i.e. get undressed)", ["verb"]),
    ("yle-2025-movers-356", "movers", "town/city centre (US center)", ["noun"]),
    ("yle-2025-flyers-001", "flyers", "a.m. (for time)", []),
    ("yle-2025-flyers-145", "flyers", "file (as in open and close a file)", ["noun"]),
    ("yle-2025-flyers-231", "flyers", "kilometre (US kilometer)", ["noun"]),
    ("yle-2025-flyers-311", "flyers", "p.m. (for time)", []),
    ("yle-2025-flyers-340", "flyers", "programme (US program)", ["noun"]),
    ("yle-2025-flyers-442", "flyers", "take (as in time e.g. it takes 20 minutes)", ["verb"]),
)


def normalized(value: str) -> str:
    return re.sub(r"\s+", " ", value.replace("’", "'").replace("–", "-").replace("—", "-")).strip()


def source_normalized(value: str) -> str:
    return re.sub(r"\s+\((?:Br Eng|Am Eng)\)$", "", normalized(value), flags=re.I).lower()


def match_forms(headword: str) -> list[str]:
    """Mirror the graph's existing YLE match-form derivation exactly."""
    value = source_normalized(headword)
    forms: set[str] = set()
    base = normalized(re.sub(r"\b(?:sth|sb)\b", "", re.sub(r"\s*\([^)]*\)", "", value)))
    if base:
        forms.add(base)
    for found in re.finditer(r"\((?:uk|us|am eng:?|br eng:?)\s+([^)]*)\)", value, re.I):
        if found.group(1).strip():
            forms.add(found.group(1).strip())
    if re.fullmatch(r"[a-z-]+/[a-z-]+", base):
        forms.update(base.split("/"))
    return sorted(forms)


def slug(value: str) -> str:
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", value.casefold())).strip("-")


def write_atomic(path: Path, payload: str) -> None:
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path.parent, delete=False) as handle:
        handle.write(payload)
        staged = Path(handle.name)
    os.replace(staged, path)


def main() -> None:
    graph = json.loads(GRAPH.read_text(encoding="utf-8"))
    inventory = json.loads(INVENTORY.read_text(encoding="utf-8"))
    existing_ids = {node["id"] for node in graph["nodes"]}

    next_index = {"contains": 0, "aligned_to_standard": 0}
    for edge in graph["edges"]:
        found = re.match(r"english\.vocabulary\.edge\.(contains|aligned_to_standard)\.(\d+)$", edge["id"])
        if found:
            next_index[found.group(1)] = max(next_index[found.group(1)], int(found.group(2)))

    def new_edge(edge_type: str, source_id: str, target_id: str, rationale: str, metadata: dict) -> None:
        next_index[edge_type] += 1
        graph["edges"].append({
            "id": f"english.vocabulary.edge.{edge_type}.{next_index[edge_type]}",
            "type": edge_type,
            "sourceId": source_id,
            "targetId": target_id,
            "weight": 1,
            "confidence": "high",
            "sourceRefs": [SOURCE_REF],
            "reviewStatus": "draft",
            "rationale": rationale,
            "metadata": metadata,
        })

    created = 0
    for _row_id, stage, headword, parts in MISSING_ROWS:
        cefr = STAGE_CEFR[stage]
        exam = STAGE_EXAM[stage]
        forms = match_forms(headword)
        suffix = f".{'-'.join(parts)}" if parts else ""
        node_id = f"english.vocabulary.skill.{slug(headword)}{suffix}"
        if node_id in existing_ids:
            continue
        description_pos = ", ".join(parts) if parts else "a listed lexical item"
        graph["nodes"].append({
            "id": node_id,
            "kind": "skill",
            "title": headword,
            "domain": "english.vocabulary",
            "description": f'Know and recognize "{headword}" as {description_pos}.',
            "sourceRefs": [SOURCE_REF],
            "reviewStatus": "draft",
            "metadata": {
                "lexicalForm": headword,
                "normalizedForm": forms[0],
                "matchForms": forms,
                "sourceNormalizedForm": source_normalized(headword),
                "partsOfSpeech": list(parts),
                "cefr": cefr,
                "cefrAlignments": [cefr],
                "examAlignments": [exam],
                "modality": "vocabulary",
                "lexicalUnit": "multiword-expression" if len(headword.split()) > 1 else "word",
            },
            "difficulty": DIFFICULTY[cefr],
            "independentPracticeReady": False,
        })
        existing_ids.add(node_id)
        new_edge(
            "contains",
            f"english.vocabulary.exam.{exam}",
            node_id,
            "Cambridge exam vocabulary list contains lexical item",
            {"exam": exam},
        )
        new_edge(
            "aligned_to_standard",
            node_id,
            f"english.vocabulary.standard.{cefr}",
            f"Lexical item appears in a source aligned to CEFR {cefr.upper()}",
            {"cefr": cefr},
        )
        inventory.append({
            "headword": headword,
            "normalizedHeadword": forms[0],
            "matchForms": forms,
            "partsOfSpeech": list(parts),
            "cefrLevels": [cefr],
            "exams": [exam],
            "sourceRefs": [SOURCE_REF],
            "minimumCefr": cefr,
        })
        created += 1

    write_atomic(GRAPH, json.dumps(graph, ensure_ascii=False, indent=2) + "\n")
    write_atomic(INVENTORY, json.dumps(inventory, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({
        "created_skills": created,
        "yle_skill_count": sum(
            node.get("kind") == "skill" and SOURCE_REF in node.get("sourceRefs", [])
            for node in graph["nodes"]
        ),
        "skill_count": sum(node.get("kind") == "skill" for node in graph["nodes"]),
        "inventory_count": len(inventory),
    }, indent=2))


if __name__ == "__main__":
    main()
