# Intro Scene 1 — "The Road" (script)

**Single source for Scene 1** — beats, lines, staging, and notes all live here (`../intro.md`
keeps only a stub and the cross-scene flow). Wins over the JSON
(`data/dialogues/intro/scene_1.json`, currently an empty placeholder). Format conventions:
`README.md`. Voice authority: `../prose_style.md`.

- **Goal:** scale the decay from an anomaly to a generation (war unspoken); put the first crack
  in the player's faith without opening it; carry the rumor against the crown's orders; let
  Fenwick show the wizard half of himself at a hearth.
- **Cast:** `player`, `fenwick`, `elara` (one day's acquaintance now — warmer than Scene 0, still
  measured; knowledge boundaries: `../characters/elara.md`).
- **Staging:** split into two dialogue sequences/scenes on the top-down convention (interiors are
  separate scenes): `intro_scene_1a` plays outdoors on `homestead_exterior.tscn` (ford, yard, and
  camp beats) and ends on Fenwick's relenting line; `intro_scene_1b` opens indoors on
  `homestead_interior.tscn` (hearth beat onward) and carries the scene's closing flag,
  `intro_scene_1`. Placeholder art either way — the painted scenes come later.
- **Choices:** one, flavor only, converges, no effects — the player's footing after the sum.
- **Clean ground:** Scene 0 already paid for the dated infrastructure, the outbound-only traffic,
  Elara's two years, Fenwick the cook, and the roads-grown-dangerous plant. Scene 1 does not
  re-tread any of it. Its new ground is the human cost, the generational scale, the rumor against
  the orders, and the wizard reveal.
- **Flags:** sets `intro_scene_1` at the end.

---

## Beat — Past the ford

[Fade in. Evening. The three come up off the riverbank onto the far road.]

**Fenwick**: The far bank at last. I'd begun to think that ford went on forever.

**Player**: It was knee-deep.

**Fenwick**: For you.

## Beat — The homestead

**Elara**: There is a house off the road ahead. I have sheltered there before. It has sound walls, and
a well that still draws clean water.

[They reach it. The door hangs straight on its hinge; tools are racked along the wall; a kettle
sits by a cold hearth.]

**Player** *(reading the room)*: This place is in finer shape than I expected. It is a shame to see 
it stand abandoned.

**Fenwick**: Why would a body walk away from a place like this? Sound walls, sweet well. Someone
kept it well for years.

**Elara**: A house is only worth its neighbors. When the road empties, the last family on it does
not stay long — no smith, no market, no one to send for when the fever takes a child. Sound walls
will not feed anyone alone.

## Beat — The camp

**Fenwick**: It feels wrong, bedding down in a dead family's house.

**Player**: They're not dead. They're only gone. And a roof's a roof — we'll not find a better one
before dark.

**Fenwick** *(relenting, eyeing the hearth)*: ...No sense letting a good hearth sit cold, I
suppose.

## Beat — The hearth

**Fenwick**: Right. Let us see what this road has earned us.

[He hangs the pot — trail stock, the greens foraged that morning, something folded out of
`elara`'s pack. He snaps his fingers over the cold grate; it takes light. He does not look up
from the pot.]

**Fenwick** *(to `elara`)*: These greens you named this morning. You were right — better than
they've any business being.

**Elara**: Out here you learn the plants or you go hungry. I have eaten worse for lack of knowing.

## Beat — The question

**Player** *(quiet, looking around the room)*: Where do they all go?

**Fenwick**: Hm?

**Player**: The folk who leave. This house, the ones back on the bridge road. Whole families
walking out. Where is it they're all walking to?

## Beat — The scale

**Elara**: West, mostly. Toward the towns. It is the same on every road I run. The farther out you
go, the more houses stand empty, and the longer they have stood that way.

**Player**: This one's been a while. Ten years of dust on that kettle, near enough. Orchard's
gone to sucker.

[Beat.]

**Player** *(not liking the sum)*: The bridge was six years. This house is ten. It's not one bad
stretch of road, Fen. It runs the whole way behind us — and the deeper we go, the older it gets.

[`elara` does not answer. She turns the root in her hands and says nothing.]

**Choice** *(footing; flavor only, converges, no effects — the prompt is the silence after the
player's line)*

1. **"There'll be a reason for it. There always is."**
   - **Fenwick** *(not arguing)*: Mayhap so.
2. **"Something's wrong out here. More than one clerk asleep at his desk."**
   - **Fenwick** *(quiet)*: Aye. That's the part I don't much like.
3. **"We'll have our answers at the post. No sense chasing them in the dark."**
   - **Fenwick**: Spoken like a man who wants his supper.

## Beat — The rumor against the orders

**Elara**: Your post. I know a little more of it than its turn in the road.

**Fenwick**: Go on.

**Elara**: The road says it is not wholly empty. One man holds it — a dwarf, they tell it, the
last of a garrison that marched off eight years past. *(a small shrug)* I have never been through
the gate myself, but I have heard it from more than one mouth.

**Player**: That does not square. These orders are a month old, and they name a standing garrison.
*(unable to reconcile it)* If the last of them marched off eight years past...

**Fenwick**: Then someone wrote our orders from an eight-year-old book.

**Player** *(reaching past it)*: Or the road's got it wrong. We'll see for ourselves by midday.

## Beat — The wizard owned

**Elara** *(evenly)*: I have seen a hearth lit many ways, but never by a snap of the fingers. There
is magic where I come from, in the elven lands. It runs in the blood, or it is coaxed up out of the
wild, from living and growing things. What you did looked like neither.

**Fenwick** *(pleased)*: Ah, that. Academy-trained, I'm afraid. Three years and a diploma to prove
it, though it was evocation I loved best.

**Elara**: An academy. I did not know it could be taught. That is a great deal of schooling for a
pot of soup.

**Fenwick** *(delighted)*: Ah, but that is the whole of it. I am a gastronomancer, and the best use
I ever found for all that schooling was a supper worth sitting down to.

**Fenwick**: But you. An elf, alone, well within the kingdom's borders. That is the stranger tale by far. What sends you out this way?

**Elara** *(smoothly)*: That is a longer tale than the supper will keep. Serve it out,
gastronomancer, and let us see if all that schooling was worth it.

## Beat — Closer

**Fenwick**: I'll take first watch.

**Elara**: Wake me at the turn of the night. We reach the walls by midday, if the road holds. And...
for what it is worth, that was the finest thing I have eaten on this road.

**Fenwick** *(pleased)*: I know.

[Fade out.]

[set intro_scene_1]

---

## Construction notes

- **Divides cleanly from Scene 0.** Scene 0 was the *crown's* abandonment (bridge, detour, dead
  infrastructure); Scene 1 is the *people's* — a house left in good order, not fled. The human
  cost surfaces through Fenwick's plain question (why leave a good place) and Elara's answer (a
  house is only worth its neighbors), not a forensic read. No landscape commentary; that account
  was paid last scene.
- **The crack forms, it does not open.** The player assembles the sum himself out of his own
  dates — bridge six, house ten, deeper is older — and dislikes it, but his frame is still the
  songs. He can hold "someone failed this stretch" and "the crown is what the songs say" at once;
  the post ahead is where he still expects the answer to be. The break is Scene 2's, and the
  whole game's (`../characters/player.md`).
- **Three numbers, never added on screen.** Bridge six (Scene 0), house ten (here), garrison gone
  eight (the rumor). The generational decline and the discrete eight-year recall are deliberately
  kept apart — the decline is "everywhere behind us," the recall is one hearsay event about one
  post. Nobody names the war. An attentive player connects the dates alone.
- **The cantrip is the fuse, not the detonation.** Fenwick lights the hearth unremarked and nobody
  comments in the moment — the game's first magic, spent as a kitchen tool. Elara *saw* it and
  files it; the payoff is her question two beats later. The disownment stays fully buried
  (`../characters/fenwick.md`, heart events) — he plays the diploma as a joke, and the family
  never comes up.
- **Elara's silence is character.** She widens the scale with concrete, road-worn observation
  (every road she runs, the farther out the emptier and longer-abandoned) but offers no *cause* —
  no proverbs, no theories. When the player names the sum she says nothing. Her deflection of
  Fenwick's return question ("a longer tale than the supper will keep") keeps her mystery and her
  warmth both.
- **Crown paper against the land, second instance.** The map was the first (Scene 0); here his
  month-old orders name a "standing garrison" against a one-dwarf rumor. Fenwick names the rot —
  fresh orders written from an eight-year-old record — and the player flinches from it, reaching
  for "the road's got it wrong" and deferring to the post. That flinch (not a confident defense)
  is the trait Scene 2 starts to break; Tharr's unanswered requisitions are the third instance,
  from the other side.
- **"Well within the kingdom's borders" is dramatic irony, not error.** The realm once reached
  this far and farther; the decline has pulled its living border back, but the academy taught the
  old extent as fact, and both Fenwick and the player (academy graduates) take the older teaching
  as true. They believe they are well inside the kingdom because that is what they were taught —
  the receded border is on no map they were given. The decay around them is the evidence against
  the teaching, and they do not connect it yet. Same engine as the stale map (Scene 0) and the
  month-old orders (this scene): crown records describe a kingdom that no longer extends this far.
  Do not "correct" the line to read geographically safer — the gap is the point. (World truth:
  `../world.md`.)
- **Food threads pay off.** The Scene 0 forage question is answered on the plate (Elara made good
  on "come and I will tell you"); something bought off her pack makes her trade real; the closer
  buttons the running soup-and-schooling joke (Elara's honest verdict, Fenwick's "I know"). "Fen"
  stays canon as the player's name for him.
