#!/usr/bin/env python3
"""Build WordNet typed semantic enrichment candidate overlays.

Phase 3 of lexical_semantic_enrichment: sense-aware candidates where lemma+POS
maps to a unique WordNet synset. Ambiguous lemmas are queued, never auto-promoted.

Outputs:
  overlays/semantic-wordnet.overlay.json  (edges only; no new skills)
  reports/enrichment/semantic-wordnet.{json,md}
  review/enrichment/queues/semantic-ambiguous.jsonl
  review/enrichment/queues/semantic-unmatched.jsonl
  fixtures/enrichment/semantic-wordnet-structure.json

Run:
  uv run --with nltk python scripts/build-wordnet-semantic.py
"""

from __future__ import annotations

import hashlib
import json
import re
import sys
import tempfile
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
GRAPH = ROOT / "cefr-vocabulary-knowledge-space.json"
OUT_OVERLAY = ROOT / "overlays" / "semantic-wordnet.overlay.json"
OUT_REPORT_JSON = ROOT / "reports" / "enrichment" / "semantic-wordnet.json"
OUT_REPORT_MD = ROOT / "reports" / "enrichment" / "semantic-wordnet.md"
OUT_AMBIG = ROOT / "review" / "enrichment" / "queues" / "semantic-ambiguous.jsonl"
OUT_UNMATCHED = ROOT / "review" / "enrichment" / "queues" / "semantic-unmatched.jsonl"
OUT_FIXTURE = ROOT / "fixtures" / "enrichment" / "semantic-wordnet-structure.json"
GENERATED_AT = "2026-08-11"
SOURCE_ID = "wordnet"
SOURCE_VERSION = "3.1"
DOMAIN = "english.vocabulary"

# Max neighbors per skill per relation (keeps overlay bounded)
MAX_PER_RELATION = 15

POS_TO_WN = {
    "noun": "n",
    "verb": "v",
    "adjective": "a",
    "adverb": "r",
    "phrasal-verb": "v",
    "auxiliary-verb": "v",
    "modal-verb": "v",
}

RELATION_LAYERS = {
    "synonym": "enrichment.semantic.wordnet.synonym",
    "antonym": "enrichment.semantic.wordnet.antonym",
    "hypernym": "enrichment.semantic.wordnet.hypernym",
    "hyponym": "enrichment.semantic.wordnet.hyponym",
    "meronym": "enrichment.semantic.wordnet.meronym",
    "holonym": "enrichment.semantic.wordnet.holonym",
}


def atomic_write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=str(path.parent), delete=False) as tmp:
        tmp.write(text)
        tmp_path = Path(tmp.name)
    tmp_path.replace(path)


def normalize_lemma(form: str) -> str:
    t = form.strip().lower().replace("’", "'").replace("‘", "'")
    t = re.sub(r"\s*\([^)]*\)\s*", " ", t)
    t = re.sub(r"\s+", " ", t).strip(" -/")
    t = t.replace(" ", "_")  # WordNet style
    return t


def ensure_wordnet():
    import nltk
    from nltk.corpus import wordnet as wn

    try:
        wn.synsets("dog")
    except LookupError:
        nltk.download("wordnet", quiet=True)
        nltk.download("omw-1.4", quiet=True)
    return wn


def primary_pos(parts: list[str]) -> str | None:
    for p in parts:
        if p in POS_TO_WN:
            return p
    return None


def build_skill_index(graph: dict[str, Any]) -> tuple[list[dict[str, Any]], dict[str, list[str]]]:
    """Return skill records and lemma_pos -> skill ids (single-token only)."""
    skills: list[dict[str, Any]] = []
    lemma_pos_to: dict[str, list[str]] = defaultdict(list)

    for node in graph.get("nodes", []):
        if node.get("kind") != "skill":
            continue
        meta = node.get("metadata") or {}
        raw = str(meta.get("normalizedForm") or meta.get("lexicalForm") or "").strip()
        if not raw or " " in raw or "/" in raw:
            continue  # single-token first ship only
        lemma = normalize_lemma(raw)
        if not lemma or not re.fullmatch(r"[a-z]+(?:[_-][a-z]+)*", lemma):
            continue
        parts = list(meta.get("partsOfSpeech") or [])
        pos = primary_pos(parts)
        if not pos:
            continue
        wn_pos = POS_TO_WN[pos]
        rec = {
            "id": node["id"],
            "lemma": lemma,
            "pos": pos,
            "wn_pos": wn_pos,
            "partsOfSpeech": parts,
        }
        skills.append(rec)
        key = f"{lemma}|{wn_pos}"
        if node["id"] not in lemma_pos_to[key]:
            lemma_pos_to[key].append(node["id"])
        # also index without pos for cross-pos neighbor lookup
        bare = f"{lemma}|*"
        if node["id"] not in lemma_pos_to[bare]:
            lemma_pos_to[bare].append(node["id"])

    return skills, lemma_pos_to


def unique_synset(wn, lemma: str, wn_pos: str):
    synsets = wn.synsets(lemma, pos=wn_pos)
    # also try hyphen/underscore variants
    if not synsets and "-" in lemma:
        synsets = wn.synsets(lemma.replace("-", "_"), pos=wn_pos)
    if not synsets and "_" in lemma:
        synsets = wn.synsets(lemma.replace("_", "-"), pos=wn_pos)
    if len(synsets) == 1:
        return synsets[0], "unique"
    if len(synsets) == 0:
        return None, "none"
    return None, "ambiguous"


def lemma_names_to_skills(
    names: list[str],
    wn_pos: str | None,
    lemma_pos_to: dict[str, list[str]],
    self_id: str,
) -> list[str]:
    out: list[str] = []
    for name in names:
        lemma = name.lower().replace(" ", "_")
        keys = [f"{lemma}|*"]
        if wn_pos:
            keys.insert(0, f"{lemma}|{wn_pos}")
        for key in keys:
            for sid in lemma_pos_to.get(key, []):
                if sid != self_id and sid not in out:
                    out.append(sid)
    return out


def collect_targets(wn, synset, relation: str, lemma_pos_to, self_id: str, wn_pos: str) -> list[tuple[str, str, str]]:
    """Return list of (targetSkillId, sourceSenseId, targetSenseId)."""
    pairs: list[tuple[str, str, str]] = []
    src_name = synset.name()

    def add_from_synsets(syns, prefer_pos: str | None, limit: int = MAX_PER_RELATION):
        count = 0
        for s in syns:
            if count >= limit:
                break
            names = [lem.name() for lem in s.lemmas()]
            for sid in lemma_names_to_skills(names, prefer_pos, lemma_pos_to, self_id):
                pairs.append((sid, src_name, s.name()))
                count += 1
                if count >= limit:
                    break

    if relation == "synonym":
        names = [lem.name() for lem in synset.lemmas()]
        for sid in lemma_names_to_skills(names, wn_pos, lemma_pos_to, self_id)[:MAX_PER_RELATION]:
            pairs.append((sid, src_name, src_name))
    elif relation == "antonym":
        for lemma in synset.lemmas():
            for ant in lemma.antonyms():
                s = ant.synset()
                for sid in lemma_names_to_skills([ant.name()], wn_pos, lemma_pos_to, self_id):
                    pairs.append((sid, src_name, s.name()))
    elif relation == "hypernym":
        add_from_synsets(synset.hypernyms(), None)
    elif relation == "hyponym":
        add_from_synsets(synset.hyponyms(), wn_pos)
    elif relation == "meronym":
        add_from_synsets(list(synset.part_meronyms()) + list(synset.substance_meronyms()), None)
    elif relation == "holonym":
        add_from_synsets(list(synset.part_holonyms()) + list(synset.substance_holonyms()), None)
    return pairs


def edge_id(relation: str, source: str, target: str) -> str:
    h = hashlib.sha1(f"{relation}|{source}|{target}".encode()).hexdigest()[:12]
    return f"{DOMAIN}.edge.semantic.wordnet.{relation}.{h}"


def main() -> int:
    if not GRAPH.is_file():
        print(f"missing {GRAPH}", file=sys.stderr)
        return 1

    wn = ensure_wordnet()
    graph = json.loads(GRAPH.read_text(encoding="utf-8"))
    skills, lemma_pos_to = build_skill_index(graph)

    ambiguous: list[dict[str, Any]] = []
    unmatched: list[dict[str, Any]] = []
    edges: list[dict[str, Any]] = []
    seen_edge: set[tuple[str, str, str]] = set()
    stats = Counter()
    per_rel = Counter()

    # Resolve senses
    resolved: list[tuple[dict[str, Any], Any]] = []
    for sk in skills:
        syn, status = unique_synset(wn, sk["lemma"], sk["wn_pos"])
        stats[f"sense_{status}"] += 1
        if status == "ambiguous":
            ambiguous.append(
                {
                    "skillId": sk["id"],
                    "lemma": sk["lemma"],
                    "pos": sk["pos"],
                    "status": "ambiguous",
                    "synsetCount": len(wn.synsets(sk["lemma"], pos=sk["wn_pos"])),
                    "enrichmentLayer": "enrichment.semantic.wordnet",
                }
            )
            continue
        if status == "none":
            unmatched.append(
                {
                    "skillId": sk["id"],
                    "lemma": sk["lemma"],
                    "pos": sk["pos"],
                    "status": "unmatched",
                    "enrichmentLayer": "enrichment.semantic.wordnet",
                }
            )
            continue
        resolved.append((sk, syn))

    for sk, syn in resolved:
        for relation, layer in RELATION_LAYERS.items():
            targets = collect_targets(wn, syn, relation, lemma_pos_to, sk["id"], sk["wn_pos"])
            for tid, src_sense, tgt_sense in targets:
                # undirected relations: store only sourceId < targetId once
                a, b = sk["id"], tid
                if relation in {"synonym", "antonym"}:
                    if a > b:
                        a, b = b, a
                        src_sense, tgt_sense = tgt_sense, src_sense
                key = (relation, a, b)
                if key in seen_edge:
                    continue
                seen_edge.add(key)
                per_rel[relation] += 1
                edges.append(
                    {
                        "id": edge_id(relation, a, b),
                        "type": "supports",
                        "sourceId": a,
                        "targetId": b,
                        "weight": 0.5,
                        "confidence": "medium",
                        "sourceRefs": [f"{SOURCE_ID}-{SOURCE_VERSION}"],
                        "reviewStatus": "draft",
                        "rationale": (
                            f"WordNet {relation} candidate ({src_sense} → {tgt_sense}); "
                            "optional ranking signal; not a prerequisite"
                        ),
                        "metadata": {
                            "enrichmentLayer": layer,
                            "semanticRelation": relation,
                            "sourceId": SOURCE_ID,
                            "sourceVersion": SOURCE_VERSION,
                            "method": "sense-aware-lemma-pos-match",
                            "sourceSenseId": src_sense,
                            "targetSenseId": tgt_sense,
                            "score": None,
                            "extractionConfidence": "medium",
                            "matchKind": "sense-mapped",
                        },
                    }
                )

    if any(e.get("type") == "prerequisite_for" for e in edges):
        print("BUG: prerequisite_for", file=sys.stderr)
        return 1

    # Sort for determinism
    edges.sort(key=lambda e: e["id"])

    overlay = {
        "enrichmentLayer": "enrichment.semantic.wordnet",
        "generatedAt": GENERATED_AT,
        "coreGraph": "cefr-vocabulary-knowledge-space.json",
        "description": (
            "WordNet 3.1 typed semantic candidates (unique-synset lemma+POS only). "
            "Ambiguous senses quarantined. No new skills; no prerequisite_for."
        ),
        "source": {"id": SOURCE_ID, "version": SOURCE_VERSION},
        "hardProhibitions": {
            "prerequisite_for": False,
            "doesNotRewriteCoreFreeze": True,
            "doesNotCreateSkills": True,
            "ambiguousNeverAutoPromote": True,
        },
        "nodes": [],
        "edges": edges,
        "stats": {
            "skillsConsidered": len(skills),
            "uniqueSenseMapped": stats["sense_unique"],
            "ambiguous": stats["sense_ambiguous"],
            "unmatched": stats["sense_none"],
            "edgeCount": len(edges),
            "edgesByRelation": dict(per_rel),
            "maxPerRelation": MAX_PER_RELATION,
            "layers": list(RELATION_LAYERS.values()),
        },
    }

    report = {
        "enrichmentLayer": "enrichment.semantic.wordnet",
        "generatedAt": GENERATED_AT,
        "sourceVersion": SOURCE_VERSION,
        "prerequisite_for_count_in_overlay": 0,
        "coreGraphUntouched": True,
        "noNewSkillNodes": True,
        "ambiguousQuarantined": True,
        "stats": overlay["stats"],
        "queues": {
            "ambiguous": "review/enrichment/queues/semantic-ambiguous.jsonl",
            "unmatched": "review/enrichment/queues/semantic-unmatched.jsonl",
        },
        "status": "draft-candidates",
        "note": "Per-relation human precision gates still required before approve.",
    }

    report_md = f"""# WordNet Semantic Candidates

**Generated:** {GENERATED_AT}  
**Source:** WordNet {SOURCE_VERSION} (NLTK corpus)  
**Status:** draft candidates (not relation-layer approved)

## Counts

| Measure | Value |
|---|---:|
| Skills considered (single-token + mappable POS) | {len(skills)} |
| Unique synset mapped | {stats['sense_unique']} |
| Ambiguous (quarantined) | {stats['sense_ambiguous']} |
| Unmatched in WordNet | {stats['sense_none']} |
| Candidate edges | {len(edges)} |

## Edges by relation

| Relation | Edges |
|---|---:|
""" + "\n".join(f"| {k} | {per_rel[k]} |" for k in RELATION_LAYERS) + """

## Policy

- Ambiguous lemma+POS never auto-promotes
- No `prerequisite_for`
- Core graph untouched
- Promote/quarantine/reject per `enrichment.semantic.wordnet.*` layer after review
"""

    fixture = {
        "layerFamily": "enrichment.semantic.wordnet",
        "sourceId": SOURCE_ID,
        "sourceVersion": SOURCE_VERSION,
        "relationKinds": list(RELATION_LAYERS.keys()),
        "structureChecks": {
            "uniqueSenseOnly": True,
            "ambiguousQueued": True,
            "noPrerequisiteFor": True,
            "noSkillNodesInOverlay": True,
        },
        "buildStats": overlay["stats"],
        "sampleRelations": {
            "synonym": next((e for e in edges if e["metadata"]["semanticRelation"] == "synonym"), None),
            "hypernym": next((e for e in edges if e["metadata"]["semanticRelation"] == "hypernym"), None),
        },
    }
    # strip full edge from fixture sample for size - keep ids only
    for k, v in list(fixture["sampleRelations"].items()):
        if v:
            fixture["sampleRelations"][k] = {
                "id": v["id"],
                "sourceId": v["sourceId"],
                "targetId": v["targetId"],
                "semanticRelation": v["metadata"]["semanticRelation"],
            }

    atomic_write(OUT_OVERLAY, json.dumps(overlay, indent=2, ensure_ascii=False) + "\n")
    atomic_write(OUT_REPORT_JSON, json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    atomic_write(OUT_REPORT_MD, report_md)
    atomic_write(OUT_AMBIG, "".join(json.dumps(r, ensure_ascii=False) + "\n" for r in ambiguous))
    atomic_write(OUT_UNMATCHED, "".join(json.dumps(r, ensure_ascii=False) + "\n" for r in unmatched))
    atomic_write(OUT_FIXTURE, json.dumps(fixture, indent=2, ensure_ascii=False) + "\n")

    print(
        f"wordnet semantic: skills={len(skills)} unique={stats['sense_unique']} "
        f"ambig={stats['sense_ambiguous']} unmatched={stats['sense_none']} edges={len(edges)}"
    )
    print("by relation:", dict(per_rel))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
