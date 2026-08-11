#!/usr/bin/env python3
"""Build wordfreq corpus-frequency enrichment overlay.

Frequency is a scalar feature on a lexical node, never an edge and never a
prerequisite. This builder reads the frozen core graph read-only and emits an
overlay of node metadata patches (`metadata.frequency`) keyed by core skill id.

Policies (fixtures/enrichment/frequency-fixture-schema.json):
  mwe-policy-documented  multi-token forms are not comparable -> missing
  missing-true           zipf == 0.0 -> missing, never stored as a real score
  unreliable             zipf below RELIABILITY_FLOOR_ZIPF -> reliable: false
  rank-tie               equal zipf shares one rank (dense equal ranking)

Multi-token detection uses the wordfreq tokenizer, not whitespace and not
metadata.lexicalUnit:

  * lexicalUnit is unreliable — 115 single-token forms carry the
    "multiword-expression" label only because lexicalForm holds a parenthetical
    gloss ("ad (advertisement)"). Those are ordinary words and are scored.
  * whitespace is insufficient — "no-one" (6.10), "make-up" (5.91) and
    "cafe/café" (3.59) tokenize into two tokens and get the same inflated
    combined estimate as "a good start" (5.45) beating "cat" (4.78).
  * whitespace also over-fires — "at / @" tokenizes to ["at"] and is scored.

Run:
  uv run --with wordfreq==3.1.1 python scripts/build-frequency-metadata.py

Outputs (atomic staged write):
  overlays/frequency.overlay.json
  reports/enrichment/frequency.{json,md}
  review/enrichment/queues/frequency-missing.jsonl
  review/enrichment/queues/frequency-unreliable.jsonl
  review/enrichment/queues/frequency-label-anomalies.jsonl
"""

from __future__ import annotations

import json
import re
import sys
import tempfile
from collections import Counter
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path
from typing import Any

try:
    from wordfreq import tokenize, zipf_frequency
except ModuleNotFoundError:  # pragma: no cover - environment guard
    print(
        "wordfreq is required. Run:\n"
        "  uv run --with wordfreq==3.1.1 python scripts/build-frequency-metadata.py",
        file=sys.stderr,
    )
    raise SystemExit(1)

ROOT = Path(__file__).resolve().parents[1]
# scripts/ -> cefr-vocabulary/
GRAPH_PATH = ROOT / "cefr-vocabulary-knowledge-space.json"
OUT_OVERLAY = ROOT / "overlays" / "frequency.overlay.json"
OUT_REPORT_JSON = ROOT / "reports" / "enrichment" / "frequency.json"
OUT_REPORT_MD = ROOT / "reports" / "enrichment" / "frequency.md"
OUT_MISSING = ROOT / "review" / "enrichment" / "queues" / "frequency-missing.jsonl"
OUT_UNRELIABLE = ROOT / "review" / "enrichment" / "queues" / "frequency-unreliable.jsonl"
OUT_LABEL_ANOMALIES = (
    ROOT / "review" / "enrichment" / "queues" / "frequency-label-anomalies.jsonl"
)

LAYER = "enrichment.frequency.wordfreq"
DOMAIN = "english.vocabulary"
SOURCE = "wordfreq"
SOURCE_VERSION = "3.1.1"
LANG = "en"
ZIPF_PRECISION = 2

# Single build date; every calculatedAt reuses it so same-day reruns are
# byte-identical. No wall-clock time is embedded anywhere.
BUILD_DATE = date.today().isoformat()

# Reliability floor, in Zipf units. zipf 1.0 == 10 occurrences per billion
# tokens (1e-8 relative frequency), which is where wordfreq truncates its
# merged wordlists. At or below that magnitude an estimate rests on a handful
# of observations in one contributing corpus and is dominated by OCR noise,
# tokenization artifacts, and single-source spikes.
RELIABILITY_FLOOR_ZIPF = 1.0

RANK_TIE_POLICY = "dense-equal-rank"

# normalizedForm characters a clean lexical form is expected to use.
CLEAN_FORM_RE = re.compile(r"^[a-z0-9 '-]+$")

REASON_MULTI_TOKEN = "multi-token-not-comparable"
REASON_NOT_IN_CORPUS = "not-in-corpus"
REASON_BELOW_FLOOR = "below-reliability-floor"

MULTI_TOKEN_KINDS = ("whitespace", "hyphen", "slash", "other")

ANOMALY_MWE_LABEL = "mwe-label-single-token-form"
ANOMALY_BAD_CHARS = "unexpected-characters-in-normalized-form"
ANOMALY_WHITESPACE_SINGLE_TOKEN = "whitespace-form-scores-as-single-token"
ANOMALY_DUPLICATE_FORM = "duplicate-normalized-form"

# Concrete evidence for the multi-token exclusion, kept in the emitted reports.
MWE_EVIDENCE = {
    "phrase": "a good start",
    "phraseZipf": 5.45,
    "comparisonWord": "cat",
    "comparisonWordZipf": 4.78,
    "explanation": (
        'wordfreq scores "a good start" at zipf 5.45, above "cat" at 4.78. '
        "That is not a phrase frequency: wordfreq combines the component "
        "token frequencies under an independence assumption, so a phrase of "
        "common words outranks a common noun. Multi-token scores are therefore "
        "not comparable to single-word zipf and must not enter the ranking."
    ),
    "hyphenAndSlashCases": [
        {"form": "no-one", "tokens": ["no", "one"], "zipf": 6.10},
        {"form": "make-up", "tokens": ["make", "up"], "zipf": 5.91},
        {"form": "part-time", "tokens": ["part", "time"], "zipf": 5.66},
        {"form": "full-time", "tokens": ["full", "time"], "zipf": 5.47},
        {"form": "old-fashioned", "tokens": ["old", "fashioned"], "zipf": 3.93},
        {"form": "cafe/café", "tokens": ["cafe", "café"], "zipf": 3.59},
    ],
}


def atomic_write(path: Path, data: str | bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = data.encode("utf-8") if isinstance(data, str) else data
    with tempfile.NamedTemporaryFile(dir=str(path.parent), delete=False) as tmp:
        tmp.write(payload)
        tmp_path = Path(tmp.name)
    tmp_path.replace(path)


def zipf_of(form: str) -> float:
    return round(zipf_frequency(form, LANG), ZIPF_PRECISION)


def multi_token_kind(form: str) -> str:
    """Subtype of a multi-token form, for downstream triage.

    Precedence: whitespace, then hyphen, then slash. A form carrying more than
    one separator (e.g. "well made / well-made") reports the first that
    matches, so the classes partition the excluded set exactly once.
    """
    if " " in form:
        return "whitespace"
    if "-" in form:
        return "hyphen"
    if "/" in form:
        return "slash"
    return "other"


@dataclass
class BuildStats:
    totalNodes: int = 0
    totalSkills: int = 0
    scored: int = 0
    missingMultiToken: int = 0
    missingNotInCorpus: int = 0
    unreliableBelowFloor: int = 0
    ranked: int = 0
    maxRank: int = 0
    distinctZipfValues: int = 0
    tiedZipfValues: int = 0
    tiedNodes: int = 0
    largestTieSize: int = 0
    multiTokenKinds: Counter = field(default_factory=Counter)
    mweLabelAnomalies: int = 0
    unexpectedCharacterForms: int = 0
    whitespaceSingleTokenForms: int = 0
    duplicateNormalizedForms: int = 0
    duplicateFormSkills: int = 0
    zipfMin: float | None = None
    zipfMax: float | None = None
    largestTies: list[dict[str, Any]] = field(default_factory=list)

    def multi_token_kind_counts(self) -> dict[str, int]:
        return {k: self.multiTokenKinds.get(k, 0) for k in MULTI_TOKEN_KINDS}


def build_records(graph: dict[str, Any], stats: BuildStats) -> list[dict[str, Any]]:
    """One record per core skill node, sorted by node id."""
    records: list[dict[str, Any]] = []
    skills = [n for n in graph.get("nodes", []) if n.get("kind") == "skill"]
    stats.totalNodes = len(graph.get("nodes", []))
    stats.totalSkills = len(skills)

    form_counts = Counter(
        (n.get("metadata") or {}).get("normalizedForm") or "" for n in skills
    )
    stats.duplicateNormalizedForms = sum(1 for f, c in form_counts.items() if f and c > 1)
    stats.duplicateFormSkills = sum(c for f, c in form_counts.items() if f and c > 1)

    for node in sorted(skills, key=lambda n: n["id"]):
        meta = node.get("metadata") or {}
        form = (meta.get("normalizedForm") or "").strip()
        lexical_unit = meta.get("lexicalUnit")
        rec: dict[str, Any] = {
            "skillId": node["id"],
            "normalizedForm": form,
            "lexicalForm": meta.get("lexicalForm"),
            "lexicalUnit": lexical_unit,
            "anomalies": [],
        }

        if not form:
            rec.update(
                {
                    "state": "missing",
                    "missingReason": REASON_NOT_IN_CORPUS,
                    "zipf": None,
                    "diagnostics": {"emptyNormalizedForm": True, "diagnosticOnly": True},
                }
            )
            stats.missingNotInCorpus += 1
            records.append(rec)
            continue

        tokens = tokenize(form, LANG)

        # Core-data findings. Reported only: the core graph is frozen.
        if lexical_unit == "multiword-expression" and len(tokens) <= 1 and " " not in form:
            # Gloss artifact: the label followed a space in lexicalForm.
            # Whitespace forms that still score as one token get their own note.
            rec["anomalies"].append(ANOMALY_MWE_LABEL)
            stats.mweLabelAnomalies += 1
        if not CLEAN_FORM_RE.match(form):
            # e.g. normalizedForm "candy)" — punctuation leaked from the source.
            rec["anomalies"].append(ANOMALY_BAD_CHARS)
            stats.unexpectedCharacterForms += 1
        if " " in form and len(tokens) <= 1:
            # e.g. "at / @" tokenizes to ["at"]: malformed source form whose
            # lexical item is a single word.
            rec["anomalies"].append(ANOMALY_WHITESPACE_SINGLE_TOKEN)
            stats.whitespaceSingleTokenForms += 1
        if form_counts.get(form, 0) > 1:
            rec["anomalies"].append(ANOMALY_DUPLICATE_FORM)

        if len(tokens) > 1:
            # Policy 1: a combined-token estimate is not comparable to word zipf.
            kind = multi_token_kind(form)
            stats.multiTokenKinds[kind] += 1
            comp = [zipf_of(t) for t in tokens]
            diagnostics: dict[str, Any] = {
                "multiTokenKind": kind,
                "wordfreqTokenCount": len(tokens),
                "wordfreqTokens": list(tokens),
                # Diagnostic only. Never feeds rankWithinInventory.
                "componentMinZipf": min(comp) if comp else None,
                "combinedTokenEstimate": zipf_of(form),
                "diagnosticOnly": True,
            }
            if rec["anomalies"]:
                diagnostics["coreDataAnomalies"] = list(rec["anomalies"])
            rec.update(
                {
                    "state": "missing",
                    "missingReason": REASON_MULTI_TOKEN,
                    "multiTokenKind": kind,
                    "zipf": None,
                    "diagnostics": diagnostics,
                }
            )
            stats.missingMultiToken += 1
            records.append(rec)
            continue

        zipf = zipf_of(form)
        diagnostics = {}
        if rec["anomalies"]:
            diagnostics = {
                "coreDataAnomalies": list(rec["anomalies"]),
                "diagnosticOnly": True,
            }

        if zipf == 0.0:
            # Policy 2: never store 0.0 as a real score.
            rec.update(
                {
                    "state": "missing",
                    "missingReason": REASON_NOT_IN_CORPUS,
                    "zipf": None,
                    "diagnostics": diagnostics,
                }
            )
            stats.missingNotInCorpus += 1
            records.append(rec)
            continue

        stats.scored += 1
        if zipf < RELIABILITY_FLOOR_ZIPF:
            # Policy 3: keep the value, flag it, exclude it from ranking.
            rec.update(
                {
                    "state": "unreliable",
                    "missingReason": REASON_BELOW_FLOOR,
                    "zipf": zipf,
                    "diagnostics": diagnostics,
                }
            )
            stats.unreliableBelowFloor += 1
            records.append(rec)
            continue

        rec.update(
            {"state": "ranked", "missingReason": None, "zipf": zipf, "diagnostics": diagnostics}
        )
        records.append(rec)

    return records


def assign_dense_ranks(records: list[dict[str, Any]], stats: BuildStats) -> dict[float, int]:
    """Policy 4: equal zipf shares one rank; ranks are dense (1..N, no gaps)."""
    rankable = [r["zipf"] for r in records if r["state"] == "ranked"]
    counts = Counter(rankable)
    ordered = sorted(counts, reverse=True)
    rank_by_zipf = {z: i + 1 for i, z in enumerate(ordered)}

    stats.ranked = len(rankable)
    stats.distinctZipfValues = len(ordered)
    stats.maxRank = len(ordered)
    stats.tiedZipfValues = sum(1 for z in ordered if counts[z] > 1)
    stats.tiedNodes = sum(counts[z] for z in ordered if counts[z] > 1)
    stats.largestTieSize = max(counts.values()) if counts else 0
    stats.zipfMin = min(ordered) if ordered else None
    stats.zipfMax = max(ordered) if ordered else None
    stats.largestTies = [
        {"zipf": z, "rank": rank_by_zipf[z], "tiedNodeCount": counts[z]}
        for z in sorted(counts, key=lambda v: (-counts[v], -v))[:5]
    ]
    return rank_by_zipf


def frequency_metadata(rec: dict[str, Any], rank_by_zipf: dict[float, int]) -> dict[str, Any]:
    freq: dict[str, Any] = {
        "source": SOURCE,
        "sourceVersion": SOURCE_VERSION,
        "calculatedAt": BUILD_DATE,
    }
    if rec["state"] == "ranked":
        freq["zipf"] = rec["zipf"]
        freq["rankWithinInventory"] = rank_by_zipf[rec["zipf"]]
        freq["reliable"] = True
        freq["missing"] = False
    elif rec["state"] == "unreliable":
        # Value kept, but excluded from rankWithinInventory.
        freq["zipf"] = rec["zipf"]
        freq["reliable"] = False
        freq["missing"] = False
        freq["missingReason"] = rec["missingReason"]
    else:
        # missing: omits zipf and rankWithinInventory entirely.
        freq["reliable"] = False
        freq["missing"] = True
        freq["missingReason"] = rec["missingReason"]
        if rec.get("multiTokenKind"):
            freq["multiTokenKind"] = rec["multiTokenKind"]
    freq["rankTiePolicy"] = RANK_TIE_POLICY
    if rec.get("diagnostics"):
        freq["diagnostics"] = rec["diagnostics"]
    return freq


def queue_row(rec: dict[str, Any], status: str, disposition: str) -> dict[str, Any]:
    row = {
        "skillId": rec["skillId"],
        "normalizedForm": rec["normalizedForm"],
        "lexicalUnit": rec["lexicalUnit"],
        "missingReason": rec["missingReason"],
        "zipf": rec["zipf"],
        "status": status,
        "disposition": disposition,
        "enrichmentLayer": LAYER,
    }
    if rec.get("multiTokenKind"):
        row["multiTokenKind"] = rec["multiTokenKind"]
    if rec.get("diagnostics"):
        row["diagnostics"] = rec["diagnostics"]
    return row


def build_markdown(stats: BuildStats) -> str:
    kinds = stats.multi_token_kind_counts()
    md = [
        "# Corpus Frequency Enrichment Report",
        "",
        f"- Layer: `{LAYER}`",
        f"- Source: `{SOURCE}` version `{SOURCE_VERSION}` (language `{LANG}`)",
        f"- Calculated: **{BUILD_DATE}**",
        "- Semantics: **scalar node metadata**, not an edge, not a prerequisite",
        f"- Skills processed: **{stats.totalSkills}**",
        f"- Scored (numeric zipf stored): **{stats.scored}**",
        f"- Ranked (`rankWithinInventory` assigned): **{stats.ranked}**",
        f"- Missing, multi-token: **{stats.missingMultiToken}**",
        f"- Missing, not in corpus: **{stats.missingNotInCorpus}**",
        f"- Below reliability floor: **{stats.unreliableBelowFloor}**",
        f"- Max rank (dense): **{stats.maxRank}** over {stats.distinctZipfValues} distinct zipf values",
        f"- Zipf range: **{stats.zipfMin} .. {stats.zipfMax}**",
        f"- Core-data findings (reported, not repaired): **{stats.mweLabelAnomalies}** MWE "
        f"label anomalies, **{stats.unexpectedCharacterForms}** punctuation-leak forms, "
        f"**{stats.whitespaceSingleTokenForms}** whitespace forms scoring as one token, "
        f"**{stats.duplicateNormalizedForms}** duplicated forms",
        "- Overlay edges: **0** — `prerequisite_for` in output: **0**",
        f"- Core graph untouched: **yes** (`{GRAPH_PATH.name}`)",
        "",
        "## Multi-token forms are excluded from scoring and ranking",
        "",
        f"`zipf_frequency(\"{MWE_EVIDENCE['phrase']}\", \"en\") == {MWE_EVIDENCE['phraseZipf']}`",
        f"vs `zipf_frequency(\"{MWE_EVIDENCE['comparisonWord']}\", \"en\") == "
        f"{MWE_EVIDENCE['comparisonWordZipf']}`.",
        "",
        MWE_EVIDENCE["explanation"],
        "",
        "A four-word phrase is not more frequent than the word *cat*. wordfreq has",
        "no entry for the phrase at all; it tokenizes, looks up each token, and",
        "combines the probabilities assuming independence. The result is a",
        "well-formed number in the wrong unit — usable for nothing that compares",
        "phrases with words.",
        "",
        "### The rule is token count, not whitespace and not `lexicalUnit`",
        "",
        "    exclude when len(wordfreq.tokenize(normalizedForm, \"en\")) > 1",
        "",
        "Whitespace is the wrong test in both directions. It **misses** hyphenated",
        "compounds and slash alternations that carry the identical defect:",
        "",
        "| form | tokens | combined zipf |",
        "|---|---|---:|",
    ]
    for case in MWE_EVIDENCE["hyphenAndSlashCases"]:
        md.append(
            f"| `{case['form']}` | `{case['tokens']}` | {case['zipf']:.2f} |"
        )
    md.extend(
        [
            "",
            "`no-one` at 6.10 sits in top-100-word territory, which is plainly wrong;",
            "it is really `no` + `one` recombined. Whitespace also **over-fires**: the",
            f"{stats.whitespaceSingleTokenForms} `at / @` skills tokenize to `['at']` and are",
            "correctly scored 6.70, because the lexical item is *at*.",
            "",
            "`metadata.lexicalUnit` is not used either.",
            f"**{stats.mweLabelAnomalies}** skills carry",
            "`lexicalUnit == \"multiword-expression\"` while `normalizedForm` is a",
            "single token: the core parser applied the label whenever",
            "`lexicalForm` held a parenthetical gloss (\"ad (advertisement)\", \"apartment",
            "(UK flat)\", \"autumn (US fall)\", \"catch (e.g. a ball)\") while",
            "`normalizedForm` is correctly a single token. Those words are scored.",
            "",
            "Excluding hyphenated compounds loses a signal; including them injects a",
            "wrong one. Losing a weak signal is the correct trade — GRAPH-DESIGN.md",
            "already calls frequency \"a deliberately weak default ordering\".",
            "",
            "Policy: any skill whose `normalizedForm` tokenizes to more than one token",
            f"gets `missing: true`, `missingReason: \"{REASON_MULTI_TOKEN}\"`, no `zipf`,",
            "and no `rankWithinInventory`. `diagnostics.componentMinZipf` (the minimum",
            "zipf over component tokens) and `diagnostics.combinedTokenEstimate` (the",
            "rejected number itself) are recorded as **diagnostics only** and never feed",
            "ranking; they exist so a reviewer can judge whether a phrase's rarest",
            "component is itself rare.",
            "",
            "### Excluded subtypes (`multiTokenKind`)",
            "",
            "| kind | skills | example |",
            "|---|---:|---|",
            f"| whitespace | {kinds['whitespace']} | `a good start`, `as ... as` |",
            f"| hyphen | {kinds['hyphen']} | `no-one`, `old-fashioned` |",
            f"| slash | {kinds['slash']} | `cafe/café` |",
            f"| other | {kinds['other']} | — |",
            "",
            "Precedence is whitespace, then hyphen, then slash, so a form with several",
            "separators (`all right/alright`) is counted exactly once.",
            "",
            "## Reliability floor",
            "",
            f"`RELIABILITY_FLOOR_ZIPF = {RELIABILITY_FLOOR_ZIPF}` (named constant in "
            "`scripts/build-frequency-metadata.py`).",
            "",
            "Zipf is `log10(occurrences per billion tokens)`, so zipf 1.0 is exactly",
            "10 occurrences per billion tokens (relative frequency 1e-8). That is the",
            "magnitude at which wordfreq truncates its merged wordlists: below it an",
            "estimate rests on a handful of observations, usually contributed by a",
            "single sub-corpus, and is dominated by OCR noise, tokenization artifacts,",
            "and one-off spikes. Such a value is not a defensible ordering signal.",
            "",
            "Policy: keep the number for inspection, set `reliable: false` and",
            f"`missingReason: \"{REASON_BELOW_FLOOR}\"`, and exclude the node from",
            "`rankWithinInventory`. Rows land in",
            "`review/enrichment/queues/frequency-unreliable.jsonl`.",
            "",
            f"In this build **{stats.unreliableBelowFloor}** skills fell below the floor "
            f"(lowest scored zipf observed: {stats.zipfMin}). The floor is kept as an "
            "explicit guard for future inventory growth, not as dead code: any added "
            "rare or misspelled headword trips it instead of silently entering the rank.",
            "",
            "## Rank tie policy",
            "",
            f"`rankTiePolicy: \"{RANK_TIE_POLICY}\"`. Zipf is reported to 2 decimals, so",
            f"{stats.ranked} ranked skills collapse onto {stats.distinctZipfValues} distinct",
            f"values. **{stats.tiedZipfValues}** of those values are shared by more than one",
            f"skill, covering **{stats.tiedNodes}** skills; the largest single tie holds",
            f"**{stats.largestTieSize}** skills.",
            "",
            "Tied skills receive the *same* rank and the next distinct value receives",
            f"the next integer (dense, no gaps), so ranks run 1..{stats.maxRank}.",
            "Sorting by rank never implies an ordering that the corpus does not support.",
            "",
            "| zipf | rank | tied skills |",
            "|---:|---:|---:|",
        ]
    )
    for tie in stats.largestTies:
        md.append(f"| {tie['zipf']} | {tie['rank']} | {tie['tiedNodeCount']} |")
    md.extend(
        [
            "",
            "## Core-data findings (reported, not repaired)",
            "",
            "The core graph is frozen. These are findings for the coverage track,",
            "queued in `review/enrichment/queues/frequency-label-anomalies.jsonl`.",
            "",
            f"1. **MWE label anomaly — {stats.mweLabelAnomalies} skills.** "
            '`lexicalUnit == "multiword-expression"` with a single-token '
            "`normalizedForm`, caused by a parenthetical gloss in `lexicalForm`. "
            f"Note `{ANOMALY_MWE_LABEL}`. These skills are scored normally.",
            f"2. **Punctuation leak — {stats.unexpectedCharacterForms} skills.** "
            "`normalizedForm` contains characters outside `[a-z0-9 '-]`, e.g. "
            '`english.vocabulary.skill.candy-uk-sweet-s.noun` has `"candy)"` '
            '(matchForms `["candy)", "sweet(s"]`). Note '
            f"`{ANOMALY_BAD_CHARS}`. Forms are left untouched; the wordfreq tokenizer "
            "strips the stray punctuation, so `candy)` scores as *candy* (4.29), but "
            "the stored form itself is wrong.",
            f"3. **Whitespace form, single token — {stats.whitespaceSingleTokenForms} skills.** "
            "Both are `at / @`, which tokenizes to `['at']` and scores 6.70. The score "
            "is right because the lexical item is *at*, but the form is malformed "
            f"source data. Note `{ANOMALY_WHITESPACE_SINGLE_TOKEN}`.",
            f"4. **Duplicate forms — {stats.duplicateNormalizedForms} `normalizedForm` values "
            f"shared by {stats.duplicateFormSkills} skills.** Distinct senses of one word "
            '("catch (e.g. a ball)" / "catch (e.g. a bus)", likewise "biscuit") receive '
            "identical zipf by construction. The dense equal-rank tie policy already "
            "gives them one shared rank; no special handling is applied.",
            "",
            "## Consumer rule",
            "",
            "This layer stores the raw corpus number only. Normalization to a",
            "`utility(B)` score in [0,1] belongs to the",
            "`frequency_semantic_ranking_layer_20260611` track via provider",
            "`english.cefr.frequency-utility` (SPECIFICATION.md §10.3, decision D2).",
            "",
            "Frequency is a **weak default ordering**. It must not override learner",
            "goals, article relevance, review urgency, or source-backed pedagogical",
            "grouping, and it must never be read as a prerequisite relation. Nodes",
            "with `missing: true` have no ordering signal at all — rank them by other",
            "features rather than assuming they are rare.",
            "",
        ]
    )
    return "\n".join(md) + "\n"


ANOMALY_NOTES = {
    ANOMALY_MWE_LABEL: (
        'lexicalUnit is "multiword-expression" but normalizedForm is a single '
        "token; the label follows a parenthetical gloss in lexicalForm. Scored "
        "normally by this layer. Core graph is frozen: reported, not repaired."
    ),
    ANOMALY_BAD_CHARS: (
        "normalizedForm contains characters outside [a-z0-9 '-] (punctuation "
        "leaked from the source list). Form left untouched; the wordfreq "
        "tokenizer strips it. Reported, not repaired."
    ),
    ANOMALY_WHITESPACE_SINGLE_TOKEN: (
        "normalizedForm contains whitespace but tokenizes to a single token "
        '(e.g. "at / @" -> ["at"]). Malformed source form; the score is the '
        "single lexical item's and is kept. Reported, not repaired."
    ),
}


def main() -> int:
    if not GRAPH_PATH.is_file():
        print(f"missing graph: {GRAPH_PATH}", file=sys.stderr)
        return 1
    graph_bytes = GRAPH_PATH.read_bytes()
    graph = json.loads(graph_bytes.decode("utf-8"))

    stats = BuildStats()
    records = build_records(graph, stats)
    rank_by_zipf = assign_dense_ranks(records, stats)

    nodes: list[dict[str, Any]] = []
    missing_rows: list[dict[str, Any]] = []
    unreliable_rows: list[dict[str, Any]] = []
    anomaly_rows: list[dict[str, Any]] = []

    for rec in records:
        nodes.append(
            {
                "id": rec["skillId"],
                "kind": "skill",
                "domain": DOMAIN,
                "metadata": {"frequency": frequency_metadata(rec, rank_by_zipf)},
            }
        )
        if rec["state"] == "missing":
            disposition = (
                "wordfreq combines the component tokens under an independence "
                "assumption, so this is not a frequency for the lexical item; "
                "excluded from scoring and rank. Review the component minimum "
                "diagnostic or supply a phrase-frequency source."
                if rec["missingReason"] == REASON_MULTI_TOKEN
                else "No wordfreq entry for this form; excluded from rank. Review "
                "spelling/variant or accept as out-of-corpus."
            )
            missing_rows.append(queue_row(rec, f"excluded-{rec['missingReason']}", disposition))
        elif rec["state"] == "unreliable":
            unreliable_rows.append(
                queue_row(
                    rec,
                    "flagged-below-reliability-floor",
                    f"zipf below RELIABILITY_FLOOR_ZIPF={RELIABILITY_FLOOR_ZIPF}; "
                    "value retained for inspection, excluded from rank.",
                )
            )

        for anomaly in rec["anomalies"]:
            if anomaly not in ANOMALY_NOTES:
                continue
            anomaly_rows.append(
                {
                    "skillId": rec["skillId"],
                    "lexicalForm": rec["lexicalForm"],
                    "normalizedForm": rec["normalizedForm"],
                    "lexicalUnit": rec["lexicalUnit"],
                    "anomaly": anomaly,
                    "note": ANOMALY_NOTES[anomaly],
                    "frequencyState": rec["state"],
                    "enrichmentLayer": LAYER,
                }
            )

    kind_counts = stats.multi_token_kind_counts()
    overlay_stats = {
        "source": SOURCE,
        "sourceVersion": SOURCE_VERSION,
        "language": LANG,
        "coreNodeCount": stats.totalNodes,
        "skillsProcessed": stats.totalSkills,
        "overlayNodeCount": len(nodes),
        "overlayEdgeCount": 0,
        "scored": stats.scored,
        "missingMultiToken": stats.missingMultiToken,
        "missingMultiTokenByKind": kind_counts,
        "missingNotInCorpus": stats.missingNotInCorpus,
        "unreliableBelowFloor": stats.unreliableBelowFloor,
        "ranked": stats.ranked,
        "maxRank": stats.maxRank,
        "distinctZipfValues": stats.distinctZipfValues,
        "tiedZipfValues": stats.tiedZipfValues,
        "tiedNodes": stats.tiedNodes,
        "largestTieSize": stats.largestTieSize,
        "zipfMin": stats.zipfMin,
        "zipfMax": stats.zipfMax,
        "mweLabelAnomalies": stats.mweLabelAnomalies,
        "unexpectedCharacterForms": stats.unexpectedCharacterForms,
        "whitespaceSingleTokenForms": stats.whitespaceSingleTokenForms,
        "duplicateNormalizedForms": stats.duplicateNormalizedForms,
        "duplicateFormSkills": stats.duplicateFormSkills,
        "multiTokenDetection": "wordfreq.tokenize(normalizedForm, 'en') length > 1",
        "rankTiePolicy": RANK_TIE_POLICY,
        "reliabilityFloorZipf": RELIABILITY_FLOOR_ZIPF,
        "zipfPrecision": ZIPF_PRECISION,
    }

    overlay = {
        "enrichmentLayer": LAYER,
        "generatedAt": BUILD_DATE,
        "coreGraph": "cefr-vocabulary-knowledge-space.json",
        "description": (
            "Corpus frequency (wordfreq Zipf) as versioned node metadata. Each "
            "overlay node is a metadata patch merged into the core skill node of "
            "the same id: metadata.frequency. Frequency is a scalar feature, "
            "never an edge and never a prerequisite; multi-token and "
            "out-of-corpus forms are marked missing rather than scored, and equal "
            "zipf values share one dense rank."
        ),
        "hardProhibitions": {
            "frequency_as_edge": False,
            "frequencyIsNotPrerequisite": True,
        },
        "nodes": nodes,
        "edges": [],
        "stats": overlay_stats,
    }

    overlay_text = json.dumps(overlay, indent=2, ensure_ascii=False) + "\n"

    # Guarantees: no edges at all, no prerequisite language anywhere in output.
    if overlay["edges"]:
        print("BUG: frequency overlay must have zero edges", file=sys.stderr)
        return 1
    if "prerequisite_for" in overlay_text:
        print("BUG: overlay mentions prerequisite_for", file=sys.stderr)
        return 1
    if GRAPH_PATH.read_bytes() != graph_bytes:
        print("BUG: core graph changed during build", file=sys.stderr)
        return 1

    atomic_write(OUT_OVERLAY, overlay_text)
    atomic_write(
        OUT_MISSING,
        "".join(json.dumps(r, ensure_ascii=False) + "\n" for r in missing_rows),
    )
    atomic_write(
        OUT_UNRELIABLE,
        "".join(json.dumps(r, ensure_ascii=False) + "\n" for r in unreliable_rows),
    )
    atomic_write(
        OUT_LABEL_ANOMALIES,
        "".join(json.dumps(r, ensure_ascii=False) + "\n" for r in anomaly_rows),
    )

    report = {
        "enrichmentLayer": LAYER,
        "generatedAt": BUILD_DATE,
        "source": SOURCE,
        "sourceVersion": SOURCE_VERSION,
        "frequencySemantics": (
            "Corpus frequency is scalar node metadata giving a weak default "
            "ordering. It is not an edge, not a prerequisite, and not normalized "
            "to [0,1] here."
        ),
        "policies": {
            "multiToken": {
                "rule": (
                    "len(wordfreq.tokenize(normalizedForm, 'en')) > 1 -> missing: true, "
                    f'missingReason: "{REASON_MULTI_TOKEN}", excluded from '
                    "rankWithinInventory."
                ),
                "detectionKey": "wordfreq tokenization of metadata.normalizedForm",
                "detectionNote": (
                    "Neither metadata.lexicalUnit nor whitespace is used. The "
                    "lexicalUnit label over-counts by "
                    f"{stats.mweLabelAnomalies} single-token forms whose lexicalForm "
                    "carries a parenthetical gloss. Whitespace misses hyphenated "
                    "compounds and slash alternations (no-one, make-up, cafe/café) "
                    "that carry the identical combined-estimate defect, and "
                    f"over-fires on the {stats.whitespaceSingleTokenForms} 'at / @' "
                    "forms that tokenize to a single token."
                ),
                "evidence": MWE_EVIDENCE,
                "diagnosticsOnly": (
                    "componentMinZipf and combinedTokenEstimate are recorded as review "
                    "aids. Neither feeds rankWithinInventory."
                ),
                "excludedSkills": stats.missingMultiToken,
                "excludedByKind": kind_counts,
                "kindPrecedence": list(MULTI_TOKEN_KINDS),
            },
            "missing": {
                "rule": (
                    f'zipf == 0.0 -> missing: true, missingReason: "{REASON_NOT_IN_CORPUS}", '
                    "zipf and rankWithinInventory omitted. 0.0 is never stored as a score."
                ),
                "excludedSkills": stats.missingNotInCorpus,
            },
            "reliability": {
                "rule": (
                    "zipf < RELIABILITY_FLOOR_ZIPF -> value retained, reliable: false, "
                    f'missingReason: "{REASON_BELOW_FLOOR}", excluded from rankWithinInventory.'
                ),
                "reliabilityFloorZipf": RELIABILITY_FLOOR_ZIPF,
                "justification": (
                    "Zipf 1.0 == 10 occurrences per billion tokens (1e-8 relative "
                    "frequency), the magnitude at which wordfreq truncates its merged "
                    "wordlists. Below it an estimate rests on a handful of observations "
                    "from usually one sub-corpus and is dominated by OCR noise, "
                    "tokenization artifacts, and one-off spikes, so it cannot support "
                    "an ordering claim."
                ),
                "flaggedSkills": stats.unreliableBelowFloor,
                "lowestScoredZipf": stats.zipfMin,
            },
            "rankTie": {
                "rule": (
                    "Equal zipf values share one rank; the next distinct value takes "
                    "the next integer (dense equal ranking, ranks 1..maxRank)."
                ),
                "rankTiePolicy": RANK_TIE_POLICY,
                "zipfPrecision": ZIPF_PRECISION,
                "distinctZipfValues": stats.distinctZipfValues,
                "tiedZipfValues": stats.tiedZipfValues,
                "tiedNodes": stats.tiedNodes,
                "largestTieSize": stats.largestTieSize,
                "largestTies": stats.largestTies,
            },
        },
        "coreDataFindings": {
            "note": (
                "Core graph is frozen. These are reported for the coverage track "
                "to decide on; nothing is repaired here."
            ),
            "mweLabelAnomalies": {
                "count": stats.mweLabelAnomalies,
                "description": (
                    'lexicalUnit == "multiword-expression" with a single-token '
                    "normalizedForm, caused by a parenthetical gloss in lexicalForm."
                ),
                "examples": [
                    "ad (advertisement)",
                    "apartment (UK flat)",
                    "autumn (US fall)",
                    "catch (e.g. a ball)",
                ],
                "handling": "Scored normally by this layer.",
            },
            "unexpectedCharacterForms": {
                "count": stats.unexpectedCharacterForms,
                "description": (
                    "normalizedForm contains characters outside [a-z0-9 '-] — "
                    "punctuation leaked from the source list, e.g. "
                    'english.vocabulary.skill.candy-uk-sweet-s.noun -> "candy)".'
                ),
                "handling": (
                    "Form left untouched; wordfreq tokenization strips it, so "
                    '"candy)" scores as candy (4.29).'
                ),
            },
            "whitespaceSingleTokenForms": {
                "count": stats.whitespaceSingleTokenForms,
                "description": (
                    'normalizedForm "at / @" contains whitespace but tokenizes to '
                    "['at'] and scores 6.70. Malformed source form; the score is "
                    "correct for the lexical item at."
                ),
                "handling": "Scored; form reported for upstream cleanup.",
            },
            "duplicateNormalizedForms": {
                "distinctForms": stats.duplicateNormalizedForms,
                "skills": stats.duplicateFormSkills,
                "description": (
                    "Distinct senses of one word share a normalizedForm and therefore "
                    "receive identical zipf."
                ),
                "handling": (
                    "Dense equal-rank tie policy assigns them one shared rank; no "
                    "special handling."
                ),
            },
        },
        "stats": overlay_stats,
        "outputs": {
            "overlay": str(OUT_OVERLAY.relative_to(ROOT)),
            "missingQueue": str(OUT_MISSING.relative_to(ROOT)),
            "unreliableQueue": str(OUT_UNRELIABLE.relative_to(ROOT)),
            "labelAnomaliesQueue": str(OUT_LABEL_ANOMALIES.relative_to(ROOT)),
        },
        "edge_count_in_overlay": 0,
        "prerequisite_for_count_in_overlay": 0,
        "coreGraphUntouched": True,
        "downstreamOwnership": (
            "Normalization to utility(B) in [0,1] belongs to "
            "frequency_semantic_ranking_layer_20260611 via provider "
            "english.cefr.frequency-utility (SPECIFICATION.md 10.3, decision D2)."
        ),
    }
    atomic_write(OUT_REPORT_JSON, json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    atomic_write(OUT_REPORT_MD, build_markdown(stats))

    print(
        json.dumps(
            {
                "ok": True,
                "layer": LAYER,
                "skillsProcessed": stats.totalSkills,
                "scored": stats.scored,
                "missingMultiToken": stats.missingMultiToken,
                "missingMultiTokenByKind": kind_counts,
                "missingNotInCorpus": stats.missingNotInCorpus,
                "unreliableBelowFloor": stats.unreliableBelowFloor,
                "ranked": stats.ranked,
                "maxRank": stats.maxRank,
                "tiedZipfValues": stats.tiedZipfValues,
                "mweLabelAnomalies": stats.mweLabelAnomalies,
                "unexpectedCharacterForms": stats.unexpectedCharacterForms,
                "whitespaceSingleTokenForms": stats.whitespaceSingleTokenForms,
                "overlayEdgeCount": 0,
                "overlay": str(OUT_OVERLAY),
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
