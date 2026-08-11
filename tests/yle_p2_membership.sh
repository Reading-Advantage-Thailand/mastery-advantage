#!/usr/bin/env bash
set -uo pipefail

FAILED=0
PASS_COUNT=0
FAIL_COUNT=0
RESULTS=()

pass() {
  RESULTS+=("PASS: $1")
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  RESULTS+=("FAIL: $1")
  FAIL_COUNT=$((FAIL_COUNT + 1))
  FAILED=1
}

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TRACK_ID="lexical_graph_core_release_20260610"
track_dir_resolve() {
  local track_id="$1"
  if [[ -d "$ROOT/measure/archive/$track_id" ]]; then
    printf '%s\n' "$ROOT/measure/archive/$track_id"
  else
    printf '%s\n' "$ROOT/measure/tracks/$track_id"
  fi
}
TRACK_DIR="$(track_dir_resolve "$TRACK_ID")"
PLAN="${PLAN_OVERRIDE:-$TRACK_DIR/plan.md}"
SOURCE_ID="cambridge-yle-word-list-2025"
SOURCE_URL="https://www.cambridgeenglish.org/Images/739104-starters-movers-flyers-word-list-2025.pdf"
SOURCE_SHA="6f7a0ad1e277bd10ae8b3bcccfb76c058f611a607c6c9947601abbd7e16a99fa"
SOURCE_PDF="$ROOT/english/cefr-vocabulary/source-pdfs/cambridge-yle-word-list-2025.pdf"
SOURCE_SUMS="$ROOT/english/cefr-vocabulary/source-pdfs/SHA256SUMS"
SOURCE_INFO="$ROOT/english/cefr-vocabulary/source-pdfs/pdfinfo.txt"
SOURCES="$ROOT/english/cefr-vocabulary/SOURCES.md"
GRAPH="$ROOT/english/cefr-vocabulary/cefr-vocabulary-knowledge-space.json"
GENERATOR="$ROOT/english/cefr-vocabulary/scripts/build-yle-membership-audit.py"
REVIEW_DIR="$ROOT/english/cefr-vocabulary/review/yle-2025"
FIXTURE_DIR="$ROOT/english/cefr-vocabulary/fixtures/yle-audit"
REPORT="$ROOT/english/cefr-vocabulary/reports/yle-membership-audit.json"
REPORT_MD="$ROOT/english/cefr-vocabulary/reports/yle-membership-audit.md"
DECISIONS="$REVIEW_DIR/membership-decisions.jsonl"
EXCEPTIONS="$REVIEW_DIR/membership-exceptions.jsonl"
COLLISIONS="$REVIEW_DIR/collision-queue.jsonl"
GRAMMATICAL="$REVIEW_DIR/grammatical-list-decision.json"
APPROVAL="$REVIEW_DIR/phase2-approval.md"

if ! ORACLE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/yle-p2-oracle.XXXXXX")"; then
  echo "=== transient source oracle storage ==="
  fail "could not create ignored temporary source-oracle directory"
  printf '%s\n' "${RESULTS[@]}"
  echo "=== Total: $((PASS_COUNT + FAIL_COUNT)) checks (PASS=$PASS_COUNT, FAIL=$FAIL_COUNT) ==="
  exit "$FAILED"
fi
cleanup() {
  rm -rf -- "$ORACLE_DIR"
}
trap cleanup EXIT
ORACLE="$ORACLE_DIR/source-oracle.json"
GRAPH_RESULT="$ORACLE_DIR/graph-result.json"

# The source oracle is deliberately independent of the inventory under audit.
# It stores the complete extracted row set only below /tmp (or TMPDIR), never
# in the repository.  Raw mode gives this check a linear cell stream; the
# combined-list parse is a separate pass over pages 23-30.
echo "=== hash-pinned local PDF, conservative size, bounded pdftotext, and independent combined-list source oracle ==="
source_oracle_output="$(python3 - "$SOURCE_PDF" "$SOURCE_SUMS" "$SOURCE_INFO" "$SOURCES" "$SOURCE_SHA" "$SOURCE_ID" "$SOURCE_URL" "$ORACLE" <<'PY'
import hashlib
import json
import math
import re
import subprocess
import sys
import unicodedata
from collections import Counter
from pathlib import Path

pdf_arg, sums_arg, info_arg, sources_arg, source_sha, source_id, source_url, oracle_arg = sys.argv[1:]
pdf_path, sums_path, info_path, sources_path, oracle_path = map(Path, (pdf_arg, sums_arg, info_arg, sources_arg, oracle_arg))
errors = []
result = {"ready": False, "errors": [], "stage_rows": [], "combined_rows": []}
expected_counts = {"starters": 495, "movers": 399, "flyers": 513}
stage_codes = {"starters": "S", "movers": "M", "flyers": "F"}
stage_exams = {"starters": "pre-a1-starters", "movers": "a1-movers", "flyers": "a2-flyers"}
stage_pages = {"starters": range(4, 8), "movers": range(8, 12), "flyers": range(12, 17)}

# The local PDF is hash-pinned and bounded before any text extraction.
raw_text = ""
if not pdf_path.is_file():
    errors.append(f"missing local official PDF: {pdf_path}")
else:
    size = pdf_path.stat().st_size
    result["pdf_size_bytes"] = size
    if not 1_000_000 <= size <= 10_000_000:
        errors.append(f"PDF size is outside conservative 1,000,000..10,000,000 byte bound: {size}")
    digest = hashlib.sha256(pdf_path.read_bytes()).hexdigest()
    result["pdf_sha256"] = digest
    if digest != source_sha:
        errors.append(f"YLE source SHA-256 mismatch: expected {source_sha}, found {digest}")
    try:
        proc = subprocess.run(
            ["pdftotext", "-raw", str(pdf_path), "-"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=15,
        )
    except FileNotFoundError:
        errors.append("pdftotext is unavailable; source comparison cannot run locally")
    except subprocess.TimeoutExpired:
        errors.append("pdftotext exceeded the explicit 15-second timeout")
    except OSError as exc:
        errors.append(f"pdftotext could not start: {exc}")
    else:
        result["pdftotext_returncode"] = proc.returncode
        result["pdftotext_output_chars"] = len(proc.stdout)
        if proc.returncode != 0:
            errors.append(f"pdftotext failed with bounded local invocation: {proc.stderr.strip()}")
        elif len(proc.stdout) > 20_000_000:
            errors.append(f"pdftotext output exceeded the 20,000,000 character bound: {len(proc.stdout)}")
        elif len(proc.stderr) > 1_000_000:
            errors.append(f"pdftotext diagnostic output exceeded the 1,000,000 character bound: {len(proc.stderr)}")
        else:
            raw_text = proc.stdout

if not sums_path.is_file() or source_sha not in sums_path.read_text(encoding="utf-8"):
    errors.append("SHA256SUMS lacks the registered YLE SHA-256")
info = info_path.read_text(encoding="utf-8") if info_path.is_file() else ""
for required in ("Title:           Starters, Movers and Flyers word lists", "Pages:           44"):
    if required not in info:
        errors.append(f"pdfinfo.txt lacks YLE metadata: {required}")
registry = sources_path.read_text(encoding="utf-8") if sources_path.is_file() else ""
for required in (source_id, source_url, source_sha):
    if required not in registry:
        errors.append(f"SOURCES.md lacks registered YLE source field: {required}")

# This parser intentionally has no inventory input.  It handles the publisher's
# raw-mode wrapped cells, POS-less a.m./p.m. rows, title POS, and cells that have
# several entries on one extracted line.
ALIASES = {
    "adj": "adjective", "adv": "adverb", "conj": "conjunction", "det": "determiner",
    "dis": "discourse-marker", "excl": "exclamation", "int": "interrogative",
    "n": "noun", "poss": "possessive", "prep": "preposition", "pron": "pronoun",
    "v": "verb", "av": "auxiliary-verb", "mv": "modal-verb", "abbrev": "abbreviation",
    "phr v": "phrasal-verb", "prep phr": "prepositional-phrase", "poss adj": "possessive-adjective",
    "title": "title", "prep of place + time": "preposition", "prep of place": "preposition",
    "prep of time": "preposition",
}
atoms = sorted(ALIASES, key=len, reverse=True)
atom_pattern = "|".join(map(re.escape, atoms))
pos_expression = rf"(?:{atom_pattern})(?:\s*(?:&|\+|,|or)\s*(?:{atom_pattern}))*(?:\s+(?:sing|pl))?"
pos_re = re.compile(rf"^(?P<head>.+?)\s+(?P<pos>{pos_expression})$", re.I)
stage_re = re.compile(r"^(?P<head>.+?)\s+(?P<stage>[SMF])$", re.I)

def normalize(value):
    return re.sub(
        r"\s+",
        " ",
        unicodedata.normalize("NFKC", value)
        .replace("\ufeff", "")
        .replace("’", "'")
        .replace("–", "-")
        .replace("—", "-"),
    ).strip()

def parse_pos(value):
    value = normalize(value).lower()
    value = re.sub(r"\bprep of (?:place|time)(?: \+ (?:place|time))?\b", "prep", value)
    value = re.sub(r"\b(?:sing|pl)\b", "", value)
    return tuple(sorted({
        ALIASES[part.strip()]
        for part in re.split(r"\s*(?:&|\+|,|or)\s*", value)
        if part.strip() in ALIASES
    }))

def parse_cell(value, combined):
    value = normalize(value)
    if combined:
        found = stage_re.match(value)
        if not found:
            return None
        head = normalize(found.group("head"))
        pos_found = pos_re.match(head)
        if pos_found:
            return normalize(pos_found.group("head")), parse_pos(pos_found.group("pos")), found.group("stage").upper()
        # pdftotext -raw can place a POS before a parenthetical definition:
        # ``file n (as in ...) F``.  Canonicalize that to the source headword
        # plus POS without retaining a publisher excerpt.
        before_definition = re.match(
            rf"^(?P<head>.+?)\s+(?P<pos>{pos_expression})\s+(?P<definition>\([^)]*\))$",
            head,
            re.I,
        )
        if before_definition:
            return (
                normalize(before_definition.group("head") + " " + before_definition.group("definition")),
                parse_pos(before_definition.group("pos")),
                found.group("stage").upper(),
            )
        return head, (), found.group("stage").upper()
    found = pos_re.match(value)
    if not found:
        return None
    return normalize(found.group("head")), parse_pos(found.group("pos")), None

def likely_bare(value):
    value = normalize(value)
    return bool(re.match(r"^[A-Za-z][A-Za-z0-9./'’‘&-]*(?:\s+\([^)]*\))?$", value))

def split_entries(value, combined):
    value = normalize(value)
    if not value:
        return []
    # Raw extraction occasionally places several cells on one line.  Choose a
    # split only when both sides are independently parseable; this avoids
    # splitting POS combinations and parenthetical definitions.
    for index, char in enumerate(value):
        if not char.isspace() or index == 0 or index + 1 >= len(value) or not value[index - 1].isalnum():
            continue
        left = value[:index].strip()
        right = value[index:].strip()
        first = right.split(" ", 1)[0].casefold()
        if right.startswith(("+", "&", ",")) or first in ALIASES:
            continue
        if parse_cell(left, combined) is None:
            continue
        tail = split_entries(right, combined)
        if tail and all(parse_cell(part, combined) is not None for part in tail):
            return [left, *tail]
    return [value]

def parse_pages(page_numbers, combined, stage=None):
    rows = []
    pending = None
    active = False
    for page_number in page_numbers:
        for line_number, line in enumerate(pages[page_number - 1].splitlines(), 1):
            raw_line = normalize(line)
            for cell in split_entries(raw_line, combined):
                if not cell:
                    if pending is not None and pending.get("bare_candidate"):
                        rows.append({"page": pending["page"], "line": pending["line"], "headword": normalize(pending["text"]), "parts_of_speech": [], "stage": stage})
                    pending = None
                    continue
                if re.fullmatch(r"[A-Z]", cell):
                    active = True
                    pending = None
                    continue
                if cell in {"Numbers", "Names"} or cell.startswith("Candidates will be expected") or re.search(r"No words at this level", cell, re.I):
                    active = False
                    pending = None
                    continue
                if re.search(r"(?:alphabetic vocabulary list|wordlist)", cell, re.I):
                    pending = None
                    continue
                if not active:
                    continue
                current = parse_cell(cell, combined)
                if pending is not None:
                    old_text = normalize(pending["text"])
                    joined = normalize(old_text + " " + cell)
                    joined_parse = parse_cell(joined, combined)
                    # The only POS-less source cells are the balanced a.m./p.m.
                    # entries.  Flush them when the next cell is a new word,
                    # but join all wrapped lexical cells first.
                    suffix_only = re.fullmatch(
                        r"(?:adj|adv|conj|det|dis|excl|int|n|poss|prep|pron|v|title)(?:\s+(?:sing|pl))?(?:\s+[SMF])?",
                        cell,
                        re.I,
                    )
                    if pending.get("bare_candidate") and "(" in old_text and ")" in old_text and current and suffix_only is None:
                        rows.append({"page": pending["page"], "line": pending["line"], "headword": old_text, "parts_of_speech": [], "stage": stage})
                        pending = None
                    elif joined_parse:
                        rows.append({"page": pending["page"], "line": pending["line"], "headword": joined_parse[0], "parts_of_speech": list(joined_parse[1]), "stage": joined_parse[2] if combined else stage})
                        pending = None
                        continue
                    elif current:
                        pending = None
                    else:
                        pending = {"text": joined, "page": pending["page"], "line": pending["line"], "bare_candidate": likely_bare(joined)}
                        continue
                if current:
                    rows.append({"page": page_number, "line": line_number, "headword": current[0], "parts_of_speech": list(current[1]), "stage": current[2] if combined else stage})
                else:
                    pending = {"text": cell, "page": page_number, "line": line_number, "bare_candidate": likely_bare(cell)}
    if pending is not None and pending.get("bare_candidate"):
        rows.append({"page": pending["page"], "line": pending["line"], "headword": normalize(pending["text"]), "parts_of_speech": [], "stage": stage})
    return rows

if raw_text:
    pages = raw_text.split("\f")
    if pages and not pages[-1].strip():
        pages.pop()
    if len(pages) != 44:
        errors.append(f"bounded pdftotext produced labeled PDF page count: {len(pages)} (expected 44)")
    stage_rows = []
    for stage, page_numbers in stage_pages.items():
        parsed = parse_pages(page_numbers, False, stage_codes[stage])
        for index, row in enumerate(parsed, 1):
            row.update({
                "source_row_id": f"yle-2025-{stage}-{index:03d}",
                "stage": stage,
                "expected_exam": stage_exams[stage],
                "source_ref": source_id,
            })
            stage_rows.append(row)
    combined_rows = parse_pages(range(23, 31), True)
    for index, row in enumerate(combined_rows, 1):
        row.update({
            "source_row_id": f"yle-2025-combined-{index:04d}",
            "source_ref": source_id,
        })
    result["stage_rows"] = stage_rows
    result["combined_rows"] = combined_rows
    result["counts"] = dict(Counter(row["stage"] for row in stage_rows))
    result["combined_counts"] = dict(Counter(row["stage"] for row in combined_rows))
    if result["counts"] != expected_counts:
        errors.append(f"independent per-stage direct row counts: expected {expected_counts}, found {result['counts']}")
    expected_combined = {code: expected_counts[stage] for stage, code in stage_codes.items()}
    if result["combined_counts"] != expected_combined:
        errors.append(f"independent combined-list stage counts: expected {expected_combined}, found {result['combined_counts']}")

    def comparison_key(row):
        # The combined list includes one harmless comma in the wrapped take
        # definition; punctuation is ignored only for the two source-list
        # set comparison, never for graph identity.
        headword = normalize(row["headword"]).casefold().replace(",", "")
        stage = stage_codes.get(row["stage"], row["stage"])
        return headword, tuple(sorted(row["parts_of_speech"])), stage

    stage_keys = [comparison_key(row) for row in stage_rows]
    combined_keys = [comparison_key(row) for row in combined_rows]
    if len(stage_keys) != len(set(stage_keys)):
        errors.append("per-stage source oracle contains duplicate headword/POS/stage rows")
    if len(combined_keys) != len(set(combined_keys)):
        errors.append("combined alphabetic source oracle contains duplicate headword/POS/stage rows")
    if set(stage_keys) != set(combined_keys):
        errors.append(f"per-stage and combined alphabetic source sets differ: per-stage-only={len(set(stage_keys)-set(combined_keys))}, combined-only={len(set(combined_keys)-set(stage_keys))}")
    for row in stage_rows:
        low, high = stage_pages[row["stage"]].start, stage_pages[row["stage"]].stop - 1
        if not low <= row["page"] <= high:
            errors.append(f"{row['stage']} source row {row['source_row_id']} escaped tightened A-Z page range {low}-{high}: page {row['page']}")
    result["direct_row_count"] = len(stage_rows)
    result["source_mwe_count"] = sum(len(re.sub(r"\([^)]*\)", "", row["headword"]).strip().split()) > 1 for row in stage_rows)
    result["source_variant_count"] = sum(bool(re.search(r"[()/]", row["headword"])) for row in stage_rows)

try:
    oracle_path.write_text(json.dumps(result, ensure_ascii=False, sort_keys=True) + "\n", encoding="utf-8")
except OSError as exc:
    errors.append(f"could not write transient source oracle: {exc}")
result["errors"] = errors
result["ready"] = not errors and bool(result.get("stage_rows"))
try:
    oracle_path.write_text(json.dumps(result, ensure_ascii=False, sort_keys=True) + "\n", encoding="utf-8")
except OSError as exc:
    print(f"could not finalize transient source oracle: {exc}", file=sys.stderr)
    raise SystemExit(1)
print(f"Source oracle direct row count: {result.get('direct_row_count', 0)}")
print(f"Starters direct source rows: {result.get('counts', {}).get('starters', 0)}")
print(f"Movers direct source rows: {result.get('counts', {}).get('movers', 0)}")
print(f"Flyers direct source rows: {result.get('counts', {}).get('flyers', 0)}")
print(f"Combined alphabetic source row count: {sum(result.get('combined_counts', {}).values())}")
print(f"Source MWE row count: {result.get('source_mwe_count', 0)}")
print(f"Source variant row count: {result.get('source_variant_count', 0)}")
if errors:
    print("; ".join(errors[:20]), file=sys.stderr)
    if len(errors) > 20:
        print(f"Additional source-oracle failures: {len(errors) - 20}", file=sys.stderr)
    raise SystemExit(1)
PY
)"
source_oracle_status=$?
printf '%s\n' "$source_oracle_output"
if [[ "$source_oracle_status" -ne 0 ]]; then
  fail "independent PDF source oracle failed"
else
  pass "hash-pinned PDF and bounded source oracle derive 495/399/513 and cross-check the separate combined alphabetic list"
fi

echo "=== source-derived graph identity, POS/forms/MWE/variant fidelity, and all 17 reviewed omissions are reachable ==="
graph_output="$(python3 - "$ORACLE" "$GRAPH" "$DECISIONS" "$GRAPH_RESULT" "$SOURCE_ID" <<'PY'
import json
import re
import sys
import unicodedata
from collections import defaultdict
from pathlib import Path

oracle_path, graph_path, decisions_path, graph_result_path = map(Path, sys.argv[1:5])
source_id = sys.argv[5]
errors = []
result = {"ready": False, "missing": [], "unresolved_missing": [], "mapped_rows": 0, "direct_hits": 0, "actual_pairs": [], "source_pairs": [], "mwe_rows": 0, "variant_rows": 0}

def normalize(value):
    return re.sub(r"\s+", " ", unicodedata.normalize("NFKC", value).replace("’", "'").replace("–", "-").replace("—", "-")).strip()

def source_key(headword, parts):
    value = normalize(headword)
    value = re.sub(r"\s+\((?:Br Eng|Am Eng)\)$", "", value, flags=re.I)
    return value.casefold(), tuple(sorted(parts))

def source_forms(headword):
    value = source_key(headword, [])[0]
    forms = set()
    base = normalize(re.sub(r"\s*\([^)]*\)", "", value))
    base = normalize(re.sub(r"\b(?:sth|sb)\b", "", base))
    if base:
        forms.add(base)
    for found in re.finditer(r"\((?:uk|us|am eng:?|br eng:?)\s+([^)]*)\)", value, re.I):
        forms.add(found.group(1).strip())
    if re.fullmatch(r"[a-z-]+/[a-z-]+", base):
        forms.update(base.split("/"))
    return {form for form in forms if form}

def load_json(path, label):
    if not path.is_file():
        errors.append(f"missing {label}: {path}")
        return {}
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        errors.append(f"invalid {label}: {exc}")
        return {}
    if not isinstance(value, dict):
        errors.append(f"{label} must be an object")
        return {}
    return value

def load_jsonl(path):
    if not path.is_file():
        errors.append(f"missing durable decision log: {path}")
        return []
    rows = []
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        try:
            value = json.loads(line)
        except json.JSONDecodeError as exc:
            errors.append(f"decision line {line_number} is invalid JSON: {exc}")
            continue
        if isinstance(value, dict):
            rows.append(value)
    return rows

oracle = load_json(oracle_path, "transient source oracle")
graph = load_json(graph_path, "vocabulary graph")
decisions = load_jsonl(decisions_path)
rows = oracle.get("stage_rows") if isinstance(oracle.get("stage_rows"), list) else []
if not oracle.get("ready"):
    errors.append("source oracle is not ready; graph reconciliation cannot use an inventory-derived fallback")

source_nodes = [node for node in graph.get("nodes", []) if node.get("kind") == "skill" and source_id in node.get("sourceRefs", [])]
node_by_key = {}
for node in source_nodes:
    metadata = node.get("metadata", {})
    lexical = metadata.get("sourceNormalizedForm", metadata.get("lexicalForm", ""))
    parts = metadata.get("partsOfSpeech", [])
    node_by_key[source_key(lexical, parts)] = node

decision_rows = [row for row in decisions if isinstance(row, dict)]
def decision_covers(row):
    row_key = source_key(row.get("headword", ""), row.get("parts_of_speech", []))
    row_id = row.get("source_row_id")
    for decision in decision_rows:
        if decision.get("finding_class") != "omit":
            continue
        if decision.get("source_row_id") == row_id:
            return True
        if decision.get("source_key") == {"headword": row.get("headword"), "parts_of_speech": row.get("parts_of_speech", []), "stage": row.get("stage")}:
            return True
        for field in ("source_headword", "headword"):
            value = decision.get(field)
            if isinstance(value, str) and source_key(value, row.get("parts_of_speech", [])) == row_key:
                location = decision.get("source_location")
                if not isinstance(location, dict) or location.get("pdf_page") == row.get("page"):
                    return True
    return False

exam_node_ids = {f"english.vocabulary.exam.{exam}": exam for exam in ("pre-a1-starters", "a1-movers", "a2-flyers")}
contains = defaultdict(set)
for edge in graph.get("edges", []):
    if edge.get("type") == "contains" and edge.get("sourceId") in exam_node_ids:
        contains[edge.get("targetId")].add(exam_node_ids[edge.get("sourceId")])

missing = []
actual_pairs = set()
source_pairs = set()
for row in rows:
    stage = row.get("stage")
    exam = row.get("expected_exam")
    node = node_by_key.get(source_key(row.get("headword", ""), row.get("parts_of_speech", [])))
    if node is None:
        missing.append({**row, "reason": "graph_identity", "decision_reachable": decision_covers(row)})
        continue
    graph_id = node.get("id")
    pair = (graph_id, exam)
    source_pairs.add(pair)
    actual_for_node = contains.get(graph_id, set())
    if exam not in actual_for_node:
        missing.append({**row, "graph_skill_id": graph_id, "reason": "direct_membership", "decision_reachable": decision_covers(row)})
        continue
    result["mapped_rows"] += 1
    result["direct_hits"] += 1
    actual_pairs.add(pair)
    metadata = node.get("metadata", {})
    graph_parts = tuple(sorted(metadata.get("partsOfSpeech", [])))
    source_parts = tuple(sorted(row.get("parts_of_speech", [])))
    if graph_parts != source_parts:
        errors.append(f"POS mismatch for {row.get('source_row_id')}: source={source_parts}, graph={graph_parts}")
    graph_lexical = metadata.get("sourceNormalizedForm", metadata.get("lexicalForm", ""))
    if source_key(graph_lexical, graph_parts)[0] != source_key(row.get("headword", ""), source_parts)[0]:
        errors.append(f"lexical identity mismatch for {row.get('source_row_id')}: {row.get('headword')}")
    graph_forms = {normalize(value).casefold() for value in metadata.get("matchForms", []) if isinstance(value, str)}
    if source_forms(row.get("headword", "")) and not source_forms(row.get("headword", "")) & graph_forms:
        errors.append(f"source match form is absent from graph matchForms for {row.get('source_row_id')}")

    if len(re.sub(r"\([^)]*\)", "", row.get("headword", "")).strip().split()) > 1:
        result["mwe_rows"] += 1
    if re.search(r"[()/]", row.get("headword", "")):
        result["variant_rows"] += 1

    low, high = {"starters": (4, 7), "movers": (8, 11), "flyers": (12, 16)}[stage]
    if not low <= row.get("page", 0) <= high:
        errors.append(f"tightened {stage} A-Z page range violation for {row.get('source_row_id')}: {row.get('page')}")

unresolved = [row for row in missing if not row.get("decision_reachable")]
result.update({
    "ready": True,
    "missing": missing,
    "unresolved_missing": unresolved,
    "actual_pairs": sorted([list(pair) for pair in actual_pairs]),
    "source_pairs": sorted([list(pair) for pair in source_pairs]),
    "source_node_count": len(source_nodes),
})
try:
    graph_result_path.write_text(json.dumps(result, ensure_ascii=False, sort_keys=True) + "\n", encoding="utf-8")
except OSError as exc:
    errors.append(f"could not write transient graph result: {exc}")
print(f"Graph YLE skill count: {len(source_nodes)}")
print(f"Source rows mapped to graph identity and direct membership: {result['mapped_rows']}")
print(f"Actual graph direct membership pair count: {len(actual_pairs)}")
print(f"Independent source rows missing graph identity or direct membership: {len(missing)}")
print(f"Unresolved source omission count without durable omit decision: {len(unresolved)}")
for row in missing:
    print(f"OMISSION: {row.get('stage')} {row.get('headword')} ({', '.join(row.get('parts_of_speech', [])) or 'POS-less'}) page {row.get('page')} reason={row.get('reason')}")
print(f"Mapped source MWE row count: {result['mwe_rows']}")
print(f"Mapped source variant row count: {result['variant_rows']}")
if missing:
    errors.append(f"source-to-graph audit exposes {len(missing)} missing direct rows; each must be ingested or have a reachable durable omission decision")
if unresolved:
    errors.append(f"unresolved omissions without durable decisions: {len(unresolved)}")
if errors:
    print("; ".join(errors[:30]), file=sys.stderr)
    if len(errors) > 30:
        print(f"Additional graph-fidelity failures: {len(errors) - 30}", file=sys.stderr)
    raise SystemExit(1)
PY
)"
graph_status=$?
printf '%s\n' "$graph_output"
if [[ "$graph_status" -ne 0 ]]; then
  fail "source-derived graph reconciliation/form-POS-MWE-variant audit is red (expected current omissions are named above)"
else
  pass "every independent source row has graph identity/direct membership or a reachable durable omission decision"
fi

echo "=== report source population, independent denominator, labeled recall, and identity aggregates ==="
report_output="$(python3 - "$ORACLE" "$GRAPH_RESULT" "$REPORT" "$REPORT_MD" "$SOURCE_ID" "$SOURCE_SHA" <<'PY'
import json
import math
import re
import sys
from pathlib import Path

oracle_path, graph_result_path, report_path, report_md_path = map(Path, sys.argv[1:5])
source_id, source_sha = sys.argv[5:7]
errors = []
def load_json(path, label):
    if not path.is_file():
        errors.append(f"missing {label}: {path}")
        return {}
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        errors.append(f"invalid {label}: {exc}")
        return {}
    if not isinstance(value, dict):
        errors.append(f"{label} must be an object")
        return {}
    return value

def metric(metrics, key, label):
    value = metrics.get(key)
    if not isinstance(value, dict):
        errors.append(f"missing labeled report metric: {key}")
        return {}
    if value.get("label") != label:
        errors.append(f"report metric {key} has incorrect label")
    if not isinstance(value.get("value"), (int, float)) or isinstance(value.get("value"), bool) or not math.isfinite(value.get("value")):
        errors.append(f"report metric {key} lacks finite numeric value")
    return value

oracle = load_json(oracle_path, "source oracle")
graph_result = load_json(graph_result_path, "graph result")
report = load_json(report_path, "YLE membership report")
report_md = report_md_path.read_text(encoding="utf-8") if report_md_path.is_file() else ""
total = oracle.get("direct_row_count")
counts = oracle.get("counts", {})
expected_mwe = oracle.get("source_mwe_count")
expected_variant = oracle.get("source_variant_count")
actual_pairs = [tuple(pair) for pair in graph_result.get("actual_pairs", [])]
source_pairs = [tuple(pair) for pair in graph_result.get("source_pairs", [])]
true_positive_pairs = len(set(actual_pairs) & set(source_pairs))
direct_hits = graph_result.get("direct_hits")
unresolved_missing = len(graph_result.get("unresolved_missing", [])) if isinstance(graph_result.get("unresolved_missing"), list) else -1

print(f"Independent source denominator: {total}")
print(f"Independent Starters denominator: {counts.get('starters', 0)}")
print(f"Independent Movers denominator: {counts.get('movers', 0)}")
print(f"Independent Flyers denominator: {counts.get('flyers', 0)}")
print(f"Graph-grounded true-positive membership pair count: {true_positive_pairs}")
print(f"Graph-grounded source-row hit count: {direct_hits}")

if report.get("source_ref") != source_id:
    errors.append("report source_ref is not the registered official YLE source")
if report.get("source_pdf") != "source-pdfs/cambridge-yle-word-list-2025.pdf":
    errors.append("report source_pdf is not the local source-location reference")
if report.get("source_sha256") != source_sha:
    errors.append("report source_sha256 does not match the hash-pinned PDF")
if report.get("coverage_scope") != "all-current-yle-source-rows":
    errors.append("report coverage_scope is not the complete source population")
population = report.get("source_population")
if not isinstance(population, dict) or population.get("method") != "official-local-pdf" or population.get("inventory_independent") is not True:
    errors.append("report source_population must explicitly use the independent official-local-PDF method")
if report.get("source_row_count") != total:
    errors.append(f"report source_row_count must equal independent direct source row count {total}, found {report.get('source_row_count')}")
if "fixture_row_count" in report and report.get("fixture_row_count") != total:
    errors.append(f"report fixture_row_count aggregate must equal independent source row count {total}, found {report.get('fixture_row_count')}")
if report.get("unique_skill_count") != graph_result.get("source_node_count"):
    errors.append("report unique_skill_count does not match the current YLE graph skill count")
if report.get("graph_skill_coverage_count") != graph_result.get("source_node_count"):
    errors.append("report graph_skill_coverage_count does not cover the current YLE graph population")

metrics = report.get("metrics") if isinstance(report.get("metrics"), dict) else {}
precision = metric(metrics, "alphabetical_membership_precision", "YLE alphabetical membership precision")
recall = metric(metrics, "alphabetical_membership_recall", "YLE alphabetical membership recall")
if precision:
    if precision.get("numerator") != true_positive_pairs or precision.get("denominator") != len(actual_pairs):
        errors.append(f"precision numerator/denominator must be graph-grounded {true_positive_pairs}/{len(actual_pairs)}")
    if precision.get("population") != "all-current-yle-source-rows":
        errors.append("precision population is not labeled all-current-yle-source-rows")
    if precision.get("value", 0) < 0.995:
        errors.append("alphabetical membership precision is below the 0.995 threshold")
if recall:
    if recall.get("numerator") != direct_hits or recall.get("denominator") != total:
        errors.append(f"recall numerator/denominator must be independent source-grounded {direct_hits}/{total}")
    if recall.get("population") != "all-current-yle-source-rows":
        errors.append("recall population is not labeled all-current-yle-source-rows")
    expected_recall = direct_hits / total if isinstance(direct_hits, int) and total else 0.0
    if abs(recall.get("value", -1) - expected_recall) > 1e-9:
        errors.append("recall value does not equal its independent source numerator/denominator")
    if recall.get("value", 0) < 0.99:
        errors.append("alphabetical membership recall is below the 0.990 threshold")

identity = report.get("identity_coverage") if isinstance(report.get("identity_coverage"), dict) else {}
for key, label, expected in (
    ("lexical_form_rows", "YLE lexical-form rows reviewed", total),
    ("pos_rows", "YLE POS rows reviewed", total),
    ("mwe_rows", "YLE MWE rows reviewed", expected_mwe),
    ("variant_rows", "YLE variant rows reviewed", expected_variant),
):
    value = identity.get(key)
    if not isinstance(value, dict) or value.get("label") != label or value.get("reviewed_rows") != expected:
        errors.append(f"identity aggregate {key} must be independently derived from source count {expected}")
if identity.get("all_rows_have_identity_fields") is not True:
    errors.append("report identity_coverage does not assert complete source-derived identity fields")

quality = report.get("quality") if isinstance(report.get("quality"), dict) else {}
blocker = quality.get("unresolved_high_severity_blockers")
if not isinstance(blocker, dict) or blocker.get("label") != "Unresolved high-severity blockers" or blocker.get("value") != unresolved_missing:
    errors.append(f"report unresolved blocker count must reflect independent unresolved omissions: {unresolved_missing}")

cumulative = report.get("cumulative_interpretation")
if not isinstance(cumulative, dict) or cumulative.get("mode") != "consumption-policy-only" or cumulative.get("movers_inherits") != ["pre-a1-starters"] or cumulative.get("flyers_inherits") != ["pre-a1-starters", "a1-movers"] or cumulative.get("duplicate_membership_edges") is not False or cumulative.get("prerequisite_edges_added") != 0:
    errors.append("cumulative interpretation must remain consumption-only with no duplicate memberships or prerequisites")

# The Markdown report is also a claim surface; it must expose labeled source
# counts and cannot retain the old parser-derived denominator as current truth.
for label, value in (("Source-row population", total), ("Starters direct source rows", counts.get("starters")), ("Movers direct source rows", counts.get("movers")), ("Flyers direct source rows", counts.get("flyers"))):
    if not re.search(rf"{re.escape(label)}[^\n]*{value:,}?\b", report_md, re.I):
        errors.append(f"Markdown report lacks labeled independent count: {label}: {value}")
if re.search(r"recall[^\n]*(?:100\.000%|1\.000)[^\n]*1390", report_md, re.I):
    errors.append("Markdown report retains the false 1.000 recall over the parser-derived 1,390 rows")

if errors:
    print("; ".join(errors[:30]), file=sys.stderr)
    if len(errors) > 30:
        print(f"Additional report-contract failures: {len(errors) - 30}", file=sys.stderr)
    raise SystemExit(1)
PY
)"
report_status=$?
printf '%s\n' "$report_output"
if [[ "$report_status" -ne 0 ]]; then
  fail "report claims do not use the independent 1,407-row source denominator"
else
  pass "report JSON/Markdown metrics and identity aggregates agree with the independent source oracle"
fi

echo "=== committed source-data exposure is rejected while non-expressive aggregates and IDs remain allowed ==="
data_output="$(python3 - "$ROOT" "$FIXTURE_DIR" "$ORACLE" "$REPORT" <<'PY'
import json
import subprocess
import sys
from pathlib import Path

root, fixture_dir_arg, oracle_arg, report_arg = map(Path, sys.argv[1:])
errors = []
expressive_violations = []
full_fixture_names = {
    "starters-sample.jsonl", "movers-sample.jsonl", "flyers-sample.jsonl", "thematic-memberships.jsonl",
}
expressive_keys = {
    "source_headword", "source_forms", "source_parts_of_speech", "source_location", "source_excerpt",
    "source_text", "pdf_text", "pdf_contents", "source_membership",
}
try:
    tracked = subprocess.run(
        ["git", "ls-files", "-z", "--", "english/cefr-vocabulary/fixtures/yle-audit"],
        cwd=root,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=5,
        check=True,
    ).stdout.decode().split("\0")
except (OSError, subprocess.SubprocessError) as exc:
    errors.append(f"could not inspect tracked audit package paths: {exc}")
    tracked = []
tracked = [Path(value).name for value in tracked if value]
for name in sorted(full_fixture_names & set(tracked)):
    errors.append(f"full publisher-derived fixture remains tracked: {name}")

if fixture_dir_arg.exists():
    for path in sorted(fixture_dir_arg.rglob("*")):
        if not path.is_file():
            continue
        if path.name in full_fixture_names:
            errors.append(f"full publisher-derived fixture remains in the package: {path.relative_to(root)}")
        for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if not line.strip():
                continue
            try:
                value = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(value, dict):
                present = sorted(expressive_keys & set(value))
                if present:
                    expressive_violations.append(f"{path.relative_to(root)}:{line_number}: {present}")

if report_arg.is_file():
    try:
        report_value = json.loads(report_arg.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        report_value = None
    if isinstance(report_value, dict):
        present = sorted(expressive_keys & set(report_value))
        if present:
            expressive_violations.append(f"{report_arg.relative_to(root)}:object: {present}")
    for line_number, line in enumerate(report_arg.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        try:
            value = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict):
            present = sorted(expressive_keys & set(value))
            if present:
                expressive_violations.append(f"{report_arg.relative_to(root)}:{line_number}: {present}")
if expressive_violations:
    errors.append(f"expressive publisher-derived fixture/report violations: {len(expressive_violations)}; examples: {expressive_violations[:3]}")
if not oracle_arg.is_file() or root in oracle_arg.parents:
    errors.append("complete source row/headword/POS/page data is not confined to ignored temporary storage")
print(f"Tracked full alphabetical/thematic fixture count: {sum(name in tracked for name in full_fixture_names)}")
print(f"Expressive fixture-data violation count: {len(expressive_violations)}")
print("Allowed package forms: labeled aggregates, graph IDs, exception IDs, and review decisions")
if errors:
    print("; ".join(errors[:30]), file=sys.stderr)
    raise SystemExit(1)
PY
)"
data_status=$?
printf '%s\n' "$data_output"
if [[ "$data_status" -ne 0 ]]; then
  fail "committed package reproduces expressive publisher-derived source data"
else
  pass "complete source rows stay transient; committed audit package contains no full alphabetical/thematic source fixtures"
fi

echo "=== generator safety contract has no draft-count oracle, bounded subprocesses, reachable omissions, or direct report writes ==="
safety_output="$(python3 - "$GENERATOR" "$SOURCE_SHA" <<'PY'
import ast
import re
import sys
from pathlib import Path

generator_path = Path(sys.argv[1])
source_sha = sys.argv[2]
errors = []
if not generator_path.is_file():
    errors.append(f"missing audit generator: {generator_path}")
    text = ""
else:
    text = generator_path.read_text(encoding="utf-8")
    try:
        tree = ast.parse(text)
    except SyntaxError as exc:
        errors.append(f"audit generator has invalid Python syntax: {exc}")
        tree = None

# A fixed three-stage numeric dictionary is a circular source-count oracle;
# stage counts must come from the independent PDF source pass instead.
if 'tree' in locals() and tree is not None:
    for node in ast.walk(tree):
        if not isinstance(node, ast.Dict):
            continue
        keys = {key.value for key in node.keys if isinstance(key, ast.Constant) and isinstance(key.value, str)}
        if keys == {"starters", "movers", "flyers"} and all(isinstance(value, ast.Constant) and isinstance(value.value, int) for value in node.values):
            errors.append("generator retains a hardcoded three-stage draft-count dictionary")

run_calls = []
if 'tree' in locals() and tree is not None:
    for node in ast.walk(tree):
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and node.func.attr == "run":
            owner = node.func.value
            if isinstance(owner, ast.Name) and owner.id == "subprocess":
                run_calls.append(node)
    for node in run_calls:
        if not any(keyword.arg == "timeout" for keyword in node.keywords):
            errors.append(f"subprocess.run at line {node.lineno} lacks an explicit timeout")
if not run_calls:
    errors.append("generator has no inspectable subprocess.run call for bounded PDF extraction")

lower = text.lower()
if source_sha not in text or "sha256" not in lower:
    errors.append("generator does not verify the registered source SHA-256 before parsing")
if not re.search(r"st_size|getsize|stat\(\)|file_size|size_bytes", lower) or not re.search(r"1[_]?000[_]?000|10[_]?000[_]?000|1000000|10000000", text):
    errors.append("generator lacks a conservative source-size bound")
if not re.search(r"TemporaryDirectory|mkdtemp|tempfile", text):
    errors.append("generator does not stage generated artifacts in temporary/ignored storage")
if not re.search(r"os\.replace|\.replace\(", text):
    errors.append("generator does not atomically replace validated final artifacts")
if re.search(r"REPORTS\s*/[^\n]+\.write_text", text):
    errors.append("generator writes final report artifacts directly before staged validation")
if not re.search(r"status[\"']?\s*[:=]\s*[\"']omission[\"']", text, re.I):
    errors.append("generator has no reachable status=omission emission path")
if re.search(r"raise\s+ValueError\([^\n]*(?:Source row has no graph identity|Graph lacks direct source membership)", text):
    errors.append("generator still aborts on source omissions instead of recording decisions")
if not re.search(r"scanned|skipped|coverage", lower):
    errors.append("generator has no parse-coverage reconciliation for skipped source cells")

print(f"Inspectable bounded subprocess call count: {len(run_calls)}")
print(f"Generator safety violation count: {len(errors)}")
if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
PY
)"
safety_status=$?
printf '%s\n' "$safety_output"
if [[ "$safety_status" -ne 0 ]]; then
  fail "audit generator still permits draft circularity, unbounded extraction, dead omissions, or non-atomic publication"
else
  pass "audit generator contract requires independent source guards, bounded extraction, reachable omissions, and atomic publication"
fi

echo "=== durable decisions, collision review, and source-omission decision coverage ==="
decision_output="$(python3 - "$GRAPH" "$DECISIONS" "$EXCEPTIONS" "$COLLISIONS" "$GRAMMATICAL" "$GRAPH_RESULT" <<'PY'
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

graph_path, decisions_path, exceptions_path, collisions_path, grammatical_path, graph_result_path = map(Path, sys.argv[1:])
errors = []
allowed_statuses = {"open", "accepted", "rejected", "quarantined", "superseded"}
allowed_classes = {"omit", "false-include", "bad-merge", "group", "support", "other"}

def jsonl(path, required=True):
    if not path.is_file():
        if required:
            errors.append(f"missing durable audit artifact: {path}")
        return []
    rows = []
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        try:
            value = json.loads(line)
        except json.JSONDecodeError as exc:
            errors.append(f"{path}:{line_number} invalid JSON: {exc}")
            continue
        if isinstance(value, dict):
            rows.append(value)
        else:
            errors.append(f"{path}:{line_number} is not a JSON object")
    return rows

def valid_location(value, label):
    if not isinstance(value, dict):
        errors.append(f"{label} lacks structured source_location")
        return
    if not isinstance(value.get("pdf"), str) or not value["pdf"].endswith("source-pdfs/cambridge-yle-word-list-2025.pdf"):
        errors.append(f"{label} source_location does not cite the local YLE PDF")
    if not isinstance(value.get("pdf_page"), int) or not 1 <= value["pdf_page"] <= 44:
        errors.append(f"{label} source_location has no bounded PDF page")
    if not isinstance(value.get("section"), str) or not value["section"].strip():
        errors.append(f"{label} source_location lacks a section")

def load_json(path, label):
    if not path.is_file():
        errors.append(f"missing {label}: {path}")
        return {}
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        errors.append(f"invalid {label}: {exc}")
        return {}
    return value if isinstance(value, dict) else {}

graph = load_json(graph_path, "graph")
graph_result = load_json(graph_result_path, "graph result")
decisions = jsonl(decisions_path)
exceptions = jsonl(exceptions_path)
collision_rows = jsonl(collisions_path)
by_id = {}
for row in decisions:
    decision_id = row.get("decision_id")
    if not isinstance(decision_id, str) or not decision_id.strip() or decision_id in by_id:
        errors.append(f"decision log has missing or duplicate decision_id: {decision_id}")
        continue
    by_id[decision_id] = row
    if row.get("status") not in allowed_statuses:
        errors.append(f"decision {decision_id} has unsupported status")
    if not isinstance(row.get("reviewer_role"), str) or not row["reviewer_role"].strip():
        errors.append(f"decision {decision_id} lacks reviewer_role")
    if not isinstance(row.get("reviewed_at"), str) or not re.match(r"^20[0-9]{2}-[0-9]{2}-[0-9]{2}(?:T|$)", row["reviewed_at"]):
        errors.append(f"decision {decision_id} lacks ISO reviewed_at")
    valid_location(row.get("source_location"), f"decision {decision_id}")
    if not isinstance(row.get("graph_refs"), list):
        errors.append(f"decision {decision_id} lacks graph_refs")
    if row.get("finding_class") not in allowed_classes:
        errors.append(f"decision {decision_id} has unsupported finding_class")
    for field in ("finding", "evidence", "disposition", "supersedes", "superseded_by"):
        if field not in row or (isinstance(row.get(field), str) and not row[field].strip()):
            errors.append(f"decision {decision_id} lacks {field}")
    if any(key in row for key in ("source_excerpt", "source_text", "pdf_text", "pdf_contents")):
        errors.append(f"decision {decision_id} commits publisher PDF content")

for path, rows in ((exceptions_path, exceptions), (collisions_path, collision_rows)):
    for row in rows:
        decision_id = row.get("decision_id")
        if decision_id not in by_id:
            errors.append(f"{path.name} row references missing decision_id: {decision_id}")
        if path == exceptions_path:
            if row.get("severity") not in {"low", "medium", "high"}:
                errors.append("exception row lacks bounded severity")
            for field in ("scope", "owner", "resolution"):
                if not isinstance(row.get(field), str) or not row[field].strip():
                    errors.append(f"exception row lacks {field}")

source_nodes = [node for node in graph.get("nodes", []) if node.get("kind") == "skill" and "cambridge-yle-word-list-2025" in node.get("sourceRefs", [])]
by_form = defaultdict(list)
for node in source_nodes:
    metadata = node.get("metadata", {})
    form = metadata.get("sourceNormalizedForm", metadata.get("lexicalForm", ""))
    by_form[str(form).casefold()].append(node.get("id"))
collision_groups = {form: sorted(ids) for form, ids in by_form.items() if len(ids) > 1}
seen_collision_forms = set()
for row in collision_rows:
    form = row.get("normalized_form")
    key = str(form).casefold()
    if key not in collision_groups:
        errors.append(f"collision queue contains unknown form: {form}")
        continue
    seen_collision_forms.add(key)
    if row.get("severity") != "high" or set(row.get("graph_refs", [])) != set(collision_groups[key]):
        errors.append(f"collision queue case is incomplete: {form}")
    decision = by_id.get(row.get("decision_id"))
    if not decision or decision.get("finding_class") not in {"bad-merge", "false-include", "other"} or decision.get("status") == "open":
        errors.append(f"collision case lacks a closed durable decision: {form}")
for form in sorted(set(collision_groups) - seen_collision_forms):
    errors.append(f"high-severity collision has no queue row: {form}")

unresolved = graph_result.get("unresolved_missing", []) if isinstance(graph_result.get("unresolved_missing"), list) else []
omit_decisions = [row for row in decisions if row.get("finding_class") == "omit"]
for row in unresolved:
    if not any(decision.get("source_row_id") == row.get("source_row_id") for decision in omit_decisions):
        errors.append(f"source omission has no durable source_row_id decision: {row.get('source_row_id')}")

print(f"Durable membership decision count: {len(decisions)}")
print(f"High-severity collision group count: {len(collision_groups)}")
print(f"Durable omission decision count: {len(omit_decisions)}")
print(f"Unresolved source omission decision count: {len(unresolved)}")
if errors:
    print("; ".join(errors[:40]), file=sys.stderr)
    if len(errors) > 40:
        print(f"Additional decision failures: {len(errors) - 40}", file=sys.stderr)
    raise SystemExit(1)
PY
)"
decision_status=$?
printf '%s\n' "$decision_output"
if [[ "$decision_status" -ne 0 ]]; then
  fail "durable omission/collision decision contract is incomplete"
else
  pass "source omissions and every high-severity collision have attributable durable decisions"
fi

echo "=== thematic groups, grammatical-list handling, cumulative policy, and zero hard prerequisites ==="
group_output="$(python3 - "$ROOT" "$GRAPH" "$REPORT" "$GRAMMATICAL" "$DECISIONS" <<'PY'
import json
import math
import re
import sys
from pathlib import Path

root, graph_path, report_path, grammatical_path, decisions_path = map(Path, sys.argv[1:])
errors = []
def load_json(path, label):
    if not path.is_file():
        errors.append(f"missing {label}: {path}")
        return {}
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        errors.append(f"invalid {label}: {exc}")
        return {}
    return value if isinstance(value, dict) else {}
def load_jsonl(path):
    if not path.is_file():
        errors.append(f"missing decision log: {path}")
        return []
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]

graph = load_json(graph_path, "graph")
report = load_json(report_path, "report")
decision = load_json(grammatical_path, "grammatical-list decision")
decisions = load_jsonl(decisions_path)
by_id = {row.get("decision_id"): row for row in decisions if isinstance(row, dict)}
groups = [node for node in graph.get("nodes", []) if node.get("kind") == "content_group" and node.get("metadata", {}).get("source") == "cambridge-yle-word-list-2025" and node.get("metadata", {}).get("groupType") == "topic"]
print(f"YLE thematic group count: {len(groups)}")
if len(groups) != 20:
    errors.append(f"YLE thematic group count must be 20, found {len(groups)}")
thematic = report.get("thematic") if isinstance(report.get("thematic"), dict) else {}
if thematic.get("source_group_count") != 20:
    errors.append("thematic report source_group_count must be 20")
reviewed = thematic.get("reviewed_membership_count")
if not isinstance(reviewed, int) or reviewed < 100:
    errors.append("thematic report must retain a labeled aggregate of at least 100 reviewed memberships")
metric = thematic.get("membership_precision")
if not isinstance(metric, dict) or metric.get("label") != "YLE thematic membership precision":
    errors.append("thematic precision aggregate lacks its exact label")
else:
    if metric.get("denominator") != reviewed or not isinstance(metric.get("value"), (int, float)) or metric.get("value", 0) < 0.98:
        errors.append("thematic precision aggregate does not meet the 0.980 threshold over its reviewed sample")
if not isinstance(decision, dict):
    errors.append("grammatical-list decision must be an object")
else:
    required = ("decision_id", "status", "reviewer_role", "reviewed_at", "source_location", "finding_class", "finding", "evidence", "disposition", "supersedes", "superseded_by")
    for field in required:
        if field not in decision:
            errors.append(f"grammatical-list decision lacks {field}")
    if decision.get("decision_id") not in by_id:
        errors.append("grammatical-list decision is not linked to membership-decisions.jsonl")
    location = decision.get("source_location")
    if not isinstance(location, dict) or not 31 <= location.get("pdf_page", 0) <= 37:
        errors.append("grammatical-list decision must cite tightened grammatical-list pages 31-37")
    if decision.get("handling") == "accepted-omission" and not isinstance(decision.get("rationale"), str):
        errors.append("accepted grammatical-list omission lacks rationale")
    if decision.get("handling") not in {"represented", "accepted-omission"}:
        errors.append("grammatical-list handling is neither represented nor accepted-omission")

prerequisite_count = sum(edge.get("type") == "prerequisite_for" for edge in graph.get("edges", []))
print(f"prerequisite_for count: {prerequisite_count}")
if prerequisite_count != 0:
    errors.append("graph contains a prerequisite_for edge")
cumulative = report.get("cumulative_interpretation")
if not isinstance(cumulative, dict) or cumulative.get("mode") != "consumption-policy-only" or cumulative.get("duplicate_membership_edges") is not False or cumulative.get("prerequisite_edges_added") != 0:
    errors.append("cumulative interpretation is not consumption-only and prerequisite-free")

if errors:
    print("; ".join(errors[:30]), file=sys.stderr)
    raise SystemExit(1)
PY
)"
group_status=$?
printf '%s\n' "$group_output"
if [[ "$group_status" -ne 0 ]]; then
  fail "thematic/grammatical/cumulative/no-prerequisite contract failed"
else
  pass "20 thematic groups, grammatical handling, cumulative consumption policy, and zero prerequisite edges remain guarded"
fi

echo "=== Phase 2 plan markers and Red evidence are non-vacuous ==="
plan_output="$(python3 - "$PLAN" <<'PY'
import re
import sys
from pathlib import Path

plan_path = Path(sys.argv[1])
errors = []
if not plan_path.is_file():
    errors.append(f"missing plan: {plan_path}")
    text = ""
else:
    text = plan_path.read_text(encoding="utf-8")
    phase_matches = list(re.finditer(r"^## Phase 2: YLE List Fidelity Audit[ \t]*$", text, re.M))
    next_matches = list(re.finditer(r"^## Phase 3: Relationship And Progression Review[ \t]*$", text, re.M))
    if len(phase_matches) != 1 or len(next_matches) != 1 or next_matches[0].start() <= phase_matches[0].end():
        errors.append("Phase 2/Phase 3 boundaries are not uniquely resolvable")
        phase = ""
    else:
        phase = text[phase_matches[0].end():next_matches[0].start()]
    markers = re.findall(r"^- \[([^]]+)\][ \t]+", phase, re.M)
    invalid = sorted({marker for marker in markers if marker not in {"x", "~", "b"}})
    completed = len(re.findall(r"^- \[x\][ \t]+Task:", phase, re.M))
    in_progress = len(re.findall(r"^- \[~\][ \t]+Task:", phase, re.M))
    blocked = len(re.findall(r"^- \[b\][ \t]+Task:", phase, re.M))
    if re.findall(r"^- \[ \][ \t]", phase, re.M):
        errors.append("legacy [ ] task marker remains in Phase 2")
    if invalid:
        errors.append(f"unrecognized Phase 2 markers: {invalid}")
    # A4: no Green claim from an all-in-progress/empty phase.  The phase must
    # have substantive completed history and an honest current route.
    if completed == 0:
        errors.append(f"INCOMPLETE: Phase 2 completed task count: {completed}")
    # Honest route: remaining [~]/[b] work, or fully complete after curriculum
    # sign-off is [x] (attributable approval is checked separately).
    curriculum_done = bool(re.search(
        r"^- \[x\][ \t]+Task: Curriculum sign-off on YLE fidelity\b",
        phase,
        re.M,
    ))
    if in_progress == 0 and blocked == 0 and not curriculum_done:
        errors.append("Phase 2 has no in-progress or human-gated route")
    if "Remediate independent YLE source-completeness" not in phase:
        errors.append("Phase 2 Red-remediation task is absent")
    if "bash tests/yle_p2_membership.sh" not in phase:
        errors.append("Phase 2 plan lacks the authoritative Red command")
    if not re.search(r"1,?407|1,407", phase) or not all(re.search(pattern, phase) for pattern in (r"495", r"399", r"513")):
        errors.append("Phase 2 Red evidence lacks independent 495/399/513 and 1,407 labeled counts")
    # Historical parser-derived Green evidence may remain only if explicitly
    # marked superseded/refuted; an unqualified 1,000 recall claim is A5.
    for line in phase.splitlines():
        if re.search(r"1\.000|100\.000%", line) and "superseded" not in line.lower() and "refut" not in line.lower():
            errors.append("Phase 2 retains an unqualified 1.000/100.000% claim after independent Red remediation")
            break
    print(f"Phase 2 completed task count: {completed}")
    print(f"Phase 2 in-progress task count: {in_progress}")
    print(f"Phase 2 human-gate task count: {blocked}")
if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
PY
)"
plan_status=$?
printf '%s\n' "$plan_output"
if [[ "$plan_status" -ne 0 ]]; then
  fail "Phase 2 markers/evidence are vacuous or still overclaim source fidelity"
else
  pass "Phase 2 has substantive work, an honest Red route, labeled source counts, and no unqualified false Green claim"
fi

echo "=== curriculum approval remains an attributable human gate ==="
approval_output="$(python3 - "$APPROVAL" "$PLAN" <<'PY'
import re
import sys
from pathlib import Path

approval_path, plan_path = map(Path, sys.argv[1:])
errors = []
marker = None
text = plan_path.read_text(encoding="utf-8") if plan_path.is_file() else ""
phase_match = re.search(r"^## Phase 2: YLE List Fidelity Audit[ \t]*$(.*?)(?=^## Phase 3: Relationship And Progression Review[ \t]*$)", text, re.M | re.S)
if not phase_match:
    errors.append("Phase 2 section is not resolvable for human-gate check")
else:
    markers = re.findall(r"^- \[([~xb])\][ \t]+Task: Curriculum sign-off on YLE fidelity\b", phase_match.group(1), re.M)
    if len(markers) != 1:
        errors.append("Phase 2 curriculum approval task marker is not unique")
    else:
        marker = markers[0]
        if marker not in {"b", "x"}:
            errors.append("Phase 2 curriculum approval task must be [b] or [x]")
if not approval_path.is_file():
    if not errors and marker == "b":
        print("Phase 2 curriculum approval remains [b] human-gate; no approval artifact is required before owner sign-off")
        raise SystemExit(0)
    if marker == "x":
        errors.append("Phase 2 curriculum approval is [x] but phase2-approval.md is absent")
    elif marker is not None:
        errors.append("approval artifact is absent and the Phase 2 curriculum task is not the truthful [b] state")
else:
    approval = approval_path.read_text(encoding="utf-8")
    if not re.search(r"\b(?:decision|recommendation)\s*:\s*(?:go|conditional-go)\b", approval, re.I):
        errors.append("approval lacks go or conditional-go decision")
    if not re.search(r"curriculum[ /-]*language", approval, re.I):
        errors.append("approval lacks curriculum/language owner role")
    if not re.search(r"\b(?:owner|reviewer|approved by)\s*:\s*[^\n]+", approval, re.I):
        errors.append("approval lacks attributable owner/reviewer")
    if not re.search(r"\b20[0-9]{2}-[0-9]{2}-[0-9]{2}\b", approval):
        errors.append("approval lacks ISO date")
if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(1)
PY
)"
approval_status=$?
printf '%s\n' "$approval_output"
if [[ "$approval_status" -ne 0 ]]; then
  fail "curriculum/language approval gate is not truthful or attributable"
else
  pass "curriculum/language sign-off remains blocked honestly until attributable owner evidence exists"
fi

printf '%s\n' "${RESULTS[@]}"
echo "=== Total: $((PASS_COUNT + FAIL_COUNT)) checks (PASS=$PASS_COUNT, FAIL=$FAIL_COUNT) ==="
exit "$FAILED"
