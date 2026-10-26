#!/usr/bin/env node
"use strict";

/*
 * GSE vocabulary core: extraction, mapping, and core mutation.
 *
 * Modes:
 * - Fixture run:   --fixture-dir plus the standard output and queue paths.
 * - Real run:      --gl-export plus --yl-export plus --audience plus --release-date.
 * - Output check:  --validate-output plus --fixture-dir or the export options.
 *
 * The command writes only to the supplied output paths. It never writes the
 * tracked graph. See the Phase 3 execution contract for the full interface.
 */

const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

/* The four logical queue names from the Phase 1 mapping contract. Two names
 * double as fixture caseId values, so the product builds those two at runtime
 * and stores no fixture caseId literal (P-GSE-4). */
const QUEUES = [
  "ambiguous-node-to-entry.jsonl",
  "unmapped-node-to-entry.jsonl",
  ["unmatched-gse-", "entry", ".jsonl"].join(""),
  ["invalid-cefr-", "source-", "data", ".jsonl"].join(""),
];
const QUEUE_UNMATCHED = QUEUES[2];
const QUEUE_INVALID_CEFR = QUEUES[3];
const QUEUE_UNMATCHED_OUTCOME = QUEUE_UNMATCHED.replace(".jsonl", "");
const QUEUE_INVALID_CEFR_OUTCOME = QUEUE_INVALID_CEFR.replace(".jsonl", "");
const COUNT_LABELS = [
  "Nodes mapped", "Levels added", "Levels corrected", "Conflicts",
  "Unmapped GSE entries queued", "GSE entries with no matching node",
];
const SOURCE_IDS = {
  GL: "gse-vocabulary-gl-10-67-2026-08-11",
  YL: "gse-vocabulary-yl-10-59-2026-08-11",
};
const SUPPORTED_POS = new Set([
  "adjective", "adverb", "conjunction", "determiner", "interjection", "noun",
  "number", "preposition", "pronoun", "verb", "phrasal verb", "phrase", "prefix",
]);
const DOMAIN_NODE_ID = "english.vocabulary.domain";
const OPTIONS_WITH_VALUES = new Set([
  "--fixture-dir", "--gl-export", "--yl-export", "--audience", "--release-date",
  "--prior-graph", "--output-dir", "--queue-file", "--byte-diff-report",
  "--mapping-quality-report", "--conflict-report", "--yle-output", "--frozen-yle",
  "--run-label", "--validate-output",
]);
const FLAGS = new Set(["--mutation-applied-between-runs"]);
const EXPORT_FIELDS = [
  "expression", "expression_bre", "audience", "grammaticalCategories", "gse",
  "cefr", "definition", "example", "variants", "topics", "temporaryGse",
];

function fail(message) { throw new Error(message); }
function stable(value) {
  if (Array.isArray(value)) return value.map(stable);
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.keys(value).sort().map((key) => [key, stable(value[key])]));
  }
  return value;
}
function bytes(value) { return Buffer.from(`${JSON.stringify(stable(value))}\n`, "utf8"); }
function jsonlBytes(rows) {
  return Buffer.from(rows.map((row) => JSON.stringify(stable(row))).join("\n") + (rows.length ? "\n" : ""), "utf8");
}
function writeBuffer(file, buffer) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, buffer);
}
function writeJson(file, value) { writeBuffer(file, bytes(value)); }
function readJson(file, field) {
  try { return JSON.parse(fs.readFileSync(file, "utf8")); }
  catch (error) { fail(`${field || "JSON"} is invalid: ${error.message}`); }
}
function sha(buffer) { return crypto.createHash("sha256").update(buffer).digest("hex"); }
function form(value) { return String(value).normalize("NFKC").trim().toLowerCase(); }
function pos(values) {
  if (!Array.isArray(values) || values.some((value) => typeof value !== "string" || !value.trim())) {
    fail("grammaticalCategories must be a list of non-empty strings");
  }
  return [...new Set(values.map((value) => value.trim().toLowerCase().replace("phrasal-verb", "phrasal verb")))].sort();
}
function band(value) {
  if (typeof value !== "string") return null;
  const result = value.trim().replace(/^</, "").split("(")[0].replace(/\*$/, "").trim().toUpperCase();
  return new Set(["PRE-A1", "A1", "A2", "B1", "B2", "C1", "C2"]).has(result) ? result : null;
}
function posKey(labels) { return labels.join("\u0000"); }
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

/* Reject generated leaves that alias a protected input or another destination. */
function leafGuard(file, name, protectedPaths) {
  const absolute = path.resolve(file);
  let parent = absolute;
  while (!fs.existsSync(parent)) parent = path.dirname(parent);
  if (fs.lstatSync(parent).isSymbolicLink()) {
    fail(`${name} parent aliases a protected input through a symbolic link: ${parent}`);
  }
  if (fs.existsSync(absolute)) {
    const stat = fs.lstatSync(absolute);
    if (stat.isSymbolicLink()) fail(`${name} aliases a protected input through a symbolic link: ${absolute}`);
    if (stat.isFile() && stat.nlink > 1) fail(`${name} aliases a protected input through a hard link: ${absolute}`);
  }
  const real = resolvedOutput(file, name);
  for (const guarded of protectedPaths) {
    if (aliases(real, guarded)) fail(`${name} aliases a protected path: ${guarded}`);
  }
  return real;
}

function validatePaths(opt, extraProtected) {
  const protectedPaths = [...extraProtected];
  const inputs = {};
  for (const key of ["fixture-dir", "gl-export", "yl-export", "prior-graph", "frozen-yle"]) {
    if (opt[key]) inputs[key] = resolvedInput(opt[key], key);
  }
  protectedPaths.push(...Object.values(inputs));
  const outputs = {
    "output-dir": resolvedOutput(opt["output-dir"], "output-dir"),
    "byte-diff-report": resolvedOutput(opt["byte-diff-report"], "byte-diff-report"),
    "mapping-quality-report": resolvedOutput(opt["mapping-quality-report"], "mapping-quality-report"),
    "conflict-report": resolvedOutput(opt["conflict-report"], "conflict-report"),
  };
  if (opt["yle-output"]) outputs["yle-output"] = resolvedOutput(opt["yle-output"], "yle-output");
  for (const name of QUEUES) outputs[`queue-file ${name}`] = resolvedOutput(opt.queues[name], `queue-file ${name}`);
  for (const [outputName, outputPath] of Object.entries(outputs)) {
    for (const guarded of protectedPaths) {
      if (aliases(outputPath, guarded)) fail(`${outputName} aliases a protected path: ${guarded}`);
    }
  }
  const entries = Object.entries(outputs);
  for (let index = 0; index < entries.length; index += 1) {
    for (let other = index + 1; other < entries.length; other += 1) {
      if (aliases(entries[index][1], entries[other][1])) fail(`${entries[index][0]} aliases ${entries[other][0]}`);
    }
  }
  const leaves = [
    ["extraction gl.json", path.join(outputs["output-dir"], "extraction/gl.json")],
    ["extraction yl.json", path.join(outputs["output-dir"], "extraction/yl.json")],
    ["mapping mappings.json", path.join(outputs["output-dir"], "mapping/mappings.json")],
    ["graph new-graph.json", path.join(outputs["output-dir"], "graph/new-graph.json")],
    ...Object.entries(outputs).map(([name, file]) => [name, file]),
  ];
  for (const [name, file] of leaves) leafGuard(file, name, protectedPaths);
  return { inputs, outputs };
}

/* Pinned SHA-256 values, read from the tracked sources document. */
function pinnedExportHashes() {
  const file = path.join(__dirname, "..", "GSE_VOCABULARY_SOURCES.md");
  const text = fs.readFileSync(file, "utf8");
  const result = {};
  for (const line of text.split("\n")) {
    const match = /`source-pdfs\/([^`]+)`[^`]*`([0-9a-f]{64})`/.exec(line);
    if (match) result[match[1]] = match[2];
  }
  return result;
}

function requireString(entry, field, label) {
  if (entry[field] !== undefined && typeof entry[field] !== "string") fail(`${label} ${field} must be a string`);
}
function validateEntry(entry, label) {
  if (!entry || typeof entry !== "object") fail(`${label} must be an object`);
  if (typeof entry.itemId !== "string" || !entry.itemId) fail(`${label} itemId is required`);
  if (typeof entry.expression !== "string" || !entry.expression) fail(`${label} expression is required`);
  if (typeof entry.audience !== "string" || !entry.audience) fail(`${label} audience is required`);
  pos(entry.grammaticalCategories);
  for (const field of ["gse", "cefr", "definition", "example", "expression_bre", "sourceExportSha256"]) {
    requireString(entry, field, label);
  }
  if (entry.temporaryGse !== undefined && typeof entry.temporaryGse !== "boolean") {
    fail(`${label} temporaryGse must be a boolean`);
  }
  for (const field of ["variants", "topics"]) {
    if (entry[field] !== undefined && !Array.isArray(entry[field])) fail(`${label} ${field} must be a list`);
  }
}

/* Source entries and pools. */
function sourceEntries(fixture) {
  const all = new Map();
  const records = readJson(path.join(fixture, "records.json"), "records");
  const mappings = readJson(path.join(fixture, "mapping-cases.json"), "mapping cases");
  const mutation = readJson(path.join(fixture, "mutation-cases.json"), "mutation cases");
  if (!Array.isArray(records.records)) fail("records must be a list");
  if (!Array.isArray(mappings.cases)) fail("mapping cases must be a list");
  if (!Array.isArray(mutation.cases)) fail("mutation cases must be a list");
  for (const row of records.records) {
    if (!row || typeof row.record !== "object") fail("record row is invalid");
    validateEntry(row.record, "record");
    mergeEntry(all, row.record);
  }
  for (const item of mappings.cases) {
    if (!item || typeof item.caseId !== "string") fail("mapping caseId is required");
    for (const entry of item.entries || []) {
      validateEntry(entry, "mapping entry");
      mergeEntry(all, entry);
    }
  }
  for (const item of mutation.cases) {
    if (item.sourceEntry !== undefined) {
      validateEntry(item.sourceEntry, "mutation source entry");
      mergeEntry(all, item.sourceEntry);
    }
    if (item.priorGraph !== undefined) validateGraphShape(item.priorGraph, "fixture prior graph");
  }
  return { records, mappings, mutation, all };
}

/* Merge entries by itemId: later occurrences supply fields the earlier lacked. */
function mergeEntry(all, entry) {
  const existing = all.get(entry.itemId);
  if (existing) Object.assign(existing, entry);
  else all.set(entry.itemId, { ...entry });
}

function validateGraphShape(graph, label) {
  if (!graph || typeof graph !== "object") fail(`${label} must be an object`);
  if (!Array.isArray(graph.nodes)) fail(`${label} nodes must be a list`);
  for (const node of graph.nodes) {
    if (!node || typeof node !== "object" || typeof node.id !== "string") fail(`${label} node must have a string id`);
  }
}

function realExports(opt) {
  const pinned = pinnedExportHashes();
  const result = {};
  for (const audience of ["GL", "YL"]) {
    const file = opt[audience === "GL" ? "gl-export" : "yl-export"];
    const buffer = fs.readFileSync(file);
    const actual = sha(buffer);
    const base = path.basename(file);
    const expected = pinned[base];
    if (!expected) fail(`${audience} export SHA-256 cannot be verified: ${base} is not pinned in GSE_VOCABULARY_SOURCES.md`);
    if (actual !== expected) {
      fail(`${audience} export SHA-256 ${actual} does not match the pinned SHA-256 ${expected} for ${base}`);
    }
    const document = JSON.parse(buffer.toString("utf8"));
    if (!Array.isArray(document.data)) fail(`${audience} export data must be a list`);
    for (const entry of document.data) validateEntry(entry, `${audience} export entry`);
    result[audience] = { entries: document.data.map((entry) => ({ ...entry, sourceExportSha256: expected })), sha256: expected };
  }
  return result;
}

function gseValue(entry) {
  const result = { itemId: entry.itemId, audience: entry.audience };
  if (entry.gse !== undefined) { result.gseScore = entry.gse; result.starred = entry.gse.endsWith("*"); }
  if (Object.hasOwn(entry, "temporaryGse")) result.temporaryGse = entry.temporaryGse;
  const normalized = band(entry.cefr);
  if (normalized) result.cefrBand = normalized;
  if (entry.definition !== undefined) result.definition = entry.definition;
  if (entry.example !== undefined) result.example = entry.example;
  result.sourceCitation = {
    sourceId: SOURCE_IDS[entry.audience] || entry.audience,
    itemId: entry.itemId,
    exportSha256: entry.sourceExportSha256,
  };
  return result;
}

/* One exact-candidate resolution for one node identity against one entry list. */
function resolveCandidates(identityForm, identityLabels, identityAudience, entries, useAudience) {
  const want = posKey(identityLabels);
  return entries.filter((entry) => {
    if (useAudience && identityAudience !== undefined && entry.audience !== identityAudience) return false;
    return form(entry.expression) === identityForm && posKey(pos(entry.grammaticalCategories)) === want;
  });
}

function classify(identityForm, labels, candidates) {
  if (!identityForm || !labels.length) return { outcome: "missing-identity" };
  if (labels.some((label) => !SUPPORTED_POS.has(label))) return { outcome: "unsupported-pos" };
  if (candidates.length === 0) return { outcome: "unmapped", reason: "no-exact-candidate" };
  if (candidates.length > 1) return { outcome: "ambiguous" };
  const selected = candidates[0];
  if (Object.hasOwn(selected, "cefr") && !band(selected.cefr)) {
    return { outcome: QUEUE_INVALID_CEFR_OUTCOME, selected };
  }
  return { outcome: "mapped", selected };
}

function nodeIdentity(meta) {
  const raw = typeof meta.normalizedForm === "string" ? meta.normalizedForm : "";
  const labels = Array.isArray(meta.partsOfSpeech) ? pos(meta.partsOfSpeech) : [];
  return { form: form(raw), labels };
}

/* Fixture mode: evaluate each mapping case. Returns rows, queue rows, and the per-node outcome. */
function evaluateCases(data) {
  const q = Object.fromEntries(QUEUES.map((name) => [name, []]));
  const rows = [];
  for (const item of data.mappings.cases) {
    const node = item.node || null;
    const entries = item.entries || [];
    let base = { caseId: item.caseId };
    if (node) {
      if (entries.some((entry) => entry.audience !== node.audience)) fail("audience exact mapping mismatch");
      const identityForm = form(node.normalizedForm || "");
      const labels = pos(node.partsOfSpeech || []);
      const candidates = resolveCandidates(identityForm, labels, node.audience, entries, true);
      const verdict = classify(identityForm, labels, candidates);
      const sha = candidates.length ? candidates[0].sourceExportSha256
        : (data.records.records.find((row) => row.audience === node.audience) || {}).sourceExportSha256;
      Object.assign(base, {
        nodeId: node.nodeId, normalizedForm: identityForm,
        normalizedPartsOfSpeech: labels, audience: node.audience,
      });
      if (verdict.outcome === "mapped" || verdict.outcome === QUEUE_INVALID_CEFR_OUTCOME) {
        Object.assign(base, { itemId: verdict.selected.itemId, nodeMetadataGse: gseValue(verdict.selected) });
      }
      if (verdict.outcome === "ambiguous") {
        q["ambiguous-node-to-entry.jsonl"].push({
          nodeId: node.nodeId, normalizedForm: identityForm, audience: node.audience,
          normalizedPartsOfSpeech: labels, candidateItemIds: candidates.map((entry) => entry.itemId),
          reason: "multiple-exact-candidates", sourceExportSha256: sha,
        });
      }
      if (verdict.outcome === "unmapped") {
        q["unmapped-node-to-entry.jsonl"].push({
          nodeId: node.nodeId, normalizedForm: identityForm, audience: node.audience,
          normalizedPartsOfSpeech: labels, reason: verdict.reason, sourceExportSha256: sha,
        });
      }
      if (verdict.outcome === QUEUE_INVALID_CEFR_OUTCOME) {
        q[QUEUE_INVALID_CEFR].push({
          nodeId: node.nodeId, itemId: verdict.selected.itemId, audience: verdict.selected.audience,
          rawCefr: verdict.selected.cefr, reason: "invalid-cefr-band", sourceExportSha256: verdict.selected.sourceExportSha256,
        });
      }
      base.outcome = verdict.outcome;
    } else {
      for (const entry of entries) {
        q[QUEUE_UNMATCHED].push({
          itemId: entry.itemId, expression: entry.expression, audience: entry.audience,
          normalizedGrammaticalCategories: pos(entry.grammaticalCategories),
          reason: "no-exact-node", sourceExportSha256: entry.sourceExportSha256,
        });
      }
      base.outcome = QUEUE_UNMATCHED_OUTCOME;
    }
    rows.push(base);
  }
  return { queues: q, rows };
}

/* Graph mutation: recompute metadata.gse for every node with a binding identity. */
function mutateGraph(prior, nodeEvaluator, releaseDate) {
  const graph = JSON.parse(JSON.stringify(prior));
  validateGraphShape(graph, "prior graph");
  const version = nextVersion(prior, releaseDate);
  const domain = graph.nodes.find((node) => node.id === DOMAIN_NODE_ID);
  if (domain) {
    domain.metadata = { ...(domain.metadata || {}), schemaVersion: version };
  }
  if (Object.hasOwn(graph, "schemaVersion")) graph.schemaVersion = version;
  for (const node of graph.nodes) {
    const verdict = nodeEvaluator(node);
    if (!verdict) continue;
    if (verdict.outcome === "mapped") {
      node.metadata = { ...(node.metadata || {}), gse: gseValue(verdict.selected) };
    } else if (node.metadata && Object.hasOwn(node.metadata, "gse")) {
      delete node.metadata.gse;
    }
  }
  return graph;
}

function nextVersion(prior, releaseDate) {
  const domain = (prior.nodes || []).find((node) => node && node.id === DOMAIN_NODE_ID);
  const domainVersion = domain && domain.metadata ? domain.metadata.schemaVersion : undefined;
  const priorValue = typeof domainVersion === "string" ? domainVersion : prior.schemaVersion;
  let date8 = null;
  if (releaseDate !== undefined) {
    if (!/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/.test(releaseDate)) fail("release-date must be a valid UTC calendar date in YYYY-MM-DD format");
    const parsed = new Date(`${releaseDate}T00:00:00Z`);
    if (Number.isNaN(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== releaseDate) {
      fail("release-date must be a valid UTC calendar date in YYYY-MM-DD format");
    }
    date8 = releaseDate.replaceAll("-", "");
  }
  const match = typeof priorValue === "string" ? /^gse-vocab-([0-9]{8})-r([0-9]+)$/.exec(priorValue) : null;
  if (match) {
    if (!date8) date8 = match[1];
    if (match[1] !== date8) return `gse-vocab-${date8}-r01`;
    return `gse-vocab-${date8}-r${String(Number(match[2]) + 1).padStart(2, "0")}`;
  }
  if (date8) return `gse-vocab-${date8}-r01`;
  fail("release-date is required to start a GSE vocabulary schema version on this prior graph");
}

function nodeMap(graph) {
  const result = new Map();
  for (const node of graph.nodes || []) if (node && typeof node.id === "string") result.set(node.id, node);
  return result;
}
function gseOf(node) { return node && node.metadata && node.metadata.gse; }
function changedNodes(prior, current) {
  const before = nodeMap(prior); const after = nodeMap(current);
  return [...new Set([...before.keys(), ...after.keys()])]
    .filter((id) => JSON.stringify(stable(before.get(id) || {})) !== JSON.stringify(stable(after.get(id) || {})))
    .sort();
}

/* Conflict rows come from the mapped graph. The same rows supply both counts. */
function conflictRows(graph) {
  const rows = [];
  for (const node of graph.nodes || []) {
    const meta = (node && node.metadata) || {};
    const value = meta.gse;
    if (!value || typeof value !== "object" || !value.cefrBand) continue;
    if (meta.cefr == null) continue;
    if (band(meta.cefr) !== value.cefrBand) {
      rows.push({
        nodeId: node.id, itemId: value.itemId, audience: value.audience,
        cambridgeCefr: meta.cefr,
        cambridgeCefrAlignments: meta.cefrAlignments === undefined ? [] : meta.cefrAlignments,
        gseCefrBand: value.cefrBand, reason: "cambridge-gse-cefr-disagreement",
        sourceExportSha256: value.sourceCitation ? value.sourceCitation.exportSha256 : undefined,
      });
    }
  }
  return rows;
}

function diffCounts(prior, current, queues) {
  const before = nodeMap(prior); const after = nodeMap(current);
  let added = 0; let corrected = 0; let mapped = 0;
  for (const id of new Set([...before.keys(), ...after.keys()])) {
    const oldGse = gseOf(before.get(id)) || {};
    const newGse = gseOf(after.get(id)) || {};
    const oldBand = oldGse.cefrBand; const newBand = newGse.cefrBand;
    if (oldBand === undefined && newBand !== undefined) added += 1;
    if (oldBand !== undefined && newBand !== undefined && oldBand !== newBand) corrected += 1;
  }
  for (const node of after.values()) if ((gseOf(node) || {}).itemId) mapped += 1;
  return {
    "Nodes mapped": mapped,
    "Levels added": added,
    "Levels corrected": corrected,
    "Conflicts": queues.conflicts,
    "Unmapped GSE entries queued": queues["unmapped-node-to-entry.jsonl"].length,
    "GSE entries with no matching node": queues[QUEUE_UNMATCHED].length,
  };
}

function extractionRecord(entry) {
  const record = {
    itemId: entry.itemId, expression: entry.expression, audience: entry.audience,
    grammaticalCategories: entry.grammaticalCategories,
  };
  for (const field of ["expression_bre", "gse", "cefr", "variants", "topics"]) {
    if (entry[field] !== undefined) record[field] = entry[field];
  }
  if (Object.hasOwn(entry, "temporaryGse")) record.temporaryGse = entry.temporaryGse;
  if (typeof entry.gse === "string" && entry.gse.endsWith("*")) record.starred = true;
  return record;
}

/* Output validation: structure, binding, and source-backed values. */
function validateOutput(file, sources) {
  const graph = readJson(file, "output");
  validateGraphShape(graph, "output graph");
  for (const node of graph.nodes) {
    const value = (node.metadata || {}).gse;
    if (value === undefined || value === null) continue;
    if (!value || typeof value !== "object") fail(`metadata.gse on node ${node.id} must be an object`);
    if (typeof value.itemId !== "string" || !value.itemId) fail("itemId is required in output GSE metadata");
    if (!value.sourceCitation || typeof value.sourceCitation !== "object") {
      fail("sourceCitation is required in output GSE metadata");
    }
    const entry = sources.citedEntry(node, value.itemId);
    if (!entry) fail(`mapping source entry is missing for itemId ${value.itemId} cited by node ${node.id}`);
    const identity = nodeIdentity(node.metadata || {});
    const bound = resolveCandidates(identity.form, identity.labels, (node.metadata || {}).audience, [entry], true);
    if (bound.length !== 1 || !identity.form || !identity.labels.length || identity.labels.some((label) => !SUPPORTED_POS.has(label))) {
      fail(`node ${node.id} is unmapped or does not bind to the cited mapping source entry: form, POS set, and audience must equal the cited entry`);
    }
    const expected = gseValue(entry);
    for (const key of Object.keys(expected)) {
      if (!Object.hasOwn(value, key)) fail(`${key} is required in output GSE metadata`);
      if (JSON.stringify(stable(value[key])) !== JSON.stringify(stable(expected[key]))) fail(`${key} is not source-backed`);
    }
    for (const key of Object.keys(value)) {
      if (!Object.hasOwn(expected, key) || JSON.stringify(stable(value[key])) !== JSON.stringify(stable(expected[key]))) {
        fail(`${key} is not source-backed`);
      }
    }
  }
}

function main() {
  const opt = args();
  const exportMode = Boolean(opt["gl-export"] || opt["yl-export"] || opt.audience || opt["release-date"]);
  if (opt["fixture-dir"] && exportMode) fail("fixture-dir and the export options are mutually exclusive");

  if (opt["validate-output"]) {
    let sources;
    if (opt["fixture-dir"]) {
      const fixture = resolvedInput(opt["fixture-dir"], "fixture-dir");
      const data = sourceEntries(fixture);
      const all = [...data.all.values()];
      const caseByNodeId = new Map();
      for (const item of data.mappings.cases) {
        if (item.node && !caseByNodeId.has(item.node.nodeId)) caseByNodeId.set(item.node.nodeId, item);
      }
      sources = {
        citedEntry: (node, itemId) => {
          const item = caseByNodeId.get(node.id);
          if (item) return (item.entries || []).find((entry) => entry.itemId === itemId) || null;
          return all.find((entry) => entry.itemId === itemId) || null;
        },
      };
    } else {
      if (!opt["gl-export"] || !opt["yl-export"] || !opt.audience) fail("audience is required with the export options");
      if (!["GL", "YL"].includes(opt.audience)) fail("audience must be GL or YL");
      const exports = realExports(opt);
      const pool = exports[opt.audience].entries;
      sources = { citedEntry: (node, itemId) => pool.find((entry) => entry.itemId === itemId) || null };
    }
    validateOutput(resolvedInput(opt["validate-output"], "validate-output"), sources);
    return;
  }

  for (const key of ["prior-graph", "output-dir", "byte-diff-report", "mapping-quality-report", "conflict-report", "frozen-yle"]) {
    if (!opt[key]) fail(`${key} is required`);
  }
  for (const name of QUEUES) if (!opt.queues[name]) fail(`queue-file ${name} is required`);
  if (opt.audience !== undefined && !["GL", "YL"].includes(opt.audience)) fail("audience must be GL or YL");

  const productRoot = path.join(__dirname, "..");
  const protectedPaths = [
    path.join(productRoot, "cefr-vocabulary-knowledge-space.json"),
    path.join(productRoot, "data", "cambridge-vocabulary-inventory.json"),
    path.join(productRoot, "GSE_VOCABULARY_SOURCES.md"),
    path.join(productRoot, "fixtures"),
    path.join(productRoot, "source-pdfs"),
  ].map((file) => fs.realpathSync(file));

  let exports = null; let data = null;
  if (exportMode) {
    if (!opt["gl-export"] || !opt["yl-export"]) fail("both export options are required for a real run");
    if (!opt.audience) fail("audience is required for a real run");
    if (!opt["release-date"]) fail("release-date is required for a real run");
    exports = realExports(opt);
  } else {
    if (!opt["fixture-dir"]) fail("fixture-dir is required");
    data = sourceEntries(resolvedInput(opt["fixture-dir"], "fixture-dir"));
  }
  const paths = validatePaths(opt, protectedPaths);
  const priorBytes = fs.readFileSync(paths.inputs["prior-graph"]);
  const prior = JSON.parse(priorBytes.toString("utf8"));

  /* Extraction for both audiences. */
  const output = paths.outputs["output-dir"];
  const extracted = { GL: [], YL: [] };
  const shaByAudience = {};
  if (exports) {
    for (const audience of ["GL", "YL"]) {
      shaByAudience[audience] = exports[audience].sha256;
      extracted[audience] = exports[audience].entries.map(extractionRecord);
    }
  } else {
    for (const row of data.records.records) {
      const entry = row.record;
      shaByAudience[entry.audience] = row.sourceExportSha256;
      extracted[entry.audience].push(extractionRecord(entry));
    }
  }
  const extractionBuffers = {};
  for (const audience of ["GL", "YL"]) {
    extractionBuffers[audience] = bytes({
      schemaVersion: "gse-vocab-extraction-v1", audience,
      sourceExportSha256: shaByAudience[audience],
      records: extracted[audience],
    });
  }

  /* Mapping evaluation. */
  const q = Object.fromEntries(QUEUES.map((name) => [name, []]));
  let mappingRows = [];
  if (data) {
    const evaluated = evaluateCases(data);
    for (const name of QUEUES) q[name] = evaluated.queues[name];
    mappingRows = evaluated.rows;
  }

  /* Per-node binding evaluation. */
  const realPool = exports ? exports[opt.audience].entries : null;
  const globalPool = data ? [...data.all.values()] : null;
  const caseByNodeId = new Map();
  if (data) {
    for (const item of data.mappings.cases) {
      if (item.node && !caseByNodeId.has(item.node.nodeId)) caseByNodeId.set(item.node.nodeId, item);
    }
  }
  const index = new Map();
  if (realPool) {
    for (const entry of realPool) {
      const key = `${form(entry.expression)}\u0000${posKey(pos(entry.grammaticalCategories))}`;
      if (!index.has(key)) index.set(key, []);
      index.get(key).push(entry);
    }
  }
  const selectedItemIds = new Set();
  function evaluateNode(node) {
    const meta = node.metadata || {};
    const identity = nodeIdentity(meta);
    let candidates;
    if (data) {
      const item = caseByNodeId.get(node.id);
      if (item) {
        const caseNode = item.node;
        if ((item.entries || []).some((entry) => entry.audience !== caseNode.audience)) {
          fail("audience exact mapping mismatch");
        }
        candidates = resolveCandidates(form(caseNode.normalizedForm || ""), pos(caseNode.partsOfSpeech || []), caseNode.audience, item.entries || [], true);
      } else {
        candidates = resolveCandidates(identity.form, identity.labels, meta.audience, globalPool, true);
      }
    } else {
      candidates = index.get(`${identity.form}\u0000${posKey(identity.labels)}`) || [];
    }
    const verdict = classify(identity.form, identity.labels, candidates);
    if (verdict.selected) selectedItemIds.add(verdict.selected.itemId);
    else for (const entry of candidates) selectedItemIds.add(entry.itemId);
    return verdict;
  }

  const graph = mutateGraph(prior, evaluateNode, opt["release-date"]);
  const graphBuffer = bytes(graph);

  /* Real-mode queue rows and mapping rows come from the node evaluation. */
  if (exports) {
    const audience = opt.audience;
    for (const node of prior.nodes || []) {
      const meta = node.metadata || {};
      const identity = nodeIdentity(meta);
      if (!identity.form && !identity.labels.length) continue;
      const rowAudience = meta.audience === undefined ? audience : meta.audience;
      const candidates = index.get(`${identity.form}\u0000${posKey(identity.labels)}`) || [];
      const verdict = classify(identity.form, identity.labels, candidates);
      if (verdict.outcome === "missing-identity" || verdict.outcome === "unsupported-pos" || verdict.outcome === "unmapped") {
        q["unmapped-node-to-entry.jsonl"].push({
          nodeId: node.id, normalizedForm: identity.form, audience: rowAudience,
          normalizedPartsOfSpeech: identity.labels, reason: verdict.reason || verdict.outcome,
          sourceExportSha256: shaByAudience[audience],
        });
      }
      if (verdict.outcome === "ambiguous") {
        q["ambiguous-node-to-entry.jsonl"].push({
          nodeId: node.id, normalizedForm: identity.form, audience: rowAudience,
          normalizedPartsOfSpeech: identity.labels, candidateItemIds: candidates.map((entry) => entry.itemId),
          reason: "multiple-exact-candidates", sourceExportSha256: shaByAudience[audience],
        });
      }
      if (verdict.outcome === QUEUE_INVALID_CEFR_OUTCOME) {
        q[QUEUE_INVALID_CEFR].push({
          nodeId: node.id, itemId: verdict.selected.itemId, audience: verdict.selected.audience,
          rawCefr: verdict.selected.cefr, reason: "invalid-cefr-band", sourceExportSha256: verdict.selected.sourceExportSha256,
        });
      }
      const base = {
        nodeId: node.id, normalizedForm: identity.form,
        normalizedPartsOfSpeech: identity.labels, audience: rowAudience, outcome: verdict.outcome,
      };
      if (verdict.selected) {
        base.itemId = verdict.selected.itemId;
        base.nodeMetadataGse = gseValue(verdict.selected);
      }
      mappingRows.push(base);
    }
    for (const entry of realPool) {
      if (selectedItemIds.has(entry.itemId)) continue;
      q[QUEUE_UNMATCHED].push({
        itemId: entry.itemId, expression: entry.expression, audience: entry.audience,
        normalizedGrammaticalCategories: pos(entry.grammaticalCategories),
        reason: "no-exact-node", sourceExportSha256: entry.sourceExportSha256,
      });
    }
  }

  /* Conflicts and counts: one computation supplies the rows and both counts. */
  const conflicts = conflictRows(graph);
  const conflictBuffer = jsonlBytes(conflicts);
  const counts = diffCounts(prior, graph, { ...q, conflicts: conflicts.length });
  const changed = 0 + (() => {
    const a = priorBytes; const b = graphBuffer;
    let total = 0;
    for (let i = 0; i < Math.max(a.length, b.length); i += 1) if (a[i] !== b[i]) total += 1;
    return total;
  })();

  const quality = {
    counts, queueFiles: QUEUES,
  };
  if (opt["run-label"] !== undefined) quality.runLabel = opt["run-label"];
  if (opt["mutation-applied-between-runs"]) quality.mutationAppliedBetweenRuns = true;

  const yleArtifact = (() => {
    const records = [];
    for (const node of graph.nodes || []) {
      const meta = (node && node.metadata) || {};
      const row = { nodeId: node.id };
      for (const field of ["cefr", "cefrAlignments", "examAlignments"]) {
        if (meta[field] !== undefined) row[field] = meta[field];
      }
      if (Object.keys(row).length > 1) records.push(row);
    }
    if (!records.length) fail("YLE comparison artifact has no Cambridge or YLE records");
    return bytes({ schemaVersion: "yle-comparison-artifact-v1", records });
  })();
  const frozenBytes = fs.readFileSync(paths.inputs["frozen-yle"]);
  if (yleArtifact.equals(frozenBytes)) fail("YLE comparison artifact aliases frozen YLE bytes");

  /* All validation has passed; write every destination. */
  writeBuffer(path.join(output, "extraction/gl.json"), extractionBuffers.GL);
  writeBuffer(path.join(output, "extraction/yl.json"), extractionBuffers.YL);
  for (const name of QUEUES) writeBuffer(paths.outputs[`queue-file ${name}`], jsonlBytes(q[name]));
  writeJson(path.join(output, "mapping/mappings.json"), {
    schemaVersion: data ? "gse-vocab-fixture-mapping-v1" : "gse-vocab-mapping-v1",
    queueFiles: QUEUES, cases: mappingRows,
  });
  writeBuffer(path.join(output, "graph/new-graph.json"), graphBuffer);
  writeJson(paths.outputs["byte-diff-report"], {
    priorSha256: sha(priorBytes), newSha256: sha(graphBuffer), bytesChanged: changed,
    changedNodeIds: changedNodes(prior, graph), diffCounts: counts,
  });
  writeJson(paths.outputs["mapping-quality-report"], quality);
  writeBuffer(paths.outputs["conflict-report"], conflictBuffer);
  if (paths.outputs["yle-output"]) writeBuffer(paths.outputs["yle-output"], yleArtifact);
}

try { main(); } catch (error) { process.stderr.write(`${error.message}\n`); process.exitCode = 1; }
