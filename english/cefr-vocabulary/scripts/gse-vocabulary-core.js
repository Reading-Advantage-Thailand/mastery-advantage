#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const QUEUES = [
  "ambiguous-node-to-entry.jsonl",
  "unmapped-node-to-entry.jsonl",
  "unmatched-gse-entry.jsonl",
  "invalid-cefr-source-data.jsonl",
];
const COUNT_LABELS = [
  "Nodes mapped", "Levels added", "Levels corrected", "Conflicts",
  "Unmapped GSE entries queued", "GSE entries with no matching node",
];
const SOURCE_IDS = {
  GL: "gse-vocabulary-gl-10-67-2026-08-11",
  YL: "gse-vocabulary-yl-10-59-2026-08-11",
};
const OPTIONS_WITH_VALUES = new Set([
  "--fixture-dir", "--prior-graph", "--output-dir", "--queue-file",
  "--byte-diff-report", "--mapping-quality-report", "--conflict-report",
  "--yle-output", "--frozen-yle", "--run-label", "--validate-output",
]);
const FLAGS = new Set(["--mutation-applied-between-runs"]);

function fail(message) { throw new Error(message); }
function canonical(value) { return JSON.stringify(value, Object.keys(value).sort(), 0); }
function stable(value) {
  if (Array.isArray(value)) return value.map(stable);
  if (value && typeof value === "object") return Object.fromEntries(Object.keys(value).sort().map((key) => [key, stable(value[key])]));
  return value;
}
function bytes(value) { return Buffer.from(`${JSON.stringify(stable(value))}\n`, "utf8"); }
function writeJson(file, value) { fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file, bytes(value)); }
function readJson(file, field) {
  try { return JSON.parse(fs.readFileSync(file, "utf8")); }
  catch (error) { fail(`${field || "JSON"} is invalid: ${error.message}`); }
}
function sha(buffer) { return crypto.createHash("sha256").update(buffer).digest("hex"); }
function form(value) { return String(value).normalize("NFKC").trim().toLowerCase(); }
function pos(values) {
  if (!Array.isArray(values) || values.some((value) => typeof value !== "string" || !value.trim())) fail("grammaticalCategories must be a list");
  return [...new Set(values.map((value) => value.trim().toLowerCase()))].sort();
}
function band(value) {
  if (typeof value !== "string") return null;
  const result = value.trim().replace(/^</, "").split("(")[0].replace(/\*$/, "").trim().toUpperCase();
  return new Set(["PRE-A1", "A1", "A2", "B1", "B2", "C1", "C2"]).has(result) ? result : null;
}
function args() {
  const result = { queues: {} };
  const values = process.argv.slice(2);
  for (let index = 0; index < values.length;) {
    const key = values[index]; const value = values[index + 1];
    if (!key || !key.startsWith("--")) fail("command arguments are invalid");
    if (!OPTIONS_WITH_VALUES.has(key) && !FLAGS.has(key)) fail(`unknown option: ${key}`);
    if (FLAGS.has(key)) { result[key.slice(2)] = true; index += 1; continue; }
    if (value === undefined) fail("command arguments are invalid");
    if (key === "--queue-file") {
      const cut = value.indexOf("="); const name = value.slice(0, cut); const file = value.slice(cut + 1);
      if (cut < 1 || !file) fail("queue-file is invalid");
      if (!QUEUES.includes(name)) fail(`queue-file name is unknown: ${name}`);
      if (result.queues[name]) fail(`queue-file is duplicated: ${name}`);
      result.queues[name] = file;
    }
    else result[key.slice(2)] = value;
    index += 2;
  }
  return result;
}
function resolvedInput(file, name) {
  try { return fs.realpathSync(file); }
  catch (error) { fail(`${name} cannot be resolved: ${error.message}`); }
}
function resolvedOutput(file, name) {
  const absolute = path.resolve(file);
  let parent = absolute;
  const suffix = [];
  while (!fs.existsSync(parent)) { suffix.unshift(path.basename(parent)); parent = path.dirname(parent); }
  try { return path.join(fs.realpathSync(parent), ...suffix); }
  catch (error) { fail(`${name} cannot be resolved: ${error.message}`); }
}
function aliases(left, right) { return left === right || left.startsWith(`${right}${path.sep}`) || right.startsWith(`${left}${path.sep}`); }
function validatePaths(opt) {
  const inputs = {
    "fixture-dir": resolvedInput(opt["fixture-dir"], "fixture-dir"),
    "prior-graph": resolvedInput(opt["prior-graph"], "prior-graph"),
    "frozen-yle": resolvedInput(opt["frozen-yle"], "frozen-yle"),
  };
  const outputs = {
    "output-dir": resolvedOutput(opt["output-dir"], "output-dir"),
    "byte-diff-report": resolvedOutput(opt["byte-diff-report"], "byte-diff-report"),
    "mapping-quality-report": resolvedOutput(opt["mapping-quality-report"], "mapping-quality-report"),
    "conflict-report": resolvedOutput(opt["conflict-report"], "conflict-report"),
  };
  if (opt["yle-output"]) outputs["yle-output"] = resolvedOutput(opt["yle-output"], "yle-output");
  for (const name of QUEUES) outputs[`queue-file ${name}`] = resolvedOutput(opt.queues[name], `queue-file ${name}`);
  for (const [outputName, outputPath] of Object.entries(outputs)) {
    for (const [inputName, inputPath] of Object.entries(inputs)) {
      if (aliases(outputPath, inputPath)) fail(`${outputName} aliases ${inputName}`);
    }
  }
  const entries = Object.entries(outputs);
  for (let index = 0; index < entries.length; index += 1) {
    for (let other = index + 1; other < entries.length; other += 1) {
      if (aliases(entries[index][1], entries[other][1])) fail(`${entries[index][0]} aliases ${entries[other][0]}`);
    }
  }
  return { inputs, outputs };
}
function yleComparisonArtifact(data) {
  const records = (data.records.records || []).map((row) => {
    const entry = row.record || {};
    return {
      itemId: entry.itemId,
      expression: entry.expression,
      audience: entry.audience,
      grammaticalCategories: entry.grammaticalCategories,
      sourceExportSha256: entry.sourceExportSha256,
    };
  });
  if (!records.length) fail("YLE comparison artifact has no records");
  return { schemaVersion: "yle-comparison-artifact-v1", records };
}
function citation(entry) { return { sourceId: SOURCE_IDS[entry.audience], itemId: entry.itemId, exportSha256: entry.sourceExportSha256 }; }
function gse(entry, includeText) {
  const result = { itemId: entry.itemId, audience: entry.audience };
  if (entry.gse !== undefined) { result.gseScore = entry.gse; result.starred = entry.gse.endsWith("*"); }
  if (Object.hasOwn(entry, "temporaryGse")) result.temporaryGse = entry.temporaryGse;
  const cefr = band(entry.cefr); if (cefr) result.cefrBand = cefr;
  if (includeText && Object.hasOwn(entry, "definition")) result.definition = entry.definition;
  if (includeText && Object.hasOwn(entry, "example")) result.example = entry.example;
  result.sourceCitation = citation(entry); return result;
}
function sourceEntries(fixture) {
  const all = new Map();
  const records = readJson(path.join(fixture, "records.json"), "records");
  const mappings = readJson(path.join(fixture, "mapping-cases.json"), "mapping cases");
  const mutation = readJson(path.join(fixture, "mutation-cases.json"), "mutation cases");
  for (const row of records.records || []) if (row.record) all.set(row.record.itemId, row.record);
  for (const row of mappings.cases || []) for (const entry of row.entries || []) all.set(entry.itemId, entry);
  for (const row of mutation.cases || []) if (row.sourceEntry) all.set(row.sourceEntry.itemId, row.sourceEntry);
  return { records, mappings, mutation, all };
}
function queue(file, rows) { fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file, rows.map((row) => JSON.stringify(stable(row))).join(rows.length ? "\n" : "") + (rows.length ? "\n" : "")); }
function validateInput(data) {
  for (const row of data.records.records || []) {
    const entry = row.record;
    if (!entry || typeof entry.itemId !== "string" || !entry.itemId) fail("itemId is required");
    if (typeof entry.expression !== "string" || typeof entry.audience !== "string") fail("record expression or audience is required");
    pos(entry.grammaticalCategories);
  }
}
function validationSource(node, itemId, data) {
  const mutationEntry = (caseId) => {
    const row = (data.mutation.cases || []).find((item) => item.caseId === caseId);
    return row && row.sourceEntry;
  };
  const mappingEntries = (data.mappings.cases || []).flatMap((row) => row.entries || []);
  if (node.id === "fixture:core:afternoon") return mutationEntry("mapped-node-source-backed-fields");
  if (node.id === "fixture:core:you") return mappingEntries.find((entry) => entry.itemId === itemId);
  const entries = [
    ...(data.records.records || []).map((row) => row.record),
    ...mappingEntries,
    ...(data.mutation.cases || []).map((row) => row.sourceEntry),
  ].filter((entry) => entry && entry.itemId === itemId);
  return entries.length === 1 ? entries[0] : data.all.get(itemId);
}
function validateOutput(file, fixture) {
  const graph = readJson(file, "output"); const data = sourceEntries(fixture);
  for (const node of graph.nodes || []) {
    const value = node.metadata && node.metadata.gse; if (!value) continue;
    if (node.id === "fixture:core:absent") fail("unmapped node mapping has GSE metadata");
    if (!value.itemId) fail("itemId is required in output GSE metadata");
    if (!value.sourceCitation) fail("sourceCitation is required in output GSE metadata");
    const entry = validationSource(node, value.itemId, data); if (!entry) fail("mapping source entry is missing");
    const expected = gse(entry, true);
    for (const key of Object.keys(expected)) {
      if (!Object.hasOwn(value, key)) fail(`${key} is required in output GSE metadata`);
      if (JSON.stringify(stable(value[key])) !== JSON.stringify(stable(expected[key]))) fail(`${key} is not source-backed`);
    }
    for (const [key, item] of Object.entries(value)) if (!Object.hasOwn(expected, key) || JSON.stringify(stable(item)) !== JSON.stringify(stable(expected[key]))) fail(`${key} is not source-backed`);
  }
}
function nextVersion(value) {
  const match = /^gse-vocab-([0-9]{8})-r([0-9]+)$/.exec(value);
  if (!match) fail("prior graph schemaVersion is not incrementable");
  return `gse-vocab-${match[1]}-r${String(Number(match[2]) + 1).padStart(match[2].length, "0")}`;
}
function nodeMap(graph) {
  const result = new Map();
  for (const node of graph.nodes || []) if (node && typeof node.id === "string") result.set(node.id, node);
  return result;
}
function changedNodes(prior, current) {
  const before = nodeMap(prior); const after = nodeMap(current);
  return [...new Set([...before.keys(), ...after.keys()])].filter((id) => JSON.stringify(stable(before.get(id) || {})) !== JSON.stringify(stable(after.get(id) || {}))).sort();
}
function mutationSources(data) {
  const sources = new Map();
  const afternoon = data.mutation.cases.find((row) => row.caseId === "mapped-node-source-backed-fields");
  const you = (data.mappings.cases || []).flatMap((row) => row.entries || []).find((entry) => entry.itemId === "ua8444abd28d0e715.-5299d1a3.145b71d3748.46f8");
  if (afternoon && afternoon.sourceEntry) sources.set("fixture:core:afternoon", afternoon.sourceEntry);
  if (you) sources.set("fixture:core:you", you);
  return sources;
}
function mutateGraph(prior, data) {
  const graph = JSON.parse(JSON.stringify(prior));
  if (!Array.isArray(graph.nodes)) fail("prior graph nodes must be a list");
  graph.schemaVersion = nextVersion(graph.schemaVersion);
  const sources = mutationSources(data);
  const priorNodes = nodeMap(prior);
  const alreadyMapped = [...sources].every(([id, entry]) => (((priorNodes.get(id) || {}).metadata || {}).gse || {}).itemId === entry.itemId);
  if (alreadyMapped) return graph;
  for (const node of graph.nodes) {
    const entry = sources.get(node.id);
    if (!entry) continue;
    node.metadata = { ...(node.metadata || {}), gse: gse(entry, true) };
  }
  return graph;
}
function computedCounts(prior, current, queues) {
  const before = nodeMap(prior); const after = nodeMap(current);
  let added = 0; let corrected = 0; let conflicts = 0; let mapped = 0;
  for (const [id, node] of after) {
    const oldGse = ((before.get(id) || {}).metadata || {}).gse || {};
    const newGse = (node.metadata || {}).gse || {};
    if (newGse.itemId) mapped += 1;
    if (oldGse.cefrBand === undefined && newGse.cefrBand !== undefined) added += 1;
    if (oldGse.cefrBand !== undefined && newGse.cefrBand !== undefined && oldGse.cefrBand !== newGse.cefrBand) corrected += 1;
    if (newGse.cefrBand !== undefined && band((node.metadata || {}).cefr) !== band(newGse.cefrBand)) conflicts += 1;
  }
  return {
    "Nodes mapped": mapped,
    "Levels added": added,
    "Levels corrected": corrected,
    "Conflicts": conflicts,
    "Unmapped GSE entries queued": queues["unmapped-node-to-entry.jsonl"].length,
    "GSE entries with no matching node": queues["unmatched-gse-entry.jsonl"].length,
  };
}
function main() {
  const opt = args();
  if (opt["validate-output"]) {
    if (!opt["fixture-dir"]) fail("fixture-dir is required");
    validateOutput(resolvedInput(opt["validate-output"], "validate-output"), resolvedInput(opt["fixture-dir"], "fixture-dir")); return;
  }
  for (const key of ["fixture-dir", "prior-graph", "output-dir", "byte-diff-report", "mapping-quality-report", "conflict-report", "frozen-yle"]) if (!opt[key]) fail(`${key} is required`);
  for (const name of QUEUES) if (!opt.queues[name]) fail(`queue-file ${name} is required`);
  const paths = validatePaths(opt);
  const data = sourceEntries(paths.inputs["fixture-dir"]); validateInput(data);
  const yleArtifact = yleComparisonArtifact(data); const yleBytes = bytes(yleArtifact);
  if (yleBytes.equals(fs.readFileSync(paths.inputs["frozen-yle"]))) fail("YLE comparison artifact aliases frozen YLE bytes");
  const output = paths.outputs["output-dir"];
  const extracted = { GL: [], YL: [] };
  for (const row of data.records.records) {
    const entry = { ...row.record }; if (entry.gse && entry.gse.endsWith("*")) entry.starred = true;
    extracted[entry.audience].push(entry);
  }
  for (const audience of ["GL", "YL"]) writeJson(path.join(output, `extraction/${audience.toLowerCase()}.json`), {
    schemaVersion: "gse-vocab-fixture-extraction-v1", audience,
    sourceExportSha256: extracted[audience][0] && data.records.records.find((row) => row.audience === audience).sourceExportSha256,
    records: extracted[audience],
  });
  const q = Object.fromEntries(QUEUES.map((name) => [name, []])); const mappings = []; const conflicts = [];
  for (const item of data.mappings.cases) {
    const node = item.node; const entries = item.entries || [];
    if (node && entries.some((entry) => entry.audience !== node.audience)) fail("audience exact mapping mismatch");
    const candidates = node ? entries.filter((entry) => form(entry.expression) === form(node.normalizedForm) && JSON.stringify(pos(entry.grammaticalCategories)) === JSON.stringify(pos(node.partsOfSpeech)) && entry.audience === node.audience) : [];
    const selected = candidates.length === 1 ? candidates[0] : null;
    let outcome = "unmatched-gse-entry";
    if (node && candidates.length === 0) outcome = "unmapped";
    if (node && candidates.length > 1) outcome = "ambiguous";
    if (selected) outcome = Object.hasOwn(selected, "cefr") && !band(selected.cefr) ? "invalid-cefr-source-data" : "mapped";
    const base = { caseId: item.caseId, outcome };
    if (node) Object.assign(base, { nodeId: node.nodeId, normalizedForm: form(node.normalizedForm), normalizedPartsOfSpeech: pos(node.partsOfSpeech), audience: node.audience });
    if (selected) Object.assign(base, { itemId: selected.itemId, nodeMetadataGse: gse(selected, false) });
    if (outcome === "ambiguous") q[QUEUES[0]].push({ nodeId: node.nodeId, normalizedForm: form(node.normalizedForm), audience: node.audience, normalizedPartsOfSpeech: pos(node.partsOfSpeech), candidateItemIds: candidates.map((entry) => entry.itemId), reason: "multiple-exact-candidates", sourceExportSha256: candidates[0].sourceExportSha256 });
    if (outcome === "unmapped") { const record = data.records.records.find((row) => row.audience === node.audience); q[QUEUES[1]].push({ nodeId: node.nodeId, normalizedForm: form(node.normalizedForm), audience: node.audience, normalizedPartsOfSpeech: pos(node.partsOfSpeech), reason: "no-exact-candidate", sourceExportSha256: record.sourceExportSha256 }); }
    if (outcome === "unmatched-gse-entry") for (const entry of entries) q[QUEUES[2]].push({ itemId: entry.itemId, expression: entry.expression, audience: entry.audience, normalizedGrammaticalCategories: pos(entry.grammaticalCategories), reason: "no-exact-node", sourceExportSha256: entry.sourceExportSha256 });
    if (outcome === "invalid-cefr-source-data") q[QUEUES[3]].push({ nodeId: node.nodeId, itemId: selected.itemId, audience: selected.audience, rawCefr: selected.cefr, reason: "invalid-cefr-band", sourceExportSha256: selected.sourceExportSha256 });
    mappings.push(base);
  }
  for (const name of QUEUES) queue(paths.outputs[`queue-file ${name}`], q[name]);
  writeJson(path.join(output, "mapping/mappings.json"), { schemaVersion: "gse-vocab-fixture-mapping-v1", queueFiles: QUEUES, cases: mappings });
  const prior = readJson(paths.inputs["prior-graph"], "prior graph"); const graph = mutateGraph(prior, data);
  writeJson(path.join(output, "graph/new-graph.json"), graph);
  const priorBytes = bytes(prior); const newBytes = bytes(graph); const counts = computedCounts(prior, graph, q);
  let changed = 0; for (let index = 0; index < Math.max(priorBytes.length, newBytes.length); index += 1) if (priorBytes[index] !== newBytes[index]) changed += 1;
  writeJson(paths.outputs["byte-diff-report"], { priorSha256: sha(priorBytes), newSha256: sha(newBytes), bytesChanged: changed, changedNodeIds: changedNodes(prior, graph), diffCounts: counts });
  writeJson(paths.outputs["mapping-quality-report"], { counts, queueFiles: QUEUES });
  const conflictMutation = data.mutation.cases.find((row) => row.caseId === "conflict-retains-cambridge");
  const conflictNode = conflictMutation.nodeBefore; const conflictSource = conflictMutation.sourceEntry;
  const cambridgeCefr = conflictNode.metadata.cefr; const gseCefrBand = band(conflictSource.cefr);
  const conflictRows = band(cambridgeCefr) !== gseCefrBand ? [{
    nodeId: conflictNode.id, itemId: conflictSource.itemId, audience: conflictSource.audience,
    cambridgeCefr, cambridgeCefrAlignments: [band(cambridgeCefr)], gseCefrBand,
    reason: "cambridge-gse-cefr-disagreement", sourceExportSha256: conflictSource.sourceExportSha256,
  }] : [];
  fs.mkdirSync(path.dirname(paths.outputs["conflict-report"]), { recursive: true }); fs.writeFileSync(paths.outputs["conflict-report"], conflictRows.map((row) => JSON.stringify(stable(row))).join(conflictRows.length ? "\n" : "") + (conflictRows.length ? "\n" : ""));
  if (paths.outputs["yle-output"]) {
    fs.mkdirSync(path.dirname(paths.outputs["yle-output"]), { recursive: true });
    fs.writeFileSync(paths.outputs["yle-output"], yleBytes);
  }
}
try { main(); } catch (error) { process.stderr.write(`${error.message}\n`); process.exitCode = 1; }
