# Bulwark — Tutorial & Onboarding

Smooth guided onboarding from the moment the intro cutscene ends through the player's first week at
the outpost. Follows the Stardew/Coral Island pattern: give the player one clear task at a time, teach
a mechanic by doing it, expand the scope only after the previous step is understood. No tutorial popups
or walls of text — the characters deliver guidance through dialogue, and the quest log tracks
objectives.

**The opening is directed, not free (rewritten 2026-07-16).** Day 1 is a single frozen-clock task that
closes on a scripted cutscene. Day 2 tours the ruins and hands the player two specific builds. Freedom
widens only once the base loop is taught. The canonical step-by-step spine is the quest chain in
`design/tutorial_quests.md` — this doc describes the onboarding *experience*; where the two disagree,
the quest chain wins.

## Principles

- **One thing at a time.** Each step teaches exactly one mechanic. The player should never be learning
  two systems at once.
- **NPCs are the teachers.** Tharr teaches building and gathering. Fenwick teaches cooking. Elara
  teaches trading — but later, because the store she runs is gated behind the deep forest. The player
  learns by talking to people, not by reading panels.
- **Earn the complexity.** Day 1 is "get wood and stone," on a frozen clock. Day 2 is "here is how the
  outpost grows — raise these two." The forest, farming, combat, and the deep woods reveal themselves in
  order after that.
- **The quest log is the guide.** Each tutorial step appears as a tracked quest objective. Completing
  one reveals the next. The player always knows what to do next.
- **Character motivation drives the tasks.** Tharr needs the lodging patched because people need to
  sleep. Fenwick needs the Tavern because morale starts at the table. The player needs the Farmhouse
  because the soil is still good. The tasks are not arbitrary — they are what each character would
  naturally want done first.
- **One building at a time.** Tharr is the outpost's only mason. When a building is commissioned, he is
  busy for 1-2 days performing the construction. During that time the planning table is unavailable for
  new commissions. The player spends the downtime gathering, farming, fighting, or socializing. This
  mirrors Stardew's Robin: construction takes real calendar time and the builder is occupied until it
  finishes. The rhythm is gather → commission → wait/adventure → building rises → gather for the next.

---

## Day 1 — "Shelter" (the clock is frozen)

The cutscene fades out with Tharr walking through the gate. The player gains control standing in the
outpost. **Day 1's clock is FROZEN** — time does not advance from the moment the intro ends until the
scripted day close. The player can take as long as they like on the single task, and the day will not
end until it is done. Tharr is nearby. The first thing the player does is talk to him.

### Step 1: Talk to Tharr

**Trigger:** Player gains control after the intro cutscene (`intro_complete`).

**Quest appears:** "Repair the Lodging"

Tharr is standing near the Command Post. Talking to him triggers a short dialogue sequence (the regular
dialogue box, first real use of the talk system).

```
THARR
Before anything else, the lodging needs mending. The roof has
held, but the walls have not. If you intend to sleep under
something other than sky tonight, I will need stone and timber.

PLAYER CHOICE:
  > "Tell me what you need."
  > "Where do I find stone and timber out here?"

[If "what you need"]
THARR
Fifteen lengths of cut timber. Ten blocks of stone. There is a
forest beyond the gate with both, if you know where to swing.

[If "where do I find"]
THARR
Beyond the gate. The forest edge still has standing timber and
the old quarry cuts are not far. Take an axe to the trees and
a pick to the rock. Bring what you find back here.

[Converge]
THARR
I will handle the rest. Just bring the materials.
```

**Quest updates:** "Gather timber (0/15)" + "Gather stone (0/10)"

The player now knows: go outside the gate, use tools to gather resources, bring them back. Small enough
to complete in a single trip.

### Step 2: Learn the tools

**Trigger:** Player approaches the outpost gate for the first time.

A brief tooltip appears (the only popup-style hint in the tutorial): "Press [Tab] to cycle tools. Use
[E] to interact with the world." The player already has the Axe and Pick in their tool belt.

### Step 3: First expedition (the near forest)

**Trigger:** Player exits through the outpost gate.

The Verdant Fringe (the near forest — the "Thornwood" of `design/world.md`) loads. Resource nodes are
visible: trees (axe) and stone outcrops (pick).

**Gathering teaches:** tool selection (Tab), interact to harvest (E), items into inventory (the Bulk
carry system, each item has weight). **The day clock does NOT tick — Day 1 is frozen.** The player
cannot burn the day on the tutorial's first task; there is no time pressure at all on Day 1.

**Combat is welcome but not required on the first expedition.** A rat or goblin roamer patrols the edge
of the gathering zone — close enough that many players will brush into their first fight while
collecting timber. That is intended texture: gather, scrap, gather, head home. The quest gates on
materials, not combat. Whenever the first victory lands, Tharr's `first_combat_victory` debrief follows
it. The directed combat introduction ("First Blood," see `design/tutorial_quests.md`) comes after the
first building is commissioned on Day 2, so combat stays woven through the opening rather than arriving
as one lesson.

### Step 4: Return and repair

**Trigger:** Player returns to the outpost with 15 wood + 10 stone and talks to Tharr.

```
THARR
That will do. Give me a moment.

[Beat. The lodging hall visually updates — patched walls, a door
that closes properly, bunks ready for use.]

THARR
The lodging holds. You have beds, a roof, and a door that shuts.
It is not much, but it is enough for the night.
```

**Quest completes:** "Repair the Lodging" (`lodging_repaired`).

This is the last thing the player *does* on Day 1. There is no separate "rest" task — turning in the
bundle triggers the scripted close.

### Step 5: The scripted day close (automatic)

**Trigger:** `lodging_repaired`. **The day closes on its own** — the player does not choose to sleep.

A short cutscene plays (full draft in `design/intro.md`, "The Hearth and the Howl"). Two beats:

- **Fenwick at the hearth.** He has found the hearth Tharr mentioned and is examining the flue — warm,
  self-deprecating, food-adjacent. "A proper hearth under all the soot. Give me a few days and it will
  feed everyone here." He tells the player to rest; the outpost can simply be *standing* for one night.
- **The howl.** After the fade, a long low wolf howl carries through the dark — held too long to be a
  dog, closer than anyone would like. Foreshadow only; no name yet. It pays off in the wolf hunt
  (`design/tutorial_quests.md` quest 7).

The sequence advances to Day 2, sets `first_rest`, and **unfreezes the clock** — from here on, time
runs normally. This replaces the old "Rest for the Night" quest entirely; the day close is scripted, not
a player action.

---

## Day 2 — "The Table" (time now runs)

The player wakes on Day 2. The clock is live. Tharr has new dialogue gated on `first_rest`.

### Step 6: The planning table and the tour

**Trigger:** Talk to Tharr on Day 2 (`first_rest`, no `planning_table_shown`).

Tharr walks the player past the three ruins, the camera panning to each (the `camera` staging step):
the sagging **farmhouse** frame, the **hearth** Fenwick has claimed, and the collapsed **storefront**
Elara has her eye on.

```
THARR
Now that we have a roof that holds, let me show you how we
build the rest.

[The camera pans across the three ruins as he names them.]

THARR
This is the planning table. Every building the outpost needs
starts here. You bring the materials, I handle the construction.

THARR
Two we can raise now — the farmhouse and the hearth. The
storefront waits. Its timber comes from deeper in the forest than
we can yet walk. First things first.
```

**Quest appears:** "Raise the Hearths" — raise the **Farmhouse** and the **Tavern** to stage 1.

The player interacts with the planning table. The build panel (hotkey B) opens for the first time. All
three starter ruins are visible, but the **Trading Post is shown deferred** — its bundle lists Elderwood
**hardwood**, which the party cannot gather yet, so it cannot be funded until the deep forest opens:

- **Farmhouse** — 90g, wood + stone — "The fields have gone to seed, but the soil is still good."
- **Tavern** — 70g, wood + stone + herb — "Fenwick found the hearth. He needs walls around it."
- **Trading Post** — *deferred* — 60g, wood + stone + **hardwood** — "The frame is sound, but the last
  of its timber grows where we cannot yet reach."

The NPCs reinforce the directed order:

```
FENWICK (condition: planning_table_shown)
The hearth draws well, but the room around it needs a roof and a
proper flue. A tavern is only as good as the walls that keep the
rain out of the soup.

ELARA (condition: planning_table_shown)
There is a storefront in the eastern wall. The frame is sound.
But the good timber for it — the hardwood — grows deep, past
where anything sane wants to walk just now. It will keep.
```

**Flag set:** `planning_table_shown`. **Quest updates:** "Commission the Farmhouse and the Tavern."

### Step 7: Gather and build

The player gathers materials for whichever of the two they choose first. This is the first "real"
economy loop: gather → return → contribute to the bundle → repeat until full → building commissions.
Both bundles are cheap Verdant Fringe timber and stone, gatherable within a trip or two each.

Once the player commissions the first building, Tharr begins construction. He is occupied for 1-2 days —
the planning table is locked and Tharr has a build-day talk line:

```
THARR (condition: building_under_construction)
The work is underway. Give me another day. Gather what you need
for whatever comes next.
```

The combat quest **First Blood** (`design/tutorial_quests.md` quest 4) fires on that first commission,
filling the build day with a directed fight. When construction finishes the next morning (or the one
after), the building appears at its marker, the associated NPC claims it, and the planning table reopens
for the second commission. The two starters go up across several days, not one.

### Step 8: NPC activation

**Tavern commissions → Fenwick starts cooking.**

```
FENWICK
(standing at the hearth, already cooking something)
The tavern is open. Bring me ingredients and I will turn them
into something worth eating. A well-fed party fights better,
works harder, and complains less. Mostly less.
```

The player learns: meal buffs (day-long benefits from eating), the crafting/recipe system.

**Farmhouse commissions → the soil opens** (farming is taught in Step 10 below).

The **Trading Post does not activate on Day 2** — it is deferred until the Elderwood opens. Elara's
store-open line waits for `trading_post_built`, which cannot happen until the dire wolf is dead.

---

## The freeform week — farm, fight, and the deep forest

Once the Farmhouse and Tavern stand, the tutorial's tight rails loosen. The player gathers, fights, and
socializes at their own pace while the story quests thread through. NPCs wander the outpost. The player
can take the **full squad — player, Tharr, Fenwick, and Elara** — on expedition (the party-select gate
at territory travel; the founding four are the expedition party until recruits arrive).

### Step 9: Farming (after Farmhouse + Tavern)

**Trigger:** `farmhouse_built`.

```
THARR / ambient (condition: farmhouse_built)
The fields are cleared enough to start. The soil is poor but it
will answer to steady work. Plant what you can, water it daily,
and the harvest will come.
```

Because **no store exists yet** (the Trading Post is deferred), the **starter seeds are granted via
dialogue** — the farming intro line hands them over (a dialogue `item` effect) so the loop can start
without a shop. The player learns: tilling, planting, watering, growth over days, harvesting. The
directed farm quest ("First Harvest," quest 5) tracks six crops.

### Step 10: The first meal

**Trigger:** First Harvest complete AND `tavern_built`.

The harvest in hand IS the lesson: crops go to the hearth. The player gives Fenwick three fresh crops;
he cooks; the player eats; the meal-buff icon appears on the HUD ("Fenwick's Table," quest 6). Selling
is NOT taught here — there is still no store. This is one clean economy sink, no busywork.

Completing the meal quest is the hinge: it opens BOTH the wolf hunt and the Trading Post restoration.

### Step 11: The wolf and the deep forest

**Trigger:** Fenwick's Table complete.

Two threads start together (`design/tutorial_quests.md` quests 7 and 8):

- **The Wolf of the Fringe.** The howl from the first night returns. A dire wolf holds the passage
  between the near forest and the deep Elderwood. A fixed lair appears at the passage; the wolf is a
  Severe encounter tuned for a level 1–2 party of four, **beatable with the gear the party already
  carries — no Smithy required.** The strategy is everything already taught: eat a meal, treat wounds,
  spend three actions well. Killing it (`dire_wolf_slain`) **opens the Elderwood.**
- **Restore the Trading Post.** Its bundle needs Elderwood hardwood, so its guidance objectives — enter
  the Elderwood, gather hardwood — send the player into the deep forest the wolf's death just opened.
  Funding it (`trading_post_built`) is what finally lets Elara open her store.

**On the first walk home after the wolf kill,** the party finds Arkus wounded on the road — the same
beast, the same ground (`arkus_found`; cutscene in `design/intro.md`, "On the Road Home"). He is the
first recruit, laid up unconscious until he wakes.

### Step 12: Arkus wakes → the forge and the sickbed

**Trigger:** the day-start after `arkus_found` AND `trading_post_built`.

Arkus wakes ("The Smith and the Sickbed," quest 9). Blunt orc honesty: what he carried was not enough,
and the outpost has no proper place to mend the wounded. His asks make **two** buildings commissionable
at once — the **Smithy** and the **Infirmary**, both gated on `arkus_awake`. The player learns
character-first arrivals (a villager brings a building) and that one arrival can open more than one.
First Steel (crafting) and Mend the Wounded (Treat Wounds — Josen arrives 1-3 days after the Infirmary
is built) follow from here and close the arc. Command Post upgrade tiers are deferred pending design
(see `design/economy/buildings.md`), so there is no tier-upgrade beat this pass.

---

## After the arc — open play

By the end of the arc the player has:
- Repaired the lodging (Day 1, frozen clock, scripted close)
- Raised the Farmhouse and Tavern (building system understood)
- Farmed and cooked (economy loop understood)
- Fought roamers and the dire wolf boss (combat and preparation understood)
- Opened the Elderwood, restored the Trading Post, recruited Arkus, built the Smithy and Infirmary
- Crafted at the forge and treated a squad member's wounds (First Steel, Mend the Wounded)

The tutorial does not formally end; the quest log transitions to the broader restoration goals, which
emerge from the pacing schedule. The game has taught its mechanics. From here, the player explores at
their own pace.

---

## Quest log structure

Tutorial quests appear in the quest log with clear objectives and progress tracking. The canonical table
is in `design/tutorial_quests.md`; the onboarding-facing subset:

| Quest | Objectives | Trigger | Completion |
|---|---|---|---|
| Repair the Lodging | Gather timber (0/15), Gather stone (0/10), Return to Tharr | Intro ends | Lodging repairs; scripted Day-1 close fires |
| *(Day-1 close)* | *(automatic cutscene, not a quest)* | Lodging repaired | Day advances, `first_rest` set, clock unfreezes |
| The Planning Table | Follow Tharr's tour, visit the planning table | Day 2, talk to Tharr | Build panel opens |
| Raise the Hearths | Commission the Farmhouse and the Tavern (Trading Post deferred) | Planning table visited | Both `*_built` |
| (varies by building) | Building-specific intro from the NPC | Building commissions | NPC functional, mechanic unlocked |

Later quests (First Blood, First Harvest, Fenwick's Table, the wolf hunt, the Trading Post, Arkus's
arrival, the Smith and the Sickbed, First Steel, Mend the Wounded) flow from the quest chain and are
documented in `design/tutorial_quests.md`.

---

## Story flags (tutorial-specific)

| Flag | Set by | Consumed by |
|---|---|---|
| `intro_complete` | Intro cutscene Scene 2 | Tharr's first talk / Repair the Lodging start |
| `lodging_repaired` | Repair the Lodging turn-in | Scripted Day-1 close trigger; lodging visual update |
| `first_rest` | **The scripted Day-1 close** (no longer a rest quest) | Tharr's Day-2 planning dialogue |
| `planning_table_shown` | Tharr's Day-2 tour + table visit | Fenwick/Elara building-hint lines; Raise the Hearths start |
| `first_commission` | First building commissioned | First Blood start |
| `first_combat_victory` | First encounter won | Tharr's combat debrief line |
| `farmhouse_built` | Farmhouse commissioned | Farming intro (starter-seed grant); First Harvest start |
| `tavern_built` | Tavern commissioned | Fenwick cooking-open line; Fenwick's Table gate |
| `dire_wolf_slain` | Dire wolf boss defeated | Elderwood territory unlock; Arkus-found gate |
| `trading_post_built` | Trading Post commissioned (needs Elderwood hardwood) | Elara store-open line; half of Arkus's wake gate |
| `arkus_found` | Arkus-found cutscene (first return after `dire_wolf_slain`) | Arkus placed as unconscious resident; half of the wake gate |
| `arkus_awake` | Arkus's wake (day-start after `arkus_found` + `trading_post_built`) | Smithy AND Infirmary commissionability |

Retired since the prior version: no `Rest for the Night` quest (the day close is scripted); the free
three-building Day-2 choice is gone (directed Farmhouse+Tavern, Trading Post deferred); Elara's
store-open no longer fires on Day 2 (it waits on the Elderwood).

---

## Tone notes

- **Tharr is the primary tutorial voice.** Practical and direct. He tells you what needs doing, where to
  find it, and lets you go. He does not over-explain.
- **Elara and Fenwick supplement, not duplicate.** Fenwick teaches cooking when the Tavern goes up.
  Elara teaches trading — but later, once the Elderwood opens her store. Neither repeats Tharr's lessons.
- **No hand-holding past the freeform week.** The tutorial teaches gather → build → farm → cook → fight
  → open the deep forest. After that, the game trusts the player. Deeper mechanics (runes, Treat Wounds
  DC choices, party composition, friendship) surface through play.
- **The quest log is the safety net.** If the player gets lost, the quest log always has the next
  objective. But the NPCs make the next step obvious enough that most players will not need it.
