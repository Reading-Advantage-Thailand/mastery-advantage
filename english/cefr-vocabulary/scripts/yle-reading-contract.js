#!/usr/bin/env node
/**
 * Offline YLE reading-program matcher and coverage evaluator.
 * Longest-MWE match against YLE matchForms; known/unknown/unmatched;
 * eligible-token known coverage (unmatched stays in denominator);
 * bounded target vocabulary with explicit cap; explainability traces.
 *
 * Usage:
 *   node yle-reading-contract.js <graph.json> <caseDir>
 *   node yle-reading-contract.js --self-check <graph.json> <fixturesRoot>
 */

'use strict';

const fs = require('fs');
const path = require('path');

const YLE_EXAMS = new Set(['pre-a1-starters', 'a1-movers', 'a2-flyers']);
const STAGE_TO_EXAM = {
  starters: 'pre-a1-starters',
  movers: 'a1-movers',
  flyers: 'a2-flyers',
};
const CUMULATIVE = {
  starters: ['pre-a1-starters'],
  movers: ['pre-a1-starters', 'a1-movers'],
  flyers: ['pre-a1-starters', 'a1-movers', 'a2-flyers'],
};

function loadJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function normalizeToken(raw) {
  return String(raw)
    .toLowerCase()
    .replace(/[“”"']/g, '')
    .replace(/[^a-z0-9'-]+/g, '')
    .replace(/^'+|'+$/g, '');
}

function tokenize(text) {
  // Keep original offsets roughly via split on whitespace/punctuation boundaries.
  const tokens = [];
  const re = /[A-Za-z][A-Za-z'-]*|[0-9]+/g;
  let match;
  while ((match = re.exec(text)) !== null) {
    const raw = match[0];
    const norm = normalizeToken(raw);
    if (!norm) continue;
    tokens.push({
      index: tokens.length,
      raw,
      normalized: norm,
      start: match.index,
      end: match.index + raw.length,
    });
  }
  return tokens;
}

function isMastered(status) {
  if (status == null) return false;
  const value = String(status).toLowerCase();
  return value === 'known' || value === 'mastered';
}

function buildYleLexicon(graph) {
  const forms = new Map(); // normalized multiword form -> [skillRef...]
  for (const node of graph.nodes || []) {
    if (node.kind !== 'skill') continue;
    const exams = node.metadata?.examAlignments || [];
    if (!exams.some((exam) => YLE_EXAMS.has(exam))) continue;
    const matchForms = node.metadata?.matchForms || [];
    for (const form of matchForms) {
      const norm = normalizeToken(String(form).replace(/\s+/g, ' ').trim());
      // For multi-token forms, normalize each token joined by space.
      const parts = String(form)
        .toLowerCase()
        .split(/[\s/]+/)
        .map((part) => normalizeToken(part))
        .filter(Boolean);
      if (!parts.length) continue;
      const key = parts.join(' ');
      if (!forms.has(key)) forms.set(key, []);
      forms.get(key).push({
        skillId: node.id,
        form: key,
        tokenCount: parts.length,
        exams: exams.filter((exam) => YLE_EXAMS.has(exam)),
        matchForm: form,
        lexicalUnit: node.metadata?.lexicalUnit || 'word',
      });
    }
  }
  return forms;
}

function longestMatchAt(tokens, index, lexicon) {
  // Try from longest plausible window down to 1.
  const maxWindow = Math.min(6, tokens.length - index);
  for (let size = maxWindow; size >= 1; size -= 1) {
    const slice = tokens.slice(index, index + size);
    const key = slice.map((token) => token.normalized).join(' ');
    const hits = lexicon.get(key);
    if (hits && hits.length) {
      // Prefer MWE (longer already), then first stable skill id.
      const ranked = [...hits].sort((a, b) => {
        if (b.tokenCount !== a.tokenCount) return b.tokenCount - a.tokenCount;
        if (a.lexicalUnit === 'multiword-expression' && b.lexicalUnit !== 'multiword-expression') return -1;
        if (b.lexicalUnit === 'multiword-expression' && a.lexicalUnit !== 'multiword-expression') return 1;
        return a.skillId.localeCompare(b.skillId);
      });
      return { size, key, skill: ranked[0], candidates: ranked };
    }
  }
  return null;
}

function evaluateReading(graph, caseConfig, text) {
  const lexicon = buildYleLexicon(graph);
  const tokens = tokenize(text);
  const mastery = caseConfig.learnerState?.mastery || {};
  const goalStage = caseConfig.learnerState?.goalStage || 'starters';
  const expectedExams = new Set(CUMULATIVE[goalStage] || CUMULATIVE.starters);
  const targetCap = caseConfig.targetVocabularyCap ?? 5;

  const spans = [];
  let i = 0;
  while (i < tokens.length) {
    const hit = longestMatchAt(tokens, i, lexicon);
    if (!hit) {
      spans.push({
        tokenIndexes: [i],
        surface: tokens[i].raw,
        normalized: tokens[i].normalized,
        classification: 'unmatched',
        skillId: null,
        graphFacts: [],
        learnerStateFields: [
          { field: 'goalStage', value: goalStage },
        ],
        rationale: {
          reason: 'no_yle_matchForm',
          token: tokens[i].normalized,
        },
      });
      i += 1;
      continue;
    }
    const skillId = hit.skill.skillId;
    const known = isMastered(mastery[skillId]);
    const inGoal = hit.skill.exams.some((exam) => expectedExams.has(exam));
    const classification = known ? 'known' : 'unknown';
    spans.push({
      tokenIndexes: Array.from({ length: hit.size }, (_, offset) => i + offset),
      surface: tokens.slice(i, i + hit.size).map((token) => token.raw).join(' '),
      normalized: hit.key,
      classification,
      skillId,
      inGoalScope: inGoal,
      graphFacts: [
        {
          kind: 'matchForms',
          skillId,
          matchForm: hit.skill.matchForm,
          classification: 'source-backed fact',
        },
        {
          kind: 'exam_membership',
          skillId,
          exams: hit.skill.exams,
          classification: 'source-backed fact',
        },
      ],
      learnerStateFields: [
        { field: 'goalStage', value: goalStage },
        { field: 'mastery', skillId, value: mastery[skillId] || 'unknown' },
      ],
      rationale: {
        reason: known ? 'matched_known_skill' : 'matched_unknown_skill',
        matchForm: hit.skill.matchForm,
        longestMatchTokenCount: hit.size,
        skillId,
      },
    });
    i += hit.size;
  }

  const eligible = spans; // all tokens/spans are eligible; unmatched remain in denominator
  const knownCount = eligible.filter((span) => span.classification === 'known').length;
  const unknownCount = eligible.filter((span) => span.classification === 'unknown').length;
  const unmatchedCount = eligible.filter((span) => span.classification === 'unmatched').length;
  const denominator = eligible.length;
  const knownCoverage = denominator === 0 ? 0 : knownCount / denominator;

  // Bounded target vocabulary: unknown matched skills in goal scope, stable order, hard cap.
  const targetSkills = [];
  const seen = new Set();
  let capped = false;
  for (const span of spans) {
    if (span.classification !== 'unknown' || !span.skillId) continue;
    if (seen.has(span.skillId)) continue;
    seen.add(span.skillId);
    if (targetSkills.length >= targetCap) {
      capped = true;
      break;
    }
    targetSkills.push({
      skillId: span.skillId,
      surface: span.surface,
      graphFacts: span.graphFacts,
      learnerStateFields: span.learnerStateFields,
      rationale: {
        reason: 'reading_target_unknown',
        matchForm: span.rationale.matchForm,
        skillId: span.skillId,
      },
    });
  }

  // Simulated before/after progress: mark first target as known after one review.
  const afterMastery = { ...mastery };
  if (targetSkills[0]) afterMastery[targetSkills[0].skillId] = 'known';
  const after = evaluateReadingWithMastery(graph, caseConfig, text, afterMastery);

  return {
    contractVersion: 'yle-reading.v1',
    caseId: caseConfig.id,
    goalStage,
    targetVocabularyCap: targetCap,
    metrics: {
      eligible_token_span_count: {
        label: 'Eligible token-span count',
        value: denominator,
      },
      known_span_count: {
        label: 'Known span count',
        value: knownCount,
      },
      unknown_span_count: {
        label: 'Unknown span count',
        value: unknownCount,
      },
      unmatched_span_count: {
        label: 'Unmatched span count',
        value: unmatchedCount,
      },
      known_coverage: {
        label: 'Eligible-token known coverage',
        value: Number(knownCoverage.toFixed(6)),
        numerator: knownCount,
        denominator,
      },
    },
    spans,
    targetVocabulary: {
      cap: targetCap,
      size: targetSkills.length,
      exceededCap: capped,
      items: targetSkills,
    },
    progress: {
      beforeKnownCoverage: Number(knownCoverage.toFixed(6)),
      afterSimulatedReviewKnownCoverage: after.metrics.known_coverage.value,
      simulatedReviewedSkillId: targetSkills[0] ? targetSkills[0].skillId : null,
    },
  };
}

function evaluateReadingWithMastery(graph, caseConfig, text, masteryOverride) {
  const cloned = {
    ...caseConfig,
    learnerState: {
      ...(caseConfig.learnerState || {}),
      mastery: masteryOverride,
    },
  };
  // Avoid infinite recursion on progress block by calling core without progress.
  return evaluateReadingCore(graph, cloned, text);
}

function evaluateReadingCore(graph, caseConfig, text) {
  const lexicon = buildYleLexicon(graph);
  const tokens = tokenize(text);
  const mastery = caseConfig.learnerState?.mastery || {};
  const goalStage = caseConfig.learnerState?.goalStage || 'starters';
  let knownCount = 0;
  let i = 0;
  let denom = 0;
  while (i < tokens.length) {
    const hit = longestMatchAt(tokens, i, lexicon);
    denom += 1;
    if (!hit) {
      i += 1;
      continue;
    }
    if (isMastered(mastery[hit.skill.skillId])) knownCount += 1;
    i += hit.size;
  }
  return {
    metrics: {
      known_coverage: {
        label: 'Eligible-token known coverage',
        value: denom === 0 ? 0 : Number((knownCount / denom).toFixed(6)),
        numerator: knownCount,
        denominator: denom,
      },
    },
  };
}

function runCase(graphPath, caseDir) {
  const graph = loadJson(graphPath);
  const config = loadJson(path.join(caseDir, 'profile.json'));
  const text = fs.readFileSync(path.join(caseDir, 'text.txt'), 'utf8');
  return evaluateReading(graph, config, text);
}

function selfCheck(graphPath, fixturesRoot) {
  const graph = loadJson(graphPath);
  const stages = ['starters', 'movers', 'flyers'];
  const results = [];
  for (const stage of stages) {
    const caseDir = path.join(fixturesRoot, stage);
    if (!fs.existsSync(path.join(caseDir, 'text.txt'))) {
      throw new Error(`missing ${stage}/text.txt`);
    }
    if (!fs.existsSync(path.join(caseDir, 'profile.json'))) {
      throw new Error(`missing ${stage}/profile.json`);
    }
    if (!fs.existsSync(path.join(caseDir, 'expected.json'))) {
      throw new Error(`missing ${stage}/expected.json`);
    }
    const config = loadJson(path.join(caseDir, 'profile.json'));
    const expected = loadJson(path.join(caseDir, 'expected.json'));
    const text = fs.readFileSync(path.join(caseDir, 'text.txt'), 'utf8');
    const actual = evaluateReading(graph, config, text);

    if (actual.metrics.unmatched_span_count.value < (expected.minUnmatched || 0)) {
      throw new Error(`${stage}: unmatched count below minimum ${expected.minUnmatched}`);
    }
    if (actual.metrics.known_coverage.denominator !== actual.metrics.eligible_token_span_count.value) {
      throw new Error(`${stage}: coverage denominator must equal eligible token-span count (include unmatched)`);
    }
    if (actual.targetVocabulary.size > actual.targetVocabulary.cap) {
      throw new Error(`${stage}: target vocabulary exceeds cap`);
    }
    if (expected.requireUnmatchedInDenominator && actual.metrics.unmatched_span_count.value < 1) {
      throw new Error(`${stage}: expected at least one unmatched token in denominator`);
    }
    for (const item of actual.targetVocabulary.items) {
      if (!item.rationale || !item.graphFacts || !item.graphFacts.some((fact) => fact.kind === 'matchForms')) {
        throw new Error(`${stage}: target lacks matchForms rationale`);
      }
    }
    if (expected.minKnownCoverage != null && actual.metrics.known_coverage.value < expected.minKnownCoverage) {
      throw new Error(`${stage}: known coverage below minimum`);
    }
    if (expected.maxKnownCoverage != null && actual.metrics.known_coverage.value > expected.maxKnownCoverage) {
      throw new Error(`${stage}: known coverage above maximum`);
    }
    if (expected.requireMweMatch) {
      const mwe = actual.spans.find(
        (span) => span.classification !== 'unmatched' && span.normalized.includes(' '),
      );
      if (!mwe) throw new Error(`${stage}: expected a multi-token (MWE) match`);
    }
    // Progress snapshot must move coverage when a target exists.
    if (actual.targetVocabulary.size > 0) {
      if (actual.progress.afterSimulatedReviewKnownCoverage < actual.progress.beforeKnownCoverage) {
        throw new Error(`${stage}: simulated review decreased known coverage`);
      }
    }
    results.push({
      stage,
      knownCoverage: actual.metrics.known_coverage.value,
      unmatched: actual.metrics.unmatched_span_count.value,
      targets: actual.targetVocabulary.size,
      cap: actual.targetVocabulary.cap,
    });
  }
  return { ok: true, cases: results };
}

function main(argv) {
  if (argv[2] === '--self-check') {
    const result = selfCheck(argv[3], argv[4]);
    process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
    return 0;
  }
  const result = runCase(argv[2], argv[3]);
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
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

module.exports = { evaluateReading, tokenize, buildYleLexicon };
