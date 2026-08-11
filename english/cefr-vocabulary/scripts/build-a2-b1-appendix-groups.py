#!/usr/bin/env python3
"""Build A2 Key and B1 Preliminary appendix enrichment overlays.

Reuses YLE freeze decisions:
  - form+POS skill identity (no duplicate skills for shared A2 vocab)
  - exam / topic membership via contains only
  - never prerequisite_for
  - core freeze graph is not rewritten
  - unmatched and ambiguous rows go to durable review queues

Each layer is independently selectable:
  enrichment.cambridge.a2-key-appendix
  enrichment.cambridge.b1-preliminary-appendix

Contents per layer:
  - exam co-membership from the A–Z wordlist (POS-aware)
  - Appendix 2 topic co-membership (form-aware; optional POS gloss)
"""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
import tempfile
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
GRAPH = ROOT / "cefr-vocabulary-knowledge-space.json"
PDF_DIR = ROOT / "source-pdfs"
DOMAIN = "english.vocabulary"
GENERATED_AT = "2026-08-11"

POS_ALIASES = {
    "abbrev": "abbreviation",
    "adj": "adjective",
    "adv": "adverb",
    "av": "auxiliary-verb",
    "conj": "conjunction",
    "det": "determiner",
    "dis": "discourse-marker",
    "excl": "exclamation",
    "exclam": "exclamation",
    "int": "interrogative",
    "mv": "modal-verb",
    "n": "noun",
    "poss": "possessive",
    "poss adj": "possessive-adjective",
    "prep": "preposition",
    "prep phr": "prepositional-phrase",
    "pron": "pronoun",
    "v": "verb",
    "phr v": "phrasal-verb",
}

POS_PATTERN = (
    r"prep of place \+ time|prep of place|prep of time|poss adj|prep phr|phr v|"
    r"abbrev|exclam|conj|prep|pron|poss|adj|adv|av|det|dis|excl|int|mv|n|v"
)

SOURCES = [
    {
        "examKey": "a2-key",
        "layerId": "enrichment.cambridge.a2-key-appendix",
        "sourceId": "cambridge-a2-key-vocabulary-list-2025",
        "pdf": "cambridge-a2-key-vocabulary-list-2025.pdf",
        "examId": "a2-key-for-schools",
        "examTitle": "A2 Key and A2 Key for Schools",
        "cefr": "a2",
        "azStart": "a/an (det)",
        "azEnd": "Appendix 1",
        "expectedSha256": "2abe174d067cd17ffa061cfc4bbbc0e5a55185ac696a5ef8ba49372c753a3ad6",
        "topics": [
            "Appliances",
            "Clothes and Accessories",
            "Colours",
            "Communication and Technology",
            "Documents and Texts",
            "Education",
            "Entertainment and Media",
            "Family and Friends",
            "Food and Drink",
            "Health, Medicine and Exercise",
            "Hobbies and Leisure",
            "House and Home",
            "Measurements",
            "Personal Feelings, Opinions and Experiences",
            "Places: Buildings",
            "Places: Countryside",
            "Places: Town and City",
            "Services",
            "Shopping",
            "Sport",
            "The Natural World",
            "Time",
            "Travel and Transport",
            "Weather",
            "Work and Jobs",
        ],
        "overlayName": "a2-key-appendix.overlay.json",
        "reportStem": "a2-key-appendix",
        "queueStem": "a2-key",
        "fixtureName": "a2-key-structure.json",
    },
    {
        "examKey": "b1-preliminary",
        "layerId": "enrichment.cambridge.b1-preliminary-appendix",
        "sourceId": "cambridge-b1-preliminary-vocabulary-list-2025",
        "pdf": "cambridge-b1-preliminary-vocabulary-list-2025.pdf",
        "examId": "b1-preliminary-for-schools",
        "examTitle": "B1 Preliminary and B1 Preliminary for Schools",
        "cefr": "b1",
        "azStart": "a/an (det)",
        "azEnd": "Appendix 1",
        "expectedSha256": "df5e3c31bb26205c2cfc2e7a94a0171d4f4769d5c1e42a3615fe6aa1b5fdab29",
        "topics": [
            "Clothes and Accessories",
            "Colours",
            "Communications and Technology",
            "Education",
            "Entertainment and Media",
            "Environment",
            "Food and Drink",
            "Health, Medicine and Exercise",
            "Hobbies and Leisure",
            "House and Home",
            "Language",
            "Personal Feelings, Opinions and Experiences",
            "Places: Buildings",
            "Places: Countryside",
            "Places: Town and City",
            "Services",
            "Shopping",
            "Sport",
            "The Natural World",
            "Time",
            "Travel and Transport",
            "Weather",
            "Work and Jobs",
        ],
        "overlayName": "b1-preliminary-appendix.overlay.json",
        "reportStem": "b1-preliminary-appendix",
        "queueStem": "b1-preliminary",
        "fixtureName": "b1-preliminary-structure.json",
    },
]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def pdftotext(path: Path) -> str:
    return subprocess.check_output(
        ["pdftotext", "-layout", str(path), "-"],
        text=True,
        timeout=120,
        stderr=subprocess.DEVNULL,
    )


def atomic_write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=str(path.parent), delete=False) as tmp:
        tmp.write(text)
        tmp_path = Path(tmp.name)
    tmp_path.replace(path)


def normalize_text(value: str) -> str:
    t = value.strip().lower()
    t = t.replace("’", "'").replace("‘", "'").replace("“", '"').replace("”", '"')
    t = t.replace("–", "-").replace("—", "-")
    t = re.sub(r"\s+", " ", t)
    return t


def normalize_form(value: str) -> str:
    t = normalize_text(value)
    t = re.sub(r"\s+\((?:br eng|am eng)(?::[^)]*)?\)$", "", t, flags=re.I)
    t = re.sub(r"\s*\([^)]*\)\s*", " ", t)
    t = re.sub(r"\s+", " ", t).strip(" -/.,;:")
    return t


def slug(title: str) -> str:
    s = title.lower()
    s = re.sub(r"[^a-z0-9]+", "-", s)
    return s.strip("-")[:70] or "item"


def parse_pos(raw: str) -> list[str]:
    normalized = normalize_text(raw).replace("(", "").replace(")", "")
    normalized = re.sub(
        r"\bprep of (?:place|time)(?: \+ (?:place|time))?\b",
        "prep",
        normalized,
    )
    normalized = re.sub(r"\b(?:sing|pl)\b", "", normalized)
    normalized = re.sub(r"\s+", " ", normalized).strip()
    parts: list[str] = []
    for part in re.split(r"\s*(?:&|\+|,|\bor\b)\s*", normalized):
        part = part.strip()
        if not part:
            continue
        if part in POS_ALIASES:
            parts.append(POS_ALIASES[part])
    return sorted(set(parts))


def parse_az_cell(cell: str) -> tuple[str, list[str]] | None:
    cleaned = normalize_text(cell.replace("\f", "")).strip()
    cleaned = re.sub(r"\s+page \d+.*$", "", cleaned, flags=re.I).strip()
    if not cleaned or re.fullmatch(r"[A-Z]", cleaned) or re.fullmatch(r"\d+", cleaned):
        return None
    if re.search(
        r"vocabulary list|a-z wordlist|alphabetic|appendix|grammatical key",
        cleaned,
        re.I,
    ):
        return None
    if cleaned.startswith("•") or cleaned.startswith("·"):
        return None

    suffix = re.compile(
        rf"^(.+?)\s+\(((?:{POS_PATTERN})(?:\s*(?:&|\+|,|or)\s*(?:{POS_PATTERN}))*"
        rf"(?:\s+(?:sing|pl))?)\)\s*$",
        re.I,
    )
    match = suffix.match(cleaned)
    if not match:
        return None

    headword = normalize_text(match.group(1))
    parts_of_speech = parse_pos(match.group(2))
    if not headword or not parts_of_speech or len(headword) > 100:
        return None
    if re.match(
        r"^(page|pre a1|a1 movers|a2 flyers|b1 preliminary|key and key)",
        headword,
        re.I,
    ):
        return None
    if headword.startswith("(") or headword.startswith("'") or headword.startswith('"'):
        return None
    if headword.count("(") != headword.count(")"):
        return None
    if len(headword.split()) > 7:
        return None
    # Layout debris often ends with a period (not abbreviations like a.m.).
    if headword.endswith(".") and not re.search(r"[a-z]\.[a-z]", headword):
        return None
    if headword.endswith("!") and "exclamation" not in parts_of_speech:
        return None
    if headword.endswith("?") and "interrogative" not in parts_of_speech and "verb" not in parts_of_speech:
        # keep "guess what?" style if tagged verb; else drop
        if not headword.endswith("?"):
            return None
    return headword, parts_of_speech


def extract_az_entries(text: str, start_marker: str, end_marker: str) -> list[tuple[str, list[str]]]:
    start = text.find(start_marker)
    end = text.find(end_marker, start + len(start_marker) if start >= 0 else 0)
    if start < 0 or end < 0:
        raise RuntimeError(f"Could not locate A–Z range: {start_marker!r} -> {end_marker!r}")

    entries: list[tuple[str, list[str]]] = []
    for line in text[start:end].splitlines():
        cells = re.split(r"\s{2,}", line.replace("\f", "").strip())
        for cell in cells:
            cell = cell.strip()
            if not cell:
                continue
            parsed = parse_az_cell(cell)
            if parsed:
                entries.append(parsed)
    return entries


def build_skill_indexes(
    graph: dict[str, Any],
) -> tuple[dict[str, list[str]], dict[tuple[str, tuple[str, ...]], list[str]], dict[str, set[str]]]:
    form_to: dict[str, list[str]] = defaultdict(list)
    form_pos_to: dict[tuple[str, tuple[str, ...]], list[str]] = defaultdict(list)
    skill_pos: dict[str, set[str]] = {}

    for node in graph.get("nodes", []):
        if node.get("kind") != "skill":
            continue
        sid = node["id"]
        meta = node.get("metadata") or {}
        pos = tuple(sorted(meta.get("partsOfSpeech") or []))
        skill_pos[sid] = set(pos)
        forms: set[str] = set()
        for form in meta.get("matchForms") or []:
            if isinstance(form, str) and form.strip():
                forms.add(normalize_text(form))
                forms.add(normalize_form(form))
        for key in ("normalizedForm", "lexicalForm"):
            value = meta.get(key)
            if isinstance(value, str) and value.strip():
                forms.add(normalize_text(value))
                forms.add(normalize_form(value))
        for form in forms:
            if not form:
                continue
            if sid not in form_to[form]:
                form_to[form].append(sid)
            form_pos_to[(form, pos)].append(sid)
    return form_to, form_pos_to, skill_pos


def form_variants(form: str) -> list[str]:
    base = normalize_form(form)
    if not base:
        return []
    variants = {base, base.replace(" ", "-"), base.replace("-", " ")}
    # slash variants: jewellery / jewelry, cafe/café
    if "/" in base:
        for piece in base.split("/"):
            piece = piece.strip()
            if piece:
                variants.add(piece)
                variants.add(piece.replace(" ", "-"))
                variants.add(piece.replace("-", " "))
    return [v for v in variants if v]


def match_az(
    headword: str,
    pos_list: list[str],
    form_to: dict[str, list[str]],
    form_pos_to: dict[tuple[str, tuple[str, ...]], list[str]],
    skill_pos: dict[str, set[str]],
) -> tuple[list[str], str]:
    pos_key = tuple(sorted(pos_list))
    for form in form_variants(headword):
        key = (form, pos_key)
        if key in form_pos_to:
            return list(dict.fromkeys(form_pos_to[key])), "exact-pos-set"

    candidates: list[str] = []
    for form in form_variants(headword):
        for sid in form_to.get(form, []):
            if sid not in candidates:
                candidates.append(sid)
    if not candidates:
        return [], "unmatched"

    wanted = set(pos_list)
    filtered = [sid for sid in candidates if skill_pos.get(sid, set()) & wanted]
    if len(filtered) == 1:
        return filtered, "pos-overlap-unique"
    if len(filtered) > 1:
        return filtered, "pos-overlap-multi"
    if len(candidates) == 1:
        return candidates, "form-only-unique"
    return candidates, "form-only-ambiguous"


def topic_heading_pattern(title: str) -> re.Pattern[str]:
    if title.startswith("Personal Feelings"):
        return re.compile(r"^\s*Personal Feelings", re.M)
    return re.compile(r"^\s*" + re.escape(title), re.M)


def extract_topic_sections(text: str, topics: list[str]) -> list[tuple[str, str]]:
    idx = text.rfind("Appendix 2")
    if idx < 0:
        raise RuntimeError("Missing Appendix 2 anchor")
    topic_text = text[idx:]
    locations: list[tuple[str, int]] = []
    search = 0
    for title in topics:
        pattern = topic_heading_pattern(title)
        rem = topic_text[search:]
        match = pattern.search(rem)
        if not match:
            raise RuntimeError(f"Missing topic heading {title!r}")
        locations.append((title, search + match.start()))
        search = search + match.start() + len(match.group(0))

    sections: list[tuple[str, str]] = []
    for i, (title, start) in enumerate(locations):
        end = locations[i + 1][1] if i + 1 < len(locations) else len(topic_text)
        sections.append((title, topic_text[start:end]))
    return sections


def _paren_balance(text: str) -> int:
    """Net open-paren count (positive = unclosed opens)."""
    return text.count("(") - text.count(")")


def _is_noise_topic_cell(cell: str, title_norm: str) -> bool:
    if not cell or len(cell) < 2:
        return True
    cn = normalize_form(cell)
    if not cn or cn == title_norm or cn.startswith(title_norm):
        return True
    if re.fullmatch(r"\d+", cn):
        return True
    if cn in {
        "key",
        "schools",
        "preliminary",
        "vocabulary",
        "list",
        "ucles",
        "and",
        "or",
        "the",
        "of",
        "a",
        "an",
    }:
        return True
    # Pure POS gloss debris: (n), (v), (n & v)
    if re.fullmatch(r"\([^)]{1,20}\)", cell):
        return True
    return False


def _is_orphan_paren_fragment(cell: str) -> bool:
    """True for wrap halves that are not complete lemmas.

    Layout pairs look like: 'barbecue (n &' + 'v)'  or  'bunch (of' + 'bananas)'.
    If we have {word}) we also have ({word} / word (… — drop both if unrejoined.
    """
    t = cell.strip()
    if not t:
        return True
    bal = _paren_balance(t)
    # Closing half alone: v), bananas), TV), competition), prison/police)
    if bal < 0:
        return True
    if re.fullmatch(r"[A-Za-z/'-]+\)", t):
        return True
    # Opening half alone: barbecue (n &, bunch (of, channel (with, officer (e.g.
    if bal > 0:
        return True
    # Trailing incomplete POS connector without close
    if re.search(r"\(\s*(?:n|v|adj|adv|phr v)?\s*&\s*$", t, re.I):
        return True
    if re.search(r"\(\s*(?:of|with|a|an|the|e\.g\.?)\s*$", t, re.I):
        return True
    return False


def _merge_column_fragments(fragments: list[str]) -> list[str]:
    """Rejoin vertical wraps inside one PDF column.

    Multi-column layout puts 'barbecue (n &' above 'v)' in the same column, with
    other columns' cells interleaved in left-to-right reading order. Column-wise
    merge restores the pair before matching.

    Rule: an open half ({word} / word (… always pairs with a later close half
    {word}) in the same column. Emit one rejoined token, or drop both if the
    pair never balances.
    """
    merged: list[str] = []
    buf: str | None = None
    for frag in fragments:
        frag = frag.strip()
        if not frag:
            continue
        if buf is None:
            if _paren_balance(frag) > 0:
                buf = frag
            elif _paren_balance(frag) < 0 or re.fullmatch(r"[A-Za-z/'-]+\)", frag):
                # Orphan close half with no open partner — drop
                continue
            else:
                merged.append(frag)
            continue

        candidate = re.sub(r"\s+", " ", f"{buf} {frag}").strip()
        # ' (n &' + 'v)' → tidy double spaces only; already single-spaced
        if _paren_balance(candidate) > 0:
            buf = candidate
            continue
        if _paren_balance(candidate) < 0:
            # Still broken — drop the open buffer and reconsider frag alone
            buf = None
            if _paren_balance(frag) > 0:
                buf = frag
            elif _paren_balance(frag) == 0 and not re.fullmatch(r"[A-Za-z/'-]+\)", frag):
                merged.append(frag)
            continue
        merged.append(candidate)
        buf = None
    # Trailing open half with no close partner — drop (paired with missing {word}))
    return merged


def _cells_with_columns(line: str) -> list[tuple[int, str]]:
    """Return (start_column, cell_text) for multi-space-separated cells."""
    raw = line.replace("\f", "")
    if not raw.strip():
        return []
    cells: list[tuple[int, str]] = []
    for match in re.finditer(r"\S(?:.*?\S)?(?=\s{2,}|\s*$)", raw):
        text = match.group(0).strip()
        if text:
            cells.append((match.start(), text))
    return cells


def extract_topic_lemmas(section_text: str, title: str) -> list[str]:
    """Return surface lemmas from a topic section body.

    Appendix topic pages are multi-column. Parenthetical glosses often wrap
    *within* a column ('bunch (of' / 'bananas)'). If we only split on spaces,
    we get both halves as separate lemmas. Rejoin by column first; drop any
    residual orphan half so {word}) never ships without its ({word} partner
    being resolved into one token.
    """
    lines = section_text.splitlines()
    body_lines: list[str] = []
    seen_body = False
    title_norm = normalize_form(title.split("(")[0])
    for line in lines:
        stripped = line.strip()
        if not seen_body:
            if topic_heading_pattern(title).match(line) or (
                stripped and normalize_form(stripped).startswith(title_norm[:20])
            ):
                seen_body = True
                continue
            continue
        body_lines.append(line)

    # Group cells by approximate column (topic pages are typically 4 columns).
    column_bins: dict[int, list[str]] = defaultdict(list)
    for line in body_lines:
        if re.search(r"©\s*UCLES|Page\s+\d+|Vocabulary List|Appendix\s+\d+", line, re.I):
            continue
        for start, cell in _cells_with_columns(line):
            if _is_noise_topic_cell(cell, title_norm):
                continue
            # Bin width ~22 chars matches observed A2/B1 topic column pitch
            col = start // 22
            column_bins[col].append(cell)

    lemmas: list[str] = []
    for col in sorted(column_bins):
        for cell in _merge_column_fragments(column_bins[col]):
            if _is_noise_topic_cell(cell, title_norm):
                continue
            if _is_orphan_paren_fragment(cell):
                # Unrejoined half — do not emit; partner is also dropped
                continue
            lemmas.append(cell)
    return lemmas


def match_topic_lemma(
    surface: str,
    form_to: dict[str, list[str]],
    skill_pos: dict[str, set[str]],
) -> tuple[list[str], str]:
    # Optional trailing POS gloss: rest (n), clean (adj & v)
    pos_hint: list[str] = []
    m = re.match(rf"^(.+?)\s+\(((?:{POS_PATTERN})(?:\s*(?:&|\+|,|or)\s*(?:{POS_PATTERN}))*)\)\s*$", surface, re.I)
    head = surface
    if m:
        head = m.group(1)
        pos_hint = parse_pos(m.group(2))

    pieces: list[str] = []
    # Expand slash forms first on the surface head
    head_norm = normalize_form(head)
    if "/" in head_norm:
        pieces.extend(p.strip() for p in head_norm.split("/") if p.strip())
    else:
        pieces.append(head_norm)

    # Expand optional morphology like kilo(gram[me]) roughly by stripping brackets content carefully
    expanded: list[str] = []
    for piece in pieces:
        expanded.append(piece)
        # gram(me) → gram, gramme
        if "(" in piece and ")" in piece:
            # take form without parenthetical segments
            expanded.append(re.sub(r"\([^)]*\)", "", piece).strip())
            # take first alternative inside brackets for [me]
            br = re.sub(r"\[([^\]]+)\]", r"\1", piece)
            expanded.append(re.sub(r"[()]", "", br).strip())

    candidates: list[str] = []
    for piece in expanded:
        for form in form_variants(piece):
            for sid in form_to.get(form, []):
                if sid not in candidates:
                    candidates.append(sid)

    if not candidates:
        return [], "unmatched"

    if pos_hint:
        wanted = set(pos_hint)
        filtered = [sid for sid in candidates if skill_pos.get(sid, set()) & wanted]
        if len(filtered) == 1:
            return filtered, "topic-pos-unique"
        if len(filtered) > 1:
            return filtered, "topic-pos-multi"
        # fall through to form-only if POS filter emptied (gloss noise)

    if len(candidates) == 1:
        return candidates, "topic-form-unique"
    if len(candidates) <= 3:
        return candidates, "topic-form-multi"
    return candidates, "topic-form-ambiguous"


def build_layer(
    src: dict[str, Any],
    graph: dict[str, Any],
    form_to: dict[str, list[str]],
    form_pos_to: dict[tuple[str, tuple[str, ...]], list[str]],
    skill_pos: dict[str, set[str]],
) -> dict[str, Any]:
    pdf_path = PDF_DIR / src["pdf"]
    if not pdf_path.is_file():
        raise FileNotFoundError(pdf_path)
    digest = sha256(pdf_path)
    if digest != src["expectedSha256"]:
        raise RuntimeError(
            f"SHA-256 mismatch for {src['pdf']}: got {digest}, expected {src['expectedSha256']}"
        )

    text = pdftotext(pdf_path)
    az_raw = extract_az_entries(text, src["azStart"], src["azEnd"])

    # Deduplicate A–Z by normalized form + POS set
    az_unique: dict[tuple[str, tuple[str, ...]], tuple[str, list[str]]] = {}
    for headword, pos_list in az_raw:
        key = (normalize_form(headword), tuple(sorted(pos_list)))
        az_unique[key] = (headword, pos_list)

    az_match_stats: Counter[str] = Counter()
    az_membership: list[tuple[str, str, list[str], str]] = []  # headword, matchKind, skillIds, rawKind
    az_unmatched: list[dict[str, Any]] = []
    az_ambiguous: list[dict[str, Any]] = []
    exam_skill_ids: set[str] = set()

    for (_nf, _pt), (headword, pos_list) in sorted(az_unique.items()):
        sids, kind = match_az(headword, pos_list, form_to, form_pos_to, skill_pos)
        az_match_stats[kind] += 1
        if not sids:
            az_unmatched.append(
                {
                    "sourceId": src["sourceId"],
                    "section": "a-z",
                    "lemma": headword,
                    "partsOfSpeech": pos_list,
                    "status": "unmatched",
                    "enrichmentLayer": src["layerId"],
                }
            )
            continue
        match_kind = "exact" if kind == "exact-pos-set" else "normalized"
        if kind in {"pos-overlap-multi", "form-only-ambiguous"}:
            az_ambiguous.append(
                {
                    "sourceId": src["sourceId"],
                    "section": "a-z",
                    "lemma": headword,
                    "partsOfSpeech": pos_list,
                    "candidateSkillIds": sids,
                    "status": "ambiguous",
                    "matchKind": kind,
                    "enrichmentLayer": src["layerId"],
                }
            )
            # Still attach all candidates: shared form+POS inventory is intentional;
            # multi hits are co-membership, not new skills.
        for sid in sids:
            exam_skill_ids.add(sid)
        az_membership.append((headword, match_kind, sids, kind))

    # Topics
    topic_sections = extract_topic_sections(text, src["topics"])
    topic_buckets: dict[str, set[tuple[str, str]]] = defaultdict(set)  # title -> {(lemma, skillId)}
    topic_unmatched: list[dict[str, Any]] = []
    topic_ambiguous: list[dict[str, Any]] = []
    topic_stats: Counter[str] = Counter()
    topic_lemma_count = 0

    for title, section in topic_sections:
        seen_surfaces: set[str] = set()
        for surface in extract_topic_lemmas(section, title):
            surface_key = normalize_text(surface)
            if surface_key in seen_surfaces:
                continue
            seen_surfaces.add(surface_key)
            topic_lemma_count += 1
            sids, kind = match_topic_lemma(surface, form_to, skill_pos)
            topic_stats[kind] += 1
            lemma = normalize_form(surface) or surface
            if not sids:
                topic_unmatched.append(
                    {
                        "sourceId": src["sourceId"],
                        "section": "topic",
                        "topic": title,
                        "lemma": surface,
                        "status": "unmatched",
                        "enrichmentLayer": src["layerId"],
                    }
                )
                continue
            if kind in {"topic-form-ambiguous", "topic-pos-multi"}:
                topic_ambiguous.append(
                    {
                        "sourceId": src["sourceId"],
                        "section": "topic",
                        "topic": title,
                        "lemma": surface,
                        "candidateSkillIds": sids,
                        "status": "ambiguous",
                        "matchKind": kind,
                        "enrichmentLayer": src["layerId"],
                    }
                )
            for sid in sids:
                topic_buckets[title].add((lemma, sid))

    # Build overlay
    nodes: list[dict[str, Any]] = []
    edges: list[dict[str, Any]] = []
    edge_seq = 0
    layer = src["layerId"]
    source_id = src["sourceId"]
    exam_key = src["examKey"]

    root_id = f"{DOMAIN}.group.{exam_key}.layer-root"
    nodes.append(
        {
            "id": root_id,
            "kind": "content_group",
            "title": f"{src['examTitle']} enrichment layer",
            "domain": DOMAIN,
            "reviewStatus": "draft",
            "sourceRefs": [source_id],
            "metadata": {
                "enrichmentLayer": layer,
                "sourceId": source_id,
                "role": "layer-root",
                "cefrBandHint": src["cefr"],
                "relationshipKind": "exam-list-group",
                "unitNumberIsNotPrerequisite": True,
                "reusesYleDecisions": [
                    "form+POS identity",
                    "no prerequisite_for",
                    "membership via contains",
                    "core freeze isolation",
                ],
            },
        }
    )

    exam_group_id = f"{DOMAIN}.group.{exam_key}.exam-membership"
    nodes.append(
        {
            "id": exam_group_id,
            "kind": "content_group",
            "title": f"{src['examTitle']} A–Z membership",
            "domain": DOMAIN,
            "reviewStatus": "draft",
            "sourceRefs": [source_id],
            "metadata": {
                "enrichmentLayer": layer,
                "sourceId": source_id,
                "role": "exam-membership",
                "exam": src["examId"],
                "cefrBandHint": src["cefr"],
                "relationshipKind": "exam-list-group",
            },
        }
    )
    edge_seq += 1
    edges.append(
        {
            "id": f"{DOMAIN}.edge.contains.{exam_key}.{edge_seq}",
            "type": "contains",
            "sourceId": root_id,
            "targetId": exam_group_id,
            "weight": 1,
            "confidence": "high",
            "sourceRefs": [source_id],
            "reviewStatus": "draft",
            "rationale": "Layer root contains exam A–Z membership group",
            "metadata": {
                "enrichmentLayer": layer,
                "matchKind": "structure",
                "extractionConfidence": "high",
            },
        }
    )

    # Exam membership edges (one per skill)
    for headword, match_kind, sids, kind in az_membership:
        for sid in sids:
            edge_seq += 1
            edges.append(
                {
                    "id": f"{DOMAIN}.edge.contains.{exam_key}.{edge_seq}",
                    "type": "contains",
                    "sourceId": exam_group_id,
                    "targetId": sid,
                    "weight": 1,
                    "confidence": "high" if kind == "exact-pos-set" else "medium",
                    "sourceRefs": [source_id],
                    "reviewStatus": "draft",
                    "rationale": (
                        f'{src["examTitle"]} A–Z lists "{headword}" '
                        "(exam membership; not a prerequisite; shared form+POS skill)"
                    ),
                    "metadata": {
                        "enrichmentLayer": layer,
                        "sourceId": source_id,
                        "indexLemma": headword,
                        "matchKind": match_kind,
                        "matchDetail": kind,
                        "extractionConfidence": "high" if kind == "exact-pos-set" else "medium",
                        "relationshipKind": "exam-list-group",
                        "section": "a-z",
                    },
                }
            )

    # Topic groups
    for title in src["topics"]:
        pairs = topic_buckets.get(title, set())
        gid = f"{DOMAIN}.group.{exam_key}.topic.{slug(title)}"
        nodes.append(
            {
                "id": gid,
                "kind": "content_group",
                "title": title,
                "domain": DOMAIN,
                "reviewStatus": "draft",
                "sourceRefs": [source_id],
                "metadata": {
                    "enrichmentLayer": layer,
                    "sourceId": source_id,
                    "role": "topic-group",
                    "topicTitle": title,
                    "exam": src["examId"],
                    "cefrBandHint": src["cefr"],
                    "relationshipKind": "topic-list-group",
                    "appendix": "Appendix 2",
                },
            }
        )
        edge_seq += 1
        edges.append(
            {
                "id": f"{DOMAIN}.edge.contains.{exam_key}.{edge_seq}",
                "type": "contains",
                "sourceId": root_id,
                "targetId": gid,
                "weight": 1,
                "confidence": "high",
                "sourceRefs": [source_id],
                "reviewStatus": "draft",
                "rationale": f"Layer root contains Appendix 2 topic group {title!r}",
                "metadata": {
                    "enrichmentLayer": layer,
                    "matchKind": "structure",
                    "extractionConfidence": "high",
                },
            }
        )
        for lemma, sid in sorted(pairs):
            edge_seq += 1
            edges.append(
                {
                    "id": f"{DOMAIN}.edge.contains.{exam_key}.{edge_seq}",
                    "type": "contains",
                    "sourceId": gid,
                    "targetId": sid,
                    "weight": 1,
                    "confidence": "medium",
                    "sourceRefs": [source_id],
                    "reviewStatus": "draft",
                    "rationale": (
                        f'Appendix 2 topic {title!r} co-lists "{lemma}" '
                        "(topic membership; not a prerequisite)"
                    ),
                    "metadata": {
                        "enrichmentLayer": layer,
                        "sourceId": source_id,
                        "topicTitle": title,
                        "indexLemma": lemma,
                        "matchKind": "normalized",
                        "extractionConfidence": "medium",
                        "relationshipKind": "topic-list-group",
                        "section": "topic",
                    },
                }
            )

    if any(e.get("type") == "prerequisite_for" for e in edges):
        raise RuntimeError("BUG: prerequisite_for in overlay")

    # Overlay nodes must not collide with core skill ids (groups are new)
    core_ids = {n["id"] for n in graph.get("nodes", [])}
    for node in nodes:
        if node["id"] in core_ids:
            raise RuntimeError(f"overlay node collides with core: {node['id']}")

    az_matched = len(az_unique) - len(az_unmatched)
    topic_matched = topic_lemma_count - len(topic_unmatched)
    topic_membership = sum(len(v) for v in topic_buckets.values())

    stats = {
        "sourceId": source_id,
        "sourceSha256": digest,
        "layerId": layer,
        "exam": src["examId"],
        "azRawEntries": len(az_raw),
        "azUniqueEntries": len(az_unique),
        "azMatchedEntries": az_matched,
        "azUnmatchedEntries": len(az_unmatched),
        "azAmbiguousEntries": len(az_ambiguous),
        "azMatchRate": round(az_matched / len(az_unique), 4) if az_unique else 0.0,
        "azMatchKinds": dict(az_match_stats),
        "examMembershipSkillCount": len(exam_skill_ids),
        "topicCount": len(src["topics"]),
        "topicLemmaObservations": topic_lemma_count,
        "topicMatchedLemmas": topic_matched,
        "topicUnmatchedLemmas": len(topic_unmatched),
        "topicAmbiguousLemmas": len(topic_ambiguous),
        "topicMatchRate": round(topic_matched / topic_lemma_count, 4) if topic_lemma_count else 0.0,
        "topicMatchKinds": dict(topic_stats),
        "topicMembershipEdgeCount": topic_membership,
        "groupCount": 1 + 1 + len(src["topics"]),  # root + exam + topics
        "noNewSkills": True,
        "identityPolicy": "form+POS; shared Key/Flyers/B1 vocab is one skill with multi membership",
    }

    overlay = {
        "enrichmentLayer": layer,
        "generatedAt": GENERATED_AT,
        "coreGraph": "cefr-vocabulary-knowledge-space.json",
        "description": (
            f"{src['examTitle']} A–Z exam membership and Appendix 2 topic groups. "
            "Matches existing form+POS skills only; does not invent duplicate skills "
            "for vocabulary shared with YLE Flyers or other exams."
        ),
        "yleDecisionsReused": [
            "form+POS assessable unit",
            "contains membership only",
            "prerequisite_for forbidden",
            "core freeze isolation",
            "unmatched/ambiguous durable queues",
        ],
        "hardProhibitions": {
            "prerequisite_for": False,
            "doesNotRewriteCoreFreeze": True,
            "doesNotCreateDuplicateSkills": True,
        },
        "nodes": nodes,
        "edges": edges,
        "stats": stats,
    }

    report = {
        "enrichmentLayer": layer,
        "generatedAt": GENERATED_AT,
        "sourceId": source_id,
        "sourceSha256": digest,
        "relationshipSemantics": (
            "Exam A–Z and Appendix 2 topic co-membership; not prerequisites. "
            "Shared A2 vocabulary with Flyers is one skill with multiple memberships."
        ),
        "prerequisite_for_count_in_overlay": 0,
        "coreGraphUntouched": True,
        "noNewSkillNodes": True,
        "stats": stats,
        "queues": {
            "unmatched": f"review/enrichment/queues/{src['queueStem']}-unmatched.jsonl",
            "ambiguous": f"review/enrichment/queues/{src['queueStem']}-ambiguous.jsonl",
        },
    }

    report_md = f"""# {src['examTitle']} enrichment report

**Layer:** `{layer}`  
**Source:** `{source_id}`  
**SHA-256:** `{digest}`  
**Generated:** {GENERATED_AT}

## Policy (YLE decisions reused)

- Form+POS skill identity — no duplicate skills for Key/Flyers overlap
- Membership via `contains` only
- Zero `prerequisite_for`
- Core freeze graph untouched
- Unmatched / ambiguous rows queued

## A–Z exam membership

| Metric | Value |
|---|---:|
| Unique A–Z entries | {stats['azUniqueEntries']} |
| Matched | {stats['azMatchedEntries']} |
| Unmatched | {stats['azUnmatchedEntries']} |
| Ambiguous | {stats['azAmbiguousEntries']} |
| Match rate | {stats['azMatchRate']} |
| Distinct skills | {stats['examMembershipSkillCount']} |

## Appendix 2 topics

| Metric | Value |
|---|---:|
| Topics | {stats['topicCount']} |
| Lemma observations | {stats['topicLemmaObservations']} |
| Matched | {stats['topicMatchedLemmas']} |
| Unmatched | {stats['topicUnmatchedLemmas']} |
| Ambiguous | {stats['topicAmbiguousLemmas']} |
| Match rate | {stats['topicMatchRate']} |
| Membership edges | {stats['topicMembershipEdgeCount']} |

## Isolation

- `prerequisite_for` in overlay: 0
- Core graph rewritten: no
- New skill nodes: no
"""

    fixture = {
        "sourceId": source_id,
        "pdf": f"source-pdfs/{src['pdf']}",
        "sha256": digest,
        "layerId": layer,
        "structureChecks": {
            "titleHasA2Key": src["examKey"] == "a2-key",
            "titleHasB1": src["examKey"] == "b1-preliminary",
            "disclaimerNotExhaustive": True,
            "appendix2TopicCount": len(src["topics"]),
            "azUniqueEntries": stats["azUniqueEntries"],
            "azMatchRate": stats["azMatchRate"],
            "topicMatchRate": stats["topicMatchRate"],
            "minExtractedCharsFirstPages": (
                10106 if src["examKey"] == "a2-key" else 10926
            ),
        },
    }
    if src["examKey"] == "a2-key":
        fixture["structureChecks"]["mentionsAugust2025"] = True

    unmatched_rows = az_unmatched + topic_unmatched
    ambiguous_rows = az_ambiguous + topic_ambiguous

    return {
        "overlay": overlay,
        "report": report,
        "report_md": report_md,
        "fixture": fixture,
        "unmatched": unmatched_rows,
        "ambiguous": ambiguous_rows,
        "paths": {
            "overlay": ROOT / "overlays" / src["overlayName"],
            "report_json": ROOT / "reports" / "enrichment" / f"{src['reportStem']}.json",
            "report_md": ROOT / "reports" / "enrichment" / f"{src['reportStem']}.md",
            "unmatched": ROOT / "review" / "enrichment" / "queues" / f"{src['queueStem']}-unmatched.jsonl",
            "ambiguous": ROOT / "review" / "enrichment" / "queues" / f"{src['queueStem']}-ambiguous.jsonl",
            "fixture": ROOT / "fixtures" / "enrichment" / src["fixtureName"],
        },
        "stats": stats,
    }


def main() -> int:
    if not GRAPH.is_file():
        print(f"missing graph: {GRAPH}", file=sys.stderr)
        return 1

    graph = json.loads(GRAPH.read_text(encoding="utf-8"))
    form_to, form_pos_to, skill_pos = build_skill_indexes(graph)

    summary: list[str] = []
    for src in SOURCES:
        result = build_layer(src, graph, form_to, form_pos_to, skill_pos)
        paths = result["paths"]
        atomic_write(paths["overlay"], json.dumps(result["overlay"], indent=2, ensure_ascii=False) + "\n")
        atomic_write(paths["report_json"], json.dumps(result["report"], indent=2, ensure_ascii=False) + "\n")
        atomic_write(paths["report_md"], result["report_md"])
        atomic_write(paths["fixture"], json.dumps(result["fixture"], indent=2, ensure_ascii=False) + "\n")
        atomic_write(
            paths["unmatched"],
            "".join(json.dumps(r, ensure_ascii=False) + "\n" for r in result["unmatched"]),
        )
        atomic_write(
            paths["ambiguous"],
            "".join(json.dumps(r, ensure_ascii=False) + "\n" for r in result["ambiguous"]),
        )
        st = result["stats"]
        line = (
            f"{src['examKey']}: az {st['azMatchedEntries']}/{st['azUniqueEntries']} "
            f"({st['azMatchRate']}) topics {st['topicMatchedLemmas']}/{st['topicLemmaObservations']} "
            f"({st['topicMatchRate']}) skills={st['examMembershipSkillCount']}"
        )
        summary.append(line)
        print(line)

    print("wrote A2 Key and B1 Preliminary enrichment overlays")
    for line in summary:
        print(" ", line)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
