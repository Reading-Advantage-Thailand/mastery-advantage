# Sense Collisions Sample (50)
Generated: 2026-08-11
Policy: form+POS identity; same-POS senses share one node unless publisher gloss already split the form string.

## Summary
- Sample size: 50
- Forms with multi-skill IDs: 42
- Forms with WordNet synsets ≥2 on some POS: 31
- Forms with publisher gloss in lexicalForm: 12

## Characterization: computeNodeId(form, pos) collapse
Current skills are keyed by normalized form + POS (and optional gloss fragment in the form string for some YLE rows). WordNet-level sense distinctions **within the same POS** are not separate nodes. Example: `bank` noun (financial vs river) is one skill if the inventory stores one noun form.

### Collapse examples
| Form | Graph skill IDs | POS sets | WordNet max synsets | Collapse?
|---|---|---|---:|---|
| bank | 1 ids | [['noun']] | 10 | YES same-POS senses merged |
| bat | 2 ids | [['noun'], ['noun']] | 5 | multi-node (usually multi-POS or gloss split), still may merge senses per POS |
| light | 2 ids | [['adjective', 'noun'], ['adjective', 'noun', 'verb']] | 25 | multi-node (usually multi-POS or gloss split), still may merge senses per POS |
| run | 1 ids | [['verb']] | 41 | YES same-POS senses merged |
| blue | 2 ids | [['adjective'], ['adjective', 'noun']] | 8 | multi-node (usually multi-POS or gloss split), still may merge senses per POS |
| book | 2 ids | [['noun'], ['noun', 'verb']] | 11 | multi-node (usually multi-POS or gloss split), still may merge senses per POS |
| fair | 2 ids | [['adjective'], ['adjective', 'noun']] | 10 | multi-node (usually multi-POS or gloss split), still may merge senses per POS |
| mean | 1 ids | [['verb']] | 7 | YES same-POS senses merged |

## Sample rows (50)

### 1. `on` (zipf≈6.91, wnSynsets≤3, skills=2)
- skillIds: `english.vocabulary.skill.on.adverb-preposition`, `english.vocabulary.skill.on.preposition`
- posSets: [['adverb', 'preposition'], ['preposition']]
- publisherGlossInForm: False
- currentGrouping: form+POS; WordNet senses not split
- WordNet adverb sample senses: along.r.01: with a forward motion | on.r.02: indicates continuity or persistence or concentration | on.r.03: in a state required for something to function or be effectiv

### 2. `be` (zipf≈6.79, wnSynsets≤13, skills=2)
- skillIds: `english.vocabulary.skill.be.auxiliary-verb-verb`, `english.vocabulary.skill.be.verb`
- posSets: [['auxiliary-verb', 'verb'], ['verb']]
- publisherGlossInForm: False
- currentGrouping: form+POS; WordNet senses not split
- WordNet auxiliary-verb sample senses: be.v.01: have the quality of being; (copula, used with an adjective o | be.v.02: be identical to; be someone or something | be.v.03: occupy a certain position or area; be somewhere | exist.v.01: have an existence, be extant | be.v.05: happen, occur, take place …

### 3. `have` (zipf≈6.71, wnSynsets≤19, skills=2)
- skillIds: `english.vocabulary.skill.have.auxiliary-verb-verb`, `english.vocabulary.skill.have.verb`
- posSets: [['auxiliary-verb', 'verb'], ['verb']]
- publisherGlossInForm: False
- currentGrouping: form+POS; WordNet senses not split
- WordNet auxiliary-verb sample senses: have.v.01: have or possess, either in a concrete or an abstract sense | have.v.02: have as a feature | experience.v.03: go through (mental or physical states or experiences) | own.v.01: have ownership or possession of | get.v.03: cause to move; cause to be in a certain position or conditio …

### 4. `so` (zipf≈6.52, wnSynsets≤10, skills=2)
- skillIds: `english.vocabulary.skill.so.adverb-conjunction`, `english.vocabulary.skill.so.discourse-marker`
- posSets: [['adverb', 'conjunction'], ['discourse-marker']]
- publisherGlossInForm: False
- currentGrouping: form+POS; WordNet senses not split
- WordNet adverb sample senses: so.r.01: to a very great extent or degree | so.r.02: in a manner that facilitates | so.r.03: in such a condition or manner, especially as expressed or im | so.r.04: to a certain unspecified extent or degree | so.r.05: in the same way; also …

### 5. `will` (zipf≈6.45, wnSynsets≤3, skills=3)
- skillIds: `english.vocabulary.skill.will.modal-verb`, `english.vocabulary.skill.will.verb`, `english.vocabulary.skill.will-ll.modal-verb`
- posSets: [['modal-verb'], ['verb'], ['modal-verb']]
- publisherGlossInForm: True
- currentGrouping: form+POS; WordNet senses not split
- WordNet modal-verb sample senses: will.v.01: decree or ordain | will.v.02: determine by choice | bequeath.v.01: leave or give by will after one's death

### 6. `just` (zipf≈6.43, wnSynsets≤6, skills=1)
- skillIds: `english.vocabulary.skill.just.adverb`
- posSets: [['adverb']]
- publisherGlossInForm: False
- currentGrouping: form+POS; WordNet senses not split
- WordNet adverb sample senses: merely.r.01: and nothing more | precisely.r.01: indicating exactness or preciseness | just.r.03: only a moment ago | just.r.04: absolutely | barely.r.01: only a very short time before; ; ; ; ; - W.B.Yeats …

### 7. `like` (zipf≈6.41, wnSynsets≤5, skills=2)
- skillIds: `english.vocabulary.skill.like.adverb-preposition-verb`, `english.vocabulary.skill.like.preposition-verb`
- posSets: [['adverb', 'preposition', 'verb'], ['preposition', 'verb']]
- publisherGlossInForm: False
- currentGrouping: form+POS; WordNet senses not split
- WordNet verb sample senses: wish.v.02: prefer or wish to do something | like.v.02: find enjoyable or agreeable | like.v.03: be fond of | like.v.04: feel about or towards; consider, evaluate, or regard | like.v.05: want to have

### 8. `about` (zipf≈6.4, wnSynsets≤7, skills=2)
- skillIds: `english.vocabulary.skill.about.adverb-preposition`, `english.vocabulary.skill.about.preposition`
- posSets: [['adverb', 'preposition'], ['preposition']]
- publisherGlossInForm: False
- currentGrouping: form+POS; WordNet senses not split
- WordNet adverb sample senses: approximately.r.01: (of quantities) imprecise but fairly close to correct | about.r.02: all around or on all sides | about.r.03: in the area or vicinity | about.r.04: used of movement to or among many different places or in no  | about.r.05: in or to a reversed position or direction …

### 9. `up` (zipf≈6.39, wnSynsets≤5, skills=1)
- skillIds: `english.vocabulary.skill.up.adverb-preposition`
- posSets: [['adverb', 'preposition']]
- publisherGlossInForm: False
- currentGrouping: form+POS; WordNet senses not split
- WordNet adverb sample senses: up.r.01: spatially or metaphorically from a lower to a higher positio | up.r.02: to a higher intensity | up.r.03: nearer to the speaker | up.r.04: to a more central or a more northerly place | up.r.05: to a later time

### 10. `out` (zipf≈6.38, wnSynsets≤3, skills=1)
- skillIds: `english.vocabulary.skill.out.adverb`
- posSets: [['adverb']]
- publisherGlossInForm: False
- currentGrouping: form+POS; WordNet senses not split
- WordNet adverb sample senses: out.r.01: away from home | out.r.02: moving or appearing to move away from a place, especially on | away.r.02: from one's possession

### 11. `do` (zipf≈6.35, wnSynsets≤13, skills=2)
- skillIds: `english.vocabulary.skill.do.auxiliary-verb-verb`, `english.vocabulary.skill.do.verb`
- posSets: [['auxiliary-verb', 'verb'], ['verb']]
- publisherGlossInForm: False
- currentGrouping: form+POS; WordNet senses not split
- WordNet auxiliary-verb sample senses: make.v.01: engage in | perform.v.01: carry out or perform an action | do.v.03: get (something) done | do.v.04: proceed or get along | cause.v.01: give rise to; cause to happen or occur, not always intention …

### 12. `no` (zipf≈6.35, wnSynsets≤3, skills=2)
- skillIds: `english.vocabulary.skill.no.adverb-determiner`, `english.vocabulary.skill.no.adverb-determiner-pronoun`
- posSets: [['adverb', 'determiner'], ['adverb', 'determiner', 'pronoun']]
- publisherGlossInForm: False
- currentGrouping: form+POS; WordNet senses not split
- WordNet adverb sample senses: no.r.01: referring to the degree to which a certain quality is presen | no.r.02: not in any degree or manner; not at all | no.r.03: used to express refusal or denial or disagreement etc or esp

### 13. `there` (zipf≈6.31, wnSynsets≤3, skills=1)
- skillIds: `english.vocabulary.skill.there.adverb`
- posSets: [['adverb']]
- publisherGlossInForm: False
- currentGrouping: form+POS; WordNet senses not split
- WordNet adverb sample senses: there.r.01: in or at that place | there.r.02: in that matter | there.r.03: to or toward that place; away from the speaker

### 14. `time` (zipf≈6.29, wnSynsets≤10, skills=2)
- skillIds: `english.vocabulary.skill.time.noun`, `english.vocabulary.skill.time.noun-verb`
- posSets: [['noun'], ['noun', 'verb']]
- publisherGlossInForm: False
- currentGrouping: form+POS; WordNet senses not split
- WordNet noun sample senses: time.n.01: an instance or single occasion for some event | time.n.02: a period of time considered as a resource under your control | time.n.03: an indefinite period (usually marked by specific attributes  | time.n.04: a suitable moment | time.n.05: the continuum of experience in which events pass from the fu …

### 15. `get` (zipf≈6.28, wnSynsets≤36, skills=1)
- skillIds: `english.vocabulary.skill.get.verb`
- posSets: [['verb']]
- publisherGlossInForm: False
- currentGrouping: form+POS; WordNet senses not split
- WordNet verb sample senses: get.v.01: come into the possession of something concrete or abstract | become.v.01: enter or assume a certain state or condition | get.v.03: cause to move; cause to be in a certain position or conditio | receive.v.02: receive a specified treatment (abstract) | arrive.v.01: reach a destination; arrive by movement or progress …

### 16. `new` (zipf≈6.25, wnSynsets≤11, skills=1)
- skillIds: `english.vocabulary.skill.new.adjective`
- posSets: [['adjective']]
- publisherGlossInForm: False
- currentGrouping: form+POS; WordNet senses not split
- WordNet adjective sample senses: new.a.01: not of long duration; having just (or relatively recently) c | fresh.s.03: original and of a kind not seen before | raw.s.11: lacking training or experience | new.s.03: having no previous example or precedent or parallel | new.s.04: other than the former one(s); different …

### 17. `people` (zipf≈6.25, wnSynsets≤4, skills=2)
- skillIds: `english.vocabulary.skill.people.noun`, `english.vocabulary.skill.person-people.noun`
- posSets: [['noun'], ['noun']]
- publisherGlossInForm: False
- currentGrouping: form+POS; WordNet senses not split
- WordNet noun sample senses: people.n.01: (plural) any group of human beings (men or women or children | citizenry.n.01: the body of citizens of a state or country | people.n.03: members of a family line | multitude.n.03: the common people generally

### 18. `now` (zipf≈6.18, wnSynsets≤7, skills=1)
- skillIds: `english.vocabulary.skill.now.adverb`
- posSets: [['adverb']]
- publisherGlossInForm: False
- currentGrouping: form+POS; WordNet senses not split
- WordNet adverb sample senses: now.r.01: in the historical present; at this point in the narration of | nowadays.r.01: in these times; - Nancy Mitford | now.r.03: used to preface a command or reproof or request | now.r.04: at the present moment | immediately.r.01: without delay or hesitation; with no time intervening …

### 19. `other` (zipf≈6.16, wnSynsets≤4, skills=2)
- skillIds: `english.vocabulary.skill.other.adjective-determiner-pronoun`, `english.vocabulary.skill.other.determiner-pronoun`
- posSets: [['adjective', 'determiner', 'pronoun'], ['determiner', 'pronoun']]
- publisherGlossInForm: False
- currentGrouping: form+POS; WordNet senses not split
- WordNet adjective sample senses: other.a.01: not the same one or ones already mentioned or implied; - the | other.s.01: recently past | early.s.01: belonging to the distant past | other.s.03: very unusual; different in character or quality from the nor

### 20. `good` (zipf≈6.12, wnSynsets≤21, skills=1)
- skillIds: `english.vocabulary.skill.good.adjective`
- posSets: [['adjective']]
- publisherGlossInForm: False
- currentGrouping: form+POS; WordNet senses not split
- WordNet adjective sample senses: good.a.01: having desirable or positive qualities especially those suit | full.s.04: having the normally expected amount | good.a.03: morally admirable | estimable.s.01: deserving of esteem and respect | beneficial.s.01: promoting or enhancing well-being …

### 21. `a` (zipf≈7.36, wnSynsets≤0, skills=2)
- skillIds: `english.vocabulary.skill.a.determiner`, `english.vocabulary.skill.a-an.determiner`
- posSets: [['determiner'], ['determiner']]
- publisherGlossInForm: False
- currentGrouping: form+POS; WordNet senses not split

### 22. `in` (zipf≈7.27, wnSynsets≤1, skills=2)
- skillIds: `english.vocabulary.skill.in.adverb-preposition`, `english.vocabulary.skill.in.preposition`
- posSets: [['adverb', 'preposition'], ['preposition']]
- publisherGlossInForm: False
- currentGrouping: form+POS; WordNet senses not split

### 23. `that` (zipf≈7.01, wnSynsets≤0, skills=3)
- skillIds: `english.vocabulary.skill.that.conjunction-determiner-pronoun`, `english.vocabulary.skill.that.conjunction-pronoun`, `english.vocabulary.skill.that.determiner-pronoun`
- posSets: [['conjunction', 'determiner', 'pronoun'], ['conjunction', 'pronoun'], ['determiner', 'pronoun']]
- publisherGlossInForm: False
- currentGrouping: form+POS; WordNet senses not split

### 24. `it` (zipf≈6.95, wnSynsets≤1, skills=3)
- skillIds: `english.vocabulary.skill.it.noun`, `english.vocabulary.skill.it.pronoun`, `english.vocabulary.skill.it-information-technology.noun`
- posSets: [['noun'], ['pronoun'], ['noun']]
- publisherGlossInForm: True
- currentGrouping: form+POS; WordNet senses not split

### 25. `as` (zipf≈6.77, wnSynsets≤1, skills=3)
- skillIds: `english.vocabulary.skill.as.adverb`, `english.vocabulary.skill.as.adverb-conjunction-preposition`, `english.vocabulary.skill.as.conjunction-preposition`
- posSets: [['adverb'], ['adverb', 'conjunction', 'preposition'], ['conjunction', 'preposition']]
- publisherGlossInForm: False
- currentGrouping: form+POS; WordNet senses not split

### 26. `but` (zipf≈6.63, wnSynsets≤0, skills=2)
- skillIds: `english.vocabulary.skill.but.conjunction`, `english.vocabulary.skill.but.conjunction-preposition`
- posSets: [['conjunction'], ['conjunction', 'preposition']]
- publisherGlossInForm: False
- currentGrouping: form+POS; WordNet senses not split

### 27. `my` (zipf≈6.57, wnSynsets≤0, skills=2)
- skillIds: `english.vocabulary.skill.my.determiner`, `english.vocabulary.skill.my.possessive-adjective`
- posSets: [['determiner'], ['possessive-adjective']]
- publisherGlossInForm: False
- currentGrouping: form+POS; WordNet senses not split

### 28. `your` (zipf≈6.53, wnSynsets≤0, skills=2)
- skillIds: `english.vocabulary.skill.your.determiner`, `english.vocabulary.skill.your.possessive-adjective`
- posSets: [['determiner'], ['possessive-adjective']]
- publisherGlossInForm: False
- currentGrouping: form+POS; WordNet senses not split

### 29. `all` (zipf≈6.52, wnSynsets≤2, skills=2)
- skillIds: `english.vocabulary.skill.all.adjective-adverb-determiner-pronoun`, `english.vocabulary.skill.all.adverb-determiner-pronoun`
- posSets: [['adjective', 'adverb', 'determiner', 'pronoun'], ['adverb', 'determiner', 'pronoun']]
- publisherGlossInForm: False
- currentGrouping: form+POS; WordNet senses not split
- WordNet adjective sample senses: all.a.01: quantifier; used with either mass or count nouns to indicate | all.s.01: completely given to or absorbed by

### 30. `his` (zipf≈6.51, wnSynsets≤0, skills=2)
- skillIds: `english.vocabulary.skill.his.determiner-pronoun`, `english.vocabulary.skill.his.possessive-adjective-pronoun`
- posSets: [['determiner', 'pronoun'], ['possessive-adjective', 'pronoun']]
- publisherGlossInForm: False
- currentGrouping: form+POS; WordNet senses not split

### 31. `can` (zipf≈6.46, wnSynsets≤2, skills=2)
- skillIds: `english.vocabulary.skill.can.modal-verb-noun`, `english.vocabulary.skill.can.verb`
- posSets: [['modal-verb', 'noun'], ['verb']]
- publisherGlossInForm: False
- currentGrouping: form+POS; WordNet senses not split
- WordNet modal-verb sample senses: can.v.01: preserve in a can or tin | displace.v.03: terminate the employment of; discharge from an office or pos

### 32. `what` (zipf≈6.38, wnSynsets≤0, skills=2)
- skillIds: `english.vocabulary.skill.what.determiner-pronoun`, `english.vocabulary.skill.what.interrogative`
- posSets: [['determiner', 'pronoun'], ['interrogative']]
- publisherGlossInForm: False
- currentGrouping: form+POS; WordNet senses not split

### 33. `when` (zipf≈6.37, wnSynsets≤0, skills=2)
- skillIds: `english.vocabulary.skill.when.adverb`, `english.vocabulary.skill.when.adverb-conjunction-interrogative`
- posSets: [['adverb'], ['adverb', 'conjunction', 'interrogative']]
- publisherGlossInForm: False
- currentGrouping: form+POS; WordNet senses not split

### 34. `more` (zipf≈6.36, wnSynsets≤2, skills=2)
- skillIds: `english.vocabulary.skill.more.adjective-adverb-determiner-pronoun`, `english.vocabulary.skill.more.adverb-determiner-pronoun`
- posSets: [['adjective', 'adverb', 'determiner', 'pronoun'], ['adverb', 'determiner', 'pronoun']]
- publisherGlossInForm: False
- currentGrouping: form+POS; WordNet senses not split
- WordNet adjective sample senses: more.a.01: (comparative of `much' used with mass nouns) a quantifier me | more.a.02: (comparative of `many' used with count nouns) quantifier mea

### 35. `who` (zipf≈6.34, wnSynsets≤0, skills=2)
- skillIds: `english.vocabulary.skill.who.interrogative`, `english.vocabulary.skill.who.pronoun`
- posSets: [['interrogative'], ['pronoun']]
- publisherGlossInForm: False
- currentGrouping: form+POS; WordNet senses not split

### 36. `could` (zipf≈6.06, wnSynsets≤0, skills=3)
- skillIds: `english.vocabulary.skill.could.modal-verb`, `english.vocabulary.skill.could-for-possibility.verb`, `english.vocabulary.skill.could-as-in-past-of-can-for-ability.verb`
- posSets: [['modal-verb'], ['verb'], ['verb']]
- publisherGlossInForm: True
- currentGrouping: form+POS; WordNet senses not split

### 37. `go` (zipf≈6.03, wnSynsets≤30, skills=3)
- skillIds: `english.vocabulary.skill.go.noun-verb`, `english.vocabulary.skill.go.verb`, `english.vocabulary.skill.go-with-together.phrasal-verb`
- posSets: [['noun', 'verb'], ['verb'], ['phrasal-verb']]
- publisherGlossInForm: True
- currentGrouping: form+POS; WordNet senses not split
- WordNet noun sample senses: go.n.01: a time for working (after which you will be relieved by some | adam.n.03: street names for methylenedioxymethamphetamine | crack.n.09: a usually brief attempt | go.n.04: a board game for two players who place counters on a grid; t

### 38. `may` (zipf≈5.98, wnSynsets≤2, skills=4)
- skillIds: `english.vocabulary.skill.may.modal-verb`, `english.vocabulary.skill.may.noun`, `english.vocabulary.skill.may.verb`, `english.vocabulary.skill.may-as-in-girls-name.noun`
- posSets: [['modal-verb'], ['noun'], ['verb'], ['noun']]
- publisherGlossInForm: True
- currentGrouping: form+POS; WordNet senses not split
- WordNet noun sample senses: may.n.01: the month following April and preceding June | whitethorn.n.01: thorny Eurasian shrub of small tree having dense clusters of

### 39. `right` (zipf≈5.96, wnSynsets≤14, skills=5)
- skillIds: `english.vocabulary.skill.right.adjective`, `english.vocabulary.skill.right.adjective-adverb-noun`, `english.vocabulary.skill.right.discourse-marker`, `english.vocabulary.skill.right-as-in-correct.adjective`, `english.vocabulary.skill.right-as-in-direction.noun`
- posSets: [['adjective'], ['adjective', 'adverb', 'noun'], ['discourse-marker'], ['adjective'], ['noun']]
- publisherGlossInForm: True
- currentGrouping: form+POS; WordNet senses not split
- WordNet adjective sample senses: right.a.01: being or located on or directed toward the side of the body  | correct.a.01: free from error; especially conforming to fact or truth | correct.s.01: socially right or correct | right.a.04: in conformance with justice or law or morality | right.a.05: correct in opinion or judgment …

### 40. `take` (zipf≈5.92, wnSynsets≤42, skills=2)
- skillIds: `english.vocabulary.skill.take.verb`, `english.vocabulary.skill.take-as-in-time-e-g-it-takes-20-minutes.verb`
- posSets: [['verb'], ['verb']]
- publisherGlossInForm: True
- currentGrouping: form+POS; WordNet senses not split
- WordNet verb sample senses: take.v.01: carry out | take.v.02: require (time or space) | lead.v.01: take somebody somewhere | take.v.04: get into one's hands, take physically | assume.v.03: take on a certain form, attribute, or aspect …

### 41. `left` (zipf≈5.62, wnSynsets≤4, skills=2)
- skillIds: `english.vocabulary.skill.left.adjective-adverb-noun`, `english.vocabulary.skill.left-as-in-direction.adjective-noun`
- posSets: [['adjective', 'adverb', 'noun'], ['adjective', 'noun']]
- publisherGlossInForm: True
- currentGrouping: form+POS; WordNet senses not split
- WordNet adjective sample senses: left.a.01: being or located on or directed toward the side of the body  | leftover.s.01: not used up | left.s.02: intended for the left hand | left.a.04: of or belonging to the political or intellectual left

### 42. `among` (zipf≈5.31, wnSynsets≤0, skills=2)
- skillIds: `english.vocabulary.skill.among.preposition`, `english.vocabulary.skill.among-amongst.preposition`
- posSets: [['preposition'], ['preposition']]
- publisherGlossInForm: True
- currentGrouping: form+POS; WordNet senses not split

### 43. `program` (zipf≈5.27, wnSynsets≤8, skills=3)
- skillIds: `english.vocabulary.skill.program.noun`, `english.vocabulary.skill.program-me.noun`, `english.vocabulary.skill.programme-us-program.noun`
- posSets: [['noun'], ['noun'], ['noun']]
- publisherGlossInForm: True
- currentGrouping: form+POS; WordNet senses not split
- WordNet noun sample senses: plan.n.01: a series of steps to be carried out or goals to be accomplis | program.n.02: a system of projects or services intended to meet a public n | broadcast.n.02: a radio or television show | platform.n.02: a document stating the aims and principles of a political pa | program.n.05: an announcement of the events that will occur as part of a t …

### 44. `instead` (zipf≈5.24, wnSynsets≤2, skills=2)
- skillIds: `english.vocabulary.skill.instead.adverb`, `english.vocabulary.skill.instead-of.adverb`
- posSets: [['adverb'], ['adverb']]
- publisherGlossInForm: True
- currentGrouping: form+POS; WordNet senses not split
- WordNet adverb sample senses: alternatively.r.01: in place of, or as an alternative to | rather.r.01: on the contrary

### 45. `date` (zipf≈5.22, wnSynsets≤8, skills=3)
- skillIds: `english.vocabulary.skill.date.noun`, `english.vocabulary.skill.date.noun-verb`, `english.vocabulary.skill.date-as-in-time.noun`
- posSets: [['noun'], ['noun', 'verb'], ['noun']]
- publisherGlossInForm: True
- currentGrouping: form+POS; WordNet senses not split
- WordNet noun sample senses: date.n.01: the specified day of the month | date.n.02: a participant in a date | date.n.03: a meeting arranged in advance | date.n.04: a particular but unspecified point in time | date.n.05: the present …

### 46. `their` (zipf≈6.33, wnSynsets≤0, skills=2)
- skillIds: `english.vocabulary.skill.their.determiner`, `english.vocabulary.skill.their.possessive-adjective`
- posSets: [['determiner'], ['possessive-adjective']]
- publisherGlossInForm: False
- currentGrouping: form+POS; WordNet senses not split

### 47. `her` (zipf≈6.3, wnSynsets≤0, skills=2)
- skillIds: `english.vocabulary.skill.her.determiner-pronoun`, `english.vocabulary.skill.her.possessive-adjective-pronoun`
- posSets: [['determiner', 'pronoun'], ['possessive-adjective', 'pronoun']]
- publisherGlossInForm: False
- currentGrouping: form+POS; WordNet senses not split

### 48. `which` (zipf≈6.3, wnSynsets≤0, skills=3)
- skillIds: `english.vocabulary.skill.which.determiner-pronoun`, `english.vocabulary.skill.which.interrogative`, `english.vocabulary.skill.which.pronoun`
- posSets: [['determiner', 'pronoun'], ['interrogative'], ['pronoun']]
- publisherGlossInForm: False
- currentGrouping: form+POS; WordNet senses not split

### 49. `would` (zipf≈6.27, wnSynsets≤0, skills=2)
- skillIds: `english.vocabulary.skill.would.modal-verb`, `english.vocabulary.skill.would.verb`
- posSets: [['modal-verb'], ['verb']]
- publisherGlossInForm: False
- currentGrouping: form+POS; WordNet senses not split

### 50. `how` (zipf≈6.24, wnSynsets≤0, skills=2)
- skillIds: `english.vocabulary.skill.how.adverb`, `english.vocabulary.skill.how.interrogative`
- posSets: [['adverb'], ['interrogative']]
- publisherGlossInForm: False
- currentGrouping: form+POS; WordNet senses not split
