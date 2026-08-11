#!/usr/bin/env node
/**
 * Offline vocabulary/article recommendation reference (portable contract).
 * Longest-MWE match; known/unknown/unmatched with unmatched in denominator;
 * article metrics; capped next-vocab ranking with explainability.
 *
 * Usage:
 *   node recommendation-contract.js evaluate <graph.json> <caseDir> [frequency.overlay.json]
 *   node recommendation-contract.js --self-check <graph.json> <fixturesRoot> [frequency.overlay.json]
 */

'use strict';

const fs = require('fs');
const path = require('path');

const YLE_EXAMS = new Set(['pre-a1-starters', 'a1-movers', 'a2-flyers']);
const CUMULATIVE = {
  starters: ['pre-a1-starters'],
  movers: ['pre-a1-starters', 'a1-movers'],
  flyers: ['pre-a1-starters', 'a1-movers', 'a2-flyers'],
};

const DEFAULT_WEIGHTS = {
  frequency: 0.45,
  article: 0.35,
  srs: 0.15,
  goal: 0.05,
};

function loadJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function normalizeToken(raw) {
  return String(raw)
    .toLowerCase()
    .replace(/[\u201c\u201d"']/g, '')
    .replace(/[^a-z0-9'-]+/g, '')
    .replace(/^'+|'+$/g, '');
}

function tokenize(text) {
  const tokens = [];
  const re = /[A-Za-z][A-Za-z'-]*|[0-9]+/g;
  let match;
  while ((match = re.exec(text)) !== null) {
    const raw = match[0];
    const isNumber = /^[0-9]+$/.test(raw);
    const norm = isNumber ? raw : normalizeToken(raw);
    tokens.push({
      index: tokens.length,
      raw,
      normalized: norm,
      kind: isNumber ? 'number' : (norm ? 'lexical' : 'non_lexical'),
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

function buildLexicon(graph, mode) {
  const forms = new Map();
  for (const node of graph.nodes || []) {
    if (node.kind !== 'skill') continue;
    const exams = node.metadata?.examAlignments || [];
    if (mode === 'yle-only' && !exams.some((exam) => YLE_EXAMS.has(exam))) continue;
    for (const form of node.metadata?.matchForms || []) {
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
        exams: exams.filter((exam) => YLE_EXAMS.has(exam) || true),
        allExams: exams,
        matchForm: form,
        lexicalUnit: node.metadata?.lexicalUnit || 'word',
      });
    }
  }
  return forms;
}

function longestMatchAt(tokens, index, lexicon) {
  const maxWindow = Math.min(6, tokens.length - index);
  for (let size = maxWindow; size >= 1; size -= 1) {
    const slice = tokens.slice(index, index + size);
    if (slice.some((t) => t.kind !== 'lexical')) continue;
    const key = slice.map((token) => token.normalized).join(' ');
    const hits = lexicon.get(key);
    if (hits && hits.length) {
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

function loadFrequencyMap(overlayPath) {
  if (!overlayPath || !fs.existsSync(overlayPath)) return { rmax: 1, byId: new Map() };
  const ov = loadJson(overlayPath);
  const rmax = Number(ov.stats?.maxRank || 1);
  const byId = new Map();
  for (const node of ov.nodes || []) {
    const freq = node.metadata?.frequency;
    if (!freq || freq.missing) continue;
    if (freq.rankWithinInventory == null) continue;
    byId.set(node.id, {
      rank: Number(freq.rankWithinInventory),
      zipf: freq.zipf,
      sourceVersion: freq.sourceVersion,
    });
  }
  return { rmax: rmax < 2 ? 1 : rmax, byId };
}

function frequencyUtility(skillId, freqMap) {
  const row = freqMap.byId.get(skillId);
  if (!row) return 0;
  if (freqMap.rmax <= 1) return 1;
  const u = 1 - (row.rank - 1) / (freqMap.rmax - 1);
  return Math.max(0, Math.min(1, u));
}

function evaluate(graph, caseConfig, text, freqMap) {
  const mode = caseConfig.lexiconMode || 'core-only';
  const lexicon = buildLexicon(graph, mode);
  const tokens = tokenize(text);
  const mastery = caseConfig.learnerState?.mastery || {};
  const goalStage = caseConfig.learnerState?.goalStage || 'starters';
  const expectedExams = new Set(CUMULATIVE[goalStage] || CUMULATIVE.starters);
  const ignore = new Set(
    (caseConfig.learnerState?.ignoreSurfaceForms || []).map((s) => normalizeToken(s)),
  );
  const dueSet = new Set(caseConfig.learnerState?.dueSkillIds || []);
  const targetCap = caseConfig.targetVocabularyCap ?? 5;
  const weights = { ...DEFAULT_WEIGHTS, ...(caseConfig.rankingWeights || {}) };

  const spans = [];
  let i = 0;
  while (i < tokens.length) {
    const tok = tokens[i];
    if (tok.kind === 'number' || tok.kind === 'non_lexical' || ignore.has(tok.normalized)) {
      spans.push({
        tokenIndexes: [i],
        surface: tok.raw,
        normalized: tok.normalized,
        classification: 'skipped',
        skillId: null,
        rationale: { reason: tok.kind === 'number' ? 'number_token' : 'skipped_surface' },
      });
      i += 1;
      continue;
    }

    const hit = longestMatchAt(tokens, i, lexicon);
    if (!hit) {
      spans.push({
        tokenIndexes: [i],
        surface: tok.raw,
        normalized: tok.normalized,
        classification: 'unmatched',
        skillId: null,
        rationale: { reason: 'no_matchForm', token: tok.normalized },
      });
      i += 1;
      continue;
    }

    const skillId = hit.skill.skillId;
    const known = isMastered(mastery[skillId]);
    const inGoal = (hit.skill.allExams || hit.skill.exams || []).some((exam) => expectedExams.has(exam));
    spans.push({
      tokenIndexes: Array.from({ length: hit.size }, (_, offset) => i + offset),
      surface: tokens.slice(i, i + hit.size).map((t) => t.raw).join(' '),
      normalized: hit.key,
      classification: known ? 'known' : 'unknown',
      skillId,
      inGoalScope: inGoal,
      graphFacts: [
        { kind: 'matchForms', skillId, matchForm: hit.skill.matchForm },
      ],
      learnerStateFields: [
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

  const eligible = spans.filter((s) => s.classification !== 'skipped');
  const knownCount = eligible.filter((s) => s.classification === 'known').length;
  const unknownCount = eligible.filter((s) => s.classification === 'unknown').length;
  const unmatchedCount = eligible.filter((s) => s.classification === 'unmatched').length;
  const E = eligible.length || 0;
  const knownCoverage = E === 0 ? 0 : knownCount / E;
  const unmatchedRate = E === 0 ? 0 : unmatchedCount / E;
  const matchedCoverage = E === 0 ? 0 : (knownCount + unknownCount) / E;

  // Article occurrence counts for unknown skills
  const articleCounts = new Map();
  for (const span of eligible) {
    if (span.classification !== 'unknown' || !span.skillId) continue;
    articleCounts.set(span.skillId, (articleCounts.get(span.skillId) || 0) + 1);
  }

  const candidates = [];
  for (const [skillId, count] of articleCounts.entries()) {
    const freqU = frequencyUtility(skillId, freqMap);
    const articleNorm = Math.min(1, count / 3);
    const srsU = dueSet.has(skillId) ? 1 : 0;
    // goal: any span with this skill in goal scope
    const inGoal = eligible.some((s) => s.skillId === skillId && s.inGoalScope);
    const goalU = inGoal ? 1 : 0;
    const score =
      weights.frequency * freqU +
      weights.article * articleNorm +
      weights.srs * srsU +
      weights.goal * goalU;
    candidates.push({
      skillId,
      score: Number(score.toFixed(6)),
      articleCount: count,
      signals: [
        { source: 'frequency-utility', value: Number(freqU.toFixed(6)), weight: weights.frequency },
        { source: 'article-repetition', value: Number(articleNorm.toFixed(6)), weight: weights.article },
        { source: 'srs-urgency', value: srsU, weight: weights.srs },
        { source: 'goal-scope', value: goalU, weight: weights.goal },
      ],
      graphFacts: [{ kind: 'article_occurrence', skillId, count }],
      learnerStateFields: [
        { field: 'mastery', skillId, value: mastery[skillId] || 'unknown' },
      ],
    });
  }

  candidates.sort((a, b) => {
    if (b.score !== a.score) return b.score - a.score;
    if (b.articleCount !== a.articleCount) return b.articleCount - a.articleCount;
    return a.skillId.localeCompare(b.skillId);
  });

  const capped = candidates.length > targetCap;
  const ranked = candidates.slice(0, targetCap);
  const targetSpanCount = eligible.filter(
    (s) => s.classification === 'unknown' && ranked.some((r) => r.skillId === s.skillId),
  ).length;
  const targetDensity = E === 0 ? 0 : targetSpanCount / E;

  const unknownCounts = [...articleCounts.values()];
  const repetitionScore =
    unknownCounts.length === 0
      ? 0
      : unknownCounts.reduce((a, b) => a + b, 0) / unknownCounts.length;

  // Article-fit utility values for each ranked skill (RANKING_LAYER_SPEC §5 unlock)
  for (const item of ranked) {
    const count = item.articleCount || 0;
    const occurs = count > 0 ? 1 : 0;
    item.articleFitUtility = Number((0.5 * occurs + 0.5 * Math.min(1, count / 3)).toFixed(6));
  }

  return {
    contractVersion: 'recommendation.v1',
    caseId: caseConfig.id,
    lexiconMode: mode,
    goalStage,
    targetVocabularyCap: targetCap,
    rankingWeights: weights,
    metrics: {
      eligible_span_count: { label: 'Eligible span count', value: E },
      known_span_count: { label: 'Known span count', value: knownCount },
      unknown_span_count: { label: 'Unknown span count', value: unknownCount },
      unmatched_span_count: { label: 'Unmatched span count', value: unmatchedCount },
      skipped_span_count: {
        label: 'Skipped span count',
        value: spans.filter((s) => s.classification === 'skipped').length,
      },
      eligibleKnownCoverage: {
        label: 'Eligible-token known coverage (primary)',
        value: Number(knownCoverage.toFixed(6)),
        numerator: knownCount,
        denominator: E,
      },
      unmatchedTokenRate: {
        label: 'Unmatched token rate (primary)',
        value: Number(unmatchedRate.toFixed(6)),
        numerator: unmatchedCount,
        denominator: E,
      },
      matchedTokenCoverage: {
        label: 'Matched-token coverage (diagnostic only)',
        value: Number(matchedCoverage.toFixed(6)),
        numerator: knownCount + unknownCount,
        denominator: E,
        primary: false,
      },
      targetDensity: {
        label: 'Target density among eligible spans',
        value: Number(targetDensity.toFixed(6)),
        numerator: targetSpanCount,
        denominator: E,
      },
      repetitionScore: {
        label: 'Mean article occurrences per unknown skill',
        value: Number(repetitionScore.toFixed(6)),
      },
    },
    spans,
    rankedNextVocabulary: {
      cap: targetCap,
      size: ranked.length,
      exceededCap: capped,
      items: ranked,
    },
    hardRules: {
      unmatchedInDenominator: true,
      matchedOnlyNotPrimary: true,
      noPrerequisiteFor: true,
    },
  };
}

function runCase(graphPath, caseDir, freqPath) {
  const graph = loadJson(graphPath);
  const config = loadJson(path.join(caseDir, 'profile.json'));
  const text = fs.readFileSync(path.join(caseDir, 'text.txt'), 'utf8');
  const freqMap = loadFrequencyMap(freqPath);
  return evaluate(graph, config, text, freqMap);
}

function selfCheck(graphPath, fixturesRoot, freqPath) {
  const graph = loadJson(graphPath);
  const freqMap = loadFrequencyMap(freqPath);
  const indexPath = path.join(fixturesRoot, 'index.json');
  if (!fs.existsSync(indexPath)) throw new Error('missing fixtures index.json');
  const index = loadJson(indexPath);
  const results = [];

  for (const entry of index.cases || []) {
    const caseDir = path.join(fixturesRoot, entry.id);
    const config = loadJson(path.join(caseDir, 'profile.json'));
    const expected = loadJson(path.join(caseDir, 'expected.json'));
    const text = fs.readFileSync(path.join(caseDir, 'text.txt'), 'utf8');
    const actual = evaluate(graph, config, text, freqMap);

    if (actual.metrics.eligibleKnownCoverage.denominator !== actual.metrics.eligible_span_count.value) {
      throw new Error(`${entry.id}: known coverage denominator must equal eligible span count`);
    }
    if (actual.metrics.unmatchedTokenRate.denominator !== actual.metrics.eligible_span_count.value) {
      throw new Error(`${entry.id}: unmatched rate denominator must equal eligible span count`);
    }
    if (actual.rankedNextVocabulary.size > actual.rankedNextVocabulary.cap) {
      throw new Error(`${entry.id}: ranked list exceeds cap`);
    }
    if (expected.minUnmatched != null && actual.metrics.unmatched_span_count.value < expected.minUnmatched) {
      throw new Error(`${entry.id}: unmatched below min ${expected.minUnmatched}`);
    }
    if (expected.requireUnmatchedInDenominator && actual.metrics.unmatched_span_count.value < 1) {
      throw new Error(`${entry.id}: expected at least one unmatched in denominator`);
    }
    if (expected.maxTargetSize != null && actual.rankedNextVocabulary.size > expected.maxTargetSize) {
      throw new Error(`${entry.id}: target size above max`);
    }
    if (expected.requireNumbersSkipped) {
      const nums = actual.spans.filter((s) => s.rationale?.reason === 'number_token');
      if (!nums.length) throw new Error(`${entry.id}: expected number tokens skipped`);
      if (nums.some((s) => s.classification !== 'skipped')) {
        throw new Error(`${entry.id}: numbers must be skipped classification`);
      }
    }
    if (expected.requireDiagnosticMatchedCoverage) {
      if (actual.metrics.matchedTokenCoverage.primary !== false) {
        throw new Error(`${entry.id}: matched coverage must not be primary`);
      }
    }
    // Diagnostic trap: matched coverage high while unmatched rate not tiny
    if (expected.requireMatchedLooksGoodUnmatchedBad) {
      if (actual.metrics.matchedTokenCoverage.value < 0.85) {
        throw new Error(`${entry.id}: expected high matched coverage in trap fixture`);
      }
      if (actual.metrics.unmatchedTokenRate.value < 0.05) {
        throw new Error(`${entry.id}: expected non-trivial unmatched rate in trap fixture`);
      }
    }
    if (expected.requireMweMatch) {
      const mwe = actual.spans.find((s) => (s.rationale?.longestMatchTokenCount || 0) >= 2);
      if (!mwe) throw new Error(`${entry.id}: expected multi-token MWE match span`);
    }
    if (expected.requireExplainability && actual.rankedNextVocabulary.size > 0) {
      for (const item of actual.rankedNextVocabulary.items) {
        if (!Array.isArray(item.signals) || item.signals.length < 4) {
          throw new Error(`${entry.id}: ranked item missing 4 explainability signals`);
        }
        if (item.articleFitUtility == null) {
          throw new Error(`${entry.id}: ranked item missing articleFitUtility`);
        }
      }
    }
    if (expected.requireMinTargets != null) {
      if (actual.rankedNextVocabulary.size < expected.requireMinTargets) {
        throw new Error(`${entry.id}: need ≥${expected.requireMinTargets} ranked targets`);
      }
    }
    if (expected.requireFrequencySignal) {
      const hasFreq = actual.rankedNextVocabulary.items.some((item) =>
        (item.signals || []).some((sig) => sig.source === 'frequency-utility' && sig.value > 0),
      );
      if (!hasFreq) throw new Error(`${entry.id}: expected frequency-utility signal > 0`);
    }
    if (expected.requireSrsFirst) {
      const due = new Set(config.learnerState?.dueSkillIds || []);
      if (!due.size) throw new Error(`${entry.id}: profile missing dueSkillIds for srs check`);
      const top = actual.rankedNextVocabulary.items[0];
      if (!top || !due.has(top.skillId)) {
        throw new Error(`${entry.id}: expected due skill ranked first, got ${top && top.skillId}`);
      }
    }
    if (expected.requireEmptyEligible) {
      if (actual.metrics.eligible_span_count.value !== 0) {
        throw new Error(`${entry.id}: expected empty eligible set`);
      }
      if (actual.metrics.eligibleKnownCoverage.value !== 0) {
        throw new Error(`${entry.id}: empty article metrics must be 0`);
      }
    }
    if (expected.requireLexiconMode) {
      if (actual.lexiconMode !== expected.requireLexiconMode) {
        throw new Error(`${entry.id}: lexiconMode want ${expected.requireLexiconMode}, got ${actual.lexiconMode}`);
      }
    }
    if (expected.requireIgnoreSkipped) {
      const skipped = actual.spans.filter((s) => s.rationale?.reason === 'skipped_surface');
      if (!skipped.length) throw new Error(`${entry.id}: expected ignoreSurfaceForms skip`);
    }
    // Determinism: re-run and compare score list
    if (expected.requireDeterminism) {
      const again = evaluate(graph, config, text, freqMap);
      const a = actual.rankedNextVocabulary.items.map((i) => `${i.skillId}:${i.score}`).join('|');
      const b = again.rankedNextVocabulary.items.map((i) => `${i.skillId}:${i.score}`).join('|');
      if (a !== b) throw new Error(`${entry.id}: non-deterministic ranking`);
    }
    results.push({
      id: entry.id,
      knownCoverage: actual.metrics.eligibleKnownCoverage.value,
      unmatchedRate: actual.metrics.unmatchedTokenRate.value,
      targets: actual.rankedNextVocabulary.size,
    });
  }
  return results;
}

function main() {
  const args = process.argv.slice(2);
  if (args[0] === '--self-check') {
    const [, graphPath, fixturesRoot, freqPath] = args;
    const results = selfCheck(graphPath, fixturesRoot, freqPath);
    console.log(JSON.stringify({ ok: true, results }, null, 2));
    return;
  }
  if (args[0] === 'evaluate') {
    const [, graphPath, caseDir, freqPath] = args;
    const out = runCase(graphPath, caseDir, freqPath);
    console.log(JSON.stringify(out, null, 2));
    return;
  }
  console.error('Usage: recommendation-contract.js evaluate| --self-check ...');
  process.exit(2);
}

if (require.main === module) {
  main();
}

module.exports = { evaluate, tokenize, buildLexicon, frequencyUtility, loadFrequencyMap };
