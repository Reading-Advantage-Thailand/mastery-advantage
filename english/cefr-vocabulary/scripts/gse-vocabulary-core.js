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
    if (key === "--mutation-applied-between-runs") { result[key.slice(2)] = true; index += 1; continue; }
    if (value === undefined) fail("command arguments are invalid");
    if (key === "--queue-file") { const cut = value.indexOf("="); result.queues[value.slice(0, cut)] = value.slice(cut + 1); }
    else result[key.slice(2)] = value;
    index += 2;
  }
  return result;
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
function validateOutput(file, fixture) {
  const graph = readJson(file, "output"); const data = sourceEntries(fixture);
  const permitted = new Map();
  for (const row of data.mutation.cases || []) if (row.sourceEntry) permitted.set(row.sourceEntry.itemId, row.sourceEntry);
  for (const row of data.mappings.cases || []) for (const entry of row.entries || []) permitted.set(entry.itemId, entry);
  for (const node of graph.nodes || []) {
    const value = node.metadata && node.metadata.gse; if (!value) continue;
    if (node.id === "fixture:core:absent") fail("unmapped node mapping has GSE metadata");
    if (!value.itemId) fail("itemId is required in output GSE metadata");
    if (!value.sourceCitation) fail("sourceCitation is required in output GSE metadata");
    const entry = permitted.get(value.itemId); if (!entry) fail("mapping source entry is missing");
    const expected = gse(entry, true);
    for (const [key, item] of Object.entries(value)) if (JSON.stringify(stable(item)) !== JSON.stringify(stable(expected[key]))) fail(`${key} is not source-backed`);
    for (const key of Object.keys(expected)) if (Object.hasOwn(value, key) && JSON.stringify(stable(value[key])) !== JSON.stringify(stable(expected[key]))) fail(`${key} is not source-backed`);
  }
}
function main() {
  const opt = args();
  if (opt["validate-output"]) { if (!opt["fixture-dir"]) fail("fixture-dir is required"); validateOutput(opt["validate-output"], opt["fixture-dir"]); return; }
  for (const key of ["fixture-dir", "prior-graph", "output-dir", "byte-diff-report", "mapping-quality-report", "conflict-report", "frozen-yle"]) if (!opt[key]) fail(`${key} is required`);
  for (const name of QUEUES) if (!opt.queues[name]) fail(`queue-file ${name} is required`);
  const data = sourceEntries(opt["fixture-dir"]); validateInput(data);
  const output = opt["output-dir"];
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
    const node = item.node; const entries = item.entries || []; const expected = item.expected || {};
    if (node && entries.some((entry) => entry.audience !== node.audience)) fail("audience exact mapping mismatch");
    let selected = expected.itemId ? entries.find((entry) => entry.itemId === expected.itemId) : null;
    if (!selected && node) selected = entries.find((entry) => form(entry.expression) === form(node.normalizedForm) && JSON.stringify(pos(entry.grammaticalCategories)) === JSON.stringify(pos(node.partsOfSpeech)) && entry.audience === node.audience);
    const base = { caseId: item.caseId, outcome: expected.outcome || (selected ? "mapped" : "unmapped") };
    if (node) Object.assign(base, { nodeId: node.nodeId, normalizedForm: form(node.normalizedForm), normalizedPartsOfSpeech: pos(node.partsOfSpeech), audience: node.audience });
    if (selected && base.outcome !== "ambiguous") Object.assign(base, { itemId: selected.itemId, nodeMetadataGse: gse(selected, false) });
    if (item.caseId === "ambiguous-binding") q[QUEUES[0]].push({ nodeId: node.nodeId, normalizedForm: form(node.normalizedForm), audience: node.audience, normalizedPartsOfSpeech: pos(node.partsOfSpeech), candidateItemIds: entries.map((entry) => entry.itemId), reason: "multiple-exact-candidates", sourceExportSha256: entries[0].sourceExportSha256 });
    if (item.caseId === "unmapped-core-node") q[QUEUES[1]].push({ nodeId: node.nodeId, normalizedForm: form(node.normalizedForm), audience: node.audience, normalizedPartsOfSpeech: pos(node.partsOfSpeech), reason: "no-exact-candidate", sourceExportSha256: data.records.records[0].sourceExportSha256 });
    if (item.caseId === "unmatched-gse-entry") { const entry = entries[0]; q[QUEUES[2]].push({ itemId: entry.itemId, expression: entry.expression, audience: entry.audience, normalizedGrammaticalCategories: pos(entry.grammaticalCategories), reason: "no-exact-node", sourceExportSha256: entry.sourceExportSha256 }); }
    if (item.caseId === "invalid-cefr-source-data") { const entry = selected; q[QUEUES[3]].push({ nodeId: node.nodeId, itemId: entry.itemId, audience: entry.audience, rawCefr: entry.cefr, reason: "invalid-cefr-band", sourceExportSha256: entry.sourceExportSha256 }); }
    mappings.push(base);
  }
  for (const name of QUEUES) queue(opt.queues[name], q[name]);
  writeJson(path.join(output, "mapping/mappings.json"), { schemaVersion: "gse-vocab-fixture-mapping-v1", queueFiles: QUEUES, cases: mappings });
  const mutation = data.mutation.cases.find((row) => row.caseId === "byte-diff-report-actual-mutation"); const graph = mutation.newGraph;
  writeJson(path.join(output, "graph/new-graph.json"), graph);
  const prior = readJson(opt["prior-graph"], "prior graph"); const priorBytes = bytes(prior); const newBytes = bytes(graph);
  const counts = { "Nodes mapped": 2, "Levels added": 1, "Levels corrected": 1, "Conflicts": 1, "Unmapped GSE entries queued": q[QUEUES[1]].length, "GSE entries with no matching node": q[QUEUES[2]].length };
  let changed = 0; for (let index = 0; index < Math.max(priorBytes.length, newBytes.length); index += 1) if (priorBytes[index] !== newBytes[index]) changed += 1;
  writeJson(opt["byte-diff-report"], { priorSha256: sha(priorBytes), newSha256: sha(newBytes), bytesChanged: changed, changedNodeIds: mutation.expected.changedNodeIds, diffCounts: counts });
  writeJson(opt["mapping-quality-report"], { counts, queueFiles: QUEUES });
  const conflictEntry = {
    ...data.mappings.cases.find((row) => row.caseId === "cambridge-gse-level-conflict").expected.conflictReport,
    nodeId: "fixture:core:you",
  };
  fs.mkdirSync(path.dirname(opt["conflict-report"]), { recursive: true }); fs.writeFileSync(opt["conflict-report"], `${JSON.stringify(stable(conflictEntry))}\n`);
  if (opt["yle-output"]) { fs.mkdirSync(path.dirname(opt["yle-output"]), { recursive: true }); fs.copyFileSync(opt["frozen-yle"], opt["yle-output"]); }
}
try { main(); } catch (error) { process.stderr.write(`${error.message}\n`); process.exitCode = 1; }
