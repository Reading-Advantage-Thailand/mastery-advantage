# Sense-Level Lexical Identity Specification

**Status:** Spec ready; implementation deferred (2026-08-11).  
**Track:** `sense_level_identity_spec_20260611`.  
**Depends on:** form+POS freeze (YLE); WordNet semantic draft; no bulk EVP without license.

## 1. Problem

Current identity is **form + POS** (with occasional publisher gloss text baked
into `lexicalForm` / id for YLE constraints). That collapses distinct **senses**
under the same POS (e.g. `bank` noun: finance vs river). Effects:

- Mastery claims mix unrelated meanings
- WordNet candidates quarantine 2,478 lemma+POS rows as ambiguous
- Article matching can credit the wrong sense exposure

## 2. When sense identity is required

| Situation | form+POS enough? | Sense required? |
|---|---|---|
| Function words with one dominant use | yes | no |
| Open-class lemma, WordNet synset count = 1 | yes | no |
| Open-class lemma, WordNet synset count ≥ 2 **and** pedagogy distinguishes uses | no | **yes** (or explicit “undifferentiated” policy) |
| Cambridge list already constrains sense via gloss (`bank` + money sentence) | partial | prefer encode as sense child or keep gloss-key as interim |
| Multiword expressions | form+POS / MWE id | sense only if inventory is sense-tagged |

**Default for app adoption where polysemy matters:** require sense children for
high-frequency forms with ≥2 pedagogical senses; keep form+POS parent as a
rollup for placement and coarse goals.

## 3. Sense inventory sources

| Source | Role | License / repro | Decision |
|---|---|---|---|
| **Princeton WordNet 3.1** (NLTK) | Primary offline sense ids (`synset.name()`) | Permissive; pin corpus version | **Primary** |
| Cambridge list gloss / example constraints | Pedagogical sense hint already in freeze | Official lists; no bulk EVP dump | **Fallback / override** when present |
| English Vocabulary Profile bulk | Fine CEFR-by-sense | **Excluded until company license** | Not used |
| Live dictionary APIs | — | Non-reproducible | Forbidden |

**Justification:** WordNet is offline, versionable, already used for semantic
candidates. Cambridge lists rarely give full sense inventories; when they do
give gloss constraints, those win over bare WordNet ranking for exam fidelity.

## 4. Identity rules (proposed)

### 4.1 Stable ids (additive)

```text
# current (unchanged)
english.vocabulary.skill.<form-slug>.<pos-slug>

# sense child (new, optional)
english.vocabulary.skill.<form-slug>.<pos-slug>.sense.<synset-or-local>

# example
english.vocabulary.skill.bank.noun.sense.bank.n.02
```

Parent form+POS nodes **remain**. Sense nodes are children via a soft edge
(e.g. existing `supports` or future `sense_of` filtered by metadata). **No**
`prerequisite_for` from sense structure.

### 4.2 Provenance (required on sense nodes)

```json
{
  "metadata": {
    "identityGrain": "sense",
    "senseInventory": "wordnet",
    "senseInventoryVersion": "3.1",
    "senseId": "bank.n.02",
    "senseGloss": "a financial institution…",
    "parentSkillId": "english.vocabulary.skill.bank.noun",
    "pedagogicalOverride": null
  }
}
```

### 4.3 When not to split

- WordNet unique synset
- Closed-class / titles / letters unless exam gloss requires it
- Product explicitly chooses “form+POS mastery only” for a domain mode

## 5. Migration path (non-breaking)

1. **Phase A (now):** Keep form+POS freeze; WordNet edges only for unique senses;
   ambiguous queue documents split candidates.
2. **Phase B:** Add sense child nodes for reviewed sample (start with 50-sample
   high-frequency multi-synset nouns/verbs). Re-point **new** enrichment only.
3. **Phase C:** App opt-in to assess sense children; parent form+POS remains for
   cumulative exam membership.
4. **Never:** Silent re-key of frozen YLE skill ids without migration map.

Exam `contains` stays on form+POS parents unless a later freeze explicitly
moves membership.

## 6. Schema extension

Additive only:

- New skill nodes with `metadata.identityGrain = "sense"`
- Optional edge metadata `relationshipKind: "sense-child"`
- No removal of form+POS fields
- Validators: core-only graphs still valid without sense children

Compatible with SPECIFICATION domain graph patterns (skills, contains,
supports); does not change kst-srs engine schemas.

## 7. Generator sketch

```text
for each form+POS skill S:
  synsets = WordNet(lemma(S), pos(S))
  if |synsets| <= 1: keep S only
  if |synsets| >= 2:
    enqueue ambiguous OR
    if S has publisher gloss: map gloss→synset (manual/heuristic) create one child
    if reviewed: create sense children for approved synsets only
```

Pseudo-code only; full pipeline is a follow-up implementation track.

## 8. Validation (50-sample)

Artifacts:

- `samples/sense_collisions.md` — 50 stratified forms
- `reports/sense-identity/top200-polysemous-forms.json`
- `reports/sense-identity/sample50.json`
- `reports/sense-identity/phase2-source-eval.json`
- `reports/sense-identity/identity-collapse-characterization.json`

**Characterization:** `bank` has **1** graph noun skill and **10** WordNet noun
synsets → same-POS senses collapse under form+POS.

## 9. Non-goals

- Rewriting the YLE freeze package in place
- Auto-promoting all WordNet senses without review
- Using unlicensed EVP bulk sense levels
- Treating sense edges as mastery prerequisites

## 10. Follow-on

Implementation track (not this design track): sense-child builder, migration
map, app flag for sense-aware SRS.
