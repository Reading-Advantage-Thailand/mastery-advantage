#!/usr/bin/env python3
"""Independent probes for the Phase 3 review findings."""
import copy
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unicodedata

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "english/cefr-vocabulary"
ENTRY = BASE / "scripts/gse-vocabulary-core.js"
FIX = BASE / "fixtures/gse-vocab"
FROZEN = BASE / "cefr-vocabulary-knowledge-space.json"
INVENTORY = BASE / "data/cambridge-vocabulary-inventory.json"
QUEUES = ("ambiguous-node-to-entry.jsonl", "unmapped-node-to-entry.jsonl",
          "unmatched-gse-entry.jsonl", "invalid-cefr-source-data.jsonl")
POS = set("adjective adverb conjunction determiner interjection noun number preposition pronoun verb phrase prefix".split()) | {"phrasal verb"}


def need(value, message):
    if not value:
        raise AssertionError(message)


def load(path):
    return json.loads(Path(path).read_text())


def write(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(",", ":")) + "\n")


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def form(value):
    return unicodedata.normalize("NFKC", value).strip().casefold()


def pos(values):
    return sorted({v.strip().casefold().replace("phrasal-verb", "phrasal verb") for v in values})


def band(value):
    if not isinstance(value, str):
        return None
    value = value.strip().lstrip("<").split("(")[0].strip().rstrip("*").upper()
    return value if value in {"PRE-A1", "A1", "A2", "B1", "B2", "C1", "C2"} else None


def jsonl(path):
    return [json.loads(line) for line in Path(path).read_text().splitlines() if line.strip()]


def invoke(args):
    return subprocess.run(["node", str(ENTRY), *map(str, args)], cwd=ROOT,
                          capture_output=True, text=True, timeout=120)


def success(result):
    need(result.returncode == 0, f"CLI exit {result.returncode}: {result.stderr.strip()}")


def rejected(result, field):
    need(result.returncode != 0, f"The command accepted invalid {field}.")
    need(field.casefold() in result.stderr.casefold(), f"The diagnostic does not name {field}: {result.stderr.strip()}")


class Run:
    def __init__(self, root, real=False, audience="GL"):
        self.root = root
        root.mkdir(parents=True)
        self.fixture = root / "fixture"
        shutil.copytree(FIX, self.fixture)
        self.prior = root / "prior.json"
        self.frozen = root / "frozen.json"
        shutil.copyfile(FROZEN, self.frozen)
        self.output = root / "output"
        self.graph = self.output / "graph/new-graph.json"
        self.mapping = self.output / "mapping/mappings.json"
        self.diff = root / "reports/diff.json"
        self.quality = root / "reports/quality.json"
        self.conflicts = root / "reports/conflicts.jsonl"
        self.yle = root / "yle.json"
        self.queues = {q: root / "queues" / q for q in QUEUES}
        self.real = real
        self.audience = audience
        self.exports = {}
        if real:
            shutil.copyfile(FROZEN, self.prior)
            for a in ("GL", "YL"):
                filename = load(FIX / "manifest.json")["sourceExports"][a]["file"]
                self.exports[a] = root / filename
                shutil.copyfile(BASE / "source-pdfs" / filename, self.exports[a])
        else:
            cases = load(self.fixture / "mapping-cases.json")["cases"]
            graph = copy.deepcopy(next(c["priorGraph"] for c in load(FIX / "mutation-cases.json")["cases"] if "priorGraph" in c))
            nodes = {n["id"]: n for n in graph["nodes"]}
            for case in cases:
                n = case.get("node")
                if not n:
                    continue
                node = nodes.setdefault(n["nodeId"], {"id": n["nodeId"], "metadata": {}})
                node["metadata"].update(normalizedForm=n["normalizedForm"], partsOfSpeech=n["partsOfSpeech"], audience=n["audience"])
                if "cambridgeCefr" in n:
                    node["metadata"].update(cefr=n["cambridgeCefr"], cefrAlignments=n["cambridgeCefrAlignments"])
            nodes["fixture:core:afternoon"]["metadata"].update(normalizedForm="afternoon", partsOfSpeech=["noun"], audience="GL")
            graph["nodes"] = list(nodes.values())
            graph.setdefault("edges", [])
            write(self.prior, graph)

    def sources(self):
        if self.real:
            return ["--gl-export", self.exports["GL"], "--yl-export", self.exports["YL"], "--audience", self.audience]
        return ["--fixture-dir", self.fixture]

    def args(self):
        args = self.sources() + ["--prior-graph", self.prior, "--output-dir", self.output,
                                "--byte-diff-report", self.diff, "--mapping-quality-report", self.quality,
                                "--conflict-report", self.conflicts, "--yle-output", self.yle, "--frozen-yle", self.frozen]
        if self.real:
            args += ["--release-date", "2026-10-25"]
        for name, path in self.queues.items():
            args += ["--queue-file", f"{name}={path}"]
        return args

    def run(self):
        return invoke(self.args())

    def validate(self, graph):
        path = self.root / "validation.json"
        write(path, graph)
        return invoke(["--validate-output", path, *self.sources()])

    def untouched_outputs(self):
        need(not any(p.exists() for p in [self.output, self.diff.parent, self.yle, *self.queues.values()]),
             "Invalid input created output files.")


def fixture_case(run, name):
    return next(c for c in load(run.fixture / "mapping-cases.json")["cases"] if c["caseId"] == name)


def mapped_mutation(root):
    run = Run(root)
    success(run.run())
    nodes = {n["id"]: n for n in load(run.graph)["nodes"]}
    for name in ("multi-pos-expression", "same-form-different-pos-falsifier", "cambridge-gse-level-conflict", "absent-optional-cefr"):
        case = fixture_case(run, name)
        candidates = [e for e in case["entries"]
                      if form(e["expression"]) == form(case["node"]["normalizedForm"])
                      and pos(e["grammaticalCategories"]) == pos(case["node"]["partsOfSpeech"])
                      and e["audience"] == case["node"]["audience"]]
        need(len(candidates) == 1, "The test requires one exact candidate.")
        value = nodes[case["node"]["nodeId"]]["metadata"].get("gse", {})
        need(value.get("itemId") == candidates[0]["itemId"], f"Mapped node lacks the selected itemId: {name}")


def no_inference(root):
    run = Run(root)
    success(run.run())
    nodes = {n["id"]: n for n in load(run.graph)["nodes"]}
    for name in ("ambiguous-binding", "unmapped-core-node", "invalid-cefr-source-data"):
        case = fixture_case(run, name)
        need("gse" not in nodes[case["node"]["nodeId"]]["metadata"], f"Rejected mapping carries GSE data: {name}")


def validation(root, mode):
    run = Run(root)
    if mode == "structure":
        rejected(run.validate({}), "nodes")
        return
    if mode == "false-gse":
        graph = load(run.prior)
        for node in graph["nodes"]:
            node.get("metadata", {}).pop("gse", None)
        graph["nodes"][0]["metadata"]["gse"] = False
        rejected(run.validate(graph), "gse")
        return
    success(run.run())
    graph = load(run.graph)
    if mode == "itemId":
        node = next(n for n in graph["nodes"] if n.get("metadata", {}).get("gse"))
        del node["metadata"]["gse"]["itemId"]
        rejected(run.validate(graph), "itemId")
    else:
        node = copy.deepcopy(next(n for n in graph["nodes"] if n.get("metadata", {}).get("gse")))
        node["id"] = "probe:unrelated-node"
        node["metadata"].update(normalizedForm="not the cited expression", partsOfSpeech=["prefix"], audience="GL")
        graph["nodes"].append(node)
        rejected(run.validate(graph), "mapping")


def conflicts(root):
    run = Run(root)
    prior = load(run.prior)
    target = fixture_case(run, "cambridge-gse-level-conflict")["node"]["nodeId"]
    for node in prior["nodes"]:
        if node["id"] == target:
            node["metadata"]["cefrAlignments"] = ["pre-a1", "a2", "b1"]
    write(run.prior, prior)
    success(run.run())
    expected = []
    for node in load(run.graph)["nodes"]:
        meta = node.get("metadata", {})
        gse = meta.get("gse", {})
        if meta.get("cefr") is not None and gse.get("cefrBand") and band(meta["cefr"]) != gse["cefrBand"]:
            expected.append({"nodeId": node["id"], "itemId": gse["itemId"], "audience": gse["audience"],
                             "cambridgeCefr": meta["cefr"], "cambridgeCefrAlignments": meta.get("cefrAlignments", []),
                             "gseCefrBand": gse["cefrBand"], "reason": "cambridge-gse-cefr-disagreement",
                             "sourceExportSha256": gse["sourceCitation"]["exportSha256"]})
    rows = jsonl(run.conflicts)
    need(sorted(rows, key=lambda r: r["nodeId"]) == sorted(expected, key=lambda r: r["nodeId"]), "Conflict rows differ from the mapped graph.")
    need(any(r["nodeId"] == target and r["cambridgeCefrAlignments"] == ["pre-a1", "a2", "b1"] for r in rows), "The report did not copy the node alignments.")
    for path, key in ((run.diff, "diffCounts"), (run.quality, "counts")):
        need(load(path)[key]["Conflicts"] == len(rows), "The conflict count differs from the row count.")


def correction(root):
    run = Run(root)
    success(run.run())
    graph = load(run.graph)
    node = next(n for n in graph["nodes"] if n["id"] == "fixture:core:afternoon")
    need(node["metadata"]["gse"]["cefrBand"] == "A1", "The setup lacks the source band.")
    node["metadata"]["gse"]["cefrBand"] = "C2"
    write(run.prior, graph)
    success(run.run())
    node = next(n for n in load(run.graph)["nodes"] if n["id"] == node["id"])
    need(node["metadata"]["gse"]["cefrBand"] == "A1", "The same itemId kept a stale band.")
    need(load(run.diff)["diffCounts"]["Levels corrected"] == 1, "Levels corrected does not count the seeded correction.")


def literals(_root):
    text = ENTRY.read_text()
    values = set()
    def visit(value, key=""):
        if isinstance(value, dict):
            for k, v in value.items():
                visit(v, k)
        elif isinstance(value, list):
            for v in value:
                visit(v, key)
        elif isinstance(value, str) and key in ("caseId", "itemId"):
            values.add(value)
    for path in FIX.glob("*.json"):
        visit(load(path))
    hits = sorted(v for v in values if v in text)
    need("fixture:" not in text and not hits, f"The product contains fixture literals: {hits}")


def pinned(run):
    text = (BASE / "GSE_VOCABULARY_SOURCES.md").read_text()
    result = {}
    for audience, path in run.exports.items():
        match = re.search(r"\|[^\n]*`source-pdfs/" + re.escape(path.name) + r"`[^\n]*`([0-9a-f]{64})`", text)
        need(match is not None, f"The sources document lacks the hash for {audience}.")
        need(digest(path) == match[1], f"The {audience} export differs from its pinned SHA-256.")
        result[audience] = match[1]
    return result


def real_run(root, audience="GL"):
    run = Run(root, real=True, audience=audience)
    pinned(run)
    need(run.prior.read_bytes() == FROZEN.read_bytes(), "The prior copy is not byte-identical.")
    prior_bytes = run.prior.read_bytes()
    success(run.run())
    need(run.prior.read_bytes() == prior_bytes, "The command changed its prior input.")
    return run


def real_source(root):
    for audience in ("GL", "YL"):
        run = real_run(root / audience, audience)
        hashes = {a: digest(path) for a, path in run.exports.items()}
        graph = load(run.graph)
        nodes = {n["id"]: n for n in graph["nodes"]}
        need(nodes["english.vocabulary.domain"]["metadata"]["schemaVersion"] == "gse-vocab-20261025-r01", "The domain version does not use the supplied date.")
        need(load(run.diff)["priorSha256"] == digest(run.prior), "The report does not hash the actual prior bytes.")
        need(load(run.diff)["newSha256"] == digest(run.graph), "The report does not hash the actual graph bytes.")
        for a in ("GL", "YL"):
            raw = load(run.exports[a])["data"]
            output = load(run.output / f"extraction/{a.lower()}.json")
            records = {r["itemId"]: r for r in output["records"]}
            need(len(records) == len(raw), f"The extractor dropped {a} records.")
            need(output["sourceExportSha256"] == hashes[a], f"The {a} extraction has the wrong hash.")
            for entry in raw:
                for key in ("expression", "grammaticalCategories", "audience", "gse", "cefr", "variants", "topics", "temporaryGse"):
                    if key in entry:
                        need(records[entry["itemId"]].get(key) == entry[key], f"Extraction changed {a} {key}.")
        source = {e["itemId"]: e for e in load(run.exports[audience])["data"]}
        population = [n for n in graph["nodes"] if n.get("metadata", {}).get("gse")]
        need(len(population) > 0, "The real graph has no mapped nodes.")
        prior_nodes = {n["id"]: n for n in load(run.prior)["nodes"]}
        need(set(nodes) == set(prior_nodes), "The mutation added or removed core nodes.")
        need(graph["edges"] == load(run.prior)["edges"], "The mutation changed core edges.")
        index = {}
        for entry in source.values():
            key = (form(entry["expression"]), tuple(pos(entry["grammaticalCategories"])))
            index.setdefault(key, []).append(entry)
        accepted = set()
        for node_id, old in prior_nodes.items():
            old_meta = old.get("metadata", {})
            for key in ("cefr", "cefrAlignments", "examAlignments"):
                need(nodes[node_id].get("metadata", {}).get(key) == old_meta.get(key), f"The mutation changed Cambridge field {key}.")
            labels = pos(old_meta.get("partsOfSpeech", []))
            if not old_meta.get("normalizedForm") or not labels or not set(labels) <= POS:
                continue
            candidates = index.get((form(old_meta["normalizedForm"]), tuple(labels)), [])
            if len(candidates) == 1 and ("cefr" not in candidates[0] or band(candidates[0]["cefr"])):
                accepted.add(node_id)
        need({n["id"] for n in population} == accepted, "The mutated node set differs from the independent exact join.")
        for node in population:
            meta = node["metadata"]
            value = meta["gse"]
            need(value.get("itemId") in source, "A mapped node lacks a pinned itemId.")
            entry = source[value["itemId"]]
            need(form(meta["normalizedForm"]) == form(entry["expression"]), "The cited form does not bind.")
            need(pos(meta["partsOfSpeech"]) == pos(entry["grammaticalCategories"]), "The cited POS does not bind.")
            need(value["audience"] == entry["audience"] == audience, "The cited audience does not bind.")
            need(value["sourceCitation"]["exportSha256"] == hashes[audience], "The citation hash differs.")
            need(value.get("gseScore") == entry["gse"], "The mapped score differs from the source.")
            need(value.get("cefrBand") == band(entry.get("cefr")), "The mapped band differs from the accepted rule.")
            expected = {"itemId": entry["itemId"], "audience": audience, "gseScore": entry["gse"],
                        "starred": entry["gse"].endswith("*"), "sourceCitation": {
                            "sourceId": run.exports[audience].stem, "itemId": entry["itemId"],
                            "exportSha256": hashes[audience]}}
            for key in ("definition", "example", "temporaryGse"):
                if key in entry:
                    expected[key] = entry[key]
            if band(entry.get("cefr")):
                expected["cefrBand"] = band(entry["cefr"])
            need(value == expected, "Mapped GSE fields differ from the cited source.")
        second = Run(root / f"{audience}-second", real=True, audience=audience)
        success(second.run())
        for left, right in ((run.graph, second.graph), (run.mapping, second.mapping), (run.diff, second.diff)):
            need(left.read_bytes() == right.read_bytes(), "Real outputs are not deterministic.")
        write(run.prior, graph)
        success(run.run())
        domain = next(n for n in load(run.graph)["nodes"] if n["id"] == "english.vocabulary.domain")
        need(domain["metadata"]["schemaVersion"] == "gse-vocab-20261025-r02", "The repeated date did not increment its revision.")


def tampered_export(root, audience):
    real_run(root / "control")
    run = Run(root / "tampered", real=True)
    with run.exports[audience].open("ab") as stream:
        stream.write(b" ")
    result = run.run()
    rejected(result, "SHA-256")
    need(audience.casefold() in result.stderr.casefold(), "The hash diagnostic lacks the audience.")
    run.untouched_outputs()


def real_pos(root):
    run = real_run(root / "control")
    raw = load(run.exports["GL"])["data"]
    candidates = {}
    for entry in raw:
        if pos(entry["grammaticalCategories"]) == ["phrasal verb"] and band(entry.get("cefr")):
            candidates.setdefault(form(entry["expression"]), []).append(entry)
    expression = next(k for k, entries in candidates.items() if len(entries) == 1)
    graph = load(run.prior)
    for suffix, labels in (("supported", ["phrasal-verb"]), ("unsupported", ["title"]), ("missing", [])):
        graph["nodes"].append({"id": f"probe:pos:{suffix}", "type": "skill", "metadata": {"normalizedForm": expression, "partsOfSpeech": labels}})
    write(run.prior, graph)
    success(run.run())
    nodes = {n["id"]: n for n in load(run.graph)["nodes"]}
    need(nodes["probe:pos:supported"]["metadata"].get("gse", {}).get("itemId") == candidates[expression][0]["itemId"], "Core phrasal-verb did not bind GSE phrasal verb.")
    rows = {r["nodeId"]: r for r in jsonl(run.queues[QUEUES[1]])}
    for suffix, reason in (("unsupported", "unsupported-pos"), ("missing", "missing-identity")):
        need(rows.get(f"probe:pos:{suffix}", {}).get("reason") == reason, f"The mapper omitted {reason}.")
        need("gse" not in nodes[f"probe:pos:{suffix}"]["metadata"], "An unsupported node carries GSE data.")


def durable_queues(root):
    tracked = set(subprocess.check_output(["git", "ls-files"], cwd=ROOT, text=True).splitlines())
    for name in QUEUES:
        path = BASE / "review/gse-vocab/queues" / name
        need(path.relative_to(ROOT).as_posix() in tracked and path.is_file(), f"The durable queue is not tracked: {name}")
    run = real_run(root)
    for name, generated in run.queues.items():
        path = BASE / "review/gse-vocab/queues" / name
        need(path.read_bytes() == generated.read_bytes(), f"The durable queue differs from the real GL run: {name}")
    invalid = jsonl(run.queues[QUEUES[3]])
    need(any("+" in r["rawCefr"] for r in invalid), "The real queue has no plus-band evidence.")
    nodes = {n["id"]: n for n in load(run.graph)["nodes"]}
    for name in (QUEUES[0], QUEUES[1], QUEUES[3]):
        for row in jsonl(run.queues[name]):
            need("gse" not in nodes[row["nodeId"]].get("metadata", {}), "A queued node carries GSE data.")


def destination_alias(root, mode):
    run = Run(root)
    before = {p: p.read_bytes() for p in (run.prior, run.frozen, run.fixture / "records.json")}
    target = run.frozen
    if mode == "input-equality":
        run.output = run.prior
    elif mode == "dot-segments":
        run.output = root / "unused" / ".." / "prior.json"
    elif mode == "parent-symlink":
        run.output.mkdir()
        (run.output / "graph").symlink_to(run.fixture, target_is_directory=True)
        target = run.fixture / "new-graph.json"
        target.write_text("protected sentinel\n")
        before[target] = target.read_bytes()
    else:
        run.graph.parent.mkdir(parents=True)
        if mode == "leaf-hardlink":
            os.link(target, run.graph)
        else:
            run.graph.symlink_to(target)
    result = run.run()
    for path, content in before.items():
        need(path.read_bytes() == content, f"The alias changed a protected input: {path.name}")
    rejected(result, "alias")
    need(not run.diff.exists() and not run.mapping.exists(), "The rejected alias left partial output.")


def malformed_entry(root, field, container):
    run = Run(root)
    path = run.fixture / ("mapping-cases.json" if container == "mapping" else "mutation-cases.json")
    document = load(path)
    if container == "mapping":
        case = next(c for c in document["cases"] if c["caseId"] == "same-form-different-pos-falsifier")
        entry = next(e for e in case["entries"] if e["grammaticalCategories"] == ["verb"])
    else:
        entry = next(c["sourceEntry"] for c in document["cases"] if "sourceEntry" in c)
    if field == "itemId":
        del entry[field]
    elif field == "definition":
        entry[field] = {"invalid": "object"}
    else:
        entry[field] = "true"
    write(path, document)
    run.diff.parent.mkdir()
    run.diff.write_text("existing report\n")
    result = run.run()
    need(run.diff.read_text() == "existing report\n", "Invalid input changed an existing report.")
    rejected(result, field)
    need(not run.output.exists() and not run.yle.exists(), "Invalid source entries produced extraction or graph output.")
    need(not any(p.exists() for p in run.queues.values()), "Invalid source entries produced queue output.")


def sandbox_yle(root):
    script = root / "english/cefr-vocabulary/scripts/generate-vocabulary-graph.js"
    script.parent.mkdir(parents=True)
    shutil.copyfile(BASE / "scripts/generate-vocabulary-graph.js", script)
    (script.parent.parent / "source-pdfs").symlink_to(BASE / "source-pdfs", target_is_directory=True)
    result = subprocess.run(["node", str(script)], cwd=root, capture_output=True, text=True, timeout=120)
    success(result)
    artifact = script.parent.parent / "cefr-vocabulary-knowledge-space.json"
    need(artifact.is_file() and artifact.stat().st_size > 0, "The sandbox generator produced no comparison artifact.")
    return artifact.read_bytes()


def yle_graph(root):
    sandbox_before = sandbox_yle(root / "sandbox-before")
    before = Run(root / "before")
    success(before.run())
    graph = load(before.graph)
    after = Run(root / "after")
    item = next(n["metadata"]["gse"]["itemId"] for n in graph["nodes"] if n["id"] == "fixture:core:afternoon")
    def change_source(value):
        if isinstance(value, dict):
            if value.get("itemId") == item and "gse" in value:
                value["gse"] = "20*"
            for child in value.values():
                change_source(child)
        elif isinstance(value, list):
            for child in value:
                change_source(child)
    for path in after.fixture.glob("*.json"):
        document = load(path)
        change_source(document)
        write(path, document)
    graph = copy.deepcopy(graph)
    next(n for n in graph["nodes"] if n["id"] == "fixture:core:afternoon")["metadata"].pop("gse")
    write(after.prior, graph)
    success(after.run())
    after_graph = load(after.graph)
    before_score = next(n["metadata"]["gse"]["gseScore"] for n in load(before.graph)["nodes"] if n["id"] == "fixture:core:afternoon")
    after_score = next(n["metadata"]["gse"]["gseScore"] for n in after_graph["nodes"] if n["id"] == "fixture:core:afternoon")
    need(before_score != after_score and after_score == "20*", "The proof did not change a mapped GSE score.")
    need(before.yle.read_bytes() == after.yle.read_bytes(), "A GSE-only mutation changed the YLE comparison.")
    need(sandbox_before == sandbox_yle(root / "sandbox-after"), "The accepted sandbox procedure changed after the GSE mutation.")
    changed = Run(root / "changed")
    shutil.rmtree(changed.fixture)
    shutil.copytree(after.fixture, changed.fixture)
    graph = after_graph
    node = next(n for n in graph["nodes"] if n.get("metadata", {}).get("cefr"))
    old = node["metadata"]["cefr"]
    node["metadata"]["cefr"] = "B2" if old != "B2" else "A1"
    write(changed.prior, graph)
    success(changed.run())
    need(after.yle.read_bytes() != changed.yle.read_bytes(), "A Cambridge CEFR change did not alter the YLE comparison.")


def destination_files(run):
    return [run.output / "extraction/gl.json", run.output / "extraction/yl.json",
            run.mapping, run.graph, run.diff, run.quality, run.conflicts, run.yle,
            *run.queues.values()]


def seed_destinations(run, omit=()):
    for index, path in enumerate(destination_files(run)):
        if path not in omit:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(f"destination sentinel {index}\n".encode())


def tree_state(root):
    """Record all temporary bytes and links without following directory links."""
    result = {}
    for parent, directories, files in os.walk(root, followlinks=False):
        directories[:] = [name for name in directories if name != ".git"]
        for name in directories + files:
            path = Path(parent) / name
            key = path.relative_to(root).as_posix()
            if path.is_symlink():
                result[key] = ("link", os.readlink(path))
            elif path.is_dir():
                result[key] = ("directory",)
            else:
                result[key] = ("file", path.read_bytes())
    return result


def reject_without_writes(run, snapshot_root, label, field=None, entry=None, cwd=None):
    before = tree_state(snapshot_root)
    if entry is None:
        result = run.run()
    else:
        result = subprocess.run(["node", str(entry), *map(str, run.args())], cwd=cwd,
                                capture_output=True, text=True, timeout=120)
    after = tree_state(snapshot_root)
    changed = sorted(k for k in before.keys() | after.keys() if before.get(k) != after.get(k))
    errors = []
    if result.returncode == 0:
        errors.append(f"The command accepted {label}.")
    if changed:
        errors.append(f"Rejection changed temporary paths: {', '.join(changed)}.")
    if result.returncode != 0:
        if field:
            if field.casefold() not in result.stderr.casefold():
                errors.append(f"The diagnostic does not name {field}: {result.stderr.strip()}")
        elif not result.stderr.strip():
            errors.append("The rejection has no diagnostic.")
    need(not errors, " ".join(errors))


def dangling_generated_leaf(root):
    # Execution contract 49, 129-132: reject every generated symlink before writes.
    run = Run(root)
    seed_destinations(run, omit=(run.graph,))
    target = root / "unsupplied-target.json"
    run.graph.parent.mkdir(parents=True, exist_ok=True)
    run.graph.symlink_to(target)
    need(run.graph.is_symlink() and not target.exists(), "The setup needs a dangling link.")
    reject_without_writes(run, root, "a dangling generated leaf")
    need(not target.exists(), "The command created an unsupplied target.")


def copied_product(root):
    """Give the entry script a temporary repository and read-only protected inputs."""
    repo = root / "repository"
    product = repo / "english/cefr-vocabulary"
    entry = product / "scripts/gse-vocabulary-core.js"
    entry.parent.mkdir(parents=True)
    shutil.copyfile(ENTRY, entry)
    for relative in ("cefr-vocabulary-knowledge-space.json", "data/cambridge-vocabulary-inventory.json",
                     "GSE_VOCABULARY_SOURCES.md", "fixtures", "source-pdfs"):
        path = product / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.symlink_to(BASE / relative, target_is_directory=(BASE / relative).is_dir())
    success(subprocess.run(["git", "init", "--quiet", str(repo)], capture_output=True, text=True))
    return repo, entry


def tracked_destination(root, mode):
    # Only the four durable GL queue paths have repository write authority.
    # Never track or write a destination in the real checkout.
    repo, entry = copied_product(root)
    run = Run(root / "run")
    target = repo / "foreign-track/queues/foreign-queue.jsonl"
    if mode == "report":
        run.diff = target
    elif mode == "queue":
        run.queues[QUEUES[0]] = target
    else:
        run.output = repo / "generated"
        run.graph = run.output / "graph/new-graph.json"
        run.mapping = run.output / "mapping/mappings.json"
        target = run.graph
    seed_destinations(run)
    success(subprocess.run(["git", "add", "--", str(target.relative_to(repo))], cwd=repo,
                           capture_output=True, text=True))
    tracked = subprocess.check_output(["git", "ls-files"], cwd=repo, text=True).splitlines()
    need(tracked == [target.relative_to(repo).as_posix()], "The setup must track only the sentinel.")
    reject_without_writes(run, root, f"a tracked foreign {mode} destination", entry=entry, cwd=repo)


def foreign_queue_sentinel(root):
    # Mapping contract 68-76, 110-116: foreign queues remain isolated.
    run = Run(root)
    run.queues[QUEUES[0]] = root / "foreign-track/queues/foreign-queue.jsonl"
    seed_destinations(run)
    reject_without_writes(run, root, "a foreign queue destination")


def source_metadata(run, entry):
    """Copy only stated fields, with the accepted Phase 3 band rule."""
    source_file = load(run.fixture / "manifest.json")["sourceExports"][entry["audience"]]["file"]
    value = {"itemId": entry["itemId"], "audience": entry["audience"],
             "sourceCitation": {"sourceId": Path(source_file).stem, "itemId": entry["itemId"],
                                "exportSha256": entry["sourceExportSha256"]}}
    if "gse" in entry:
        value.update(gseScore=entry["gse"], starred=entry["gse"].endswith("*"))
    for field in ("definition", "example", "temporaryGse"):
        if field in entry:
            value[field] = copy.deepcopy(entry[field])
    if band(entry.get("cefr")):
        value["cefrBand"] = band(entry["cefr"])
    return value


def validate_rejected_outcome(root, case_name):
    # Execution contract 61, 106, 160-164: a citation cannot override classification.
    run = Run(root)
    success(run.run())
    graph = load(run.graph)
    success(run.validate(graph))
    case = fixture_case(run, case_name)
    identity = case["node"]
    candidates = [e for e in case["entries"]
                  if form(e["expression"]) == form(identity["normalizedForm"])
                  and pos(e["grammaticalCategories"]) == pos(identity["partsOfSpeech"])
                  and e["audience"] == identity["audience"]]
    if case_name == "ambiguous-binding":
        need(len(candidates) > 1, "The setup needs multiple exact candidates.")
    else:
        need(len(candidates) == 1 and "cefr" in candidates[0] and band(candidates[0]["cefr"]) is None,
             "The setup needs one invalid-CEFR candidate under the Phase 3 rule.")
    node = next(n for n in graph["nodes"] if n["id"] == identity["nodeId"])
    need("gse" not in node["metadata"], "The control graph already carries rejected metadata.")
    node["metadata"]["gse"] = source_metadata(run, candidates[0])
    validation_path = root / "validation.json"
    write(validation_path, graph)
    before = tree_state(root)
    result = invoke(["--validate-output", validation_path, *run.sources()])
    need(tree_state(root) == before, "Output validation changed temporary bytes.")
    rejected(result, "gse")


def mismatched_prior_identity(root):
    # Mapping contract 11-23: actual node identity controls mutation.
    run = Run(root)
    success(run.run())
    case = fixture_case(run, "same-form-different-pos-falsifier")
    target = case["node"]["nodeId"]
    control = next(n for n in load(run.graph)["nodes"] if n["id"] == target)
    need(control["metadata"]["gse"]["itemId"] == case["expected"]["itemId"], "The control did not map make.")
    prior = load(run.prior)
    node = next(n for n in prior["nodes"] if n["id"] == target)
    node["metadata"].update(normalizedForm="synthetic unrelated prior identity")
    node["metadata"].pop("gse", None)
    write(run.prior, prior)
    seed_destinations(run)
    before = tree_state(root)
    result = run.run()
    if result.returncode != 0:
        need(tree_state(root) == before, "Rejected prior identity changed destination bytes.")
        need(bool(result.stderr.strip()), "Rejected prior identity has no diagnostic.")
    else:
        node = next(n for n in load(run.graph)["nodes"] if n["id"] == target)
        need("gse" not in node["metadata"], "The mismatched actual prior node received make GSE metadata.")


def hardened_mapping_source(root, mode):
    # Execution contract 129, 162: validate complete citations before writes.
    run = Run(root)
    path = run.fixture / "mapping-cases.json"
    document = load(path)
    case = next(c for c in document["cases"] if c["caseId"] == "same-form-different-pos-falsifier")
    entry = next(e for e in case["entries"] if e["grammaticalCategories"] == ["verb"])
    field = "sourceExportSha256"
    if mode == "missing-citation-hash":
        del entry[field]
    elif mode == "malformed-citation-hash":
        entry[field] = "not-a-sha256"
    else:
        duplicate = copy.deepcopy(entry)
        if mode == "conflicting-duplicate-identity":
            duplicate["expression"] = "synthetic conflicting identity"
            field = "itemId"
        elif mode == "conflicting-duplicate-source":
            duplicate["gse"] = "12"
            field = "itemId"
        elif mode == "unsupported-audience":
            duplicate.update(itemId="synthetic:unsupported-audience", audience="unsupported")
            field = "audience"
        elif mode == "agreeing-duplicate":
            duplicate["definition"] = "Synthetic additive fixture text."
        else:
            raise AssertionError(f"Unknown source probe: {mode}")
        document["cases"].append({"caseId": f"probe:{mode}", "node": None, "entries": [duplicate]})
    write(path, document)
    if mode == "agreeing-duplicate":
        success(run.run())
        node = next(n for n in load(run.graph)["nodes"] if n["id"] == case["node"]["nodeId"])
        need(node["metadata"]["gse"]["itemId"] == entry["itemId"], "An agreeing duplicate lost the mapping.")
        need(node["metadata"]["gse"]["gseScore"] == entry["gse"], "An agreeing duplicate changed the source score.")
        success(run.validate(load(run.graph)))
    else:
        seed_destinations(run)
        reject_without_writes(run, root, mode, field=field)


def main():
    probes = {"mapped-mutation": mapped_mutation, "no-inference": no_inference,
              "validation-binding": lambda r: validation(r, "binding"),
              "validation-itemId": lambda r: validation(r, "itemId"),
              "validation-structure": lambda r: validation(r, "structure"),
              "validation-false-gse": lambda r: validation(r, "false-gse"),
              "conflicts": conflicts, "correction": correction, "fixture-literals": literals}
    probes.update(EXTRA_PROBES)
    name = sys.argv[1]
    before = {p: digest(p) for p in (FROZEN, INVENTORY)}
    try:
        temporary_root = Path(os.environ.get("TMPDIR") or "/tmp").resolve()
        need(not temporary_root.is_relative_to(ROOT), "Temporary storage must stay outside the repository.")
        with tempfile.TemporaryDirectory(prefix="gse-vocab-p3-review-", dir=temporary_root) as tmp:
            probes[name](Path(tmp) / "run")
    finally:
        for path, value in before.items():
            need(digest(path) == value, f"Protected input changed: {path}")


EXTRA_PROBES = {"real-source": real_source,
                "tampered-GL": lambda r: tampered_export(r, "GL"),
                "tampered-YL": lambda r: tampered_export(r, "YL"),
                "real-pos": real_pos, "durable-queues": durable_queues, "yle-graph": yle_graph}
EXTRA_PROBES.update({
    "RB-P3R-B1-dangling-generated-leaf": dangling_generated_leaf,
    "RB-P3R-B1-foreign-queue-sentinel": foreign_queue_sentinel,
    "RB-P3R-B2-validate-ambiguous": lambda r: validate_rejected_outcome(r, "ambiguous-binding"),
    "RB-P3R-B2-validate-invalid-cefr": lambda r: validate_rejected_outcome(r, "invalid-cefr-source-data"),
    "RB-P3R-B2-mismatched-prior-identity": mismatched_prior_identity,
})
for _label, _mode in (("tracked-report", "report"), ("tracked-generated-leaf", "leaf"), ("tracked-foreign-queue", "queue")):
    EXTRA_PROBES[f"RB-P3R-B1-{_label}"] = lambda r, mode=_mode: tracked_destination(r, mode)
for _mode in ("missing-citation-hash", "malformed-citation-hash", "conflicting-duplicate-identity",
              "conflicting-duplicate-source", "unsupported-audience", "agreeing-duplicate"):
    EXTRA_PROBES[f"RB-P3R-B3-{_mode}"] = lambda r, mode=_mode: hardened_mapping_source(r, mode)
for _mode in ("leaf-symlink", "leaf-hardlink", "parent-symlink", "dot-segments", "input-equality"):
    EXTRA_PROBES[_mode] = lambda r, mode=_mode: destination_alias(r, mode)
for _container in ("mapping", "mutation"):
    for _field in ("itemId", "definition", "temporaryGse"):
        EXTRA_PROBES[f"malformed-{_container}-{_field}"] = lambda r, field=_field, container=_container: malformed_entry(r, field, container)

if __name__ == "__main__":
    try:
        main()
    except (AssertionError, OSError, ValueError, KeyError, StopIteration, TypeError, subprocess.TimeoutExpired) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
