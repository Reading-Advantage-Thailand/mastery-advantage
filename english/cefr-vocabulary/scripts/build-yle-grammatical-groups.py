#!/usr/bin/env python3
"""Build YLE grammatical-list enrichment overlay.

The freeze accepted omitting grammatical *groups* while keeping alphabetical
skills. This optional layer restores category × stage co-membership from the
official grammatical vocabulary list (PDF pp. 31–37) as content_group + contains.

Semantics: co-listed grammatical sets (e.g. Starters nouns), not prerequisites.
Core freeze graph is not rewritten.
"""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
import tempfile
from collections import defaultdict
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
PDF = ROOT / "source-pdfs" / "cambridge-yle-word-list-2025.pdf"
GRAPH = ROOT / "cefr-vocabulary-knowledge-space.json"
LAYER = "enrichment.cambridge.grammatical-groups"
SOURCE_ID = "cambridge-yle-word-list-2025"
DOMAIN = "english.vocabulary"
PAGES = (31, 37)

OUT_OVERLAY = ROOT / "overlays" / "yle-grammatical-groups.overlay.json"
OUT_REPORT_JSON = ROOT / "reports" / "enrichment" / "yle-grammatical-groups.json"
OUT_REPORT_MD = ROOT / "reports" / "enrichment" / "yle-grammatical-groups.md"
OUT_UNMATCHED = ROOT / "review" / "enrichment" / "queues" / "yle-grammatical-unmatched.jsonl"
OUT_FIXTURE = ROOT / "fixtures" / "enrichment" / "yle-grammatical-structure.json"

CATEGORY_ALIASES = {
    "nouns": "nouns",
    "verbs": "verbs",
    "adjectives": "adjectives",
    "adverbs": "adverbs",
    "prepositions": "prepositions",
    "conjunctions": "conjunctions",
    "pronouns": "pronouns",
    "determiners": "determiners",
    "modals": "modals",
    "question": "question-words",
    "question words": "question-words",
    "exclamations": "exclamations",
    "articles": "articles",
    "titles": "titles",
    "letters": "letters",
    "names": "names",
    "ordinal numbers": "ordinal-numbers",
    "cardinal numbers": "cardinal-numbers",
}

STAGE_KEYS = {
    "starters": "pre-a1-starters",
    "movers": "a1-movers",
    "flyers": "a2-flyers",
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def pdftotext(path: Path, first: int, last: int) -> str:
    cmd = ["pdftotext", "-layout", "-f", str(first), "-l", str(last), str(path), "-"]
    return subprocess.check_output(cmd, text=True, timeout=90, stderr=subprocess.DEVNULL)


def atomic_write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=str(path.parent), delete=False) as tmp:
        tmp.write(text)
        tmp_path = Path(tmp.name)
    tmp_path.replace(path)


def normalize_form(s: str) -> list[str]:
    t = s.strip().lower()
    t = t.replace("’", "'").replace("‘", "'")
    t = re.sub(r"\s+", " ", t)
    # drop leading/trailing parens notes kept separately
    variants = {t, t.replace(" ", "-"), t.replace("-", " ")}
    return [v for v in variants if v]


def build_form_index(graph: dict[str, Any]) -> dict[str, list[str]]:
    form_to: dict[str, list[str]] = defaultdict(list)
    for node in graph.get("nodes", []):
        if node.get("kind") != "skill":
            continue
        sid = node["id"]
        meta = node.get("metadata") or {}
        forms = set()
        for f in meta.get("matchForms") or []:
            if isinstance(f, str) and f.strip():
                forms.update(normalize_form(f))
        for key in ("normalizedForm", "lexicalForm"):
            v = meta.get(key)
            if isinstance(v, str) and v.strip():
                forms.update(normalize_form(v))
        for f in forms:
            if sid not in form_to[f]:
                form_to[f].append(sid)
    return form_to


def detect_columns(line: str) -> tuple[int, int, int] | None:
    """Return (starters_col, movers_col, flyers_col) if this is a stage header."""
    if "grammatical vocabulary list" in line.lower():
        return None
    s = line.find("Pre A1 Starters")
    m = line.find("A1 Movers")
    f = line.find("A2 Flyers")
    if s >= 0 and m > s and f > m:
        return s, m, f
    return None


def detect_category(line: str) -> str | None:
    stripped = line.strip()
    # category may be left-aligned with trailing words on same line
    for raw, slug in CATEGORY_ALIASES.items():
        if re.match(rf"^{re.escape(raw)}\b", stripped, re.I):
            return slug
        # indented category label only
        if re.match(rf"^\s{{0,8}}{re.escape(raw)}\s{{2,}}", line, re.I):
            return slug
    return None


def stage_for_position(col: int, starters: int, movers: int, flyers: int) -> str:
    mid_sm = (starters + movers) // 2
    mid_mf = (movers + flyers) // 2
    if col < mid_sm:
        return "starters"
    if col < mid_mf:
        return "movers"
    return "flyers"


# Single headword tokens (optional parenthetical gloss). Multi-column PDF layout
# must not glue adjacent columns into one span.
TOKEN_RE = re.compile(
    r"[A-Za-z][A-Za-z'’\-/]*(?:\s*\([^)]{1,40}\))?"
)


def extract_tokens(line: str, starters: int, movers: int, flyers: int) -> list[tuple[str, str, int]]:
    """Return list of (stage, surface, col)."""
    out: list[tuple[str, str, int]] = []
    # Skip pure header/footer
    if re.search(r"grammatical vocabulary list|^\s*\d+\s*$", line, re.I):
        return out
    for m in TOKEN_RE.finditer(line):
        surface = m.group(0).strip()
        col = m.start()
        # skip category labels themselves
        if surface.lower().rstrip("s") in {
            "noun",
            "verb",
            "adjective",
            "adverb",
            "preposition",
            "conjunction",
            "pronoun",
            "determiner",
            "modal",
            "question",
            "article",
            "title",
            "letter",
            "name",
        } or surface.lower() in CATEGORY_ALIASES:
            continue
        if surface.lower() in {"example", "etc", "e.g"}:
            continue
        # strip trailing parenthetical gloss for matching key, keep surface
        base = re.sub(r"\s*\([^)]*\)\s*", " ", surface)
        base = re.sub(r"\s+", " ", base).strip(" -/")
        if len(base) < 1:
            continue
        # UK/US variant lines like "(UK flat)" alone — skip orphan notes
        if base.lower() in {"uk", "us"}:
            continue
        stage = stage_for_position(col, starters, movers, flyers)
        out.append((stage, base, col))
    return out


def clean_lemma(surface: str) -> str:
    t = surface.strip()
    # child/children → keep both later; primary before slash
    if "/" in t and not t.startswith("http"):
        # prefer full form; match both sides separately upstream
        pass
    t = re.sub(r"\s*\([^)]*\)\s*", " ", t)
    t = re.sub(r"\s+", " ", t).strip(" -")
    return t


def expand_slash_forms(lemma: str) -> list[str]:
    if "/" not in lemma:
        return [lemma]
    # child/children, Ann/Anna
    parts = [p.strip() for p in lemma.split("/") if p.strip()]
    return parts if parts else [lemma]


def match_skills(lemma: str, form_to: dict[str, list[str]]) -> list[str]:
    found: list[str] = []
    for piece in expand_slash_forms(lemma):
        for key in normalize_form(piece):
            if key in form_to:
                for sid in form_to[key]:
                    if sid not in found:
                        found.append(sid)
                break
    return found


def main() -> int:
    if not PDF.is_file():
        print(f"missing PDF: {PDF}", file=sys.stderr)
        return 1
    if not GRAPH.is_file():
        print(f"missing graph: {GRAPH}", file=sys.stderr)
        return 1

    graph = json.loads(GRAPH.read_text(encoding="utf-8"))
    form_to = build_form_index(graph)
    text = pdftotext(PDF, PAGES[0], PAGES[1])

    starters_c, movers_c, flyers_c = 15, 55, 96
    category: str | None = None
    # memberships: (stage, category) -> set of (lemma, skill_id)
    buckets: dict[tuple[str, str], set[tuple[str, str]]] = defaultdict(set)
    unmatched: list[dict[str, Any]] = []
    seen_lemmas: set[tuple[str, str, str]] = set()
    token_count = 0

    for line in text.splitlines():
        cols = detect_columns(line)
        if cols:
            starters_c, movers_c, flyers_c = cols
            continue
        cat = detect_category(line)
        if cat:
            category = cat
            # same line may continue with words after category label
            # blank out category word for token extract
            line_for_tokens = re.sub(
                rf"(?i)^\s*{re.escape(cat.replace('-', ' '))}s?\b",
                " " * 8,
                line,
            )
            # also try raw keys
            for raw in CATEGORY_ALIASES:
                if CATEGORY_ALIASES[raw] == cat:
                    line_for_tokens = re.sub(rf"(?i)^\s*{re.escape(raw)}\b", " " * len(raw), line_for_tokens)
        else:
            line_for_tokens = line

        if not category:
            continue

        for stage, surface, _col in extract_tokens(line_for_tokens, starters_c, movers_c, flyers_c):
            lemma = clean_lemma(surface)
            if len(lemma) < 2:
                continue
            token_count += 1
            key = (stage, category, lemma.lower())
            if key in seen_lemmas:
                continue
            seen_lemmas.add(key)
            skills = match_skills(lemma, form_to)
            if not skills:
                unmatched.append(
                    {
                        "sourceId": SOURCE_ID,
                        "stage": stage,
                        "category": category,
                        "lemma": lemma,
                        "status": "unmatched",
                        "enrichmentLayer": LAYER,
                        "pdfPages": f"{PAGES[0]}-{PAGES[1]}",
                    }
                )
                continue
            for sid in skills:
                buckets[(stage, category)].add((lemma.lower(), sid))

    # Build overlay nodes/edges
    nodes: list[dict[str, Any]] = []
    edges: list[dict[str, Any]] = []
    edge_seq = 0

    root_id = f"{DOMAIN}.group.yle-grammatical.layer-root"
    nodes.append(
        {
            "id": root_id,
            "kind": "content_group",
            "title": "YLE grammatical vocabulary groups (enrichment)",
            "domain": DOMAIN,
            "reviewStatus": "draft",
            "sourceRefs": [SOURCE_ID],
            "metadata": {
                "enrichmentLayer": LAYER,
                "sourceId": SOURCE_ID,
                "role": "layer-root",
                "pdfPages": list(PAGES),
                "relationshipKind": "grammatical-list-group",
                "unitNumberIsNotPrerequisite": True,
            },
        }
    )

    membership = 0
    for (stage, category), pairs in sorted(buckets.items()):
        exam = STAGE_KEYS[stage]
        gid = f"{DOMAIN}.group.yle-grammatical.{stage}.{category}"
        nodes.append(
            {
                "id": gid,
                "kind": "content_group",
                "title": f"YLE {stage.title()} grammatical {category}",
                "domain": DOMAIN,
                "reviewStatus": "draft",
                "sourceRefs": [SOURCE_ID],
                "metadata": {
                    "enrichmentLayer": LAYER,
                    "sourceId": SOURCE_ID,
                    "stage": stage,
                    "exam": exam,
                    "grammaticalCategory": category,
                    "role": "grammatical-group",
                    "relationshipKind": "grammatical-list-group",
                    "pdfPages": list(PAGES),
                },
            }
        )
        edge_seq += 1
        edges.append(
            {
                "id": f"{DOMAIN}.edge.contains.yle-gram.{edge_seq}",
                "type": "contains",
                "sourceId": root_id,
                "targetId": gid,
                "weight": 1,
                "confidence": "high",
                "sourceRefs": [SOURCE_ID],
                "reviewStatus": "draft",
                "rationale": "Grammatical enrichment layer contains category×stage group",
                "metadata": {"enrichmentLayer": LAYER, "matchKind": "structure"},
            }
        )
        for lemma, sid in sorted(pairs):
            edge_seq += 1
            membership += 1
            edges.append(
                {
                    "id": f"{DOMAIN}.edge.contains.yle-gram.{edge_seq}",
                    "type": "contains",
                    "sourceId": gid,
                    "targetId": sid,
                    "weight": 1,
                    "confidence": "medium",
                    "sourceRefs": [SOURCE_ID],
                    "reviewStatus": "draft",
                    "rationale": (
                        f'YLE grammatical list co-lists "{lemma}" under {stage}/{category} '
                        "(group membership; not a prerequisite)"
                    ),
                    "metadata": {
                        "enrichmentLayer": LAYER,
                        "sourceId": SOURCE_ID,
                        "stage": stage,
                        "grammaticalCategory": category,
                        "indexLemma": lemma,
                        "matchKind": "normalized",
                        "extractionConfidence": "medium",
                        "relationshipKind": "grammatical-list-group",
                    },
                }
            )

    # domain link recorded only in extended use — overlay stays free of core ids
    if any(e.get("type") == "prerequisite_for" for e in edges):
        print("BUG: prerequisite_for in overlay", file=sys.stderr)
        return 1

    unique_lemmas = len({k[2] for k in seen_lemmas})
    matched_lemmas = unique_lemmas - len({(u["stage"], u["category"], u["lemma"].lower()) for u in unmatched})
    # recompute matched as seen - unmatched carefully
    unmatched_keys = {(u["stage"], u["category"], u["lemma"].lower()) for u in unmatched}
    matched_count = sum(1 for k in seen_lemmas if k not in unmatched_keys)

    stats = {
        "sourceId": SOURCE_ID,
        "sourceSha256": sha256(PDF),
        "pdfPages": list(PAGES),
        "tokenObservations": token_count,
        "uniqueStageCategoryLemmas": len(seen_lemmas),
        "matchedLemmas": matched_count,
        "unmatchedLemmas": len(unmatched),
        "matchRate": round(matched_count / len(seen_lemmas), 4) if seen_lemmas else 0.0,
        "groupCount": len(buckets),
        "membershipEdgeCount": membership,
        "groups": {
            f"{stage}.{category}": len(pairs) for (stage, category), pairs in sorted(buckets.items())
        },
    }

    overlay = {
        "enrichmentLayer": LAYER,
        "generatedAt": "2026-08-11",
        "coreGraph": "cefr-vocabulary-knowledge-space.json",
        "description": (
            "YLE grammatical vocabulary list groups (optional enrichment). "
            "Restores category×stage co-membership omitted from the freeze package."
        ),
        "freezeNote": (
            "YLE-2025-GRAMMATICAL-001 accepted omission of grammatical groups in the "
            "core freeze; this overlay is an independently selectable layer."
        ),
        "hardProhibitions": {
            "prerequisite_for": False,
            "doesNotRewriteCoreFreeze": True,
        },
        "nodes": nodes,
        "edges": edges,
        "stats": stats,
    }

    atomic_write(OUT_OVERLAY, json.dumps(overlay, indent=2, ensure_ascii=False) + "\n")
    atomic_write(
        OUT_UNMATCHED,
        "".join(json.dumps(r, ensure_ascii=False) + "\n" for r in unmatched),
    )

    report = {
        "enrichmentLayer": LAYER,
        "generatedAt": "2026-08-11",
        "relationshipSemantics": "Grammatical-list co-membership groups; not prerequisites.",
        "stats": stats,
        "prerequisite_for_count_in_overlay": 0,
        "coreGraphUntouched": True,
        "outputs": {
            "overlay": "overlays/yle-grammatical-groups.overlay.json",
            "unmatchedQueue": "review/enrichment/queues/yle-grammatical-unmatched.jsonl",
        },
    }
    atomic_write(OUT_REPORT_JSON, json.dumps(report, indent=2, ensure_ascii=False) + "\n")

    md = [
        "# YLE Grammatical Groups Enrichment",
        "",
        f"- Layer: `{LAYER}`",
        "- Source: Cambridge YLE 2025 grammatical vocabulary list (pp. 31–37)",
        "- Semantics: category×stage **co-listing** via `contains`, not prerequisites",
        f"- Groups: **{stats['groupCount']}**",
        f"- Membership edges: **{membership}**",
        f"- Matched lemmas: **{matched_count}** / {len(seen_lemmas)} (rate {stats['matchRate']})",
        f"- Unmatched: **{len(unmatched)}**",
        "- Core freeze graph: **untouched**",
        "",
        "Optional layer; freeze decision YLE-2025-GRAMMATICAL-001 remains valid for core.",
        "",
    ]
    atomic_write(OUT_REPORT_MD, "\n".join(md) + "\n")

    fixture = {
        "sourceId": SOURCE_ID,
        "pdf": "source-pdfs/cambridge-yle-word-list-2025.pdf",
        "sha256": sha256(PDF),
        "layerId": LAYER,
        "pdfPages": {"start": PAGES[0], "end": PAGES[1]},
        "section": "Pre A1 Starters, A1 Movers and A2 Flyers grammatical vocabulary list",
        "structureChecks": {
            "titlePresent": "grammatical vocabulary list" in text.lower(),
            "columnsPresent": all(x in text for x in ["Pre A1 Starters", "A1 Movers", "A2 Flyers"]),
            "categoriesDetected": sorted({c for (_s, c) in buckets.keys()}),
        },
        "buildStats": stats,
        "relationshipKind": "grammatical-list-group",
        "unitNumberIsNotPrerequisite": True,
    }
    atomic_write(OUT_FIXTURE, json.dumps(fixture, indent=2, ensure_ascii=False) + "\n")

    print(
        json.dumps(
            {
                "ok": True,
                "layer": LAYER,
                "groups": stats["groupCount"],
                "membershipEdges": membership,
                "matchRate": stats["matchRate"],
                "unmatched": len(unmatched),
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
