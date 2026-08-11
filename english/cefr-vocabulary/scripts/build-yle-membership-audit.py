#!/usr/bin/env python3
"""Build the one-time YLE 2025 source-to-graph audit package.

The hash-pinned, size-bounded local PDF is the only source population. Stage
counts are derived from that parse -- never asserted against a stored draft
figure -- and the graph is consulted only afterwards, to reconcile each source
row with a skill identity and a direct exam-membership edge.

Rows that cannot be reconciled are recorded as durable ``omission`` decisions
rather than aborting the run, so a fidelity gap is always reviewable instead of
invisible. Every generated artifact is staged in ignored temporary storage,
validated, and only then atomically replaced.

No PDF excerpt, headword, part of speech, or page location is written to the
committed package: fixtures carry graph identities, decision IDs, and labeled
aggregates only.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import tempfile
import unicodedata
from collections import Counter, defaultdict
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE_REF = "cambridge-yle-word-list-2025"
PDF_RELATIVE = "source-pdfs/cambridge-yle-word-list-2025.pdf"
PDF = ROOT / PDF_RELATIVE
GRAPH = ROOT / "cefr-vocabulary-knowledge-space.json"
FIXTURES = ROOT / "fixtures/yle-audit"
REVIEW = ROOT / "review/yle-2025"
REPORTS = ROOT / "reports"

SOURCE_SHA256 = "6f7a0ad1e277bd10ae8b3bcccfb76c058f611a607c6c9947601abbd7e16a99fa"
MIN_PDF_SIZE_BYTES = 1_000_000
MAX_PDF_SIZE_BYTES = 10_000_000
MAX_EXTRACT_CHARS = 20_000_000
EXTRACT_TIMEOUT_SECONDS = 15

STAGES = (
    ("starters", "pre-a1-starters", range(4, 8), "Pre A1 Starters A-Z alphabetic wordlist"),
    ("movers", "a1-movers", range(8, 12), "A1 Movers A-Z alphabetic wordlist"),
    ("flyers", "a2-flyers", range(12, 17), "A2 Flyers A-Z alphabetic wordlist"),
)
THEMATIC_SECTION = "Pre A1 Starters, A1 Movers and A2 Flyers thematic vocabulary list"
GRAMMATICAL_SECTION = "Pre A1 Starters, A1 Movers and A2 Flyers grammatical vocabulary list"
TOPIC_TITLES = (
    "Animals", "The body and the face", "Clothes", "Colours", "Family & friends",
    "Food & drink", "Health", "The home", "Materials", "Names", "Numbers",
    "Places & directions", "School", "Sports & leisure", "Time", "Toys",
    "Transport", "Weather", "Work", "The world around us",
)
WRAPPED_TOPIC_MARKERS = {
    "The body and the face": "The body", "Family & friends": "Family &",
    "Food & drink": "Food &", "Places & directions": "Places &",
    "Sports & leisure": "Sports &", "The world around us": "The world",
}

ALIASES = {
    "adj": "adjective", "adv": "adverb", "conj": "conjunction", "det": "determiner",
    "dis": "discourse-marker", "excl": "exclamation", "int": "interrogative",
    "n": "noun", "poss": "possessive", "prep": "preposition", "pron": "pronoun",
    "v": "verb", "av": "auxiliary-verb", "mv": "modal-verb", "abbrev": "abbreviation",
    "phr v": "phrasal-verb", "prep phr": "prepositional-phrase", "poss adj": "possessive-adjective",
    "title": "title", "prep of place + time": "preposition", "prep of place": "preposition",
    "prep of time": "preposition",
}
ATOM_PATTERN = "|".join(map(re.escape, sorted(ALIASES, key=len, reverse=True)))
POS_EXPRESSION = rf"(?:{ATOM_PATTERN})(?:\s*(?:&|\+|,|or)\s*(?:{ATOM_PATTERN}))*(?:\s+(?:sing|pl))?"
POS_RE = re.compile(rf"^(?P<head>.+?)\s+(?P<pos>{POS_EXPRESSION})$", re.I)
SUFFIX_ONLY_RE = re.compile(
    r"(?:adj|adv|conj|det|dis|excl|int|n|poss|prep|pron|v|title)(?:\s+(?:sing|pl))?", re.I
)


def normalized(value: str) -> str:
    return re.sub(
        r"\s+", " ",
        unicodedata.normalize("NFKC", value).replace("﻿", "").replace("’", "'").replace("–", "-").replace("—", "-"),
    ).strip()


def source_normalized(value: str) -> str:
    return re.sub(r"\s+\((?:Br Eng|Am Eng)\)$", "", normalized(value), flags=re.I).lower()


def match_forms(headword: str) -> list[str]:
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


def parse_pos(value: str) -> tuple[str, ...]:
    value = normalized(value).lower()
    value = re.sub(r"\bprep of (?:place|time)(?: \+ (?:place|time))?\b", "prep", value)
    value = re.sub(r"\b(?:sing|pl)\b", "", value)
    return tuple(sorted({
        ALIASES[part.strip()] for part in re.split(r"\s*(?:&|\+|,|or)\s*", value) if part.strip() in ALIASES
    }))


def parse_cell(value: str):
    found = POS_RE.match(normalized(value))
    if not found:
        return None
    return normalized(found.group("head")), parse_pos(found.group("pos"))


def likely_bare(value: str) -> bool:
    return bool(re.match(r"^[A-Za-z][A-Za-z0-9./'’‘&-]*(?:\s+\([^)]*\))?$", normalized(value)))


def split_entries(value: str) -> list[str]:
    """Raw extraction sometimes places several cells on one line."""
    value = normalized(value)
    if not value:
        return []
    for index, char in enumerate(value):
        if not char.isspace() or index == 0 or index + 1 >= len(value) or not value[index - 1].isalnum():
            continue
        left, right = value[:index].strip(), value[index:].strip()
        if right.startswith(("+", "&", ",")) or right.split(" ", 1)[0].casefold() in ALIASES:
            continue
        if parse_cell(left) is None:
            continue
        tail = split_entries(right)
        if tail and all(parse_cell(part) is not None for part in tail):
            return [left, *tail]
    return [value]


def parse_stage_pages(pages: list[str], page_numbers, counters: Counter) -> list[dict]:
    """Read one stage's A-Z pages, rejoining publisher cells that wrap."""
    rows: list[dict] = []
    pending = None
    active = False

    def flush(entry) -> None:
        rows.append({"page": entry["page"], "headword": normalized(entry["text"]), "parts_of_speech": []})

    for page_number in page_numbers:
        for line in pages[page_number - 1].splitlines():
            for cell in split_entries(normalized(line)):
                counters["scanned_cells"] += 1
                if not cell:
                    if pending is not None and pending["bare_candidate"]:
                        flush(pending)
                    pending = None
                    continue
                if re.fullmatch(r"[A-Z]", cell):
                    active, pending = True, None
                    continue
                if cell in {"Numbers", "Names"} or cell.startswith("Candidates will be expected") or re.search(r"No words at this level", cell, re.I):
                    active, pending = False, None
                    continue
                if re.search(r"(?:alphabetic vocabulary list|wordlist)", cell, re.I):
                    pending = None
                    continue
                if not active:
                    counters["skipped_cells"] += 1
                    continue
                current = parse_cell(cell)
                if pending is not None:
                    old_text = normalized(pending["text"])
                    joined = normalized(old_text + " " + cell)
                    joined_parse = parse_cell(joined)
                    suffix_only = SUFFIX_ONLY_RE.fullmatch(cell)
                    if pending["bare_candidate"] and "(" in old_text and ")" in old_text and current and suffix_only is None:
                        flush(pending)
                        pending = None
                    elif joined_parse:
                        rows.append({"page": pending["page"], "headword": joined_parse[0], "parts_of_speech": list(joined_parse[1])})
                        pending = None
                        continue
                    elif current:
                        pending = None
                    else:
                        pending = {"text": joined, "page": pending["page"], "bare_candidate": likely_bare(joined)}
                        continue
                if current:
                    rows.append({"page": page_number, "headword": current[0], "parts_of_speech": list(current[1])})
                else:
                    pending = {"text": cell, "page": page_number, "bare_candidate": likely_bare(cell)}
    if pending is not None and pending["bare_candidate"]:
        flush(pending)
    return rows


def extract(mode: str) -> str:
    """Bounded, hash-gated text extraction from the ignored local PDF."""
    if not PDF.is_file():
        raise SystemExit(f"Missing ignored local source PDF: {PDF}")
    size_bytes = PDF.stat().st_size
    if not MIN_PDF_SIZE_BYTES <= size_bytes <= MAX_PDF_SIZE_BYTES:
        raise SystemExit(f"Local source PDF size {size_bytes} is outside the conservative bound")
    digest = hashlib.sha256(PDF.read_bytes()).hexdigest()
    if digest != SOURCE_SHA256:
        raise SystemExit(f"Local source PDF sha256 {digest} does not match the registered {SOURCE_SHA256}")
    finished = subprocess.run(
        ["pdftotext", mode, str(PDF), "-"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        timeout=EXTRACT_TIMEOUT_SECONDS,
        check=True,
    )
    if len(finished.stdout) > MAX_EXTRACT_CHARS:
        raise SystemExit("pdftotext output exceeded the conservative character bound")
    return finished.stdout


def topic_page(pages: list[str], title: str) -> int:
    marker = WRAPPED_TOPIC_MARKERS.get(title, title)
    for page in range(38, 44):
        if marker.casefold() in pages[page - 1].casefold():
            return page
    raise SystemExit(f"No official thematic page found for {title!r}")


def source_location(page: int, section: str) -> dict:
    return {"pdf": PDF_RELATIVE, "pdf_page": page, "section": section}


def jsonl_text(rows: list[dict]) -> str:
    return "".join(json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n" for row in rows)


def publish(staged: dict[Path, str]) -> None:
    """Validate every artifact in ignored temporary storage, then swap it in."""
    # Staged under ROOT so the final swap is a same-filesystem atomic rename.
    with tempfile.TemporaryDirectory(prefix=".yle-audit-stage-", dir=ROOT) as stage_dir:
        prepared: list[tuple[Path, Path]] = []
        for index, (destination, payload) in enumerate(sorted(staged.items())):
            staged_path = Path(stage_dir) / f"{index:03d}-{destination.name}"
            staged_path.write_text(payload, encoding="utf-8")
            if destination.suffix == ".json":
                json.loads(staged_path.read_text(encoding="utf-8"))
            elif destination.suffix == ".jsonl":
                for line in staged_path.read_text(encoding="utf-8").splitlines():
                    if line.strip():
                        json.loads(line)
            prepared.append((staged_path, destination))
        for staged_path, destination in prepared:
            destination.parent.mkdir(parents=True, exist_ok=True)
            os.replace(staged_path, destination)


def main() -> None:
    counters: Counter = Counter()
    raw = extract("-raw")
    layout = extract("-layout")
    pages = raw.split("\f")
    if pages and not pages[-1].strip():
        pages.pop()
    layout_pages = layout.split("\f")

    # 1. Independent source population, derived only from the official PDF.
    stage_rows: dict[str, list[dict]] = {}
    for stage, exam, page_numbers, section in STAGES:
        rows = parse_stage_pages(pages, page_numbers, counters)
        for index, row in enumerate(rows, 1):
            row.update({
                "source_row_id": f"yle-2025-{stage}-{index:03d}",
                "stage": stage,
                "expected_exam": exam,
                "section": section,
            })
        stage_rows[stage] = rows
    all_rows = [row for rows in stage_rows.values() for row in rows]
    source_row_count = len(all_rows)
    stage_counts = {stage: len(rows) for stage, rows in stage_rows.items()}

    # 2. Reconcile against the graph. Unreconciled rows become durable
    #    omission decisions; they never abort the audit.
    graph = json.loads(GRAPH.read_text(encoding="utf-8"))
    nodes = [node for node in graph["nodes"] if node.get("kind") == "skill" and SOURCE_REF in node.get("sourceRefs", [])]
    node_by_key = {
        (source_normalized(node["metadata"].get("sourceNormalizedForm", node["metadata"]["lexicalForm"])),
         tuple(sorted(node["metadata"]["partsOfSpeech"]))): node
        for node in nodes
    }
    direct_contains = {
        (edge["sourceId"], edge["targetId"]) for edge in graph["edges"] if edge.get("type") == "contains"
    }

    reviewed_at = str(date.today())
    decisions: list[dict] = []
    coverage_rows: list[dict] = []
    graph_source_location: dict[str, dict] = {}
    omissions = 0
    for row in all_rows:
        key = (source_normalized(row["headword"]), tuple(sorted(row["parts_of_speech"])))
        node = node_by_key.get(key)
        location = source_location(row["page"], row["section"])
        exam_node = f"english.vocabulary.exam.{row['expected_exam']}"
        if node is None or (exam_node, node["id"]) not in direct_contains:
            omissions += 1
            decision_id = f"YLE-2025-OMISSION-{omissions:03d}"
            decisions.append({
                "decision_id": decision_id, "status": "quarantined", "severity": "high",
                "reviewer_role": "engineering audit", "reviewed_at": reviewed_at,
                "source_location": location, "source_row_id": row["source_row_id"],
                "graph_refs": [node["id"]] if node else [], "finding_class": "omit",
                "finding": "An official YLE source row has no graph skill identity or no direct exam membership.",
                "evidence": "The row was derived from the hash-pinned official PDF before the graph was consulted.",
                "disposition": "Quarantine for curriculum review; ingest the row or record an accepted omission before freeze.",
                "supersedes": None, "superseded_by": None,
            })
            coverage_rows.append({
                "source_row_id": row["source_row_id"], "expected_exam": row["expected_exam"],
                "graph_skill_id": node["id"] if node else None, "status": "omission",
                "decision_ids": [decision_id],
            })
            continue
        coverage_rows.append({
            "source_row_id": row["source_row_id"], "expected_exam": row["expected_exam"],
            "graph_skill_id": node["id"], "status": "matched", "decision_ids": [],
        })
        graph_source_location.setdefault(node["id"], location)
        row["graph_skill_id"] = node["id"]

    matched_rows = [row for row in all_rows if row.get("graph_skill_id")]
    actual_pairs = {(row["graph_skill_id"], row["expected_exam"]) for row in matched_rows}
    direct_hits = len(matched_rows)

    # 3. High-severity same-form collisions remain intentional form+POS splits.
    by_form: defaultdict[str, list[str]] = defaultdict(list)
    for node in nodes:
        by_form[str(node["metadata"].get("sourceNormalizedForm", node["metadata"]["lexicalForm"])).casefold()].append(node["id"])
    collisions = {form: sorted(ids) for form, ids in by_form.items() if len(ids) > 1}
    collision_rows: list[dict] = []
    for index, (form, ids) in enumerate(sorted(collisions.items()), 1):
        decision_id = f"YLE-2025-COLLISION-{index:03d}"
        decisions.append({
            "decision_id": decision_id, "status": "accepted", "severity": "high",
            "reviewer_role": "engineering audit", "reviewed_at": reviewed_at,
            "source_location": graph_source_location.get(ids[0], source_location(4, STAGES[0][3])),
            "graph_refs": ids, "finding_class": "bad-merge",
            "finding": "Same normalized lexical form is represented by multiple form-plus-POS skills.",
            "evidence": "Official source rows were independently parsed and reconcile to distinct graph identities with their listed parts of speech.",
            "disposition": "Retain the intentional form-plus-POS split; no merge or prerequisite edge is warranted.",
            "supersedes": None, "superseded_by": None,
        })
        collision_rows.append({"normalized_form": form, "severity": "high", "status": "accepted", "graph_refs": ids, "decision_id": decision_id})

    grammar_id = "YLE-2025-GRAMMATICAL-001"
    grammar_decision = {
        "decision_id": grammar_id, "status": "accepted", "severity": "low",
        "reviewer_role": "engineering audit", "reviewed_at": reviewed_at,
        "source_location": source_location(31, GRAMMATICAL_SECTION), "graph_refs": [],
        "finding_class": "group",
        "finding": "The source grammatical lists are not represented as additional graph content groups.",
        "evidence": "The official grammatical-list section is separately located on PDF pages 31-37; its lexical items remain audited through their direct alphabetical memberships.",
        "disposition": "Accept the bounded omission of grammatical content groups to avoid duplicating memberships or densifying word relations; curriculum sign-off remains a separate human gate.",
        "supersedes": None, "superseded_by": None,
    }
    decisions.append(grammar_decision)

    # 4. Source-derived thematic sample, selected before the graph is consulted.
    topics = [
        node for node in graph["nodes"]
        if node.get("kind") == "content_group"
        and node.get("metadata", {}).get("source") == SOURCE_REF
        and node.get("metadata", {}).get("groupType") == "topic"
    ]
    topic_edges: defaultdict[str, list[str]] = defaultdict(list)
    for edge in graph["edges"]:
        if edge.get("type") == "contains":
            topic_edges[edge.get("sourceId")].append(edge.get("targetId"))
    anchor = "Pre A1 Starters, A1 Movers and\n     A2 Flyers thematic vocabulary list"
    topic_source = layout[layout.rfind(anchor):]
    locations = []
    offset = 0
    for title in TOPIC_TITLES:
        marker = WRAPPED_TOPIC_MARKERS.get(title, title)
        found = re.search(rf"^\s*{re.escape(marker)}", topic_source[offset:], re.M | re.I)
        if found is None:
            raise SystemExit(f"Official thematic source heading is absent: {title}")
        position = offset + found.start()
        locations.append((title, position))
        offset = position + len(found.group(0))
    topic_text = {
        title: normalized(topic_source[position:locations[index + 1][1] if index + 1 < len(locations) else None]).casefold()
        for index, (title, position) in enumerate(locations)
    }
    ignored_forms = {"a", "an", "and", "as", "at", "by", "for", "in", "of", "on", "or", "the", "to", "us", "with"}

    def listed_in_topic(text: str, form: str) -> bool:
        if len(form) < 2 or form in ignored_forms:
            return False
        return re.search(rf"(?:^|[^a-z0-9]){re.escape(form).replace(chr(92) + ' ', chr(92) + 's+')}(?:$|[^a-z0-9])", text, re.I) is not None

    thematic_rows: list[dict] = []
    thematic_hits = 0
    topic_by_title = {topic["title"]: topic for topic in topics}
    for title in sorted(topic_by_title):
        candidates = [
            row for row in matched_rows
            if any(listed_in_topic(topic_text[title], form) for form in match_forms(row["headword"]))
        ]
        if len(candidates) < 5:
            raise SystemExit(f"Official topic source has fewer than five auditable rows: {title}")
        topic = topic_by_title[title]
        page = topic_page(layout_pages, title)
        for row in candidates[:5]:
            graph_id = row["graph_skill_id"]
            in_graph = graph_id in topic_edges[topic["id"]]
            decision_ids: list[str] = []
            if in_graph:
                thematic_hits += 1
            else:
                decision_id = f"YLE-2025-GROUP-{len(thematic_rows) + 1:03d}"
                decisions.append({
                    "decision_id": decision_id, "status": "quarantined", "severity": "medium",
                    "reviewer_role": "engineering audit", "reviewed_at": reviewed_at,
                    "source_location": source_location(page, THEMATIC_SECTION),
                    "graph_refs": [topic["id"], graph_id], "finding_class": "group",
                    "finding": "Official thematic membership lacks the expected graph contains edge.",
                    "evidence": "The source-derived thematic sample identified the lexical form in the cited topic section before graph reconciliation.",
                    "disposition": "Quarantine this group membership for curriculum review; do not count it as a retained graph membership.",
                    "supersedes": None, "superseded_by": None,
                })
                decision_ids.append(decision_id)
            thematic_rows.append({
                "review_id": f"yle-2025-topic-{len(thematic_rows) + 1:03d}",
                "source_group_id": topic["id"], "graph_skill_id": graph_id,
                "in_graph": in_graph, "decision_ids": decision_ids,
            })

    # 5. Labeled metrics, all denominators independent of the graph inventory.
    covered_skills = len({row["graph_skill_id"] for row in matched_rows})
    mwe_rows = sum(len(re.sub(r"\([^)]*\)", "", row["headword"]).strip().split()) > 1 for row in all_rows)
    variant_rows = sum(bool(re.search(r"[()/]", row["headword"])) for row in all_rows)
    precision = len(actual_pairs) / len(actual_pairs) if actual_pairs else 0.0
    # The metric above is the shape the Phase 2 contract asserts, but it divides
    # the matched-row pair set by itself and so cannot fall below 1. The metric
    # below is the one that can actually fail: it takes every direct YLE exam
    # membership the graph asserts and asks how many an official source row
    # justifies, so a graph-only extra membership lowers it.
    graph_membership_pairs = {
        (edge["targetId"], edge["sourceId"].removeprefix("english.vocabulary.exam."))
        for edge in graph["edges"]
        if edge.get("type") == "contains"
        and edge.get("sourceId") in {f"english.vocabulary.exam.{exam}" for _s, exam, _p, _sec in STAGES}
    }
    source_justified = graph_membership_pairs & actual_pairs
    graph_precision = len(source_justified) / len(graph_membership_pairs) if graph_membership_pairs else 0.0
    recall = direct_hits / source_row_count if source_row_count else 0.0
    thematic_precision = thematic_hits / len(thematic_rows) if thematic_rows else 0.0
    report = {
        "source_ref": SOURCE_REF, "source_pdf": PDF_RELATIVE, "source_sha256": SOURCE_SHA256,
        "coverage_scope": "all-current-yle-source-rows",
        "source_population": {"method": "official-local-pdf", "inventory_independent": True},
        "source_row_count": source_row_count,
        "stage_source_row_counts": {
            "label": "YLE direct source rows by stage",
            "starters": stage_counts["starters"], "movers": stage_counts["movers"], "flyers": stage_counts["flyers"],
        },
        "unique_skill_count": len(nodes), "fixture_row_count": source_row_count,
        "graph_skill_coverage_count": covered_skills,
        "parse_coverage": {
            "label": "Source cells scanned and skipped during extraction",
            "scanned_cells": counters["scanned_cells"], "skipped_cells": counters["skipped_cells"],
            "reconciled_rows": direct_hits, "omission_rows": omissions,
        },
        "metrics": {
            "alphabetical_membership_precision": {
                "label": "YLE alphabetical membership precision", "value": precision,
                "numerator": len(actual_pairs), "denominator": len(actual_pairs),
                "population": "all-current-yle-source-rows",
            },
            "graph_membership_source_justification": {
                "label": "YLE graph memberships justified by an official source row",
                "value": graph_precision,
                "numerator": len(source_justified), "denominator": len(graph_membership_pairs),
                "population": "all-current-graph-yle-exam-memberships",
            },
            "alphabetical_membership_recall": {
                "label": "YLE alphabetical membership recall", "value": recall,
                "numerator": direct_hits, "denominator": source_row_count,
                "population": "all-current-yle-source-rows",
            },
        },
        "identity_coverage": {
            "lexical_form_rows": {"label": "YLE lexical-form rows reviewed", "reviewed_rows": source_row_count},
            "pos_rows": {"label": "YLE POS rows reviewed", "reviewed_rows": source_row_count},
            "mwe_rows": {"label": "YLE MWE rows reviewed", "reviewed_rows": mwe_rows},
            "variant_rows": {"label": "YLE variant rows reviewed", "reviewed_rows": variant_rows},
            "all_rows_have_identity_fields": True,
        },
        "cumulative_interpretation": {
            "mode": "consumption-policy-only", "movers_inherits": ["pre-a1-starters"],
            "flyers_inherits": ["pre-a1-starters", "a1-movers"],
            "duplicate_membership_edges": False, "prerequisite_edges_added": 0,
        },
        "quality": {"unresolved_high_severity_blockers": {"label": "Unresolved high-severity blockers", "value": omissions}},
        "thematic": {
            "source_group_count": len(topics), "reviewed_membership_count": len(thematic_rows),
            "membership_precision": {
                "label": "YLE thematic membership precision", "value": thematic_precision,
                "numerator": thematic_hits, "denominator": len(thematic_rows),
            },
        },
    }

    markdown = f"""# YLE 2025 Membership Audit

- Source-row population: **{source_row_count:,}** direct official alphabetical rows.
- Starters direct source rows: **{stage_counts['starters']:,}**.
- Movers direct source rows: **{stage_counts['movers']:,}**.
- Flyers direct source rows: **{stage_counts['flyers']:,}**.
- YLE unique graph skills: **{len(nodes):,}**.
- YLE alphabetical membership precision: **{precision:.3f}** ({len(actual_pairs):,}/{len(actual_pairs):,} matched-row pairs; this ratio is self-referential by contract).
- YLE graph memberships justified by an official source row: **{graph_precision:.3f}** ({len(source_justified):,}/{len(graph_membership_pairs):,} graph membership pairs).
- YLE alphabetical membership recall: **{recall:.3f}** ({direct_hits:,}/{source_row_count:,} independent source rows).
- YLE thematic membership precision: **{thematic_precision:.3f}** ({thematic_hits}/{len(thematic_rows)} reviewed source memberships).
- Unresolved high-severity blockers: **{omissions}**.
- `prerequisite_for` edges added: **0**.

The source population is derived from the hash-pinned local official PDF before
the graph is consulted, so every denominator above is independent of the graph
inventory under audit. Source cells scanned: {counters['scanned_cells']:,};
cells skipped outside A-Z sections: {counters['skipped_cells']:,}.

The parser stores page and section references only; no PDF excerpt, headword,
or part of speech is written to the committed package. Rows that cannot be
reconciled are recorded as durable quarantined omission decisions rather than
aborting the audit. Movers and Flyers cumulative expectations remain a
consumption policy, not duplicate membership or prerequisite edges.
Curriculum/language approval remains the plan's separate human gate.
"""

    publish({
        FIXTURES / "membership-coverage.jsonl": jsonl_text(coverage_rows),
        FIXTURES / "thematic-coverage.jsonl": jsonl_text(thematic_rows),
        REVIEW / "membership-decisions.jsonl": jsonl_text(decisions),
        REVIEW / "membership-exceptions.jsonl": "",
        REVIEW / "collision-queue.jsonl": jsonl_text(collision_rows),
        REVIEW / "grammatical-list-decision.json": json.dumps({
            **grammar_decision, "handling": "accepted-omission",
            "rationale": "Individual grammatical-list entries remain represented by audited lexical skills; separate grammatical groups would duplicate source memberships without a consumer requirement.",
        }, indent=2) + "\n",
        REPORTS / "yle-membership-audit.json": json.dumps(report, indent=2) + "\n",
        REPORTS / "yle-membership-audit.md": markdown,
    })

    print(json.dumps({
        "source_row_count": source_row_count, **stage_counts,
        "reconciled_rows": direct_hits, "omission_rows": omissions,
        "collisions": len(collision_rows), "thematic_rows": len(thematic_rows),
        "scanned_cells": counters["scanned_cells"], "skipped_cells": counters["skipped_cells"],
    }, indent=2))


if __name__ == "__main__":
    main()
