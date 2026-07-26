# Bulwark — Opening Cutscene

Three-scene intro sequence before gameplay. Short, character-driven, establishes the mission
and the cast. Longer worldbuilding comes through gameplay journals and notes, not front-loaded
exposition.

This file is a beat outline, not a script. Each scene lists what happens and why. Dialogue is
written by hand from these beats; nothing here is final lines. **Once a scene is scripted, its
section here collapses to a stub and the script in `story/` becomes the single source** — beats,
lines, staging, and notes live there and only there, so each scene has exactly one place to
edit. Unscripted scenes keep their full beat outlines here until their script exists.

**The player speaks during the opening cutscene.** The intro needs a real conversational
presence — Fenwick needs a straight man, Elara needs someone to spar with. Once the cutscene
ends and gameplay begins, the player shifts to silent protagonist (choices only, Stardew-style).
Choices during the cutscene are still expressive and varied.

**Influences**: Sanderson (natural flow, characters who listen and react, wit from the
situation not from cleverness), Rothfuss (rhythm, precision, banter that feels musical), and
the Ivalician register defined in `prose_style.md` (elevated but never stiff).
 
The frontier has been declining for a *generation*: the crown
  pulling back over decades, trade thinning, roads and settlements failing. That is the wide
  backdrop. Separately, *this outpost's* garrison was recalled **eight years ago** — one recent,
  specific event, and the reason Tharr is alone. Never collapse the generational decline into the
  eight-year mark.

## Voice guide

Per-character register — sentence shape, contraction rate, archaism, oaths — lives in
`prose_style.md` under **Per-character register**. That table is authoritative; it is not
restated here, so the two cannot drift. What follows is only the ensemble dynamic particular to
the intro.

- **Player** is the straight man: a farmhand's eye for the land, a soldier's economy with words,
  the one who names what is in front of them. Sets up Fenwick's warmth and Elara's wit.
- **Fenwick** carries the talk and earns it. Wizard-college educated, cheerful, self-deprecating,
  forever steering back toward food. He is good company, which is the point of him.
- **Elara** answers the questions she finds interesting and redirects the ones she does not.
  Decades older than the humans, never flustered, parcels out what she knows at her own pace —
  and a newcomer here all the same: two years on the frontier is nothing to an elf, and she is
  honest about the edges of what she knows.
- **Tharr** speaks least. His relief at company shows in what he does not say.

## Flow

```
New Game → [Name Entry] → Scene 0 (road) → Scene 1 (road) → Scene 2 (outpost) → Gameplay
```

Each scene is a dialogue sequence. Scene 0 and 1 play on a simple road scene (user-painted
later; placeholder = dark background with character sprites). Scene 2 plays on the outpost map
with a cutscene flag active (Tharr walks out, dialogue, then player gets control).

Story flags set: `intro_scene_0`, `intro_scene_1`, `intro_complete`. A returning save with
`intro_complete` already set skips the whole intro.

---

## Scene 0 — "The Frontier"

**Scripted — `story/intro_scene_0.md` is the single source** for this scene's beats, lines,
staging, and notes. Nothing about Scene 0 is maintained here. In brief, for cross-scene
reference: the pair meet the dead bridge (first exposure to the decay, filed innocently), Elara
hails them as a merchant on the road and joins for mutual benefit, and the three exit
mid-conversation onto the detour track. Sets `intro_scene_0`. The war, the garrison recall, the
eight years, the generational scale, and the wizard reveal all stay out of it — Scene 1 cargo.

---

## Scene 1 — "The Road"

*Evening past the ford. The three camp in an abandoned homestead off the road; supper at a dead
family's hearth. Placeholder staging: dark background with sprites; the homestead scene is
painted later (focal setting: homestead interior or yard at firelight, tools still racked on
the wall).*

**Goal:** Scale the decay from an anomaly to a generation (war unspoken), put the first crack in
the player's faith without opening it, foreshadow Tharr against the orders, and let Fenwick
reveal the wizard half of himself at a hearth.

Scene 0 already covered: dated infrastructure decay (bridge, detour, ditches), outbound-only
traffic, Elara's two years, Fenwick the cook, and the roads-grown-dangerous plant. Scene 1 does
not re-tread any of it. Its clean ground: the human cost, the generational scale, the rumor
against the orders, the wizard reveal.

### Beats

- Open past the ford, late day; the crossing itself is skipped offscreen and acknowledged in one
  line (Fenwick's boots, drowned a second time). The rhythm is eased — banter, not wariness. No
  landscape commentary; that account was paid in Scene 0.
- The homestead: door on its hinge, tools racked, a kettle left behind. The player reads it with
  the farmhand's eye — left in order, not in flight. Nobody drove them out; they quit. Scene 0
  showed what the crown abandoned; this is what the people abandoned.
- Camp decision: light failing, sound walls, a working well. Fenwick uneasy about using a dead
  family's house; the player practical about it. Small and tonal, not logistical.
- Fenwick takes the hearth: supper built from trail stock, the Scene 0 forage (payoff), and
  something bought off Elara's pack (her trade made real). He lights the cold hearth with a
  flick of cantrip, unremarked — the game's first magic, spent casually. The reveal's fuse, not
  its detonation.
- The question, asked at that hearth: not "what happened here" — they have walked the answer for
  days — but the people. Where does everyone go? How long has this land been emptying?
- The scale, assembled: Elara widens it — every road she has walked in two years, the same, and
  the deeper her circuits run, the older the abandonment gets. The player adds one new date
  (this homestead: a decade, thereabouts) and does not like the sum. The retreat is a generation
  long; no one says so in as many words, no one names the war, and Elara conspicuously offers no
  causes. Her silence is character, not omission.
- **The player does not conclude the kingdom is in decay.** His frame is still the songs; he can
  hold "someone failed this stretch" and "the crown is what the songs say" at once. The outpost
  ahead is where he expects the answer to be, not where he expects the evidence to worsen. The
  crack forms from his own arithmetic; it does not open here.
- *Player choice (flavor):* his footing after the sum — defend the crown's reasons, voice a
  first doubt, or set it aside until the post. Converges. No mechanical effect.
- The rumor against the orders: Elara relays what the road says of their destination — not
  empty; one dwarf holds it, the last of a garrison that marched off **eight years ago** (the
  discrete recent event, held apart from the generational decline above). Hearsay, and she
  prices it as hearsay — she has never been through the gate. Fenwick fetches the orders and
  reads the line that calls the post manned. The gap opens on screen: one stubborn dwarf is not
  a garrison. The player's footing is the paper's — orders are official, rumors are rumors.
  Trusting crown paper is the trait Scene 2 starts to break. (Crown paper against the land,
  second instance: the map was the first; Tharr's unanswered requisitions in Scene 2 are the
  third, from the other side.)
- The wizard owned: Elara asks the question she finds interesting — she watched him light a
  hearth with no flint. Academy-trained, kitchen-called, the self-coined gastronomancer, and
  delighted about it. The disownment stays fully buried (heart events, much later). He returns
  the curiosity — what sends an elf past the edge of the maps? — and she declines it smoothly.
  Her pattern established, her mystery kept.
- Closer: a watch set in one line (keeps Scene 0's danger plant warm, spends nothing — the howl
  belongs to the Day-1 close, not here). Elara: walls by midday. Cool final beat on the player —
  the racked tools, the orders in his pack that say the frontier is fine — and fade. (Optional
  wordless gesture if staging allows: he rehangs a fallen tool.)

---

## Scene 2 — "The Outpost"

*The three reach the outpost for the first time — worse than expected but standing, and worked
by one pair of hands. The gate is freshly damaged: the dire wolf and its pack attacked a few
nights past, and Tharr is at the gate repairing it when they arrive. Plays on the outpost map
with the cutscene flag active.*

**Goal:** Land the gap between the garrison they were promised and the ruin they find, introduce
Tharr through his work, make the forest's danger present tense (the wolf thread starts here),
and turn the mission from "reinforce a garrison" into "rebuild this place." Hand the player
control.

### Beats

- The approach: the outpost from the road, standing and wrong. The player's farmhand eye reads
  **two ages of damage** — years of patient patches on the walls (one pair of hands, the rumor
  confirmed by masonry before Tharr says a word), and the gate splintered *fresh*. Claw-work,
  days old, too high and too broad. Wolves do not come at walls; he knows it and says so.
  Hammering from the gate itself — work, not battle.
- Tharr is at the gate, repairing it. He finishes setting the brace before he turns — character
  through action, his register throughout (5–8 words, declarative, stone). He counts them.
  Three. That is the greeting.
- The attack, named flat: wolves, a few nights past, a pack with a great one leading it, come
  out of the deep wood. Eight years and they never pressed the walls before. He held; the gate
  wants timber. They will come again — stated as fact, not fear. (Elara's one measured line
  ties her two years of road-talk to the claw-marks: the teeth she kept hearing about. Fenwick's
  cheer audibly strains. Nobody names the beast beyond "the big one"; the dire wolf gets its
  name later — `design/tutorial_quests.md`.)
- The paper beat (crown paper #3): the player, by the book, reports formally — to the commander
  of the post, per orders — and hands them over. The commander of record is a mason who never
  wanted command, saluted by a farm boy in academy kit. Tharr answers their paper with his own
  arithmetic: eight years of requisitions, filed and unanswered — he asked for a garrison and a
  mason's crew, and the count of his askings comes out flat. Their orders promised a garrison;
  his requisitions begged for one; both were fiction. The forest sent its answer before the
  crown sent theirs. His relief at company stays unvoiced — it shows only in the fact that he
  keeps talking.
- Introductions, triangled: Fenwick asks after the hearth and kitchen before his own bunk —
  absurd and exactly right; Tharr's response is minimal and not unkind. Elara names herself a
  trader; her eye has already found the ruined trading post, and one measured question — what
  happened to the post's trader? — does double duty: the post had a life once, and her settle
  arc gets its seed. No announcement; the look is the whole beat.
- *Player choice (flavor):* how he answers Tharr's read of them. Converges; no mechanical
  effect. Options carry the faith gradient: defend the crown ("more will come — the ministries
  answered late, not never," and Tharr's silence is its own reply, sharper now against fresh
  claw-marks), own the shortfall ("we are what was sent; best make us count"), or turn it
  around and ask what the post needs first.
- The survey: Tharr names the state of the place — walls breached, fields gone to seed, the
  forest closer every season. After the gate, that is no longer metaphor. The one line he has
  earned: the foundation holds. He has seen to that.
- The turn: the player, still by the book, asks for orders. Tharr does not give orders — he
  never wanted command and does not pretend to it now. He offers work. The mission reframes on
  screen: not reinforcing a garrison — rebuilding a bulwark (the word itself goes unsaid). The
  player accepts, plainly. His faith does not break here: he files all of it as clerical
  failure, and the acceptance is resolve, not disillusionment.
- The gate: they pass through it, Tharr last. His care surfaces the only way it can — one gruff
  caretaking line about the fresh brace as they enter. Inside, one held beat on Elara seeing
  the interior for the first time (all three are; her look is the one that lingers). Fade.
  Flag: `intro_complete`.

**Scene 2 must not:** have Tharr narrate the recall history (Scene 1's rumor carried the facts;
he confirms in one line at most — recalled eight years past; he stayed), open the Elderwood
lore beyond "out of the deep wood," break the player's faith, let Elara announce staying, or
surface Fenwick's disownment.

**Gameplay seam (decided):** the intro does not chain straight into another dialogue. The
cutscene ends, control lands, and the quest prompt appears — "Repair the Lodging," with a
talk-marker on Tharr — but the Day-1 gather *dialogue* fires only when the player walks to
Tharr and interacts. Teaches move + interact with zero tutorial text, sets the
quests-come-from-talking pattern, and the frozen Day-1 clock makes exploring first free.
`design/tutorial.md` already implements this shape (Day 1, Step 1: Talk to Tharr).

---

# Story cutscenes (post-intro)

These are in-world dialogue-box sequences that fire during play, not part of the opening road
cutscene. They follow the same JSON/dialogue-box pattern as the intro scenes and use the same
voice guide above (plus Arkus below). They belong to the early-game progression rework
(`design/tutorial.md`, `design/tutorial_quests.md`). Same treatment: beats only, dialogue written
by hand.

**Arkus's voice** (see `design/characters/arkus.md`): blunt orc honesty. Says exactly what they
think, no softening, no cruelty intended. Short, plain sentences. States problems as facts and
expects the same in return. Underneath the bluntness is someone who cares more than they know how
to show.

---

## Day-1 gather — "The Axe and the Pick"

*The quest prompt appears the moment the player gains control after intro Scene 2 (talk-marker
on Tharr); the dialogue itself fires on the player's first interact with him — see the decided
gameplay seam under Scene 2. Day 1's clock stays frozen for this whole loop — no time passes
until the lodging is repaired, and the clock UI panel is hidden entirely for all of Day 1. This
is the first directed quest and the tutorial for the gather loop and for combat.*

**Goal:** Put tools in the player's hands, send them into the near forest for the first repair
materials, and stage the game's first fight.

### Beats

- Tharr hands the player the outpost's spare axe and pick. First thing the place needs is timber
  and stone; nothing else can start until the walls and lodging have material.
- He points them at the near forest (the Thornwood) and names the objective: bring back enough
  wood and stone to mend the lodging.
- The player takes the party out on its first expedition and learns the gather loop — chopping
  timber, breaking stone — in the safe near forest.
- The trip triggers the **first combat encounter**: something in the Thornwood the party must
  fight. This is the game's tutorial fight and teaches the PF2e combat basics. (Enemy and
  encounter specifics live in `design/tutorial.md` / `design/tutorial_quests.md`. Natural
  candidate after the Scene 2 gate attack: wolves of the same pack — the thread stays warm and
  the dire wolf itself stays offscreen.)
- With the fight won and the materials gathered, the party returns to the outpost.
- Turning in the lodging repair sets `lodging_repaired`, which chains directly into the Day-1
  close below.

**Flags:** Day-1 clock remains frozen throughout. Completing the loop sets `lodging_repaired`,
which fires "The Hearth and the Howl." Quest and encounter definitions live in
`design/tutorial.md` / `design/tutorial_quests.md`.

---

## Day-1 close — "The Hearth and the Howl"

*Fires automatically the moment the lodging repair is turned in on Day 1 (flag `lodging_repaired`).
Day 1's clock is frozen until this plays; the sequence ends by advancing to Day 2 and setting
`first_rest`. The player does not choose to sleep — the day closes on its own.*

**Goal:** Close the first day on a note of small, real progress, then plant the wolf.

### Beats

- Evening. Fenwick is at the mended hearth, taking its measure. He marks how much got done today
  and credits the work rather than himself.
- He tells the player to rest — whatever this place becomes starts tomorrow; tonight it is enough
  that it stands.
- Fade to black. From far off in the dark, a long, low howl: too long for a dog, closer than
  anyone would like.
- Fade in on Day 2 morning. The howl goes unmentioned; it sits under the day.

**Flags:** sets `first_rest`; advances to Day 2; unfreezes the day clock and shows the clock UI
panel for the first time (hidden all of Day 1). The howl is an echo, not a cold plant — the
pack that hit the gate (intro Scene 2) is still out there, and everyone hearing it knows what
it is. The dire wolf thread pays off later (`design/tutorial_quests.md`).

---

## Arkus found — "On the Road Home"

*Fires on the party's first return to the outpost after the dire wolf is slain (flag
`dire_wolf_slain`, sets `arkus_found`). Uses the arrival-triggered cutscene pattern from intro
Scene 2. The full squad — player, Tharr, Fenwick, Elara — is present. Arkus is placed as an
unconscious resident afterward and does not wake here.*

**Goal:** Bring Arkus into the outpost as a debt owed, not a recruit chosen.

### Beats

- On the road home, worn from the wolf, the party finds a wounded orc slumped at the roadside,
  barely alive, wounds days old and badly tended.
- They read the wounds as the same wolf's work — it had the orc before it had them.
- Tharr calls it a debt and decides they carry the orc back, over Elara's practical objection
  about the orc's size.
- They bring the orc through the gate. Fade.

**Flags:** sets `arkus_found`. Arkus is placed as an unconscious resident at the outpost. The wake
is a separate beat (below), gated on the Trading Post being built.

---

## Arkus wakes — "What Was Not Enough"

*Fires at the start of the day after both `arkus_found` and `trading_post_built` are set (quest 9,
"The Smith and the Sickbed"). Sets `arkus_awake`; the asks make BOTH the Smithy and the Infirmary
commissionable at the planning table.*

**Goal:** Establish Arkus through blunt honesty, and turn their recovery into the outpost's next
two builds.

### Beats

- Arkus is upright on the mended bunk, stiff and badly bandaged, blunt from the first word —
  hates owing strangers.
- The party places where they found them; Arkus confirms the wolf and states plainly that the
  rite was failed. What they carried "was not enough"; bad steel breaks when you need it to hold.
- Arkus offers to build a forge — working metal is the one thing the rite did not take from them.
- *Player choice (flavor):* accept the offer, or note the orc can barely stand. Converges.
- Looking at their own botched bandages, Arkus argues for an infirmary as well — more will come
  back wounded like this; build the sickbed before it is needed.
- Tharr, from the doorway, agrees the planning table can hold both.

**Flags:** sets `arkus_awake`. Unlocks Smithy (`arkus_awake`) and Infirmary (`arkus_awake`) at the
planning table. Josen — the monk who will run the Infirmary — arrives 1-3 days after it is built,
via a random event (`design/economy/characters.md`).

---

## Infrastructure needed

- **Road scene** (`scenes/intro/road.tscn`): simple Node2D, dark/simple background the user
  can paint later. Character sprites positioned. Transitions to outpost after Scene 1 ends.
- **SceneRouter** addition: `GoToIntro()` / new-game flow routes here instead of straight to
  outpost. After Scene 1 ends: `GoToOutpost()` with `intro_scene_1` flag set.
- **Outpost cutscene trigger**: on `_Ready`, if `intro_scene_1` is set but `intro_complete`
  is NOT, play Scene 2 sequence before giving player control.
- **Story flags**: `intro_scene_0`, `intro_scene_1`, `intro_complete`
- **Dialogue files**: `data/dialogues/intro/scene_0.json`, `scene_1.json`, `scene_2.json`

## Deferred

- Road scene art (user paints later — placeholder dark/simple for now)
- Character sprite staging in road scenes (enter/exit/move commands — framework supports it,
  wiring actors to sprites is scene-specific)
- Name entry UI (currently `PlayerName` is set in code; UI is a future piece)
- Tutorial prompts from Tharr (in-world NPC interactions, not cutscene — uses existing talk
  system + story-flag-gated talk pool entries)
