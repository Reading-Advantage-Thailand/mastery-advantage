#!/usr/bin/env python3
"""Build english/phonics/phonics-knowledge-space.json (v1), phonics-gse-links.json, storytime-levels.csv.

Run: python3 -I english/phonics/build-phonics-graph.py
Reads sequence.json (a copy of the Storytime 128-week table, see its meta.source_sequence_commit),
so the build does not import from any worktree. Data tables live in this file.
Source of truth for the shapes: design.md section 5 of the Storytime track and
SPECIFICATION.md sections 3 and 4. The knowledge-space file has the same top-level shape as
english/gse-knowledge-space.json: {"nodes": [...], "edges": [...]}.
"""
import csv
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
GSE_JSON = HERE.parent / "gse-knowledge-space.json"
SEQ = json.load(open(HERE / "sequence.json", encoding="utf-8"))
SEQ_COMMIT = SEQ["meta"]["source_sequence_commit"]
GSE_COMMIT = "7344a27"
ID_RE = re.compile(r"^[a-z][a-z0-9-]*(?:\.[a-z0-9][a-z0-9-]*)+$")
D = "english.phonics"
STD = f"{D}.standard.storytime-v1"

# ---------------------------------------------------------------- load sequence
class _Gen:  # the one attribute of the old gen_sequence module that the build uses
    letters_order = SEQ["letters_order"]
gen = _Gen
ROWS = []  # (level, week, element-key|None, pa text, hf text)
for r in SEQ["rows"]:
    el = r[2]
    key = None
    m = re.match(r"E (\d+):", el)
    if m:
        key = int(m.group(1))
    else:
        m = re.match(r"(?:Thai-specific|Exit-profile week): ([TE]\d+)", el)
        if m:
            key = m.group(1)
    ROWS.append((r[0], r[1], key, r[3], r[4], el))
ELEM_WHERE = {}  # element key -> (level, week)
for lv, wk, key, pa, hf, el in ROWS:
    if key is not None and lv >= 2:
        ELEM_WHERE.setdefault(key, (lv, wk))
L1_LETTER = {}  # letter -> week (Level 1)
for lv, wk, key, pa, hf, el in ROWS:
    m = re.match(r"Letter (\w) name\+sound", el)
    if lv == 1 and m:
        L1_LETTER[m.group(1)] = wk
L1_PA = {}  # pa text -> first week
for lv, wk, key, pa, hf, el in ROWS:
    if lv == 1:
        L1_PA.setdefault(pa, wk)
TRICKY = []  # (word, level, week) first introduction; names excluded
_seen = set()
for lv, wk, key, pa, hf, el in ROWS:
    if lv < 2 or hf.startswith("("):
        continue
    for w in (x.strip() for x in hf.split(",")):
        if w in _seen or "(names)" in w or w in ("Lily", "Tom", "Mia", "Pip"):
            continue
        _seen.add(w)
        TRICKY.append((w, lv, wk))

# ---------------------------------------------------------------- provenance
def ref(source, location=None, note=None):
    d = {"source": source}
    if location:
        d["location"] = location
    if note:
        d["note"] = note
    return d

DESIGN = "storytime-advantage-design-20261021"
SOURCES = "storytime-advantage-sources-20261021"
R_DESIGN = lambda sec: ref(DESIGN, f"design.md section {sec}")
R_SEQ = ref(DESIGN, "design.md section 2 (128-week scope and sequence)")
R_THAI = ref(SOURCES, "Thai L1 interference (AJAC 77; TGT 273223)")
R_GSE = "pearson-gse-young-learners-2022"

# ---------------------------------------------------------------- phonemes (44)
PHONEMES = [  # slug, IPA, example
    ("p", "p", "pig"), ("b", "b", "bat"), ("t", "t", "top"), ("d", "d", "dog"), ("k", "k", "cat"),
    ("g", "g", "go"), ("m", "m", "man"), ("n", "n", "net"), ("ng", "ŋ", "ring"), ("f", "f", "fan"),
    ("v", "v", "van"), ("th-voiceless", "θ", "thin"), ("th-voiced", "ð", "this"), ("s", "s", "sun"),
    ("z", "z", "zip"), ("sh", "ʃ", "ship"), ("zh", "ʒ", "vision"), ("h", "h", "hat"), ("ch", "tʃ", "chip"),
    ("j", "dʒ", "jam"), ("l", "l", "leg"), ("r", "r", "red"), ("w", "w", "wet"), ("y", "j", "yes"),
    ("short-a", "æ", "cat"), ("short-e", "e", "bed"), ("short-i", "ɪ", "sit"), ("short-o", "ɑ", "hot"),
    ("short-u", "ʌ", "cup"), ("short-oo", "ʊ", "book"), ("schwa", "ə", "about"),
    ("long-a", "eɪ", "rain"), ("long-e", "i", "tree"), ("long-i", "aɪ", "night"), ("long-o", "oʊ", "boat"),
    ("long-oo", "u", "moon"), ("ow", "aʊ", "out"), ("oi", "ɔɪ", "coin"), ("ear", "ɪr", "ear"),
    ("air", "ɛr", "hair"), ("ure", "ʊr", "cure"), ("ar", "ɑr", "car"), ("or", "ɔr", "for"), ("er", "ɝ", "her"),
]
assert len(PHONEMES) == 44
PH_SLUGS = {p[0] for p in PHONEMES}

# ---------------------------------------------------------------- GPC / pattern table by element
# ("gpc", id-suffix, grapheme, [phoneme slugs]) | ("pat", slug, title)
def G(grapheme, ph):
    """GPC spec; the id suffix is the grapheme plus the phoneme slugs, for example ee.long-e."""
    return ("gpc", f"{grapheme}.{'-'.join(ph)}", grapheme, ph)
def P(slug, title, desc=None):
    return ("pat", slug, title, desc)

ELEMENTS = {
    1: [G("n", ["n"])], 2: [G("a", ["short-a"])], 3: [G("p", ["p"])],
    4: [G("m", ["m"])], 5: [G("s", ["s"])], 6: [G("t", ["t"])],
    7: [G("o", ["short-o"])], 8: [G("d", ["d"])],
    9: [P("rime-an", "Rime -an"), P("rime-ad", "Rime -ad")],
    10: [G("e", ["short-e"])], 11: [G("h", ["h"])],
    12: [P("rime-ot", "Rime -ot"), P("rime-op", "Rime -op")], 13: [G("f", ["f"])],
    14: [G("g", ["g"])], 15: [P("rime-et", "Rime -et"), P("rime-en", "Rime -en")],
    16: [G("i", ["short-i"])], 17: [G("b", ["b"])],
    18: [P("rime-it", "Rime -it"), P("rime-in", "Rime -in")], 19: [G("c", ["k"])],
    20: [G("r", ["r"])], 21: [G("u", ["short-u"])],
    22: [P("rime-ug", "Rime -ug"), P("rime-un", "Rime -un")], 23: [G("l", ["l"])],
    24: [G("w", ["w"])], 25: [P("rime-at", "Rime -at"), P("rime-ap", "Rime -ap")],
    26: [G("j", ["j"])], 27: [G("k", ["k"])],
    28: [P("rime-ut", "Rime -ut"), P("rime-ub", "Rime -ub")], 29: [G("v", ["v"])],
    30: [G("y", ["y"])], 31: [P("rime-ill", "Rime -ill"), P("rime-ip", "Rime -ip")],
    32: [G("qu", ["k", "w"])], 33: [G("x", ["k", "s"])], 34: [G("z", ["z"])],
    35: [P("rime-ob", "Rime -ob"), P("rime-ell", "Rime -ell"), G("ss", ["s"]), G("ff", ["f"]),
         G("ll", ["l"]), G("zz", ["z"])],
    36: [P("s-blend", "Initial s-blends")], 37: [P("r-blend", "Initial r-blends")],
    38: [P("l-blend", "Initial l-blends")], 39: [P("final-n-blend", "Final n-blends -nd -nt -nk")],
    40: [P("final-blend", "Final blends -mp -lt -ft -st")], 41: [P("three-letter-blend", "Three-letter initial blends")],
    42: [G("a-e", ["long-a"])], 43: [G("o-e", ["long-o"])],
    44: [G("i-e", ["long-i"])], 45: [G("u-e", ["long-oo"])],
    46: [G("sh", ["sh"])], 47: [G("ch", ["ch"])], 48: [G("ck", ["k"])],
    49: [G("ng", ["ng"])], 50: [G("th", ["th-voiceless"]), G("th", ["th-voiced"])],
    51: [G("wh", ["w"])],
    52: [P("open-vowel", "Open vowels (he, go, my)")],
    53: [G("ee", ["long-e"]), G("ea", ["long-e"]), G("ie", ["long-e"])],
    54: [G("ea", ["short-e"])],
    55: [G("ai", ["long-a"]), G("ay", ["long-a"])],
    56: [G("ea", ["long-a"]), G("eigh", ["long-a"]), G("ey", ["long-a"])],
    57: [G("oa", ["long-o"]), G("oe", ["long-o"]), G("ow", ["long-o"])],
    58: [G("i", ["long-i"]), G("igh", ["long-i"])],
    59: [G("oo", ["long-oo"]), G("ue", ["long-oo"]), G("ew", ["long-oo"])],
    60: [G("oo", ["short-oo"]), G("oul", ["short-oo"]), G("u", ["short-oo"])],
    61: [G("a", ["or"]), G("aw", ["or"]), G("au", ["or"])],
    62: [G("augh", ["or"]), G("ough", ["or"])],
    63: [G("oi", ["oi"]), G("oy", ["oi"])],
    64: [G("ou", ["ow"]), G("ow", ["ow"])],
    65: [G("or", ["or"]), G("oar", ["or"]), G("our", ["or"])],
    66: [G("air", ["air"]), G("are", ["air"]), G("ear", ["air"])],
    67: [G("ar", ["ar"])], 68: [G("er", ["er"]), G("ir", ["er"]), G("ur", ["er"])],
    "T1": [P("thai-final-stops", "Thai contrast T1: final consonants /p t k d/")],
    "T2": [P("thai-initial-clusters", "Thai contrast T2: initial clusters")],
    "T3": [P("thai-final-clusters-s", "Thai contrast T3: final clusters and -s")],
    "T4": [P("thai-th-s-f", "Thai contrast T4: th, s, f")],
    "T5": [P("thai-v-w-r-l", "Thai contrast T5: v, w and r, l")],
    "E1": [P("plural-s", "Ending -s"), P("plural-es", "Ending -es")],
    "E2": [P("ending-ing", "Ending -ing"), P("ending-ed", "Ending -ed")],
    "E3": [P("two-syllable", "Two-syllable words"), P("compound", "Compound words")],
    "E4": [P("thai-vowel-length", "Thai contrast E4: long and short vowel length")],
    "E5": [P("long-short-vowel-review", "Long and short vowel review")],
    "E6": [P("fluency-timed-reread", "Fluency: timed re-read")],
    "E7": [P("fluency-dialogue", "Fluency: dialogue and expression")],
    "E8": [P("sentence-writing-1", "Sentence writing 1")],
    "E9": [P("sentence-writing-2", "Sentence writing 2")],
    "E10": [P("bridge-read-origins-text", "Bridge: read an Origins 1 text")],
    "E11": [P("bridge-origins-frames", "Bridge: Origins 1 frames and names")],
}
assert set(ELEMENTS) >= set(range(1, 69))
CVC = {"a": 2, "o": 7, "e": 10, "i": 16, "u": 21}  # short vowel -> element

# ---------------------------------------------------------------- PA taxonomy (design 5.2)
# module -> (title, [(skill-slug, title, where)])  where: ("L1", text) | ("E", key) | ("W", level, week)
PA = {
    "listening": ("Environmental sound listening", [
        ("start-stop", "Start and stop a sound", ("W", 1, 1)),
        ("identify", "Identify an environmental sound", ("W", 1, 1)),
        ("sequence", "Sequence sounds (first, next, last)", ("W", 1, 2)),
        ("follow-directions", "Follow directions given by sound", ("W", 1, 3))]),
    "rhyme": ("Rhyme", [
        ("recognise", "Recognise rhyming words", ("L1", "Rhyme 1")),
        ("match", "Match rhyming words", ("L1", "Rhyme 2")),
        ("produce", "Produce a rhyming word", ("L1", "Rhyme 3")),
        ("odd-one-out", "Find the word that does not rhyme", ("L1", "Rhyme 3"))]),
    "sentence-word": ("Sentence and word awareness", [
        ("count-words", "Count the words in a sentence", ("L1", "Word awareness")),
        ("longer-shorter", "Say which word is longer or shorter", ("L1", "Word awareness")),
        ("complete-sentence", "Complete a spoken sentence", ("L1", "Word awareness"))]),
    "compound": ("Compound words", [
        ("blend", "Blend two words into a compound word", ("L1", "Initial sound; syllable blending")),
        ("delete-part", "Delete a part of a compound word", ("L1", "Syllable deletion; blend onset-rime"))]),
    "syllable": ("Syllables", [
        ("count", "Count syllables", ("L1", "Syllable counting")),
        ("blend", "Blend syllables", ("L1", "Initial sound; syllable blending")),
        ("segment", "Segment a word into syllables", ("L1", "Syllable counting")),
        ("delete", "Delete a syllable", ("L1", "Syllable deletion; blend onset-rime"))]),
    "onset-rime": ("Onset and rime", [
        ("blend", "Blend onset and rime", ("L1", "Syllable deletion; blend onset-rime")),
        ("segment", "Segment onset and rime", ("L1", "Segment onset-rime")),
        ("word-family", "Build a word family by rime", ("E", 9))]),
    "initial-sound": ("Initial sound", [
        ("identify", "Identify the initial sound", ("L1", "Initial sound; alliteration")),
        ("match", "Match words by initial sound", ("L1", "Initial sound; alliteration")),
        ("alliteration", "Recognise and produce alliteration", ("L1", "Initial sound; alliteration")),
        ("sort", "Sort pictures by initial sound", ("L1", "Initial sound; alliteration"))]),
    "final-sound": ("Final sound", [
        ("identify", "Identify the final sound", ("L1", "Final sound")),
        ("match", "Match words by final sound", ("L1", "Final sound")),
        ("sort", "Sort pictures by final sound", ("L1", "Final sound (pass 2)"))]),
    "medial-vowel": ("Medial vowel", [
        ("identify", "Identify the medial vowel sound", ("L1", "Medial vowel; segmentation")),
        ("sort", "Sort words by medial vowel sound", ("L1", "Initial, medial, final; segment, blend (capstone)"))]),
    "phoneme": ("Phoneme manipulation", [
        ("blend-2-3", "Blend 2 to 3 phonemes", ("L1", "Final + initial; phoneme blending")),
        ("blend-4-5", "Blend 4 to 5 phonemes", ("W", 3, 1)),
        ("segment-2-3", "Segment words of 2 to 3 phonemes", ("L1", "Initial, medial, final; segment and blend")),
        ("segment-4-5", "Segment words of 4 to 5 phonemes", ("W", 3, 1)),
        ("add", "Add a phoneme", ("L1", "Phoneme addition")),
        ("delete", "Delete a phoneme", ("L1", "Phoneme deletion")),
        ("substitute-initial", "Substitute the initial phoneme", ("L1", "Rhyme; phoneme substitution")),
        ("substitute-final", "Substitute the final phoneme", ("L1", "Phoneme substitution")),
        ("substitute-medial", "Substitute the medial phoneme", ("W", 4, 1))]),
    "cluster": ("Consonant clusters", [
        ("blend", "Blend a consonant cluster", ("E", 36)),
        ("split", "Split a consonant cluster", ("E", "T2"))]),
    "thai-contrast": ("Thai contrasts", [
        ("final-stop", "Hear and say final stops /p t k d/", ("E", "T1")),
        ("r-l", "Hear and say the r and l contrast", ("E", "T5")),
        ("v-w", "Hear and say the v and w contrast", ("E", "T5")),
        ("th-s-f", "Hear and say the th, s, f contrast", ("E", "T4")),
        ("vowel-length", "Hear and say long and short vowels", ("E", "E4"))]),
}

# ---------------------------------------------------------------- GSE links (id suffixes; verified against the GSE json)
GSE_PREFIX = "english.gse.skill.young."
GSE = {
    "reading_letters": "reading.10.can-recognise-the-letters-of-the-alphabe",
    "listening_names": "listening.10.can-understand-the-letters-of-the-alphab",
    "listening_sounds": "listening.10.can-recognise-the-letters-of-the-alphabe",
    "speaking_letters": "speaking.10.can-say-the-letters-of-the-alphabet-p",
    "speaking_sounds": "speaking.13.can-say-the-sounds-of-the-alphabet-if-su",
    "trace": "writing.10.can-trace-individual-letters-p",
    "copy_letters": "writing.10.can-copy-individual-letters-p",
    "write_lower": "writing.10.can-write-the-letters-of-the-alphabet-in",
    "write_upper": "writing.10.can-write-the-letters-of-the-alphabet-in.1",
    "read_initial": "reading.14.can-identify-the-initial-sound-in-simple",
    "hear_initial": "listening.10.can-hear-the-initial-sound-in-simple-wor",
    "combine": "reading.18.can-combine-single-letter-sounds-to-read",
    "say_combo": "speaking.20.can-say-single-sounds-represented-by-com",
    "read_aloud": "speaking.20.can-read-aloud-familiar-single-words-p",
    "freq_words": "reading.21.can-recognise-some-frequent-everyday-wor",
    "read_indiv": "reading.21.can-identify-the-individual-vowel-and-co",
    "hear_indiv": "listening.16.can-hear-the-individual-vowel-and-conson",
    "rhyme": "speaking.16.can-recite-a-short-simple-rhyme-or-chant",
    "plural": "reading.20.can-recognise-basic-plural-forms-of-comm",
    "copy_sentence": "writing.13.can-copy-short-sentences-containing-only",
    "spacing": "writing.13.can-use-appropriate-spacing-within-and-b",
    "caps_names": "writing.20.can-use-capital-letters-for-names-and-ti",
    "write_words": "writing.20.can-write-some-familiar-words-p",
    "known_letters": "reading.10.can-identify-some-known-letters-in-words",
    "copy_words": "writing.10.can-copy-some-short-familiar-words-prese",
}

# ================================================================ build
nodes, edges = [], []
NID = {}
def add_node(id_, kind, title, desc, meta, refs):
    assert ID_RE.match(id_), id_
    assert id_ not in NID, id_
    n = {"id": id_, "kind": kind, "title": title, "domain": D, "description": desc,
         "sourceRefs": refs, "reviewStatus": "draft", "metadata": meta}
    NID[id_] = n
    nodes.append(n)

ECOUNT = Counter()
SEEN_EDGES = set()
EDGE_IDS = set()
def _tail(nid):
    for p in (f"{D}.", "english.gse.skill."):
        if nid.startswith(p):
            return nid[len(p):]
    raise ValueError(nid)
def add_edge(type_, s, t, weight, conf, refs, rationale, meta=None):
    assert s in NID and t in NID, (type_, s, t)
    if (s, t, type_) in SEEN_EDGES:  # keep the first (logical) edge over a later teaching-order edge
        return
    SEEN_EDGES.add((s, t, type_))
    ECOUNT[type_] += 1
    eid = f"{D}.edge.{type_.replace('_', '-')}.{_tail(s)}--{_tail(t)}"
    n = 1
    while eid in EDGE_IDS:  # content ids collide only in rare cases; a short suffix keeps them unique
        n += 1
        eid = f"{D}.edge.{type_.replace('_', '-')}.{_tail(s)}--{_tail(t)}-{n}"
    EDGE_IDS.add(eid)
    e = {"id": eid, "type": type_, "sourceId": s,
         "targetId": t, "weight": weight, "confidence": conf, "sourceRefs": refs,
         "reviewStatus": "draft", "rationale": rationale}
    if meta:
        e["metadata"] = meta
    edges.append(e)

def lw(level, week):
    return {"level": level, "week": week, "program_week": (level - 1) * 32 + week if week else None}

# domain + standard
add_node(f"{D}.domain", "domain", "Storytime Advantage phonics and early literacy",
         "Phonemic awareness, letters, grapheme-phoneme correspondences, patterns, and sight words for Storytime Advantage Levels 1 to 4 (ages 4 to 8).",
         {"framework": "storytime-phonics", "version": "v1", "levels": 4, "weeks": 128,
          "source_sequence_commit": SEQ_COMMIT},
         [R_DESIGN("5"), ref(SOURCES, "sources.md")])
add_node(STD, "standard", "Storytime Advantage phonics exit standard v1",
         "The Storytime phonics scope: alphabet and sounds, blending and segmenting, decoding of simple and complex words, and sight words, as set against the Thai curriculum and the Starters alphabet expectation.",
         {"standard_family": "storytime", "version": "v1"},
         [ref(SOURCES, "Thai Basic Education Core Curriculum B.E. 2551, Foreign Languages, F1.1 Gr1/2",
              note="Quote: \"Specify the alphabet and sounds; accurately pronounce and spell simple words by observing principles of reading\""),
          ref(SOURCES, "Thai Basic Education Core Curriculum B.E. 2551, Foreign Languages, F1.1 Gr2/2 and Gr3/2",
              note="Indicator codes cited in design.md section 5.4; the indicator text is not quoted in sources.md"),
          ref(SOURCES, "Cambridge Pre A1 Starters handbook and word list 2018", note="Starters alphabet expectation"),
          ref(SOURCES, "DfE core criteria for systematic synthetic phonics programmes (2021)")])

# level groups
LEVELS = {1: ("Level 1 (Anuban 2)", "Anuban 2, ages 4-5"), 2: ("Level 2 (Anuban 3)", "Anuban 3, ages 5-6"),
          3: ("Level 3 (P1)", "P1, ages 6-7"), 4: ("Level 4 (P2)", "P2, ages 7-8")}
for lv, (t, g) in LEVELS.items():
    add_node(f"{D}.group.level-{lv}", "content_group", t, f"Storytime Advantage Level {lv}: {g}, 32 weeks.",
             {"level": lv, "grade": g, "weeks": f"{(lv-1)*32+1}-{lv*32}"}, [R_DESIGN("1.2"), R_DESIGN("5.7")])
    add_edge("contains", f"{D}.domain", f"{D}.group.level-{lv}", 1, "high", [R_DESIGN("5.4")], "Domain contains level group")
for mod, (mt, skills) in PA.items():
    add_node(f"{D}.group.pa.{mod}", "content_group", f"Phonemic awareness: {mt}",
             f"Phonemic awareness module {mod} with {len(skills)} skills.", {"module": mod, "skill_count": len(skills)},
             [R_DESIGN("5.2")])
    add_edge("contains", f"{D}.domain", f"{D}.group.pa.{mod}", 1, "high", [R_DESIGN("5.4")], "Domain contains PA module")
for lv in (1, 2, 3):
    add_edge("prerequisite_for", f"{D}.group.level-{lv}", f"{D}.group.level-{lv+1}", 0.8, "medium",
             [R_DESIGN("1.2")], "Level order: each level builds on the exit profile of the one before")

aligned = []  # node ids to align to the standard
def level_contains(level, nid):
    add_edge("contains", f"{D}.group.level-{level}", nid, 1, "high", [R_DESIGN("5.4")], "Level group contains member")

# phonemes (level 1 concepts)
for slug, ipa, ex in PHONEMES:
    nid = f"{D}.phoneme.{slug}"
    add_node(nid, "concept", f"Phoneme /{ipa}/", f"The English phoneme /{ipa}/ as in {ex}.",
             {**lw(1, None), "ipa": ipa, "example": ex}, [R_DESIGN("5.3")])
    level_contains(1, nid); aligned.append(nid)

# letters
LETTER_ORDER = gen.letters_order
GPC_WHERE = {}  # letter -> (level, week) of its single-letter GPC element
for _k in range(1, 69):
    for _s in ELEMENTS[_k]:
        if _s[0] == "gpc" and (len(_s[2]) == 1 or _s[2] == "qu"):
            GPC_WHERE.setdefault("q" if _s[2] == "qu" else _s[2], ELEM_WHERE[_k])
single_gpc = {}  # letter -> gpc node id (first single-letter mapping)
elem_nodes = []  # (level, week, order, node id) for the teaching-order chain
gpc_info = {}    # node id -> (grapheme, phonemes)
order = 0
for key in list(range(1, 69)) + ["T1", "T2", "T3", "T4", "T5"] + [f"E{i}" for i in range(1, 12)]:
    lv, wk = ELEM_WHERE[key]
    elem_pos = key if isinstance(key, int) else None
    for spec_ in ELEMENTS[key]:
        order += 1
        if spec_[0] == "gpc":
            _, suf, grapheme, phs = spec_
            nid = f"{D}.gpc.{suf}"
            add_node(nid, "skill", f"GPC {grapheme} = " + " ".join("/" + next(p[1] for p in PHONEMES if p[0] == x) + "/" for x in phs),
                     f"Read and spell the grapheme {grapheme} for the sound(s) {', '.join(phs)}.",
                     {**lw(lv, wk), "grapheme": grapheme, "phonemes": phs, "teaching_order": order},
                     [R_SEQ, R_DESIGN("5.3")])
            gpc_info[nid] = (grapheme, phs)
            if len(grapheme) == 1 and grapheme not in single_gpc:
                single_gpc[grapheme] = nid
            if grapheme == "qu":
                single_gpc["q"] = nid
            for p in phs:
                add_edge("supports", f"{D}.phoneme.{p}", nid, 0.6, "medium", [R_DESIGN("5.1")],
                         "The phoneme is the sound that the grapheme spells")
        else:
            _, slug, title, desc = spec_
            nid = f"{D}.pattern.{slug}"
            add_node(nid, "skill", title, desc or f"Read and spell words with the pattern: {title}.",
                     {**lw(lv, wk), "teaching_order": order},
                     [R_SEQ, R_DESIGN("5.3")] if elem_pos else [R_SEQ, R_DESIGN("2"), R_DESIGN("5.3")])
        level_contains(lv, nid); aligned.append(nid); elem_nodes.append((lv, wk, order, nid))
    if key in CVC.values():
        v = next(k for k, e in CVC.items() if e == key)
        order += 1
        nid = f"{D}.pattern.cvc-short-{v}"
        add_node(nid, "skill", f"CVC words with short {v}", f"Blend and read consonant-vowel-consonant words with short {v}.",
                 {**lw(lv, wk), "teaching_order": order}, [R_SEQ, R_DESIGN("5.3")])
        level_contains(lv, nid); aligned.append(nid); elem_nodes.append((lv, wk, order, nid))
        add_edge("prerequisite_for", f"{D}.gpc.{v}.short-{v}", nid, 1, "high", [R_DESIGN("5.4")],
                 "The short vowel GPC is needed to read the CVC words")

# letters: name, sound, form-lower (level 1; form-lower traced for the first 10), form-upper (level 2)
for i, L in enumerate(LETTER_ORDER):
    wk1 = L1_LETTER[L]
    for kind_, title, lvl, wk, extra in (
        ("name", f"Letter {L}: name", 1, wk1, {"taught_by": "alphabet song daily; focus letter of the week"}),
        ("sound", f"Letter {L}: sound", 1, wk1, {}),
        ("form-lower", f"Letter {L}: lower-case form", None, None, {}),
        ("form-upper", f"Letter {L}: upper-case form", 2, None, {"week_note": "design 5.3 puts capitals in Level 2; 1.2 puts capital use in Level 3; no week is scheduled"}),
    ):
        nid = f"{D}.letter.{L}.{kind_}"
        meta = {"letter": L, "letter_kind": kind_, "letter_order": i + 1, **extra}
        if kind_ == "form-lower":
            traced = i < 10
            if traced:
                lvl, wk = 1, wk1
            else:
                lvl, wk = GPC_WHERE[L]
            meta["traced_in_level_1"] = traced
        meta.update(lw(lvl, wk))
        add_node(nid, "skill", title, f"Letter {L}: {kind_.replace('-', ' ')}.", meta, [R_DESIGN("5.3"), R_DESIGN("1.2")])
        level_contains(meta["level"], nid)
        aligned.append(nid)

# PA skills
pa_nodes = []  # (level, week, order, id)
pa_ids = {}
porder = 0
for mod, (mt, skills) in PA.items():
    for slug, title, where in skills:
        porder += 1
        if where[0] == "L1":
            lv, wk = 1, L1_PA[where[1]]
        elif where[0] == "E":
            lv, wk = ELEM_WHERE[where[1]]
        else:
            lv, wk = where[1], where[2]
        nid = f"{D}.pa.{mod}.{slug}"
        add_node(nid, "skill", title, f"Phonemic awareness ({mt}): {title.lower()}.",
                 {**lw(lv, wk), "module": mod},
                 [R_DESIGN("5.2"), R_SEQ] + ([R_THAI] if mod == "thai-contrast" else []))
        pa_ids[(mod, slug)] = nid; pa_nodes.append((lv, wk, porder, nid))
        add_edge("contains", f"{D}.group.pa.{mod}", nid, 1, "high", [R_DESIGN("5.2")], "PA module contains skill")
        aligned.append(nid)

# ---------------------------------------------------------------- decodability (design 5.3: a tricky word is a word the
# taught GPCs cannot decode at its introduction week)
PAIR_WEEK = {}  # (grapheme, phoneme slugs joined by "-") -> first program week at which the GPC is taught
for _nid, (_g, _ph) in gpc_info.items():
    _w = NID[_nid]["metadata"]["program_week"]
    PAIR_WEEK[(_g, "-".join(_ph))] = min(_w, PAIR_WEEK.get((_g, "-".join(_ph)), 999))
# patterns that teach extra grapheme-phoneme pairs: open vowels (he, go, my) and the plural -s sound
for _slug, _pairs in (("open-vowel", [("e", "long-e"), ("o", "long-o"), ("y", "long-i")]), ("plural-s", [("s", "z")])):
    for _pr in _pairs:
        PAIR_WEEK[_pr] = NID[f"{D}.pattern.{_slug}"]["metadata"]["program_week"]
GRAPHEMES = sorted({g for g, _ in PAIR_WEEK if "-" not in g}, key=lambda g: (-len(g), g))
DEFAULT_PH = {}  # grapheme -> phonemes of the earliest-taught GPC (the default sound)
for _nid, (_g, _ph) in sorted(gpc_info.items(), key=lambda kv: NID[kv[0]]["metadata"]["teaching_order"]):
    DEFAULT_PH.setdefault(_g, "-".join(_ph))
SPLIT_LONG = {"a": "long-a", "i": "long-i", "o": "long-o", "u": "long-oo"}
# Manual parses for irregular words, as grapheme or grapheme:phoneme tokens. A pair that is not a GPC of the graph
# (for example a:short-o in "want") means the word cannot be decoded with the graph GPCs.
MANUAL_PARSE = {
    "a": "a:schwa", "i": "i:long-i", "the": "th:th-voiced e:schwa", "is": "i s:z", "his": "h i s:z", "has": "h a s:z",
    "as": "a s:z", "this": "th:th-voiced i s", "that": "th:th-voiced a t", "them": "th:th-voiced e m",
    "then": "th:th-voiced e n", "they": "th:th-voiced ey", "he": "h e:long-e", "me": "m e:long-e", "we": "w e:long-e",
    "she": "sh e:long-e", "be": "b e:long-e", "my": "m y:long-i", "by": "b y:long-i", "why": "wh y:long-i",
    "go": "g o:long-o", "no": "n o:long-o", "so": "s o:long-o", "put": "p u:short-oo t", "look": "l oo:short-oo k",
    "looks": "l oo:short-oo k s", "good": "g oo:short-oo d", "are": "a:ar r e:silent", "were": "w ere:er",
    "of": "o:short-o f:v", "goes": "g oe:long-o s:z", "said": "s ai:short-e d", "you": "y ou:long-oo",
    "over": "o:long-o v er", "want": "w a:short-o n t", "does": "d oe:short-u s:z", "have": "h a:short-a ve:v",
    "more": "m ore:or", "some": "s o:short-u m e:silent", "come": "c o:short-u m e:silent",
    "loves": "l o:short-u ve:v s", "who": "wh o:long-oo", "how": "h ow:ow", "there": "th:th-voiced ere:air",
    "where": "wh ere:air", "give": "g i:short-i ve:v", "live": "l i:short-i ve:v", "dont": "d o:long-o-closed n t",
    "every": "e v e:schwa r y:long-e", "our": "ou:ow r", "always": "a:or l w ay:long-a s:z", "about": "a:schwa b ou:ow t",
    "what": "wh a:short-o t", "says": "s ay:short-e s:z", "comes": "c o:short-u m e:silent s:z", "to": "t o:long-oo",
    "do": "d o:long-oo", "old": "o:long-o-closed l d", "color": "c o:short-u l or:er", "children": "ch i:short-i l d r e:schwa n",
    "school": "s ch:k oo:long-oo l", "write": "wr:r i-e:long-i t", "into": "i n t o:long-oo", "one": "o:w n e:silent",
    "people": "p e:long-e o:schwa p l e:silent", "find": "f i:long-i n d", "with": "w i th:th-voiced",
}

def parse_word(word):
    """Parses a word into (grapheme, phoneme slugs) pairs by greedy longest match, or by the manual table."""
    w = word.lower().replace("'", "")
    if w in MANUAL_PARSE:
        toks = [t.split(":") if ":" in t else [t, DEFAULT_PH.get(t, "?")] for t in MANUAL_PARSE[w].split()]
        return [(g, p) for g, p in toks]
    tail = []
    m = re.search(r"([aiou])([^aeiou])e$", w)
    if m and len(w) > 3:
        tail = [(m.group(1) + "-e", SPLIT_LONG[m.group(1)]), (m.group(2), DEFAULT_PH.get(m.group(2), "?"))]
        w = w[:m.start()]
    out, i = [], 0
    while i < len(w):
        g = next((x for x in GRAPHEMES if w.startswith(x, i)), None)
        if g is None:
            return [(w[i], "?")]
        out.append((g, DEFAULT_PH[g]))
        i += len(g)
    return out + tail

def decodable_from(pairs):
    """Returns the first program week at which every pair is taught, or None if a pair is not in the graph."""
    weeks = [PAIR_WEEK.get(p) for p in pairs]
    return None if None in weeks else max(weeks)

# tricky words: kept only when the word is not decodable at its introduction week
TRICKY_ALL = TRICKY
TRICKY, DECODABLE = [], []  # kept (word, level, week, decodable_from_week); dropped (word, level, week, decodable week)
for w, lv, wk in TRICKY_ALL:
    pairs = parse_word(w)
    dw = decodable_from(pairs)
    (DECODABLE if dw is not None and dw <= (lv - 1) * 32 + wk else TRICKY).append((w, lv, wk, dw, pairs))
if "--debug-parse" in sys.argv:
    for w, lv, wk, dw, pairs in TRICKY + DECODABLE:
        print(f"{w:10s} wk{(lv-1)*32+wk:4d} from {dw} {'DROP' if (w, lv, wk, dw, pairs) in DECODABLE else 'keep'} "
              + " ".join(f"{g}:{p}" for g, p in pairs))
    sys.exit(0)
for w, lv, wk, dw, pairs in TRICKY:
    slug = re.sub(r"[^a-z0-9]", "", w.lower())
    nid = f"{D}.tricky.{slug}"
    add_node(nid, "skill", f"Tricky word: {w}", f"Read the sight word \"{w}\" at sight speed.",
             {**lw(lv, wk), "word": w, "decodable_from_week": dw},
             [R_SEQ, ref(DESIGN, "design.md section 1.1 (function and high-frequency words)")])
    level_contains(lv, nid); aligned.append(nid)

# ---------------------------------------------------------------- edges
# aligned_to_standard
for nid in aligned:
    add_edge("aligned_to_standard", nid, STD, 1, "high", [R_DESIGN("5.4")], "Node is part of the Storytime phonics standard")

# logical prerequisites
def pre(a, b, w, conf, why, refs=None):
    add_edge("prerequisite_for", a, b, w, conf, refs or [R_DESIGN("5.4")], why)

for L in LETTER_ORDER:
    g = single_gpc[L]
    pre(f"{D}.letter.{L}.sound", g, 1, "high", "The letter sound is needed before its GPC")
# letters in a grapheme need the single-letter GPC (medium)
for nid, (grapheme, phs) in gpc_info.items():
    for L in sorted(set(grapheme.replace("-", ""))):
        src = single_gpc.get(L)
        if src and src != nid and len(grapheme) > 1 and grapheme != "qu":
            pre(src, nid, 0.6, "medium", f"The grapheme {grapheme} contains the letter {L}")
        elif src and src != nid and len(grapheme) == 1 and grapheme == L:
            pre(src, nid, 0.8, "medium", f"The second sound of {L} needs its first sound")
for v, e in CVC.items():
    pre(pa_ids[("phoneme", "blend-2-3")], f"{D}.pattern.cvc-short-{v}", 0.8, "medium", "Oral blending of 2-3 sounds is needed to read CVC words")
    pre(pa_ids[("phoneme", "segment-2-3")], f"{D}.pattern.cvc-short-{v}", 0.6, "medium", "Segmenting 2-3 sounds is needed to spell CVC words")
    pre(pa_ids[("medial-vowel", "identify")], f"{D}.pattern.cvc-short-{v}", 0.6, "medium", "Hearing the medial vowel is needed for CVC words")
RIME_VOWEL = {"an": "a", "ad": "a", "ot": "o", "op": "o", "et": "e", "en": "e", "it": "i", "in": "i", "ug": "u", "un": "u",
              "at": "a", "ap": "a", "ut": "u", "ub": "u", "ill": "i", "ip": "i", "ob": "o", "ell": "e"}
for r, v in RIME_VOWEL.items():
    pre(f"{D}.pattern.cvc-short-{v}", f"{D}.pattern.rime-{r}", 0.8, "medium", "CVC reading with the short vowel comes before the rime family")
    pre(pa_ids[("onset-rime", "word-family")], f"{D}.pattern.rime-{r}", 0.6, "medium", "Word family awareness supports the rime pattern")
for p in ("s-blend", "r-blend", "l-blend", "final-n-blend", "final-blend", "three-letter-blend", "thai-initial-clusters", "thai-final-clusters-s"):
    pre(pa_ids[("cluster", "blend")], f"{D}.pattern.{p}", 0.8, "medium", "Blending a cluster is needed before blend patterns")
for slug, pat in (("final-stop", "thai-final-stops"), ("th-s-f", "thai-th-s-f"), ("r-l", "thai-v-w-r-l"), ("v-w", "thai-v-w-r-l"), ("vowel-length", "thai-vowel-length")):
    pre(pa_ids[("thai-contrast", slug)], f"{D}.pattern.{pat}", 0.8, "medium", "The Thai-contrast PA skill comes before the matching pattern week", [R_DESIGN("5.2"), R_THAI])
# The PA taxonomy has no internal prerequisite edges: the order of the PA skills comes only from the week table (teaching-order edges).
# Teaching-order edges (low confidence: pedagogical, not logical). Derived ONLY from the week table: the last node of a
# week points to the first node of the next week in the same chain, so every edge goes from an earlier week to a later week.
TEACHING_REF = "english.phonics teaching-order-v1: derived from the 128-week table, earlier week -> later week"
def chain(items, label):
    by_week = defaultdict(list)
    for wk, order_, nid in items:
        by_week[wk].append((order_, nid))
    weeks = sorted(by_week)
    for w1, w2 in zip(weeks, weeks[1:]):
        a, b = max(by_week[w1])[1], min(by_week[w2])[1]
        add_edge("prerequisite_for", a, b, 0.3, "low", [TEACHING_REF, R_SEQ],
                 f"Teaching order of the {label}: week {w1} comes before week {w2}; a pedagogical order, not a logical prerequisite",
                 {"edgeRole": "teaching-order"})
PW = lambda nid: NID[nid]["metadata"]["program_week"]
chain([(PW(n), o, n) for _, _, o, n in elem_nodes], "element sequence")
chain([(PW(n), o, n) for _, _, o, n in pa_nodes], "phonemic awareness sequence")
chain([(L1_LETTER[L], i, f"{D}.letter.{L}.sound") for i, L in enumerate(LETTER_ORDER)], "Level 1 letter-sound order")

# GSE links
gse_ids = {n["id"] for n in json.load(open(GSE_JSON))["nodes"]}
GSE_MISSING = []
def gse(key):
    i = GSE_PREFIX + GSE[key]
    if i not in gse_ids:
        GSE_MISSING.append(i)
    return i
def link(src, key, type_, w, why):
    t = gse(key)
    if t not in gse_ids:
        return
    if t not in NID:
        NID[t] = None  # placeholder so add_edge's assertion passes; endpoint lives in the GSE graph
    add_edge(type_, src, t, w, "medium", [R_GSE, R_DESIGN("5.4")], why, {"crossGraph": "english.gse"})

for L in LETTER_ORDER:
    for key in ("reading_letters", "listening_names", "speaking_letters"):
        link(f"{D}.letter.{L}.name", key, "supports", 0.5, "Knowing the letter name serves the GSE alphabet objective")
    for key in ("speaking_sounds", "listening_sounds"):
        link(f"{D}.letter.{L}.sound", key, "supports", 0.5, "Knowing the letter sound serves the GSE alphabet-sound objective")
    link(f"{D}.letter.{L}.form-lower", "write_lower", "supports", 0.5, "Forming the lower-case letter serves the GSE writing objective")
    link(f"{D}.letter.{L}.form-lower", "copy_letters", "supports", 0.4, "Forming the letter serves the GSE copy-letters objective")
    link(f"{D}.letter.{L}.name", "known_letters", "supports", 0.4, "Knowing the letter name serves identifying known letters in words")
    link(f"{D}.letter.{L}.form-lower", "known_letters", "supports", 0.4, "Knowing the lower-case form serves identifying known letters in words")
    link(f"{D}.letter.{L}.form-upper", "known_letters", "supports", 0.4, "Knowing the upper-case form serves identifying known letters in words")
    link(f"{D}.letter.{L}.form-upper", "write_upper", "supports", 0.5, "Forming the upper-case letter serves the GSE writing objective")
    if NID[f"{D}.letter.{L}.form-lower"]["metadata"]["traced_in_level_1"]:
        link(f"{D}.letter.{L}.form-lower", "trace", "supports", 0.6, "Tracing the letter serves the GSE trace objective")
for nid, (grapheme, phs) in gpc_info.items():
    link(nid, "combine", "supports", 0.5, "Letter-sound knowledge is used to read simple words")
    if NID[nid]["description"].startswith("Read and spell"):
        link(nid, "copy_words", "supports", 0.3, "Spelling the grapheme serves copying short familiar words")
        link(nid, "write_words", "supports", 0.3, "Spelling the grapheme serves writing some familiar words")
    if len(grapheme) > 1 or "-" in grapheme:
        link(nid, "say_combo", "supports", 0.5, "The grapheme is a letter combination that stands for one sound")
for nid in list(NID):
    if nid.startswith(f"{D}.pattern.cvc-") or nid.startswith(f"{D}.pattern.rime-") or nid.endswith("-blend"):
        link(nid, "combine", "supports", 0.6, "Blending sounds to read simple words")
link(f"{D}.pattern.plural-s", "plural", "supports", 0.5, "Plural -s serves the GSE plural-forms objective")
link(f"{D}.pattern.plural-es", "plural", "supports", 0.5, "Plural -es serves the GSE plural-forms objective")
link(f"{D}.pattern.sentence-writing-1", "copy_sentence", "supports", 0.4, "Sentence writing builds on copying short sentences")
link(f"{D}.pattern.sentence-writing-2", "spacing", "supports", 0.4, "Sentence writing uses spacing between words")
link(f"{D}.pattern.sentence-writing-2", "caps_names", "supports", 0.4, "Sentence writing uses capital letters for names")
link(f"{D}.pattern.fluency-timed-reread", "read_aloud", "supports", 0.5, "Timed re-reading builds reading aloud of familiar words")
for w, lv, wk, _dw, _pairs in TRICKY:
    slug = re.sub(r"[^a-z0-9]", "", w.lower())
    link(f"{D}.tricky.{slug}", "freq_words", "supports", 0.5, "Sight words serve the GSE objective on frequent everyday words")
    link(f"{D}.tricky.{slug}", "read_aloud", "supports", 0.3, "Sight words serve reading aloud of familiar words")
P_ = lambda m, s: pa_ids[(m, s)]
link(P_("initial-sound", "identify"), "read_initial", "supports", 0.6, "Identifying the initial sound serves the GSE reading objective on the initial sound in simple words")
link(P_("initial-sound", "identify"), "hear_initial", "equivalent_to", 0.9, "Same skill: hear the initial sound in simple words")
for s in ("match", "alliteration", "sort"):
    link(P_("initial-sound", s), "hear_initial", "supports", 0.5, "Initial sound work serves the GSE hear-initial-sound objective")
link(P_("rhyme", "produce"), "rhyme", "supports", 0.5, "Producing rhymes serves reciting a rhyme or chant")
link(P_("rhyme", "recognise"), "rhyme", "supports", 0.4, "Hearing rhymes serves reciting a rhyme or chant")
link(P_("phoneme", "blend-2-3"), "combine", "supports", 0.6, "Oral blending serves reading simple words by combining letter sounds")
for k in ("medial-vowel.identify", "phoneme.segment-2-3"):
    m, s = k.split(".")
    link(P_(m, s), "hear_indiv", "supports", 0.5, "Hearing individual sounds serves the GSE objective")
    link(P_(m, s), "read_indiv", "supports", 0.4, "Identifying individual sounds serves the GSE objective")
for nid in [n for n in list(NID) if NID[n] is None]:
    del NID[nid]

# ---------------------------------------------------------------- self-checks
# Python re-implementation of the SPECIFICATION section 4 checks (structural, pairing, alignment, cycles), run on the phonics
# file alone and on phonics + links + GSE merged. The TypeScript validator (knowledge-space-core) is run separately by hand.
def check(nodes, edges, label):
    errs = []
    ids = Counter(n["id"] for n in nodes)
    errs += [("DUPLICATE_NODE_ID", i) for i, c in ids.items() if c > 1]
    eids = Counter(e["id"] for e in edges)
    errs += [("DUPLICATE_EDGE_ID", i) for i, c in eids.items() if c > 1]
    kinds = {n["id"]: n["kind"] for n in nodes}
    for n in nodes:
        if not ID_RE.match(n["id"]) or not n.get("sourceRefs"):
            errs.append(("BAD_NODE", n["id"]))
    seen = set()
    for e in edges:
        if not ID_RE.match(e["id"]) or not e.get("sourceRefs"):
            errs.append(("BAD_EDGE", e["id"]))
        t = e["targetId"]
        if e["sourceId"] not in kinds or t not in kinds:
            errs.append(("DANGLING_EDGE", e["id"]))
            continue
        k = (e["sourceId"], t, e["type"])
        if k in seen:
            errs.append(("DUPLICATE_EDGE", e["id"]))
        seen.add(k)
        if e["type"] == "aligned_to_standard" and (kinds[e["sourceId"]] not in ("skill", "worked_example", "task_blueprint", "concept")
                                                   or kinds[t] != "standard"):
            errs.append(("INVALID_EDGE_PAIRING", e["id"]))
        if e["type"] == "contains" and (kinds[e["sourceId"]] not in ("domain", "content_group", "instructional_unit")
                                         or kinds[t] not in ("content_group", "instructional_unit", "worked_example", "skill", "concept", "task_blueprint")):
            errs.append(("INVALID_EDGE_PAIRING", e["id"]))
    aligned_set = {e["sourceId"] for e in edges if e["type"] == "aligned_to_standard"}
    errs += [("MISSING_REQUIRED_ALIGNMENT", n["id"]) for n in nodes
             if n["kind"] in ("skill", "worked_example", "task_blueprint") and n["id"] not in aligned_set]
    errs += [("PREREQUISITE_CYCLE", c) for c in cycles(edges, include_low=False)]
    return [(label,) + e for e in errs]

def cycles(edges, include_low):
    """Returns the cycles of the prerequisite_for graph; low-confidence edges count only when include_low is true."""
    adj = defaultdict(list)
    for e in edges:
        if e["type"] == "prerequisite_for" and (include_low or e["confidence"] != "low"):
            adj[e["sourceId"]].append(e["targetId"])
    color, found = {}, []
    sys.setrecursionlimit(20000)
    def dfs(u, stack):
        color[u] = 1
        stack.append(u)
        for v in adj[u]:
            if color.get(v) == 1:
                found.append(" -> ".join(stack[stack.index(v):] + [v]))
            elif v not in color:
                dfs(v, stack)
        stack.pop()
        color[u] = 2
    for u in list(adj):
        if u not in color:
            dfs(u, [])
    return found

def check_order(nodes, edges):
    """Checks the week rules: low edges go from an earlier week to a later week, no medium or high prerequisite goes
    backward in time, and no low edge is the reverse of a medium or high edge."""
    errs = []
    week = {n["id"]: n["metadata"].get("program_week") for n in nodes}
    pre = [e for e in edges if e["type"] == "prerequisite_for"]
    strong = {(e["sourceId"], e["targetId"]) for e in pre if e["confidence"] != "low"}
    for e in pre:
        ws, wt = week[e["sourceId"]], week[e["targetId"]]
        if e["confidence"] == "low":
            if (e.get("metadata") or {}).get("edgeRole") != "teaching-order" or not any(isinstance(r, str) for r in e["sourceRefs"]):
                errs.append(("LOW_EDGE_NOT_TEACHING_ORDER", e["id"]))
            if ws is None or wt is None or ws >= wt:
                errs.append(("LOW_EDGE_NOT_FORWARD", e["id"], ws, wt))
            if (e["targetId"], e["sourceId"]) in strong:
                errs.append(("LOW_EDGE_CONTRADICTS_STRONG_EDGE", e["id"]))
        elif ws is not None and wt is not None and ws > wt:
            errs.append(("STRONG_EDGE_BACKWARD_IN_TIME", e["id"], ws, wt))
    return errs

# Edges into the GSE graph go to a second file: a document may not hold an edge to a node outside it.
links = [e for e in edges if e["targetId"].startswith(GSE_PREFIX)]
edges[:] = [e for e in edges if not e["targetId"].startswith(GSE_PREFIX)]
GSE_DOC = json.load(open(GSE_JSON, encoding="utf-8"))
errs = check(nodes, edges, "phonics")
errs += check(nodes + GSE_DOC["nodes"], edges + links + GSE_DOC["edges"], "merged")
errs += [("order",) + e for e in check_order(nodes, edges)]
errs += [("cycle-with-low-edges", c) for c in cycles(edges, include_low=True)]
_gse_all = {n["id"] for n in GSE_DOC["nodes"]}
errs += [("links", "TARGET_NOT_IN_GSE", e["id"]) for e in links if e["targetId"] not in _gse_all]
errs += [("links", "SOURCE_NOT_IN_PHONICS", e["id"]) for e in links if e["sourceId"] not in {n["id"] for n in nodes}]
errs += [("equivalent_to", e["id"]) for e in links if e["type"] == "equivalent_to" and e["targetId"] != GSE_PREFIX + GSE["hear_initial"]]
if errs:
    for e in errs[:40]:
        print("ERROR", *e)
    sys.exit(1)

def dump(path, obj):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)
        f.write("\n")
dump(HERE / "phonics-gse-links.json",
     {"meta": {"gse_file": "english/gse-knowledge-space.json", "gse_commit": GSE_COMMIT, "schemaVersion": "v1",
               "phonics_version": "v1"}, "edges": links})
dump(HERE / "phonics-knowledge-space.json", {"nodes": nodes, "edges": edges})

# level map CSV (design 5.7; reader band names per decision S15)
LEVEL_CSV = [
    (1, "Level 1", "Anuban 2", "Seed", "none (26 letters by song)", "1-32"),
    (2, "Level 2", "Anuban 3", "Seed|Sprout", "1-28", "33-64"),
    (3, "Level 3", "P1", "Sprout|Leaf|Bud", "29-51 + T1-T5", "65-96"),
    (4, "Level 4", "P2", "Bud|Flower", "52-68 + E1-E11", "97-128"),
]
with open(HERE / "storytime-levels.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f, lineterminator="\n")
    w.writerow(["level", "label", "grade", "reader_bands", "elements", "weeks"])
    w.writerows(LEVEL_CSV)

print("self-checks passed: phonics alone, merged with links + GSE, week order, cycles including low edges (0 errors)")
print("nodes", len(nodes), dict(Counter(n["kind"] for n in nodes)))
print("edges", len(edges), dict(Counter(e["type"] for e in edges)), "+ links", len(links))
print("prerequisite_for by confidence", dict(Counter(e["confidence"] for e in edges if e["type"] == "prerequisite_for")))
print("gse links", len({e["targetId"] for e in links}), "distinct;", len(links), "edges; missing", sorted(set(GSE_MISSING)),
      dict(Counter(e["type"] for e in links)))
print("tricky kept", len(TRICKY), "dropped as decodable", len(DECODABLE), "pa", len(pa_nodes), "elements", len(elem_nodes))
print("dropped (decodable high-frequency words):", ", ".join(f"{w}@{(lv-1)*32+wk}" for w, lv, wk, dw, _ in DECODABLE))
print("kept but decodable later:", sum(1 for t in TRICKY if t[3] is not None), "; never decodable in v1:", sum(1 for t in TRICKY if t[3] is None))
