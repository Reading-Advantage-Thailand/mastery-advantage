#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const graph = JSON.parse(fs.readFileSync(path.join(ROOT, 'cefr-vocabulary-knowledge-space.json'), 'utf8'));
const inventory = JSON.parse(fs.readFileSync(path.join(ROOT, 'data', 'cambridge-vocabulary-inventory.json'), 'utf8'));
const errors = [];
const nodeIds = new Set();
const edgeKeys = new Set();

for (const node of graph.nodes) {
  if (nodeIds.has(node.id)) errors.push(`Duplicate node ID: ${node.id}`);
  nodeIds.add(node.id);
}

for (const edge of graph.edges) {
  if (!nodeIds.has(edge.sourceId) || !nodeIds.has(edge.targetId)) errors.push(`Dangling edge: ${edge.id}`);
  const key = `${edge.type}::${edge.sourceId}::${edge.targetId}`;
  if (edgeKeys.has(key)) errors.push(`Duplicate edge: ${key}`);
  edgeKeys.add(key);
}

const skills = graph.nodes.filter(node => node.kind === 'skill');
const alignedSkillIds = new Set(graph.edges
  .filter(edge => edge.type === 'aligned_to_standard')
  .map(edge => edge.sourceId));

if (skills.length !== inventory.length) {
  errors.push(`Skill/inventory count mismatch: ${skills.length} !== ${inventory.length}`);
}
if (skills.length < 3500) errors.push(`Unexpectedly low skill count: ${skills.length}`);

for (const skill of skills) {
  if (!alignedSkillIds.has(skill.id)) errors.push(`Missing CEFR alignment: ${skill.id}`);
  if (!Array.isArray(skill.metadata.matchForms) || skill.metadata.matchForms.length === 0) {
    errors.push(`Missing match forms: ${skill.id}`);
  }
}

for (const item of inventory) {
  if (/^['"(]/.test(item.headword)) errors.push(`Suspicious leading punctuation: ${item.headword}`);
  if (/\.$/.test(item.headword)
    && !/^[ap]\.m\.$/i.test(item.headword)
    && !item.partsOfSpeech.includes('abbreviation')) {
    errors.push(`Suspicious sentence-like entry: ${item.headword}`);
  }
}

const adjacency = new Map();
for (const edge of graph.edges.filter(edge => edge.type === 'prerequisite_for')) {
  if (!adjacency.has(edge.sourceId)) adjacency.set(edge.sourceId, []);
  adjacency.get(edge.sourceId).push(edge.targetId);
}
const complete = new Set();
const active = new Set();
function visit(nodeId) {
  if (active.has(nodeId)) {
    errors.push(`Prerequisite cycle at ${nodeId}`);
    return;
  }
  if (complete.has(nodeId)) return;
  active.add(nodeId);
  for (const targetId of adjacency.get(nodeId) || []) visit(targetId);
  active.delete(nodeId);
  complete.add(nodeId);
}
for (const nodeId of nodeIds) visit(nodeId);

if (errors.length > 0) {
  console.error(errors.slice(0, 100).join('\n'));
  process.exit(1);
}

console.log(JSON.stringify({
  inventoryEntries: inventory.length,
  nodes: graph.nodes.length,
  skills: skills.length,
  edges: graph.edges.length,
  status: 'valid',
}, null, 2));
