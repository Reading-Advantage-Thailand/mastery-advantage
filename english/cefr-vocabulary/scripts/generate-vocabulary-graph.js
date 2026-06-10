#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const ROOT = path.join(__dirname, '..');
const SOURCE_DIR = path.join(ROOT, 'source-pdfs');
const DATA_DIR = path.join(ROOT, 'data');
const DOMAIN = 'english.vocabulary';
const REVIEW_STATUS = 'draft';

const LEVELS = [
  { id: 'pre-a1', title: 'CEFR Pre-A1', rank: 0, difficulty: 0.1 },
  { id: 'a1', title: 'CEFR A1', rank: 1, difficulty: 0.3 },
  { id: 'a2', title: 'CEFR A2', rank: 2, difficulty: 0.5 },
  { id: 'b1', title: 'CEFR B1', rank: 3, difficulty: 0.7 },
  { id: 'b2', title: 'CEFR B2', rank: 4, difficulty: 0.9 },
];

const EXAMS = [
  {
    id: 'pre-a1-starters',
    title: 'Pre A1 Starters',
    cefr: 'pre-a1',
    sourceRef: 'cambridge-yle-word-list-2025',
  },
  {
    id: 'a1-movers',
    title: 'A1 Movers',
    cefr: 'a1',
    sourceRef: 'cambridge-yle-word-list-2025',
  },
  {
    id: 'a2-flyers',
    title: 'A2 Flyers',
    cefr: 'a2',
    sourceRef: 'cambridge-yle-word-list-2025',
  },
  {
    id: 'a2-key-for-schools',
    title: 'A2 Key and A2 Key for Schools',
    cefr: 'a2',
    sourceRef: 'cambridge-a2-key-vocabulary-list-2025',
  },
  {
    id: 'b1-preliminary-for-schools',
    title: 'B1 Preliminary and B1 Preliminary for Schools',
    cefr: 'b1',
    sourceRef: 'cambridge-b1-preliminary-vocabulary-list-2025',
  },
];

const TOPIC_DEFINITIONS = [
  {
    sourceRef: 'cambridge-yle-word-list-2025',
    pdf: 'cambridge-yle-word-list-2025.pdf',
    anchor: 'Pre A1 Starters, A1 Movers and\n     A2 Flyers thematic vocabulary list',
    exams: ['pre-a1-starters', 'a1-movers', 'a2-flyers'],
    topics: [
      'Animals', 'The body and the face', 'Clothes', 'Colours', 'Family & friends',
      'Food & drink', 'Health', 'The home', 'Materials', 'Names', 'Numbers',
      'Places & directions', 'School', 'Sports & leisure', 'Time', 'Toys',
      'Transport', 'Weather', 'Work', 'The world around us',
    ],
  },
  {
    sourceRef: 'cambridge-a2-key-vocabulary-list-2025',
    pdf: 'cambridge-a2-key-vocabulary-list-2025.pdf',
    anchor: 'Appendix 2\n\nTopic Lists',
    exams: ['a2-key-for-schools'],
    topics: [
      'Appliances', 'Clothes and Accessories', 'Colours', 'Communication and Technology',
      'Documents and Texts', 'Education', 'Entertainment and Media', 'Family and Friends',
      'Food and Drink', 'Health, Medicine and Exercise', 'Hobbies and Leisure',
      'House and Home', 'Measurements', 'Personal Feelings, Opinions and Experiences',
      'Places: Buildings', 'Places: Countryside', 'Places: Town and City',
      'Services', 'Shopping', 'Sport', 'The Natural World', 'Time',
      'Travel and Transport', 'Weather', 'Work and Jobs',
    ],
  },
  {
    sourceRef: 'cambridge-b1-preliminary-vocabulary-list-2025',
    pdf: 'cambridge-b1-preliminary-vocabulary-list-2025.pdf',
    anchor: 'Appendix 2\n   Topic Lists',
    exams: ['b1-preliminary-for-schools'],
    topics: [
      'Clothes and Accessories', 'Colours', 'Communications and Technology', 'Education',
      'Entertainment and Media', 'Environment', 'Food and Drink',
      'Health, Medicine and Exercise', 'Hobbies and Leisure', 'House and Home',
      'Language', 'Personal Feelings, Opinions and Experiences', 'Places: Buildings',
      'Places: Countryside', 'Places: Town and City', 'Services', 'Shopping', 'Sport',
      'The Natural World', 'Time', 'Travel and Transport', 'Weather', 'Work and Jobs',
    ],
  },
];

const POS_ALIASES = new Map([
  ['abbrev', 'abbreviation'],
  ['adj', 'adjective'],
  ['adv', 'adverb'],
  ['av', 'auxiliary-verb'],
  ['conj', 'conjunction'],
  ['det', 'determiner'],
  ['dis', 'discourse-marker'],
  ['excl', 'exclamation'],
  ['exclam', 'exclamation'],
  ['int', 'interrogative'],
  ['mv', 'modal-verb'],
  ['n', 'noun'],
  ['poss', 'possessive'],
  ['poss adj', 'possessive-adjective'],
  ['prep', 'preposition'],
  ['prep phr', 'prepositional-phrase'],
  ['pron', 'pronoun'],
  ['v', 'verb'],
  ['phr v', 'phrasal-verb'],
]);

const POS_PATTERN = [
  'prep of place \\+ time',
  'prep of place',
  'prep of time',
  'poss adj',
  'prep phr',
  'phr v',
  'abbrev',
  'exclam',
  'conj',
  'prep',
  'pron',
  'poss',
  'adj',
  'adv',
  'av',
  'det',
  'dis',
  'excl',
  'int',
  'mv',
  'n',
  'v',
].join('|');

function extractText(pdfName) {
  const pdfPath = path.join(SOURCE_DIR, pdfName);
  if (!fs.existsSync(pdfPath)) {
    throw new Error(`Missing ${pdfPath}. Run ../download-sources.sh first.`);
  }
  return execFileSync('pdftotext', ['-layout', pdfPath, '-'], {
    encoding: 'utf8',
    maxBuffer: 30 * 1024 * 1024,
  });
}

function normalizeText(value) {
  return value
    .normalize('NFKC')
    .replace(/[‘’]/g, "'")
    .replace(/[“”]/g, '"')
    .replace(/[–—]/g, '-')
    .replace(/\s+/g, ' ')
    .trim();
}

function normalizeHeadword(value) {
  return normalizeText(value)
    .replace(/\s+\((?:Br Eng|Am Eng)\)$/i, '')
    .replace(/\s+/g, ' ')
    .toLowerCase();
}

function deriveMatchForms(headword) {
  const normalized = normalizeHeadword(headword);
  const forms = new Set();
  const base = normalized
    .replace(/\s*\([^)]*\)/g, '')
    .replace(/\b(?:sth|sb)\b/g, '')
    .replace(/\s+/g, ' ')
    .trim();

  if (base) forms.add(base);
  for (const match of normalized.matchAll(/\((?:uk|us|am eng(?::)?|br eng(?::)?)\s+([^)]*)\)/g)) {
    if (match[1].trim()) forms.add(match[1].trim());
  }
  if (/^[a-z-]+\/[a-z-]+$/.test(base)) {
    for (const alternative of base.split('/')) forms.add(alternative);
  }
  return [...forms].sort();
}

function slug(value) {
  return normalizeText(value)
    .toLowerCase()
    .replace(/&/g, ' and ')
    .replace(/['"]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .replace(/-+/g, '-')
    .slice(0, 70) || 'item';
}

function parsePos(raw) {
  const normalized = normalizeText(raw)
    .replace(/[()]/g, '')
    .replace(/\bprep of (?:place|time)(?: \+ (?:place|time))?\b/g, 'prep')
    .replace(/\bposs adj\b/g, 'poss adj')
    .replace(/\b(?:sing|pl)\b/g, '')
    .replace(/\s+/g, ' ')
    .trim();

  const parts = normalized
    .split(/\s*(?:&|\+|,|\bor\b)\s*/)
    .map(part => part.trim())
    .filter(Boolean)
    .map(part => POS_ALIASES.get(part))
    .filter(Boolean);

  return [...new Set(parts)].sort();
}

function splitColumns(line) {
  return line
    .replace(/\f/g, '')
    .split(/\s{2,}/)
    .map(cell => cell.trim())
    .filter(Boolean);
}

function parseCell(cell, parenthesizedPos) {
  const trimmedCell = cell.trim();
  if (/^[•·]/.test(trimmedCell)) return null;

  const cleaned = normalizeText(trimmedCell)
    .replace(/\s+Page \d+.*$/i, '')
    .trim();

  if (!cleaned || /^[A-Z]$/.test(cleaned) || /^\d+$/.test(cleaned)) return null;
  if (/Vocabulary List|A-Z wordlist|Alphabetic wordlist|Appendix|Grammatical key/i.test(cleaned)) return null;

  const suffix = parenthesizedPos
    ? new RegExp(`^(.+?)\\s+\\(((${POS_PATTERN})(?:\\s*(?:&|\\+|,|or)\\s*(${POS_PATTERN}))*?(?:\\s+(?:sing|pl))?)\\)$`, 'i')
    : new RegExp(`^(.+?)\\s+((${POS_PATTERN})(?:\\s*(?:&|\\+|,|or)\\s*(${POS_PATTERN}))*?(?:\\s+(?:sing|pl))?)$`, 'i');

  const match = cleaned.match(suffix);
  if (!match) return null;

  const headword = normalizeText(match[1]);
  const partsOfSpeech = parsePos(match[2]);
  if (!headword || partsOfSpeech.length === 0 || headword.length > 100) return null;
  if (/^(Page|Pre A1|A1 Movers|A2 Flyers|B1 Preliminary|Key and Key)/i.test(headword)) return null;
  if (/^['"(]/.test(headword) || /^\([^)]*\)\s*/.test(headword)) return null;
  if ((headword.match(/\(/g) || []).length !== (headword.match(/\)/g) || []).length) return null;
  const wordCount = headword.split(/\s+/).length;
  if (wordCount > 7) return null;
  if (/\.$/.test(headword)
    && !/^[ap]\.m\.$/i.test(headword)
    && !partsOfSpeech.includes('abbreviation')) return null;
  if (/\?$/.test(headword) && !partsOfSpeech.includes('interrogative')) return null;
  if (/!$/.test(headword) && !partsOfSpeech.includes('exclamation')) return null;

  return { headword, normalizedHeadword: normalizeHeadword(headword), partsOfSpeech };
}

function parseRange(text, startMarker, endMarker, parenthesizedPos, membership) {
  const start = text.indexOf(startMarker);
  const end = text.indexOf(endMarker, start + startMarker.length);
  if (start < 0 || end < 0) {
    throw new Error(`Could not locate source range: ${startMarker} -> ${endMarker}`);
  }

  const entries = [];
  for (const line of text.slice(start, end).split('\n')) {
    for (const cell of splitColumns(line)) {
      const parsed = parseCell(cell, parenthesizedPos);
      if (parsed) entries.push({ ...parsed, ...membership });
    }
  }
  return entries;
}

function extractTopicGroups() {
  const groups = [];
  const wrappedHeadingMarkers = new Map([
    ['The body and the face', 'The body'],
    ['Family & friends', 'Family &'],
    ['Food & drink', 'Food &'],
    ['Places & directions', 'Places &'],
    ['Sports & leisure', 'Sports &'],
    ['The world around us', 'The world'],
  ]);
  for (const definition of TOPIC_DEFINITIONS) {
    const text = extractText(definition.pdf);
    const anchorIndex = text.lastIndexOf(definition.anchor);
    if (anchorIndex < 0) throw new Error(`Missing topic-list anchor in ${definition.pdf}`);
    const topicText = text.slice(anchorIndex);

    const locations = [];
    let searchOffset = 0;
    for (const title of definition.topics) {
      const marker = wrappedHeadingMarkers.get(title) || title;
      const pattern = new RegExp(`^\\s*${marker.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}`, 'mi');
      const remaining = topicText.slice(searchOffset);
      const match = pattern.exec(remaining);
      if (!match) throw new Error(`Missing topic heading "${title}" in ${definition.pdf}`);
      const index = searchOffset + match.index;
      locations.push({ title, index });
      searchOffset = index + match[0].length;
    }

    for (let index = 0; index < locations.length; index++) {
      const current = locations[index];
      const next = locations[index + 1];
      groups.push({
        id: `${slug(definition.sourceRef)}.${slug(current.title)}`,
        title: current.title,
        sourceRef: definition.sourceRef,
        exams: definition.exams,
        text: normalizeText(topicText.slice(current.index, next ? next.index : topicText.length)).toLowerCase(),
      });
    }
  }
  return groups;
}

function topicContainsForm(topicText, form) {
  if (form.length < 2) return false;
  if (new Set(['a', 'an', 'and', 'as', 'at', 'by', 'for', 'in', 'of', 'on', 'or', 'the', 'to', 'us', 'with'])
    .has(form)) return false;
  const escaped = form.replace(/[.*+?^${}()|[\]\\]/g, '\\$&').replace(/\s+/g, '\\s+');
  return new RegExp(`(?:^|[^a-z0-9])${escaped}(?:$|[^a-z0-9])`, 'i').test(topicText);
}

function collectEntries() {
  const yle = extractText('cambridge-yle-word-list-2025.pdf');
  const a2 = extractText('cambridge-a2-key-vocabulary-list-2025.pdf');
  const b1 = extractText('cambridge-b1-preliminary-vocabulary-list-2025.pdf');

  return [
    ...parseRange(yle, 'Pre A1 Starters A–Z wordlist', 'A1 Movers A–Z wordlist', false, {
      exam: 'pre-a1-starters', cefr: 'pre-a1', sourceRef: 'cambridge-yle-word-list-2025',
    }),
    ...parseRange(yle, 'A1 Movers A–Z wordlist', 'A2 Flyers A–Z wordlist', false, {
      exam: 'a1-movers', cefr: 'a1', sourceRef: 'cambridge-yle-word-list-2025',
    }),
    ...parseRange(yle, 'A2 Flyers A–Z wordlist', 'Pre A1 Starters and A1 Movers', false, {
      exam: 'a2-flyers', cefr: 'a2', sourceRef: 'cambridge-yle-word-list-2025',
    }),
    ...parseRange(a2, 'a/an (det)', 'Appendix 1', true, {
      exam: 'a2-key-for-schools', cefr: 'a2', sourceRef: 'cambridge-a2-key-vocabulary-list-2025',
    }),
    ...parseRange(b1, 'a/an (det)', 'Appendix 1', true, {
      exam: 'b1-preliminary-for-schools', cefr: 'b1', sourceRef: 'cambridge-b1-preliminary-vocabulary-list-2025',
    }),
  ];
}

function mergeEntries(entries) {
  const merged = new Map();
  const levelRank = new Map(LEVELS.map(level => [level.id, level.rank]));

  for (const entry of entries) {
    const posKey = entry.partsOfSpeech.join('-');
    const key = `${entry.normalizedHeadword}::${posKey}`;
    if (!merged.has(key)) {
      merged.set(key, {
        headword: entry.headword,
        normalizedHeadword: entry.normalizedHeadword,
        matchForms: deriveMatchForms(entry.headword),
        partsOfSpeech: entry.partsOfSpeech,
        cefrLevels: [],
        exams: [],
        sourceRefs: [],
      });
    }
    const item = merged.get(key);
    item.cefrLevels.push(entry.cefr);
    item.exams.push(entry.exam);
    item.sourceRefs.push(entry.sourceRef);
  }

  return [...merged.values()]
    .map(item => {
      item.cefrLevels = [...new Set(item.cefrLevels)].sort((a, b) => levelRank.get(a) - levelRank.get(b));
      item.exams = [...new Set(item.exams)].sort();
      item.sourceRefs = [...new Set(item.sourceRefs)].sort();
      item.minimumCefr = item.cefrLevels[0];
      return item;
    })
    .sort((a, b) => a.normalizedHeadword.localeCompare(b.normalizedHeadword)
      || a.partsOfSpeech.join(',').localeCompare(b.partsOfSpeech.join(',')));
}

function buildGraph(inventory, topicGroups) {
  const nodes = [];
  const edges = [];
  const levelById = new Map(LEVELS.map(level => [level.id, level]));
  const nodeIds = new Set();
  const lexicalNodesByHeadword = new Map();
  const lexicalRecords = [];
  let edgeCounter = 0;

  function nextEdgeId(type) {
    edgeCounter++;
    return `${DOMAIN}.edge.${type}.${edgeCounter}`;
  }

  function addEdge(type, sourceId, targetId, weight, confidence, sourceRefs, rationale, metadata = {}) {
    edges.push({
      id: nextEdgeId(type),
      type,
      sourceId,
      targetId,
      weight,
      confidence,
      sourceRefs,
      reviewStatus: REVIEW_STATUS,
      rationale,
      metadata,
    });
  }

  nodes.push({
    id: `${DOMAIN}.domain`,
    kind: 'domain',
    title: 'English CEFR Vocabulary',
    domain: DOMAIN,
    description: 'Lexical skills aligned to Cambridge English Qualifications and CEFR.',
    sourceRefs: [...new Set(EXAMS.map(exam => exam.sourceRef))],
    reviewStatus: REVIEW_STATUS,
    metadata: { schemaVersion: 'english-vocabulary.v1' },
  });

  for (const level of LEVELS) {
    nodes.push({
      id: `${DOMAIN}.standard.${level.id}`,
      kind: 'standard',
      title: level.title,
      domain: DOMAIN,
      sourceRefs: ['cefr-reference-level-descriptions'],
      reviewStatus: REVIEW_STATUS,
      metadata: { framework: 'CEFR', cefr: level.id, rank: level.rank },
      difficulty: level.difficulty,
    });
  }

  for (const exam of EXAMS) {
    const examId = `${DOMAIN}.exam.${exam.id}`;
    nodes.push({
      id: examId,
      kind: 'content_group',
      title: exam.title,
      domain: DOMAIN,
      sourceRefs: [exam.sourceRef],
      reviewStatus: REVIEW_STATUS,
      metadata: { framework: 'Cambridge English Qualifications', exam: exam.id, cefr: exam.cefr },
      difficulty: levelById.get(exam.cefr).difficulty,
    });
    addEdge('contains', `${DOMAIN}.domain`, examId, 1, 'high', [exam.sourceRef],
      'Vocabulary domain contains Cambridge exam alignment group');
  }

  for (const item of inventory) {
    const posSlug = item.partsOfSpeech.map(slug).join('-');
    let id = `${DOMAIN}.skill.${slug(item.normalizedHeadword)}.${posSlug}`;
    let collision = 2;
    while (nodeIds.has(id)) id = `${DOMAIN}.skill.${slug(item.normalizedHeadword)}.${posSlug}.${collision++}`;
    nodeIds.add(id);

    const node = {
      id,
      kind: 'skill',
      title: item.headword,
      domain: DOMAIN,
      description: `Know and recognize "${item.headword}" as ${item.partsOfSpeech.join(', ')}.`,
      sourceRefs: item.sourceRefs,
      reviewStatus: REVIEW_STATUS,
      metadata: {
        lexicalForm: item.headword,
        normalizedForm: item.matchForms[0] || item.normalizedHeadword,
        matchForms: item.matchForms,
        sourceNormalizedForm: item.normalizedHeadword,
        partsOfSpeech: item.partsOfSpeech,
        cefr: item.minimumCefr,
        cefrAlignments: item.cefrLevels,
        examAlignments: item.exams,
        modality: 'vocabulary',
        lexicalUnit: item.normalizedHeadword.includes(' ') ? 'multiword-expression' : 'word',
      },
      difficulty: levelById.get(item.minimumCefr).difficulty,
      independentPracticeReady: false,
    };
    nodes.push(node);
    lexicalRecords.push({ item, node });
    if (!lexicalNodesByHeadword.has(item.normalizedHeadword)) lexicalNodesByHeadword.set(item.normalizedHeadword, []);
    lexicalNodesByHeadword.get(item.normalizedHeadword).push(node);

    for (const cefr of item.cefrLevels) {
      addEdge('aligned_to_standard', id, `${DOMAIN}.standard.${cefr}`, 1, 'high', item.sourceRefs,
        `Lexical item appears in a source aligned to CEFR ${cefr.toUpperCase()}`, { cefr });
    }
    for (const exam of item.exams) {
      const sourceRef = EXAMS.find(candidate => candidate.id === exam).sourceRef;
      addEdge('contains', `${DOMAIN}.exam.${exam}`, id, 1, 'high', [sourceRef],
        'Cambridge exam vocabulary list contains lexical item', { exam });
    }
  }

  for (const variants of lexicalNodesByHeadword.values()) {
    if (variants.length < 2) continue;
    for (let i = 0; i < variants.length; i++) {
      for (let j = 0; j < variants.length; j++) {
        if (i === j) continue;
        addEdge('supports', variants[i].id, variants[j].id, 0.7, 'medium',
          ['same-lexical-form-support-v1'], 'Knowledge of one part-of-speech use supports another');
      }
    }
  }

  for (const [expression, targets] of lexicalNodesByHeadword) {
    const tokens = expression.split(/[\s/-]+/).filter(token => token.length > 1);
    if (tokens.length < 2) continue;
    for (const token of [...new Set(tokens)]) {
      const sources = lexicalNodesByHeadword.get(token);
      if (!sources) continue;
      for (const source of sources) {
        for (const target of targets) {
          if (source.difficulty > target.difficulty) continue;
          addEdge('supports', source.id, target.id, 0.6, 'medium',
            ['multiword-component-support-v1'],
            `Component word "${token}" supports learning multi-word expression "${expression}"`,
            { component: token });
        }
      }
    }
  }

  for (const group of topicGroups) {
    const groupId = `${DOMAIN}.topic.${group.id}`;
    nodes.push({
      id: groupId,
      kind: 'content_group',
      title: group.title,
      domain: DOMAIN,
      sourceRefs: [group.sourceRef],
      reviewStatus: REVIEW_STATUS,
      metadata: {
        groupType: 'topic',
        source: group.sourceRef,
        examAlignments: group.exams,
      },
    });
    addEdge('contains', `${DOMAIN}.domain`, groupId, 1, 'high', [group.sourceRef],
      'Vocabulary domain contains source-backed topic group');

    for (const { item, node } of lexicalRecords) {
      if (!item.exams.some(exam => group.exams.includes(exam))) continue;
      if (!item.matchForms.some(form => topicContainsForm(group.text, form))) continue;
      addEdge('contains', groupId, node.id, 1, 'medium', [group.sourceRef],
        'Lexical item matched within published Cambridge topic-list section',
        { topic: group.title, source: group.sourceRef, derivationMethod: 'topic-section-text-match-v1' });
    }
  }

  return { nodes, edges };
}

function validateGraph(graph) {
  const errors = [];
  const nodeIds = new Set();
  const edgeKeys = new Set();
  const idPattern = /^[a-z][a-z0-9-]*(?:\.[a-z0-9][a-z0-9-]*)+$/;

  for (const node of graph.nodes) {
    if (!idPattern.test(node.id)) errors.push(`Invalid node ID: ${node.id}`);
    if (nodeIds.has(node.id)) errors.push(`Duplicate node ID: ${node.id}`);
    nodeIds.add(node.id);
  }
  for (const edge of graph.edges) {
    if (!nodeIds.has(edge.sourceId) || !nodeIds.has(edge.targetId)) errors.push(`Dangling edge: ${edge.id}`);
    const key = `${edge.type}::${edge.sourceId}::${edge.targetId}`;
    if (edgeKeys.has(key)) errors.push(`Duplicate edge: ${key}`);
    edgeKeys.add(key);
  }
  return errors;
}

function main() {
  fs.mkdirSync(DATA_DIR, { recursive: true });
  const extracted = collectEntries();
  const inventory = mergeEntries(extracted);
  const topicGroups = extractTopicGroups();
  const suspiciousInventory = inventory.filter(item =>
    /^['"(]/.test(item.headword)
    || (/\.$/.test(item.headword) && !/^[ap]\.m\.$/i.test(item.headword)
      && !item.partsOfSpeech.includes('abbreviation'))
    || (/\?$/.test(item.headword) && !item.partsOfSpeech.includes('interrogative'))
    || (/!$/.test(item.headword) && !item.partsOfSpeech.includes('exclamation')));
  if (suspiciousInventory.length > 0) {
    throw new Error(`Suspicious extracted entries:\n${suspiciousInventory.map(item => item.headword).join('\n')}`);
  }

  const graph = buildGraph(inventory, topicGroups);
  const errors = validateGraph(graph);
  if (errors.length > 0) throw new Error(errors.join('\n'));

  fs.writeFileSync(path.join(DATA_DIR, 'cambridge-vocabulary-inventory.json'), `${JSON.stringify(inventory, null, 2)}\n`);
  fs.writeFileSync(path.join(ROOT, 'cefr-vocabulary-knowledge-space.json'), `${JSON.stringify(graph, null, 2)}\n`);

  const countsByLevel = Object.fromEntries(LEVELS.map(level => [
    level.id,
    inventory.filter(item => item.minimumCefr === level.id).length,
  ]));
  const countsByExam = Object.fromEntries(EXAMS.map(exam => [
    exam.id,
    inventory.filter(item => item.exams.includes(exam.id)).length,
  ]));
  const edgeCounts = graph.edges.reduce((counts, edge) => {
    counts[edge.type] = (counts[edge.type] || 0) + 1;
    return counts;
  }, {});

  console.log(JSON.stringify({
    extractedEntries: extracted.length,
    uniqueLexicalSkills: inventory.length,
    graphNodes: graph.nodes.length,
    graphEdges: graph.edges.length,
    topicGroups: topicGroups.length,
    countsByLevel,
    countsByExam,
    edgeCounts,
  }, null, 2));
}

main();
