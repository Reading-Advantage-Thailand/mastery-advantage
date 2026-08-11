#!/usr/bin/env node
/**
 * Offline YLE consumption contract evaluator.
 * Pure functions over (graphSnapshot, learnerState). No DB. No graph writes.
 *
 * Usage:
 *   node yle-consumption-contract.js <graph.json> <profile.json> [out.json]
 *   node yle-consumption-contract.js --self-check <graph.json> <fixturesDir>
 */

'use strict';

const fs = require('fs');
const path = require('path');

const STAGE_ORDER = ['starters', 'movers', 'flyers'];
const STAGE_TO_EXAM = {
  starters: 'pre-a1-starters',
  movers: 'a1-movers',
  flyers: 'a2-flyers',
};
const EXAM_TO_STAGE = Object.fromEntries(
  Object.entries(STAGE_TO_EXAM).map(([stage, exam]) => [exam, stage]),
);

const CUMULATIVE_EXAMS = {
  starters: ['pre-a1-starters'],
  movers: ['pre-a1-starters', 'a1-movers'],
  flyers: ['pre-a1-starters', 'a1-movers', 'a2-flyers'],
};

function loadJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function isMastered(status) {
  if (status == null) return false;
  const value = String(status).toLowerCase();
  return value === 'known' || value === 'mastered';
}

function stageIndex(stage) {
  const idx = STAGE_ORDER.indexOf(stage);
  if (idx < 0) throw new Error(`unknown stage: ${stage}`);
  return idx;
}

function buildIndexes(graph) {
  const skills = new Map();
  const examToSkills = new Map(
    Object.values(STAGE_TO_EXAM).map((exam) => [exam, new Set()]),
  );
  const topicToSkills = new Map();
  const edgeById = new Map();
  const inboundSupports = new Map();

  for (const node of graph.nodes || []) {
    if (node.kind === 'skill') skills.set(node.id, node);
  }
  for (const edge of graph.edges || []) {
    edgeById.set(edge.id, edge);
    if (edge.type === 'contains') {
      for (const exam of examToSkills.keys()) {
        if (edge.sourceId === `english.vocabulary.exam.${exam}`) {
          examToSkills.get(exam).add(edge.targetId);
        }
      }
      if (String(edge.sourceId).includes('.topic.')) {
        if (!topicToSkills.has(edge.sourceId)) topicToSkills.set(edge.sourceId, new Set());
        topicToSkills.get(edge.sourceId).add(edge.targetId);
      }
    }
    if (edge.type === 'supports') {
      if (!inboundSupports.has(edge.targetId)) inboundSupports.set(edge.targetId, []);
      inboundSupports.get(edge.targetId).push(edge);
    }
  }
  return { skills, examToSkills, topicToSkills, edgeById, inboundSupports };
}

function earliestYleStage(skillId, examToSkills) {
  for (const stage of STAGE_ORDER) {
    const exam = STAGE_TO_EXAM[stage];
    if (examToSkills.get(exam).has(skillId)) return stage;
  }
  return null;
}

function membershipFacts(skillId, examToSkills, edgeById, exams) {
  const facts = [];
  for (const exam of exams) {
    if (!examToSkills.get(exam).has(skillId)) continue;
    // Prefer a real contains edge id when present.
    let edgeId = null;
    for (const edge of edgeById.values()) {
      if (
        edge.type === 'contains' &&
        edge.sourceId === `english.vocabulary.exam.${exam}` &&
        edge.targetId === skillId
      ) {
        edgeId = edge.id;
        break;
      }
    }
    facts.push({
      kind: 'exam_membership',
      edgeType: 'contains',
      examId: exam,
      edgeId,
      classification: 'source-backed fact',
    });
  }
  return facts;
}

function evaluate(graph, learnerState, options = {}) {
  const cap = options.cap ?? 10;
  const indexes = buildIndexes(graph);
  const goalStage = learnerState.goalStage;
  if (!STAGE_TO_EXAM[goalStage]) {
    throw new Error(`learnerState.goalStage must be starters|movers|flyers, got ${goalStage}`);
  }
  const expectedExams = CUMULATIVE_EXAMS[goalStage];
  const mastery = learnerState.mastery || {};
  const dueSkillIds = Array.isArray(learnerState.dueSkillIds) ? learnerState.dueSkillIds : [];
  const topicFocus = Array.isArray(learnerState.topicFocusGroupIds)
    ? learnerState.topicFocusGroupIds
    : [];

  const expectedSkills = new Set();
  for (const exam of expectedExams) {
    for (const skillId of indexes.examToSkills.get(exam)) expectedSkills.add(skillId);
  }

  function masteryOf(skillId) {
    return mastery[skillId] != null ? mastery[skillId] : 'unknown';
  }

  function learnerFields(skillId, extra = []) {
    return [
      { field: 'goalStage', value: goalStage },
      { field: 'mastery', skillId, value: masteryOf(skillId) },
      ...extra,
    ];
  }

  const lowerLevelGaps = [];
  const currentStageUnknowns = [];
  for (const skillId of expectedSkills) {
    if (isMastered(masteryOf(skillId))) continue;
    const earliest = earliestYleStage(skillId, indexes.examToSkills);
    if (!earliest) continue;
    const itemBase = {
      skillId,
      graphFacts: membershipFacts(skillId, indexes.examToSkills, indexes.edgeById, expectedExams),
      derivedSignals: [],
      learnerStateFields: learnerFields(skillId),
      earliestStage: earliest,
    };
    if (stageIndex(earliest) < stageIndex(goalStage)) {
      lowerLevelGaps.push({ ...itemBase, category: 'lower_level_gap' });
    } else if (earliest === goalStage) {
      currentStageUnknowns.push({ ...itemBase, category: 'current_stage_unknown' });
    }
  }

  lowerLevelGaps.sort((a, b) => {
    const stageCmp = stageIndex(a.earliestStage) - stageIndex(b.earliestStage);
    if (stageCmp !== 0) return stageCmp;
    return a.skillId.localeCompare(b.skillId);
  });
  currentStageUnknowns.sort((a, b) => a.skillId.localeCompare(b.skillId));

  const srsDue = [];
  for (const skillId of dueSkillIds) {
    if (!expectedSkills.has(skillId)) continue;
    srsDue.push({
      skillId,
      category: 'srs_due',
      graphFacts: membershipFacts(skillId, indexes.examToSkills, indexes.edgeById, expectedExams),
      derivedSignals: [],
      learnerStateFields: learnerFields(skillId, [
        { field: 'dueSkillIds', skillId, value: true },
      ]),
      earliestStage: earliestYleStage(skillId, indexes.examToSkills),
    });
  }

  const topicSkills = new Set();
  for (const groupId of topicFocus) {
    for (const skillId of indexes.topicToSkills.get(groupId) || []) {
      if (expectedSkills.has(skillId) && !isMastered(masteryOf(skillId))) {
        topicSkills.add(skillId);
      }
    }
  }
  const topicFocusItems = [...topicSkills]
    .sort()
    .map((skillId) => ({
      skillId,
      category: 'topic_focus',
      graphFacts: [
        ...membershipFacts(skillId, indexes.examToSkills, indexes.edgeById, expectedExams),
        {
          kind: 'topic_membership',
          edgeType: 'contains',
          groupId: topicFocus.find((id) => (indexes.topicToSkills.get(id) || new Set()).has(skillId)),
          classification: 'source-backed fact',
        },
      ],
      derivedSignals: [],
      learnerStateFields: learnerFields(skillId, [
        { field: 'topicFocusGroupIds', value: topicFocus },
      ]),
      earliestStage: earliestYleStage(skillId, indexes.examToSkills),
    }));

  // MWE readiness annotations (optional signals; never filter out unknowns).
  function attachMweSignals(item) {
    const skill = indexes.skills.get(item.skillId);
    if (!skill || skill.metadata?.lexicalUnit !== 'multiword-expression') return item;
    const supports = indexes.inboundSupports.get(item.skillId) || [];
    const derived = [];
    let knownComponents = 0;
    let totalComponents = 0;
    for (const edge of supports) {
      const methods = edge.sourceRefs || [];
      if (!methods.includes('multiword-component-support-v1')) continue;
      totalComponents += 1;
      const componentKnown = isMastered(masteryOf(edge.sourceId));
      if (componentKnown) knownComponents += 1;
      derived.push({
        kind: 'supports',
        edgeType: 'supports',
        method: 'multiword-component-support-v1',
        edgeId: edge.id,
        sourceId: edge.sourceId,
        componentKnown,
        classification: 'derived support signal',
        mandatoryGate: false,
      });
    }
    if (!derived.length) return item;
    return {
      ...item,
      mweReadiness: {
        knownComponents,
        totalComponents,
        blocksIntroduction: false,
      },
      derivedSignals: [...item.derivedSignals, ...derived],
      categoryNotes: ['mwe_readiness_signal'],
    };
  }

  const buckets = [
    ...srsDue,
    ...lowerLevelGaps,
    ...topicFocusItems,
    ...currentStageUnknowns,
  ].map(attachMweSignals);

  // De-dupe by skillId, first category wins (due > gap > topic > unknown).
  const seen = new Set();
  const nextSteps = [];
  for (const item of buckets) {
    if (seen.has(item.skillId)) continue;
    seen.add(item.skillId);
    const {
      earliestStage: _drop,
      ...publicItem
    } = item;
    nextSteps.push(publicItem);
    if (nextSteps.length >= cap) break;
  }

  return {
    contractVersion: 'yle-consumption.v1',
    goalStage,
    currentStage: goalStage,
    expectedExams,
    counts: {
      srsDue: srsDue.length,
      lowerLevelGaps: lowerLevelGaps.length,
      topicFocus: topicFocusItems.length,
      currentStageUnknowns: currentStageUnknowns.length,
      nextSteps: nextSteps.length,
    },
    nextSteps,
    graphMutation: false,
    hardPrerequisiteFromSupports: false,
  };
}

function assertNoStudentFieldsOnGraph(graph) {
  const banned = ['mastery', 'dueAt', 'stability', 'lastReview', 'studentId', 'learnerId'];
  for (const node of graph.nodes || []) {
    if (node.kind !== 'skill') continue;
    for (const key of banned) {
      if (Object.prototype.hasOwnProperty.call(node, key)) {
        throw new Error(`graph skill ${node.id} has banned student field ${key}`);
      }
      if (node.metadata && Object.prototype.hasOwnProperty.call(node.metadata, key)) {
        throw new Error(`graph skill ${node.id} metadata has banned student field ${key}`);
      }
    }
  }
}

function deepEqual(a, b) {
  return JSON.stringify(a) === JSON.stringify(b);
}

function selfCheck(graphPath, fixturesDir) {
  const graph = loadJson(graphPath);
  // Work on a deep clone so fixtures cannot mutate the loaded graph.
  const graphFrozen = JSON.parse(JSON.stringify(graph));
  assertNoStudentFieldsOnGraph(graphFrozen);

  const profiles = fs
    .readdirSync(fixturesDir)
    .filter((name) => name.endsWith('.profile.json'))
    .sort();
  if (!profiles.length) {
    throw new Error(`no *.profile.json fixtures in ${fixturesDir}`);
  }

  const results = [];
  for (const name of profiles) {
    const profilePath = path.join(fixturesDir, name);
    const expectedPath = path.join(fixturesDir, name.replace(/\.profile\.json$/, '.expected.json'));
    const profile = loadJson(profilePath);
    const expected = loadJson(expectedPath);
    const graphBefore = JSON.stringify(graphFrozen);
    const actual = evaluate(graphFrozen, profile.learnerState, profile.options || {});
    const graphAfter = JSON.stringify(graphFrozen);
    if (graphBefore !== graphAfter) {
      throw new Error(`${name}: evaluator mutated the graph snapshot`);
    }

    // Structural contract assertions always applied.
    if (!Array.isArray(actual.nextSteps) || !actual.nextSteps.length) {
      throw new Error(`${name}: nextSteps must be a non-empty array`);
    }
    for (const item of actual.nextSteps) {
      if (!Array.isArray(item.graphFacts) || !Array.isArray(item.learnerStateFields)) {
        throw new Error(`${name}: item ${item.skillId} lacks graphFacts/learnerStateFields arrays`);
      }
      if (!item.graphFacts.length) {
        throw new Error(`${name}: item ${item.skillId} has empty graphFacts`);
      }
      if (!item.learnerStateFields.length) {
        throw new Error(`${name}: item ${item.skillId} has empty learnerStateFields`);
      }
      for (const signal of item.derivedSignals || []) {
        if (signal.classification !== 'derived support signal' || signal.mandatoryGate !== false) {
          throw new Error(`${name}: derived signal must be non-mandatory derived support signal`);
        }
      }
    }

    if (expected.requireLowerLevelGaps && actual.counts.lowerLevelGaps < 1) {
      throw new Error(`${name}: expected lower-level gaps for Movers-goal weak Starters profile`);
    }
    if (expected.requireSrsDue && actual.counts.srsDue < 1) {
      throw new Error(`${name}: expected SRS due items`);
    }
    if (expected.requireCategories) {
      const cats = new Set(actual.nextSteps.map((item) => item.category));
      for (const cat of expected.requireCategories) {
        if (!cats.has(cat) && !(expected.allowCategoryInCountsOnly && actual.counts[expected.allowCategoryInCountsOnly[cat]] > 0)) {
          // Categories may be present in counts even if capped out of nextSteps;
          // require either nextSteps membership or positive count when listed in requireCounts.
          if (!(expected.requireCounts && expected.requireCounts[cat] != null)) {
            throw new Error(`${name}: missing category ${cat} in nextSteps`);
          }
        }
      }
    }
    if (expected.requireCounts) {
      for (const [key, min] of Object.entries(expected.requireCounts)) {
        const countKey = {
          lower_level_gap: 'lowerLevelGaps',
          srs_due: 'srsDue',
          topic_focus: 'topicFocus',
          current_stage_unknown: 'currentStageUnknowns',
        }[key] || key;
        if ((actual.counts[countKey] ?? actual.counts[key] ?? 0) < min) {
          throw new Error(`${name}: count ${key} expected >= ${min}, got ${actual.counts[countKey]}`);
        }
      }
    }
    if (expected.requireSkillCategories) {
      for (const [skillId, category] of Object.entries(expected.requireSkillCategories)) {
        const found = actual.nextSteps.find((item) => item.skillId === skillId);
        if (!found) {
          // Skill may exist only in counts population; re-evaluate membership via full lists.
          throw new Error(`${name}: expected skill ${skillId} in nextSteps with category ${category}`);
        }
        if (found.category !== category) {
          throw new Error(`${name}: skill ${skillId} category ${found.category} != ${category}`);
        }
      }
    }
    if (expected.match) {
      // Optional strict subset match on selected fields.
      for (const [key, value] of Object.entries(expected.match)) {
        if (!deepEqual(actual[key], value)) {
          throw new Error(`${name}: match.${key} mismatch`);
        }
      }
    }

    results.push({
      profile: name,
      goalStage: actual.goalStage,
      counts: actual.counts,
      nextStepCount: actual.nextSteps.length,
    });
  }

  return { ok: true, profiles: results };
}

function main(argv) {
  if (argv[2] === '--self-check') {
    const graphPath = argv[3];
    const fixturesDir = argv[4];
    const result = selfCheck(graphPath, fixturesDir);
    process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
    return 0;
  }
  const graphPath = argv[2];
  const profilePath = argv[3];
  const outPath = argv[4];
  if (!graphPath || !profilePath) {
    process.stderr.write(
      'Usage: node yle-consumption-contract.js <graph.json> <profile.json> [out.json]\n' +
        '       node yle-consumption-contract.js --self-check <graph.json> <fixturesDir>\n',
    );
    return 2;
  }
  const graph = loadJson(graphPath);
  const profile = loadJson(profilePath);
  const result = evaluate(graph, profile.learnerState, profile.options || {});
  const text = `${JSON.stringify(result, null, 2)}\n`;
  if (outPath) fs.writeFileSync(outPath, text, 'utf8');
  else process.stdout.write(text);
  return 0;
}

if (require.main === module) {
  try {
    process.exitCode = main(process.argv);
  } catch (err) {
    process.stderr.write(`${err && err.stack ? err.stack : err}\n`);
    process.exitCode = 1;
  }
}

module.exports = {
  evaluate,
  assertNoStudentFieldsOnGraph,
  CUMULATIVE_EXAMS,
  STAGE_TO_EXAM,
};
