#!/usr/bin/env python3
"""Build Vocabulary in Use unit-group enrichment overlay.

Source-backed co-membership: words taught in the same ViU unit share a
content_group via contains edges. Unit order is metadata only — never
prerequisite_for.

Outputs (atomic staged write):
  overlays/viu-unit-groups.overlay.json
  reports/enrichment/viu-unit-groups.{json,md}
  review/enrichment/queues/viu-unmatched.jsonl
  review/enrichment/queues/viu-ambiguous.jsonl
  fixtures/enrichment/viu-{band}-structure.json (all four bands)
  cefr-vocabulary-extended-viu.json (core + overlay; core file untouched)
"""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
import tempfile
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent.parent if (ROOT.parent / "measure").is_dir() else ROOT.parent
# scripts/ -> cefr-vocabulary/
PDF_DIR = ROOT / "source-pdfs"
GRAPH_PATH = ROOT / "cefr-vocabulary-knowledge-space.json"
OUT_OVERLAY = ROOT / "overlays" / "viu-unit-groups.overlay.json"
OUT_EXTENDED = ROOT / "cefr-vocabulary-extended-viu.json"
OUT_REPORT_JSON = ROOT / "reports" / "enrichment" / "viu-unit-groups.json"
OUT_REPORT_MD = ROOT / "reports" / "enrichment" / "viu-unit-groups.md"
OUT_UNMATCHED = ROOT / "review" / "enrichment" / "queues" / "viu-unmatched.jsonl"
OUT_AMBIGUOUS = ROOT / "review" / "enrichment" / "queues" / "viu-ambiguous.jsonl"
OUT_FIX = ROOT / "fixtures" / "enrichment"
LAYER = "enrichment.viu.unit-groups"
DOMAIN = "english.vocabulary"

BANDS = [
    {
        "band": "elementary",
        "sourceId": "vocabulary-in-use-elementary",
        "frontmatter": "vocabulary-in-use-elementary-frontmatter.pdf",
        "index": "vocabulary-in-use-elementary-index.pdf",
        "cefrBandHint": "A2",
        "title": "English Vocabulary in Use Elementary",
    },
    {
        "band": "pre-intermediate",
        "sourceId": "vocabulary-in-use-pre-intermediate",
        "frontmatter": "vocabulary-in-use-pre-intermediate-frontmatter.pdf",
        "index": "vocabulary-in-use-pre-intermediate-index.pdf",
        "cefrBandHint": "B1",
        "title": "English Vocabulary in Use Pre-intermediate and Intermediate",
    },
    {
        "band": "upper-intermediate",
        "sourceId": "vocabulary-in-use-upper-intermediate",
        "frontmatter": "vocabulary-in-use-upper-intermediate-frontmatter.pdf",
        "index": "vocabulary-in-use-upper-intermediate-index.pdf",
        "cefrBandHint": "B2",
        "title": "English Vocabulary in Use Upper-intermediate",
    },
    {
        "band": "advanced",
        "sourceId": "vocabulary-in-use-advanced",
        "frontmatter": "vocabulary-in-use-advanced-frontmatter.pdf",
        "index": "vocabulary-in-use-advanced-index.pdf",
        "cefrBandHint": "C1-C2",
        "title": "English Vocabulary in Use Advanced",
    },
]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def pdftotext(path: Path, first: int | None = None, last: int | None = None) -> str:
    cmd = ["pdftotext", "-layout"]
    if first is not None:
        cmd += ["-f", str(first)]
    if last is not None:
        cmd += ["-l", str(last)]
    cmd += [str(path), "-"]
    try:
        return subprocess.check_output(cmd, text=True, timeout=90, stderr=subprocess.DEVNULL)
    except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired) as exc:
        raise RuntimeError(f"pdftotext failed for {path}: {exc}") from exc


def normalize_form(text: str) -> str:
    t = text.strip().lower()
    t = t.replace("’", "'").replace("‘", "'")
    t = re.sub(r"\s+", " ", t)
    t = re.sub(r"\s*/\s*", "/", t)
    # drop parenthetical POS notes: (n.), (v.)
    t = re.sub(r"\s*\([nvadjprepconjdetpronexc\.]+\)\s*", " ", t, flags=re.I)
    t = re.sub(r"\s+", " ", t).strip(" .;,:")
    # graph often uses hyphen for multiword
    hyphen = t.replace(" ", "-")
    return t, hyphen


def parse_units_from_frontmatter(text: str) -> list[dict[str, Any]]:
    """Extract unit number + title pairs from ViU contents pages."""
    units: dict[int, str] = {}
    # Prefer region after Contents / Map of the book if present
    lower = text.lower()
    start = 0
    for marker in ("contents", "map of the book", "thanks"):
        idx = lower.find(marker)
        if idx != -1 and marker == "contents":
            start = idx
            break
    body = text[start:] if start else text

    # Two-column: "1 Title .... page   31 Other title .... page"
    # Capture unit number + title until large gap or next unit number.
    pattern = re.compile(
        r"(?<!\d)(\d{1,3})\s+([A-Za-z][^\n\d]{2,70}?)(?=(?:\s{2,}\d{1,3}\s+[A-Za-z])|(?:\s{2,}\d{1,3}\s*$)|$)",
        re.M,
    )
    for m in pattern.finditer(body):
        num = int(m.group(1))
        title = re.sub(r"\s+", " ", m.group(2)).strip(" -–—.")
        title = re.sub(r"\s+\d{1,3}$", "", title).strip()
        if num < 1 or num > 120:
            continue
        if len(title) < 3:
            continue
        if re.search(
            r"cambridge|university press|isbn|edition|printed|liberty plaza|williamstown|penang",
            title,
            re.I,
        ):
            continue
        if re.match(r"^(what|how|why|study each|develop ways)\b", title, re.I):
            continue
        # Prefer longer/cleaner first title when duplicate
        if num not in units or len(title) > len(units[num]):
            units[num] = title[:100]

    return [{"unitNumber": n, "title": units[n]} for n in sorted(units)]


def split_index_columns(line: str) -> list[str]:
    # Split on 2+ spaces into columns (ViU indexes are multi-column)
    parts = re.split(r"\s{2,}", line.strip())
    return [p.strip() for p in parts if p.strip()]


def _is_english_lemma_token(token: str) -> bool:
    """True for index headword tokens; false for IPA / SAMPA debris."""
    t = token.strip()
    if not t:
        return False
    if t in {"n.", "v.", "adj.", "adv.", "prep.", "conj.", "det.", "pron."}:
        return True
    # POS tags in parentheses handled separately
    if re.fullmatch(r"\([nvadjprepconjdetpronexc\.\s]+\)", t, flags=re.I):
        return True
    # Normal word / hyphenation / apostrophe
    if re.fullmatch(r"[A-Za-z][A-Za-z'().\-]*", t):
        # Reject short phonetic leftovers like bA, bI, D@, A:
        if re.search(r"[A-Z].*[a-z]|[a-z].*[A-Z]", t) and not t.isupper():
            # mixed case mid-token often IPA (bA) — allow genuine Camel? rare in index
            if re.fullmatch(r"[a-z]{1,2}[A-Z].*", t):
                return False
        return True
    if re.fullmatch(r"[A-Za-z]+(?:-[A-Za-z0-9]+)+", t):
        return True
    return False


def parse_index_cell(cell: str) -> tuple[str, list[int]] | None:
    raw = cell.strip()
    if not raw or re.match(r"^(the numbers|index|standard british|pronunciation)", raw, re.I):
        return None

    cleaned = re.sub(r"/[^/\n]{1,80}/", " ", raw)
    cleaned = re.sub(r"\[[^\]]*\]", " ", cleaned)
    cleaned = re.sub(r"\s+", " ", cleaned).strip()

    # Trailing unit numbers (required)
    m = re.search(r"(\d{1,3}(?:\s*,\s*\d{1,3})*)\s*$", cleaned)
    if not m:
        return None
    units = [int(x) for x in re.findall(r"\d{1,3}", m.group(1))]
    units = [u for u in units if 1 <= u <= 120]
    if not units:
        return None
    left = cleaned[: m.start()].strip()

    # Cut at explicit SAMPA marker
    left = re.split(r"\s[@\\]", left, maxsplit=1)[0]
    # Drop non-ascii phonetic residue to spaces
    left = re.sub(r"[^\x00-\x7F]+", " ", left)
    left = re.sub(r"\s+", " ", left).strip(" -–,;")

    # Leading English tokens only; stop at first IPA-like token
    eng: list[str] = []
    for tok in left.split():
        # allow (n.) / (v.) attached as token
        if re.fullmatch(r"\([nvadjprepconj\.\s]+\)", tok, flags=re.I):
            continue
        if _is_english_lemma_token(tok):
            eng.append(tok)
            if len(eng) >= 6:
                break
        else:
            break
    if not eng:
        return None

    lemma = " ".join(eng)
    lemma = re.sub(r"\s*\([nvadjprepconj\.\s]+\)\s*", " ", lemma, flags=re.I)
    lemma = re.sub(r"\s+", " ", lemma).strip(" .;,:")
    if len(lemma) < 2 or lemma.isdigit():
        return None
    # Single-letter noise
    if re.fullmatch(r"[A-Za-z]", lemma):
        return None
    return lemma, units


def parse_index(text: str) -> list[dict[str, Any]]:
    entries: list[dict[str, Any]] = []
    seen: set[tuple[str, tuple[int, ...]]] = set()
    for line in text.splitlines():
        if not line.strip():
            continue
        for cell in split_index_columns(line):
            parsed = parse_index_cell(cell)
            if not parsed:
                continue
            lemma, units = parsed
            key = (lemma.lower(), tuple(sorted(set(units))))
            if key in seen:
                continue
            seen.add(key)
            entries.append(
                {
                    "indexLemma": lemma,
                    "unitNumbers": sorted(set(units)),
                }
            )
    return entries


def build_skill_index(graph: dict[str, Any]) -> tuple[dict[str, list[str]], dict[str, dict]]:
    """Map normalized match forms -> skill ids; return skill meta by id."""
    form_to_skills: dict[str, list[str]] = defaultdict(list)
    by_id: dict[str, dict] = {}
    for node in graph.get("nodes", []):
        if node.get("kind") != "skill":
            continue
        sid = node["id"]
        by_id[sid] = node
        meta = node.get("metadata") or {}
        forms = set()
        for f in meta.get("matchForms") or []:
            if isinstance(f, str) and f.strip():
                forms.add(f.strip().lower())
                forms.add(f.strip().lower().replace(" ", "-"))
                forms.add(f.strip().lower().replace("-", " "))
        for key in ("normalizedForm", "lexicalForm", "sourceNormalizedForm"):
            v = meta.get(key)
            if isinstance(v, str) and v.strip():
                forms.add(v.strip().lower())
                forms.add(v.strip().lower().replace(" ", "-"))
                forms.add(v.strip().lower().replace("-", " "))
        for f in forms:
            if sid not in form_to_skills[f]:
                form_to_skills[f].append(sid)
    return form_to_skills, by_id


def _ligature_guesses(form: str) -> list[str]:
    """Recover common pdftotext losses (fi/ff ligatures → dropped f)."""
    guesses = [form]
    # ater/aternoon/aterwards → after/...
    g = re.sub(r"\bat(er(?:noon|wards)?|ernoon)\b", r"aft\1", form)
    g = re.sub(r"\bat(er)\b", r"aft\1", g)
    if g != form:
        guesses.append(g)
    # aircrat → aircraft, oten → often
    for a, b in (("crat", "craft"), ("oten", "often"), ("itsel ", "itself "), ("itsel$", "itself")):
        g2 = re.sub(a, b, form)
        if g2 != form:
            guesses.append(g2)
    # dedupe
    out: list[str] = []
    for x in guesses:
        if x not in out:
            out.append(x)
    return out


def match_lemma(lemma: str, form_to_skills: dict[str, list[str]]) -> tuple[list[str], str]:
    space, hyphen = normalize_form(lemma)
    keys: list[str] = []
    for base in (space, hyphen):
        for g in _ligature_guesses(base):
            keys.extend([g, g.replace("'", ""), g.replace("-", " "), g.replace(" ", "-")])
    # preserve order unique
    seen: set[str] = set()
    ordered: list[str] = []
    for k in keys:
        if k and k not in seen:
            seen.add(k)
            ordered.append(k)

    candidates: list[str] = []
    for key in ordered:
        if key in form_to_skills:
            candidates = form_to_skills[key]
            break
    if not candidates:
        return [], "unmatched"
    if len(candidates) == 1:
        return candidates, "exact"
    return candidates, "multi-skill-same-form"


def slug_band(band: str) -> str:
    return band.replace("_", "-")


def unit_group_id(band: str, unit_number: int) -> str:
    return f"{DOMAIN}.group.viu.{slug_band(band)}.unit-{unit_number}"


def edge_id(seq: int) -> str:
    return f"{DOMAIN}.edge.contains.viu.{seq}"


@dataclass
class BuildStats:
    bands: dict[str, Any] = field(default_factory=dict)
    total_index_entries: int = 0
    matched_entries: int = 0
    unmatched_entries: int = 0
    ambiguous_entries: int = 0
    membership_edges: int = 0
    unit_groups: int = 0
    multi_unit_entries: int = 0


def atomic_write(path: Path, data: str | bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(data, str):
        payload = data.encode("utf-8")
    else:
        payload = data
    with tempfile.NamedTemporaryFile(dir=str(path.parent), delete=False) as tmp:
        tmp.write(payload)
        tmp_path = Path(tmp.name)
    tmp_path.replace(path)


def main() -> int:
    if not GRAPH_PATH.is_file():
        print(f"missing graph: {GRAPH_PATH}", file=sys.stderr)
        return 1
    graph = json.loads(GRAPH_PATH.read_text(encoding="utf-8"))
    form_to_skills, skills_by_id = build_skill_index(graph)

    nodes: list[dict[str, Any]] = []
    edges: list[dict[str, Any]] = []
    unmatched_rows: list[dict[str, Any]] = []
    ambiguous_rows: list[dict[str, Any]] = []
    stats = BuildStats()
    edge_seq = 0
    # membership dedupe
    membership_keys: set[tuple[str, str]] = set()

    # Book-level parent groups
    layer_root_id = f"{DOMAIN}.group.viu.layer-root"
    nodes.append(
        {
            "id": layer_root_id,
            "kind": "content_group",
            "title": "Vocabulary in Use unit groups (enrichment)",
            "domain": DOMAIN,
            "reviewStatus": "draft",
            "sourceRefs": [b["sourceId"] for b in BANDS],
            "metadata": {
                "enrichmentLayer": LAYER,
                "role": "layer-root",
                "unitNumberIsNotPrerequisite": True,
            },
        }
    )

    fixture_summaries = []

    for band_cfg in BANDS:
        band = band_cfg["band"]
        fm_path = PDF_DIR / band_cfg["frontmatter"]
        ix_path = PDF_DIR / band_cfg["index"]
        if not fm_path.is_file() or not ix_path.is_file():
            print(f"missing PDFs for {band}", file=sys.stderr)
            return 1

        fm_text = pdftotext(fm_path)
        ix_text = pdftotext(ix_path)
        units = parse_units_from_frontmatter(fm_text)
        index_entries = parse_index(ix_text)

        book_group_id = f"{DOMAIN}.group.viu.{slug_band(band)}.book"
        nodes.append(
            {
                "id": book_group_id,
                "kind": "content_group",
                "title": band_cfg["title"],
                "domain": DOMAIN,
                "reviewStatus": "draft",
                "sourceRefs": [band_cfg["sourceId"]],
                "metadata": {
                    "enrichmentLayer": LAYER,
                    "sourceId": band_cfg["sourceId"],
                    "cefrBandHint": band_cfg["cefrBandHint"],
                    "band": band,
                    "role": "book",
                    "unitNumberIsNotPrerequisite": True,
                },
            }
        )
        edge_seq += 1
        edges.append(
            {
                "id": edge_id(edge_seq),
                "type": "contains",
                "sourceId": layer_root_id,
                "targetId": book_group_id,
                "weight": 1,
                "confidence": "high",
                "sourceRefs": [band_cfg["sourceId"]],
                "reviewStatus": "draft",
                "rationale": "ViU enrichment layer contains book band group",
                "metadata": {
                    "enrichmentLayer": LAYER,
                    "matchKind": "structure",
                    "extractionConfidence": "high",
                },
            }
        )

        unit_ids: dict[int, str] = {}
        for u in units:
            n = u["unitNumber"]
            gid = unit_group_id(band, n)
            unit_ids[n] = gid
            nodes.append(
                {
                    "id": gid,
                    "kind": "content_group",
                    "title": f"ViU {band_cfg['cefrBandHint']} Unit {n}: {u['title']}",
                    "domain": DOMAIN,
                    "reviewStatus": "draft",
                    "sourceRefs": [band_cfg["sourceId"]],
                    "metadata": {
                        "enrichmentLayer": LAYER,
                        "sourceId": band_cfg["sourceId"],
                        "unitNumber": n,
                        "unitTitle": u["title"],
                        "cefrBandHint": band_cfg["cefrBandHint"],
                        "band": band,
                        "role": "unit",
                        "unitNumberIsNotPrerequisite": True,
                        "relationshipKind": "co-taught-lesson-group",
                    },
                }
            )
            edge_seq += 1
            edges.append(
                {
                    "id": edge_id(edge_seq),
                    "type": "contains",
                    "sourceId": book_group_id,
                    "targetId": gid,
                    "weight": 1,
                    "confidence": "high",
                    "sourceRefs": [band_cfg["sourceId"]],
                    "reviewStatus": "draft",
                    "rationale": "ViU book contains unit lesson group",
                    "metadata": {
                        "enrichmentLayer": LAYER,
                        "unitNumber": n,
                        "matchKind": "structure",
                        "extractionConfidence": "high",
                    },
                }
            )

        band_matched = 0
        band_unmatched = 0
        band_ambiguous = 0
        band_edges = 0
        multi_unit = 0

        for entry in index_entries:
            stats.total_index_entries += 1
            lemma = entry["indexLemma"]
            units_n = entry["unitNumbers"]
            if len(units_n) > 1:
                multi_unit += 1
                stats.multi_unit_entries += 1

            skill_ids, match_kind = match_lemma(lemma, form_to_skills)
            if match_kind == "unmatched" or not skill_ids:
                band_unmatched += 1
                stats.unmatched_entries += 1
                unmatched_rows.append(
                    {
                        "sourceId": band_cfg["sourceId"],
                        "band": band,
                        "indexLemma": lemma,
                        "unitNumbers": units_n,
                        "status": "unmatched",
                        "enrichmentLayer": LAYER,
                    }
                )
                continue

            if match_kind == "multi-skill-same-form":
                band_ambiguous += 1
                stats.ambiguous_entries += 1
                ambiguous_rows.append(
                    {
                        "sourceId": band_cfg["sourceId"],
                        "band": band,
                        "indexLemma": lemma,
                        "unitNumbers": units_n,
                        "skillIds": skill_ids,
                        "status": "accepted-multi-skill-same-form",
                        "disposition": (
                            "Attach contains edges to all form+POS skills; "
                            "ViU units are co-teaching sets, not POS-disambiguated."
                        ),
                        "enrichmentLayer": LAYER,
                    }
                )

            band_matched += 1
            stats.matched_entries += 1
            conf = "high" if match_kind == "exact" else "medium"
            for unit_n in units_n:
                gid = unit_ids.get(unit_n)
                if not gid:
                    # unit number from index without TOC title — create placeholder group
                    gid = unit_group_id(band, unit_n)
                    if unit_n not in unit_ids:
                        unit_ids[unit_n] = gid
                        nodes.append(
                            {
                                "id": gid,
                                "kind": "content_group",
                                "title": f"ViU {band_cfg['cefrBandHint']} Unit {unit_n}",
                                "domain": DOMAIN,
                                "reviewStatus": "draft",
                                "sourceRefs": [band_cfg["sourceId"]],
                                "metadata": {
                                    "enrichmentLayer": LAYER,
                                    "sourceId": band_cfg["sourceId"],
                                    "unitNumber": unit_n,
                                    "unitTitle": None,
                                    "cefrBandHint": band_cfg["cefrBandHint"],
                                    "band": band,
                                    "role": "unit",
                                    "unitNumberIsNotPrerequisite": True,
                                    "relationshipKind": "co-taught-lesson-group",
                                    "titleFromIndexOnly": True,
                                },
                            }
                        )
                        edge_seq += 1
                        edges.append(
                            {
                                "id": edge_id(edge_seq),
                                "type": "contains",
                                "sourceId": book_group_id,
                                "targetId": gid,
                                "weight": 1,
                                "confidence": "medium",
                                "sourceRefs": [band_cfg["sourceId"]],
                                "reviewStatus": "draft",
                                "rationale": "ViU book contains index-referenced unit",
                                "metadata": {
                                    "enrichmentLayer": LAYER,
                                    "unitNumber": unit_n,
                                    "matchKind": "structure",
                                    "extractionConfidence": "medium",
                                },
                            }
                        )

                for sid in skill_ids:
                    if sid not in skills_by_id:
                        continue
                    key = (gid, sid)
                    if key in membership_keys:
                        continue
                    membership_keys.add(key)
                    edge_seq += 1
                    band_edges += 1
                    stats.membership_edges += 1
                    edges.append(
                        {
                            "id": edge_id(edge_seq),
                            "type": "contains",
                            "sourceId": gid,
                            "targetId": sid,
                            "weight": 1,
                            "confidence": conf,
                            "sourceRefs": [band_cfg["sourceId"]],
                            "reviewStatus": "draft",
                            "rationale": (
                                f'ViU unit co-teaches index lemma "{lemma}" '
                                f"(lesson group; not a prerequisite)"
                            ),
                            "metadata": {
                                "enrichmentLayer": LAYER,
                                "sourceId": band_cfg["sourceId"],
                                "unitNumber": unit_n,
                                "indexLemma": lemma,
                                "matchKind": match_kind,
                                "extractionConfidence": conf,
                                "relationshipKind": "co-taught-lesson-group",
                                "unitNumberIsNotPrerequisite": True,
                            },
                        }
                    )

        stats.unit_groups += len(unit_ids)
        stats.bands[band] = {
            "sourceId": band_cfg["sourceId"],
            "frontmatterSha256": sha256(fm_path),
            "indexSha256": sha256(ix_path),
            "labeledUnitCount": len(units),
            "indexEntryCount": len(index_entries),
            "matchedEntries": band_matched,
            "unmatchedEntries": band_unmatched,
            "ambiguousMultiSkillEntries": band_ambiguous,
            "membershipEdges": band_edges,
            "multiUnitEntries": multi_unit,
            "matchRate": round(band_matched / len(index_entries), 4) if index_entries else 0.0,
        }

        # Structure fixtures (bounded; no full index dump)
        sample_entries = index_entries[:25]
        fixture = {
            "sourceId": band_cfg["sourceId"],
            "frontmatterPdf": f"source-pdfs/{band_cfg['frontmatter']}",
            "indexPdf": f"source-pdfs/{band_cfg['index']}",
            "frontmatterSha256": sha256(fm_path),
            "indexSha256": sha256(ix_path),
            "layerId": LAYER,
            "cefrBandHint": band_cfg["cefrBandHint"],
            "unitCatalog": {
                "labeledUnitCount": len(units),
                "units": units[:80],
                "unitNumberIsNotPrerequisite": True,
                "relationshipKind": "co-taught-lesson-group",
            },
            "indexSample": {
                "sampleSize": len(sample_entries),
                "entries": sample_entries,
                "note": "Bounded sample only; full index stays transient at parse time.",
            },
            "fixtureCases": [
                {"kind": "unmatched", "indexLemma": "zzzz-not-a-real-lemma", "expected": "unmatched"},
                {
                    "kind": "multi-unit",
                    "note": "Index rows with multiple unit numbers preserve all unit memberships",
                },
                {
                    "kind": "variant",
                    "note": "US/UK spelling variants resolve via matchForms or unmatched queue",
                },
                {
                    "kind": "co-taught-group",
                    "note": "Unit contains edges encode lesson co-membership, not prerequisites",
                },
            ],
            "buildStats": stats.bands[band],
        }
        fixture_summaries.append(fixture)
        atomic_write(
            OUT_FIX / f"viu-{band}-structure.json",
            json.dumps(fixture, indent=2, ensure_ascii=False) + "\n",
        )

    # Overlay package
    overlay = {
        "enrichmentLayer": LAYER,
        "generatedAt": "2026-08-11",
        "coreGraph": "cefr-vocabulary-knowledge-space.json",
        "description": (
            "Vocabulary in Use unit groups: source-backed co-taught lesson "
            "membership via content_group contains edges. Unit order is not "
            "prerequisite_for."
        ),
        "hardProhibitions": {
            "prerequisite_for_from_unit_order": False,
            "unitNumberIsNotPrerequisite": True,
        },
        "nodes": nodes,
        "edges": edges,
        "stats": {
            "bandCount": len(BANDS),
            "unitGroupCount": stats.unit_groups,
            "overlayNodeCount": len(nodes),
            "overlayEdgeCount": len(edges),
            "membershipEdgeCount": stats.membership_edges,
            "totalIndexEntries": stats.total_index_entries,
            "matchedEntries": stats.matched_entries,
            "unmatchedEntries": stats.unmatched_entries,
            "ambiguousMultiSkillEntries": stats.ambiguous_entries,
            "multiUnitEntries": stats.multi_unit_entries,
            "matchRate": round(stats.matched_entries / stats.total_index_entries, 4)
            if stats.total_index_entries
            else 0.0,
            "bands": stats.bands,
        },
    }

    # Guarantee no prerequisite edges in overlay
    if any(e.get("type") == "prerequisite_for" for e in edges):
        print("BUG: overlay contains prerequisite_for", file=sys.stderr)
        return 1

    atomic_write(OUT_OVERLAY, json.dumps(overlay, indent=2, ensure_ascii=False) + "\n")

    # Extended graph = core + overlay (core file untouched)
    core_ids = {n["id"] for n in graph["nodes"]}
    ext_nodes = list(graph["nodes"]) + [n for n in nodes if n["id"] not in core_ids]
    ext_edges = list(graph["edges"]) + edges
    # also add domain contains layer root if domain exists
    domain_id = f"{DOMAIN}.domain"
    if domain_id in core_ids:
        edge_seq += 1
        domain_edge = {
            "id": edge_id(edge_seq),
            "type": "contains",
            "sourceId": domain_id,
            "targetId": layer_root_id,
            "weight": 1,
            "confidence": "high",
            "sourceRefs": [b["sourceId"] for b in BANDS],
            "reviewStatus": "draft",
            "rationale": "Vocabulary domain contains ViU enrichment layer root",
            "metadata": {"enrichmentLayer": LAYER},
        }
        ext_edges.append(domain_edge)
        edges.append(domain_edge)
        overlay["edges"] = edges
        overlay["stats"]["overlayEdgeCount"] = len(edges)
        atomic_write(OUT_OVERLAY, json.dumps(overlay, indent=2, ensure_ascii=False) + "\n")

    extended = {
        "version": graph.get("version"),
        "title": (graph.get("title") or "English vocabulary") + " + ViU unit groups",
        "enrichmentLayers": [LAYER],
        "nodes": ext_nodes,
        "edges": ext_edges,
        "metadata": {
            **(graph.get("metadata") or {}),
            "viuEnrichment": {
                "layer": LAYER,
                "overlay": "overlays/viu-unit-groups.overlay.json",
                "coreUntouched": True,
            },
        },
    }
    atomic_write(OUT_EXTENDED, json.dumps(extended, ensure_ascii=False) + "\n")

    # Queues
    atomic_write(
        OUT_UNMATCHED,
        "".join(json.dumps(r, ensure_ascii=False) + "\n" for r in unmatched_rows),
    )
    atomic_write(
        OUT_AMBIGUOUS,
        "".join(json.dumps(r, ensure_ascii=False) + "\n" for r in ambiguous_rows),
    )

    report = {
        "enrichmentLayer": LAYER,
        "generatedAt": "2026-08-11",
        "relationshipSemantics": (
            "ViU units are co-taught lesson groups: contains edges mean "
            "taught-together, not required-before."
        ),
        "stats": overlay["stats"],
        "outputs": {
            "overlay": str(OUT_OVERLAY.relative_to(ROOT)),
            "extendedGraph": str(OUT_EXTENDED.relative_to(ROOT)),
            "unmatchedQueue": str(OUT_UNMATCHED.relative_to(ROOT)),
            "ambiguousQueue": str(OUT_AMBIGUOUS.relative_to(ROOT)),
        },
        "prerequisite_for_count_in_overlay": 0,
        "coreGraphUntouched": True,
    }
    atomic_write(OUT_REPORT_JSON, json.dumps(report, indent=2, ensure_ascii=False) + "\n")

    md = [
        "# ViU Unit Groups Enrichment Report",
        "",
        f"- Layer: `{LAYER}`",
        "- Semantics: **co-taught lesson groups** (contains), not prerequisites",
        f"- Unit groups: **{stats.unit_groups}**",
        f"- Membership contains edges: **{stats.membership_edges}**",
        f"- Index entries parsed: **{stats.total_index_entries}**",
        f"- Matched: **{stats.matched_entries}** (rate {report['stats']['matchRate']})",
        f"- Unmatched: **{stats.unmatched_entries}**",
        f"- Multi-skill same-form (accepted): **{stats.ambiguous_entries}**",
        f"- Multi-unit index rows: **{stats.multi_unit_entries}**",
        f"- prerequisite_for in overlay: **0**",
        f"- Core graph untouched: **yes** (`{GRAPH_PATH.name}`)",
        "",
        "## Per band",
        "",
        "| Band | Units | Index | Matched | Unmatched | Membership edges | Match rate |",
        "|---|---:|---:|---:|---:|---:|---:|",
    ]
    for band, bstat in stats.bands.items():
        md.append(
            f"| {band} | {bstat['labeledUnitCount']} | {bstat['indexEntryCount']} | "
            f"{bstat['matchedEntries']} | {bstat['unmatchedEntries']} | "
            f"{bstat['membershipEdges']} | {bstat['matchRate']} |"
        )
    md.extend(
        [
            "",
            "## Consumer rule",
            "",
            "Prefer co-members of a unit for joint practice, thematic sets, and ranking.",
            "Do **not** treat lower `unitNumber` as a hard gate for higher units.",
            "",
        ]
    )
    atomic_write(OUT_REPORT_MD, "\n".join(md) + "\n")

    # Update fixtures manifest
    OUT_FIX.mkdir(parents=True, exist_ok=True)
    manifest = {
        "generatedAt": "2026-08-11",
        "fixtures": sorted(p.name for p in OUT_FIX.glob("*.json")),
        "policy": "Structure and bounded samples only; full index transient at parse time.",
        "viuLayer": LAYER,
    }
    atomic_write(OUT_FIX / "manifest.json", json.dumps(manifest, indent=2) + "\n")

    print(
        json.dumps(
            {
                "ok": True,
                "layer": LAYER,
                "unitGroups": stats.unit_groups,
                "membershipEdges": stats.membership_edges,
                "matchRate": report["stats"]["matchRate"],
                "unmatched": stats.unmatched_entries,
                "overlay": str(OUT_OVERLAY),
                "extended": str(OUT_EXTENDED),
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
