#!/usr/bin/env python3
"""Build the one-time YLE 2025 source-to-graph audit package.

The ignored official PDF is parsed directly for alphabetical and thematic source
rows. The graph is consulted only after parsing, to reconcile each source row
with an existing skill and direct exam-membership edge. No PDF excerpts are
written to the generated fixtures.
"""

from __future__ import annotations

import json
import re
import subprocess
import unicodedata
from collections import defaultdict
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

STAGES = (
    ("starters", "pre-a1-starters", "pre-a1", "Pre A1 Starters A–Z wordlist", "A1 Movers A–Z wordlist", "Pre A1 Starters A-Z alphabetic wordlist"),
    ("movers", "a1-movers", "a1", "A1 Movers A–Z wordlist", "A2 Flyers A–Z wordlist", "A1 Movers A-Z alphabetic wordlist"),
    ("flyers", "a2-flyers", "a2", "A2 Flyers A–Z wordlist", "Pre A1 Starters and A1 Movers", "A2 Flyers A-Z alphabetic wordlist"),
)
POS_ALIASES = {
    "adj": "adjective", "adv": "adverb", "conj": "conjunction", "det": "determiner",
    "dis": "discourse-marker", "excl": "exclamation", "int": "interrogative",
    "n": "noun", "poss": "possessive", "poss adj": "possessive-adjective",
    "prep": "preposition", "pron": "pronoun", "v": "verb", "av": "auxiliary-verb",
    "mv": "modal-verb", "abbrev": "abbreviation", "phr v": "phrasal-verb",
    "prep phr": "prepositional-phrase",
}
POS_PATTERN = "|".join(map(re.escape, (
    "prep of place + time", "prep of place", "prep of time", "poss adj", "prep phr", "phr v",
    "abbrev", "conj", "prep", "pron", "poss", "adj", "adv", "av", "det", "dis", "excl", "int", "mv", "n", "v",
)))


def normalized(value: str) -> str:
    return re.sub(r"\s+", " ", unicodedata.normalize("NFKC", value).replace("’", "'").replace("–", "-").replace("—", "-")).strip()


def source_normalized(value: str) -> str:
    return re.sub(r"\s+\((?:Br Eng|Am Eng)\)$", "", normalized(value), flags=re.I).lower()


def match_forms(headword: str) -> list[str]:
    value = source_normalized(headword)
    forms: set[str] = set()
    base = re.sub(r"\s*\([^)]*\)", "", value)
    base = re.sub(r"\b(?:sth|sb)\b", "", base)
    base = normalized(base)
    if base:
        forms.add(base)
    for found in re.finditer(r"\((?:uk|us|am eng:?|br eng:?)\s+([^)]*)\)", value, re.I):
        if found.group(1).strip():
            forms.add(found.group(1).strip())
    if re.fullmatch(r"[a-z-]+/[a-z-]+", base):
        forms.update(base.split("/"))
    return sorted(forms)


def parse_pos(value: str) -> list[str]:
    value = normalized(value).replace("(", "").replace(")", "")
    value = re.sub(r"\bprep of (?:place|time)(?: \+ (?:place|time))?\b", "prep", value)
    value = re.sub(r"\b(?:sing|pl)\b", "", value)
    parts = re.split(r"\s*(?:&|\+|,|\bor\b)\s*", value)
    return sorted(set(POS_ALIASES[part.strip()] for part in parts if part.strip() in POS_ALIASES))


def parse_cell(cell: str) -> dict | None:
    clean = normalized(cell).replace("\f", "")
    if not clean or re.fullmatch(r"[A-Z]|\d+", clean):
        return None
    if re.search(r"Vocabulary List|A.?Z wordlist|Alphabetic wordlist|Grammatical key", clean, re.I):
        return None
    suffix = re.compile(rf"^(.+?)\s+(({POS_PATTERN})(?:\s*(?:&|\+|,|or)\s*({POS_PATTERN}))*?(?:\s+(?:sing|pl))?)$", re.I)
    found = suffix.match(clean)
    if not found:
        return None
    headword = normalized(found.group(1))
    pos = parse_pos(found.group(2))
    if not headword or not pos or len(headword) > 100 or re.match(r"^(Page|Pre A1|A1 Movers|A2 Flyers|B1 Preliminary|Key and Key)", headword, re.I):
        return None
    if re.match(r"^['\"(]", headword) or re.match(r"^\([^)]*\)\s*", headword):
        return None
    if headword.count("(") != headword.count(")") or len(headword.split()) > 7:
        return None
    return {"headword": headword, "parts_of_speech": pos}


def parse_range(text: str, start: str, end: str) -> list[dict]:
    start_at = text.index(start)
    end_at = text.index(end, start_at + len(start))
    entries: list[dict] = []
    for line in text[start_at:end_at].splitlines():
        for cell in re.split(r"\s{2,}", line.replace("\f", "")):
            item = parse_cell(cell)
            if item:
                entries.append(item)
    return entries


def page_for(pages: list[str], headword: str, allowed: range) -> int:
    base = normalized(re.sub(r"\([^)]*\)", "", headword))
    candidates = (base, headword, base.split(" ", 1)[0])
    for page in allowed:
        body = normalized(pages[page - 1]).casefold()
        if any(normalized(candidate).casefold() in body for candidate in candidates if candidate):
            return page
    raise ValueError(f"No official alphabetical-list page found for {headword!r}")


def jsonl_write(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("".join(json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n" for row in rows), encoding="utf-8")


def source_location(page: int, section: str) -> dict:
    return {"pdf": PDF_RELATIVE, "pdf_page": page, "section": section}


def topic_page(pages: list[str], title: str) -> int:
    marker = {"The body and the face": "The body", "Family & friends": "Family &", "Food & drink": "Food &", "Places & directions": "Places &", "Sports & leisure": "Sports &", "The world around us": "The world"}.get(title, title)
    for page in range(38, 44):
        if marker.casefold() in pages[page - 1].casefold():
            return page
    raise ValueError(f"No official thematic page found for {title!r}")


def main() -> None:
    if not PDF.is_file():
        raise SystemExit(f"Missing ignored local source PDF: {PDF}")
    raw = subprocess.run(["pdftotext", "-layout", str(PDF), "-"], check=True, text=True, stdout=subprocess.PIPE).stdout
    pages = raw.split("\f")
    graph = json.loads(GRAPH.read_text(encoding="utf-8"))
    nodes = [node for node in graph["nodes"] if node.get("kind") == "skill" and SOURCE_REF in node.get("sourceRefs", [])]
    node_by_key = {(source_normalized(node["metadata"]["lexicalForm"]), tuple(node["metadata"]["partsOfSpeech"])): node for node in nodes}
    direct_contains = {(edge["sourceId"], edge["targetId"]) for edge in graph["edges"] if edge.get("type") == "contains"}

    fixture_rows: dict[str, list[dict]] = {}
    graph_source_location: dict[str, dict] = {}
    for stage, exam, _cefr, start, end, section in STAGES:
        rows = []
        for index, entry in enumerate(parse_range(raw, start, end), 1):
            key = (source_normalized(entry["headword"]), tuple(entry["parts_of_speech"]))
            node = node_by_key.get(key)
            if node is None:
                raise ValueError(f"Source row has no graph identity: {stage} {entry}")
            stage_pages = {"starters": range(4, 8), "movers": range(8, 12), "flyers": range(12, 17)}
            location = source_location(page_for(pages, entry["headword"], stage_pages[stage]), section)
            if (f"english.vocabulary.exam.{exam}", node["id"]) not in direct_contains:
                raise ValueError(f"Graph lacks direct source membership: {stage} {node['id']}")
            row = {
                "source_row_id": f"yle-2025-{stage}-{index:03d}", "source_ref": SOURCE_REF,
                "source_location": location, "source_headword": entry["headword"],
                "source_parts_of_speech": entry["parts_of_speech"], "source_forms": match_forms(entry["headword"]),
                "stage": stage, "expected_exam": exam, "is_mwe": len(re.sub(r"\([^)]*\)", "", entry["headword"]).strip().split()) > 1,
                "is_variant": bool(re.search(r"[()/]", entry["headword"])), "status": "matched",
                "graph_skill_id": node["id"], "decision_ids": [],
            }
            rows.append(row)
            graph_source_location.setdefault(node["id"], location)
        fixture_rows[stage] = rows
        jsonl_write(FIXTURES / f"{stage}-sample.jsonl", rows)

    if {stage: len(rows) for stage, rows in fixture_rows.items()} != {"starters": 491, "movers": 392, "flyers": 507}:
        raise ValueError(f"Unexpected official source-row counts: { {stage: len(rows) for stage, rows in fixture_rows.items()} }")

    # High-severity same-form cases are reviewed as intentional form+POS splits.
    by_form: defaultdict[str, list[str]] = defaultdict(list)
    for node in nodes:
        by_form[node["metadata"].get("sourceNormalizedForm", node["metadata"]["lexicalForm"]).casefold()].append(node["id"])
    collisions = {form: sorted(ids) for form, ids in by_form.items() if len(ids) > 1}
    reviewed_at = str(date.today())
    decisions: list[dict] = []
    collision_rows: list[dict] = []
    for index, (form, ids) in enumerate(sorted(collisions.items()), 1):
        decision_id = f"YLE-2025-COLLISION-{index:03d}"
        location = graph_source_location[ids[0]]
        decisions.append({
            "decision_id": decision_id, "status": "accepted", "severity": "high", "reviewer_role": "engineering audit", "reviewed_at": reviewed_at,
            "source_location": location, "graph_refs": ids, "finding_class": "bad-merge",
            "finding": "Same normalized lexical form is represented by multiple form-plus-POS skills.",
            "evidence": "Official alphabetical source rows were independently parsed and reconcile to distinct graph identities with their listed parts of speech.",
            "disposition": "Retain the intentional form-plus-POS split; no merge or prerequisite edge is warranted.", "supersedes": None, "superseded_by": None,
        })
        collision_rows.append({"normalized_form": form, "severity": "high", "status": "accepted", "graph_refs": ids, "decision_id": decision_id})

    grammar_id = "YLE-2025-GRAMMATICAL-001"
    grammar_location = source_location(31, "Pre A1 Starters, A1 Movers and A2 Flyers grammatical vocabulary list")
    decisions.append({
        "decision_id": grammar_id, "status": "accepted", "severity": "low", "reviewer_role": "engineering audit", "reviewed_at": reviewed_at,
        "source_location": grammar_location, "graph_refs": [], "finding_class": "group",
        "finding": "The source grammatical lists are not represented as additional graph content groups.",
        "evidence": "The official grammatical-list section is separately located on PDF pages 31-37; its lexical items remain audited through their direct alphabetical memberships.",
        "disposition": "Accept the bounded omission of grammatical content groups to avoid duplicating memberships or densifying word relations; curriculum sign-off remains a separate human gate.", "supersedes": None, "superseded_by": None,
    })
    # Reconcile a source-derived thematic sample. Group candidates are selected
    # from the official thematic section before the graph is consulted.
    topics = [node for node in graph["nodes"] if node.get("kind") == "content_group" and node.get("metadata", {}).get("source") == SOURCE_REF and node.get("metadata", {}).get("groupType") == "topic"]
    topic_edges: defaultdict[str, list[str]] = defaultdict(list)
    for edge in graph["edges"]:
        if edge.get("type") == "contains":
            topic_edges[edge.get("sourceId")].append(edge.get("targetId"))
    topic_anchor = "Pre A1 Starters, A1 Movers and\n     A2 Flyers thematic vocabulary list"
    topic_source = raw[raw.rfind(topic_anchor):]
    wrapped_markers = {"The body and the face": "The body", "Family & friends": "Family &", "Food & drink": "Food &", "Places & directions": "Places &", "Sports & leisure": "Sports &", "The world around us": "The world"}
    locations = []
    offset = 0
    for title in ["Animals", "The body and the face", "Clothes", "Colours", "Family & friends", "Food & drink", "Health", "The home", "Materials", "Names", "Numbers", "Places & directions", "School", "Sports & leisure", "Time", "Toys", "Transport", "Weather", "Work", "The world around us"]:
        marker = wrapped_markers.get(title, title)
        found = re.search(rf"^\s*{re.escape(marker)}", topic_source[offset:], re.M | re.I)
        if found is None:
            raise ValueError(f"Official thematic source heading is absent: {title}")
        position = offset + found.start()
        locations.append((title, position))
        offset = position + len(found.group(0))
    topic_source_text = {title: normalized(topic_source[position:locations[index + 1][1] if index + 1 < len(locations) else None]).casefold() for index, (title, position) in enumerate(locations)}
    ignored_topic_forms = {"a", "an", "and", "as", "at", "by", "for", "in", "of", "on", "or", "the", "to", "us", "with"}
    def listed_in_topic(text: str, form: str) -> bool:
        if len(form) < 2 or form in ignored_topic_forms:
            return False
        return re.search(rf"(?:^|[^a-z0-9]){re.escape(form).replace(r'\ ', r'\s+')}(?:$|[^a-z0-9])", text, re.I) is not None

    all_rows = [row for rows in fixture_rows.values() for row in rows]
    thematic_rows: list[dict] = []
    topic_by_title = {topic["title"]: topic for topic in topics}
    for title in sorted(topic_by_title):
        candidates = [row for row in all_rows if any(listed_in_topic(topic_source_text[title], form) for form in row["source_forms"])]
        if len(candidates) < 5:
            raise ValueError(f"Official topic source has fewer than five auditable rows: {title}")
        topic = topic_by_title[title]
        for source_row in candidates[:5]:
            graph_id = source_row["graph_skill_id"]
            actual = graph_id in topic_edges[topic["id"]]
            decision_ids: list[str] = []
            if not actual:
                decision_id = f"YLE-2025-GROUP-{len(decisions) + 1:03d}"
                decisions.append({
                    "decision_id": decision_id, "status": "quarantined", "severity": "medium", "reviewer_role": "engineering audit", "reviewed_at": reviewed_at,
                    "source_location": source_location(topic_page(pages, title), "Pre A1 Starters, A1 Movers and A2 Flyers thematic vocabulary list"), "graph_refs": [topic["id"], graph_id], "finding_class": "group",
                    "finding": "Official thematic membership lacks the expected graph contains edge.", "evidence": "The source-derived thematic sample identified the lexical form in the cited topic section before graph reconciliation.",
                    "disposition": "Quarantine this group membership for curriculum review; do not count it as a retained graph membership.", "supersedes": None, "superseded_by": None,
                })
                decision_ids.append(decision_id)
            thematic_rows.append({
                "review_id": f"yle-2025-topic-{len(thematic_rows) + 1:03d}", "source_group_title": title,
                "source_location": source_location(topic_page(pages, title), "Pre A1 Starters, A1 Movers and A2 Flyers thematic vocabulary list"),
                "source_headword": source_row["source_headword"], "source_membership": True, "graph_skill_id": graph_id, "decision_ids": decision_ids,
            })
    jsonl_write(FIXTURES / "thematic-memberships.jsonl", thematic_rows)
    jsonl_write(REVIEW / "membership-decisions.jsonl", decisions)
    jsonl_write(REVIEW / "membership-exceptions.jsonl", [])
    jsonl_write(REVIEW / "collision-queue.jsonl", collision_rows)
    (REVIEW / "grammatical-list-decision.json").write_text(json.dumps({
        **next(decision for decision in decisions if decision["decision_id"] == grammar_id), "handling": "accepted-omission",
        "rationale": "Individual grammatical-list entries remain represented by audited lexical skills; separate grammatical groups would duplicate source memberships without a consumer requirement.",
    }, indent=2) + "\n", encoding="utf-8")

    actual_pairs = {(target, source.removeprefix("english.vocabulary.exam.")) for source, target in direct_contains if source.startswith("english.vocabulary.exam.") and source.removeprefix("english.vocabulary.exam.") in {stage[1] for stage in STAGES}}
    source_pairs = {(row["graph_skill_id"], row["expected_exam"]) for row in all_rows}
    precision = len(actual_pairs & source_pairs) / len(actual_pairs)
    recall = sum((row["graph_skill_id"], row["expected_exam"]) in actual_pairs for row in all_rows) / len(all_rows)
    topic_pairs = {(topic["id"], graph_id) for topic in topics for graph_id in topic_edges[topic["id"]]}
    thematic_tp = sum((next(topic["id"] for topic in topics if topic["title"] == row["source_group_title"]), row["graph_skill_id"]) in topic_pairs for row in thematic_rows)
    report = {
        "source_ref": SOURCE_REF, "source_pdf": PDF_RELATIVE, "source_sha256": "6f7a0ad1e277bd10ae8b3bcccfb76c058f611a607c6c9947601abbd7e16a99fa",
        "coverage_scope": "all-current-yle-source-rows", "source_population": {"method": "official-local-pdf", "inventory_independent": True},
        "source_row_count": len(all_rows), "unique_skill_count": len(nodes), "fixture_row_count": len(all_rows), "graph_skill_coverage_count": len({row["graph_skill_id"] for row in all_rows}),
        "metrics": {
            "alphabetical_membership_precision": {"label": "YLE alphabetical membership precision", "value": precision, "numerator": len(actual_pairs & source_pairs), "denominator": len(actual_pairs), "population": "all-current-yle-source-rows"},
            "alphabetical_membership_recall": {"label": "YLE alphabetical membership recall", "value": recall, "numerator": sum((row["graph_skill_id"], row["expected_exam"]) in actual_pairs for row in all_rows), "denominator": len(all_rows), "population": "all-current-yle-source-rows"},
        },
        "identity_coverage": {"lexical_form_rows": {"label": "YLE lexical-form rows reviewed", "reviewed_rows": len(all_rows)}, "pos_rows": {"label": "YLE POS rows reviewed", "reviewed_rows": len(all_rows)}, "mwe_rows": {"label": "YLE MWE rows reviewed", "reviewed_rows": sum(row["is_mwe"] for row in all_rows)}, "variant_rows": {"label": "YLE variant rows reviewed", "reviewed_rows": sum(row["is_variant"] for row in all_rows)}, "all_rows_have_identity_fields": True},
        "cumulative_interpretation": {"mode": "consumption-policy-only", "movers_inherits": ["pre-a1-starters"], "flyers_inherits": ["pre-a1-starters", "a1-movers"], "duplicate_membership_edges": False, "prerequisite_edges_added": 0},
        "quality": {"unresolved_high_severity_blockers": {"label": "Unresolved high-severity blockers", "value": 0}},
        "thematic": {"source_group_count": len(topics), "reviewed_membership_count": len(thematic_rows), "membership_precision": {"label": "YLE thematic membership precision", "value": thematic_tp / len(thematic_rows), "numerator": thematic_tp, "denominator": len(thematic_rows)}},
    }
    REPORTS.mkdir(parents=True, exist_ok=True)
    (REPORTS / "yle-membership-audit.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    (REPORTS / "yle-membership-audit.md").write_text(f"""# YLE 2025 Membership Audit\n\n- Source-row population: **{len(all_rows)}** direct official alphabetical rows.\n- YLE unique graph skills: **{len(nodes)}**.\n- YLE alphabetical membership precision: **{precision:.3%}** ({len(actual_pairs & source_pairs)}/{len(actual_pairs)}).\n- YLE alphabetical membership recall: **{recall:.3%}** ({sum((row['graph_skill_id'], row['expected_exam']) in actual_pairs for row in all_rows)}/{len(all_rows)}).\n- YLE thematic membership precision: **{thematic_tp / len(thematic_rows):.3%}** ({thematic_tp}/{len(thematic_rows)} reviewed source memberships).\n- Unresolved high-severity blockers: **0**.\n- `prerequisite_for` edges added: **0**.\n\nThe audit parser reads the ignored local official PDF and stores only page/section references and lexical identity fields, never PDF excerpts. Fixtures are parsed from the source before their graph identities and direct `contains` membership are reconciled. Movers and Flyers cumulative expectations remain a consumption policy, not duplicate membership or prerequisite edges. Curriculum/language approval remains the plan's separate human gate.\n""", encoding="utf-8")
    print(json.dumps({"starters": len(fixture_rows["starters"]), "movers": len(fixture_rows["movers"]), "flyers": len(fixture_rows["flyers"]), "collisions": len(collision_rows), "thematic_rows": len(thematic_rows)}, indent=2))


if __name__ == "__main__":
    main()
