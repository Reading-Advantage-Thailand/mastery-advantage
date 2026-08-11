#!/usr/bin/env python3
"""Re-derive the recommendation Phase 4 checklist from the evaluator output.

Implements section 2 of recommendation-phase4-procedure.md directly against the
evaluator output. It computes each verdict from the fixtures and the reference evaluator. It
never reads recommendation-phase4-judgments.jsonl, so the recorded judgments are
checked against a computed result instead of against themselves.
"""
import json
import subprocess
import sys
from pathlib import Path

VOCAB = Path(__file__).resolve().parents[1]
GRAPH = VOCAB / "cefr-vocabulary-knowledge-space.json"
FREQ = VOCAB / "overlays" / "frequency.overlay.json"
SCRIPT = VOCAB / "scripts" / "recommendation-contract.js"

CASES = [
    "hard-unmatched", "numbers-skipped", "matched-trap", "yle-compat",
    "mwe-match", "ranking-signals", "empty-article", "core-mode",
    "ignore-surface",
]

results = []


def check(case, name, ok, note=""):
    results.append((case, name, "pass" if ok else "FAIL", note))


def run(case):
    out = subprocess.run(
        ["node", str(SCRIPT), "evaluate", str(GRAPH),
         str(VOCAB / "fixtures" / "recommendation" / case), str(FREQ)],
        capture_output=True, text=True, check=True,
    )
    return out.stdout


for case in CASES:
    raw = run(case)
    d = json.loads(raw)
    m = d["metrics"]
    spans = d["spans"]
    profile = json.loads((VOCAB / "fixtures" / "recommendation" / case / "profile.json").read_text())

    # Global invariant: eligible spans partition into known + unknown + unmatched,
    # and skipped spans stay outside the denominator.
    eligible = m["eligible_span_count"]["value"]
    parts = (m["known_span_count"]["value"] + m["unknown_span_count"]["value"]
             + m["unmatched_span_count"]["value"])
    check(case, "eligible == known+unknown+unmatched", eligible == parts,
          f"{eligible} vs {parts}")
    check(case, "coverage denominator == eligible",
          m["eligibleKnownCoverage"]["denominator"] == eligible)
    counted = sum(1 for s in spans if s["classification"] in ("known", "unknown", "unmatched"))
    check(case, "span classes agree with counts", counted == eligible,
          f"spans={counted} eligible={eligible}")
    # exceededCap means "the candidate pool was truncated", not "the emitted
    # list is over the cap". The checklist invariant is the size bound alone.
    rnv = d["rankedNextVocabulary"]
    check(case, "targets within cap",
          rnv["size"] <= rnv["cap"] and len(rnv["items"]) <= rnv["cap"],
          f"size={rnv['size']} cap={rnv['cap']} truncated={rnv['exceededCap']}")

    # Determinism: a second run must be byte-identical.
    check(case, "deterministic re-run", run(case) == raw)

    if case == "hard-unmatched":
        unmatched = [s["surface"].lower() for s in spans if s["classification"] == "unmatched"]
        check(case, "hard phrase is unmatched",
              any("quantum" in u or "telescope" in u for u in unmatched), str(unmatched))
        check(case, "unmatched inside eligible denominator",
              m["unmatchedTokenRate"]["denominator"] == eligible
              and m["unmatched_span_count"]["value"] > 0)
        check(case, "known coverage < 1", m["eligibleKnownCoverage"]["value"] < 1,
              str(m["eligibleKnownCoverage"]["value"]))

    if case == "numbers-skipped":
        digit_spans = [s for s in spans if any(ch.isdigit() for ch in s["surface"])]
        check(case, "digit tokens exist in fixture", len(digit_spans) > 0)
        check(case, "digit tokens classified skipped",
              all(s["classification"] == "skipped" for s in digit_spans),
              str([(s["surface"], s["classification"]) for s in digit_spans]))
        check(case, "no digit token counted unmatched",
              not any(s["classification"] == "unmatched" for s in digit_spans))

    if case == "matched-trap":
        check(case, "matchedTokenCoverage >= 0.85",
              m["matchedTokenCoverage"]["value"] >= 0.85,
              str(m["matchedTokenCoverage"]["value"]))
        check(case, "unmatchedTokenRate >= 0.05",
              m["unmatchedTokenRate"]["value"] >= 0.05,
              str(m["unmatchedTokenRate"]["value"]))
        check(case, "matched coverage marked diagnostic only",
              m["matchedTokenCoverage"].get("primary") is False)

    if case == "yle-compat":
        check(case, "unmatched present", m["unmatched_span_count"]["value"] > 0)

    if case == "mwe-match":
        widths = [len(s.get("tokenIndexes", [])) for s in spans]
        check(case, "a span covers >= 2 tokens", max(widths) >= 2, f"max={max(widths)}")
        mwe = [s for s in spans if len(s.get("tokenIndexes", [])) >= 2]
        check(case, "MWE span carries explainability",
              all(s.get("graphFacts") for s in mwe))

    if case == "ranking-signals":
        items = d["rankedNextVocabulary"]["items"]
        check(case, "ranking is non-empty", len(items) > 0)
        due = set(profile.get("learnerState", {}).get("dueSkillIds") or [])
        check(case, "fixture declares a due skill", bool(due), str(sorted(due)))
        if due and items:
            check(case, "due skill ranks first", items[0]["skillId"] in due,
                  f"first={items[0]['skillId']} due={sorted(due)}")
        freq = [s for s in items[0]["signals"] if s["source"] == "frequency-utility"] if items else []
        check(case, "frequency signal > 0", bool(freq) and freq[0]["value"] > 0,
              str(freq))
        check(case, "scores are monotonically non-increasing",
              all(items[i]["score"] >= items[i + 1]["score"] for i in range(len(items) - 1)))

    if case == "empty-article":
        check(case, "eligible count is 0", eligible == 0)
        check(case, "coverage metrics are 0",
              m["eligibleKnownCoverage"]["value"] == 0
              and m["unmatchedTokenRate"]["value"] == 0)

    if case == "core-mode":
        check(case, "lexiconMode is core-only", d["lexiconMode"] == "core-only",
              d["lexiconMode"])

    if case == "ignore-surface":
        ignore_list = profile.get("learnerState", {}).get("ignoreSurfaceForms") or []
        check(case, "fixture sets ignoreSurfaceForms", bool(ignore_list), str(ignore_list))
        ignored = {x.lower() for x in ignore_list}
        hits = [s for s in spans if s["surface"].lower() in ignored]
        check(case, "ignored surface produces a skipped span",
              bool(hits) and all(s["classification"] == "skipped" for s in hits),
              str([(s["surface"], s["classification"]) for s in hits]))

failures = [r for r in results if r[2] != "pass"]
for case, name, verdict, note in results:
    if verdict != "pass":
        print(f"  {verdict}  {case}: {name}  {note}")
print(f"\n=== independent checks: {len(results)} total, "
      f"{len(results) - len(failures)} pass, {len(failures)} fail ===")
sys.exit(1 if failures else 0)
