# Bulwark — Tutorial & Onboarding

Smooth guided onboarding from the moment the intro cutscene ends through the player's first
few days at the outpost. Follows the Stardew/Coral Island pattern: give the player one clear
task at a time, teach a mechanic by doing it, expand the scope only after the previous step is
understood. No tutorial popups or walls of text — the characters deliver guidance through
dialogue, and the quest log tracks objectives.

## Principles

- **One thing at a time.** Each step teaches exactly one mechanic. The player should never be
  learning two systems at once.
- **NPCs are the teachers.** Tharr teaches building and gathering. Elara teaches trading.
  Fenwick teaches cooking and rest. The player learns by talking to people, not by reading
  panels.
- **Earn the complexity.** The planning table, the territory system, and combat reveal
  themselves in order. Day 1 is "get wood and stone." Day 2 is "here is how the outpost
  grows." Day 3+ is "go further, fight harder, bring back more."
- **The quest log is the guide.** Each tutorial step appears as a tracked quest objective.
  Completing one reveals the next. The player always knows what to do next.
- **Character motivation drives the tasks.** Tharr needs the lodging patched because people
  need to sleep. Elara eyes the Trading Post because she sees opportunity. Fenwick needs the
  Kitchen because morale starts at the table. The tutorial tasks are not arbitrary — they are
  what each character would naturally want done first.
- **One building at a time.** Tharr is the outpost's only mason. When a building is
  commissioned, he is busy for 1-2 days performing the construction. During that time the
  planning table is unavailable for new commissions or upgrades. The player spends the
  downtime gathering, farming, adventuring, or socializing. This mirrors Stardew's Robin:
  construction takes real calendar time and the builder is occupied until it finishes. The
  pacing creates a natural rhythm of gather → commission → wait/adventure → building rises →
  gather for the next one.

---

## Day 1 — "Shelter"

The cutscene fades out with Tharr walking through the gate. The player gains control standing
in the outpost. Tharr is nearby. The quest log is empty. The first thing the player does is
talk to Tharr.

### Step 1: Talk to Tharr

**Trigger:** Player gains control after the intro cutscene.

**Quest appears:** "Speak with Tharr"

Tharr is standing near the Command Post. Talking to him triggers a short dialogue sequence
(not a cutscene — the regular dialogue box, first real use of the talk system).

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

The player now knows: go outside the gate, use tools to gather resources, bring them back.
The amounts are small enough to complete in a single expedition.

### Step 2: Learn the tools

**Trigger:** Player approaches the outpost gate for the first time.

A brief tooltip appears (the only popup-style hint in the tutorial): "Press [Tab] to cycle
tools. Use [E] to interact with the world."

The player already has the Axe and Pick in their tool belt from the start. The tool HUD at
the bottom shows the equipped tool.

### Step 3: First expedition

**Trigger:** Player exits through the outpost gate.

The Verdant Fringe (the starting territory) loads. Resource nodes are visible: trees (axe)
and stone outcrops (pick). The player walks up to a tree, equips the axe, hits E, and gathers
wood. Same for stone.

**Gathering teaches:**
- Tool selection (Tab)
- Interact to harvest (E)
- Items go into inventory (the Bulk carry system — each item has weight)
- The day clock ticks while you work

**No mandatory combat on the first expedition.** Roaming enemies exist in the territory but
the first few resource nodes are placed near the gate, before the roamer patrol zones. The
player CAN stumble into a fight, but they do not HAVE to. The tutorial does not assume combat
knowledge yet.

If the player does encounter a roamer: the combat system handles itself (it's already
built). The tutorial quest does not gate on combat — it gates on materials gathered.

### Step 4: Return and repair

**Trigger:** Player returns to the outpost with 15 wood + 10 stone.

Talk to Tharr. He takes the materials and the lodging repair completes.

```
THARR
That will do. Give me a moment.

[Beat. The lodging hall visually updates — patched walls, a door
that closes properly.]

THARR
The lodging holds. You have beds, a roof, and a door that shuts.
It is not much, but it is enough for the night.
```

**Quest completes:** "Repair the Lodging"

**Unlocks:**
- The party can now sleep at the outpost (the sleep/rest mechanic becomes available)
- Tharr's next quest appears

### Step 5: Rest

**Trigger:** Lodging repair complete. The day is getting late (or the player can choose
to keep exploring).

Fenwick has a talk line available (condition: `lodging_repaired`, no flag `first_rest`):

```
FENWICK
The lodging is sorted, and I have found the hearth Tharr
mentioned. It is not much yet, but I can work with it. Get some
rest tonight. Tomorrow we start making this place livable.
```

When the player sleeps (interact with the bed): full rest resolves, the day advances, the
end-of-day summary appears. The player has completed their first day.

**Flag set:** `first_rest`

---

## Day 2 — "The Table"

The player wakes. Tharr has new dialogue gated on `first_rest`.

### Step 6: The planning table

**Trigger:** Talk to Tharr on Day 2 (flag: `first_rest`, no flag: `planning_table_shown`).

```
THARR
Now that we have a roof that holds, let me show you how we
build the rest.

[The camera pans to the Command Post planning table.]

THARR
This is the planning table. Every building the outpost needs
starts here. You bring the materials, I handle the construction.

THARR
Three buildings are ready to go up first. Each one opens a part
of the outpost we will need.
```

**Quest appears:** "Visit the Planning Table"

The player interacts with the planning table. The build panel (hotkey B) opens for the first
time, showing three commissionable buildings:

- **Trading Post** — 60 gold, 90 wood, 60 stone — "Elara has been eyeing the old storefront
  since she arrived."
- **Kitchen** — (similar cost, wood + stone + fiber) — "Fenwick found the hearth. He needs
  walls around it."
- **Farmhouse** — (similar cost, wood + stone) — "The fields have gone to seed, but the soil
  is still good."

**No forced order.** The player can build any of the three first. Each NPC has a talk line
that hints at their building:

```
ELARA (condition: planning_table_shown)
There is a storefront in the eastern wall. The frame is sound.
With timber and stone I can have it open within the week.

FENWICK (condition: planning_table_shown)
The hearth draws well, but the room around it needs a roof and
a proper flue. A kitchen is only as good as the walls that keep
the rain out of the soup.
```

**Flag set:** `planning_table_shown`

**Quest updates:** "Commission your first building at the planning table"

### Step 7: Gather and build

The player gathers materials for whichever building they choose. This is the first
"real" economy loop: gather resources → return → contribute to the building bundle →
repeat until the bundle is full → building commissions.

The bundle costs are tuned so that the Trading Post and Kitchen can each be gathered
within 2-3 trips (Days 2-4). Once the player has the materials and commissions the building,
Tharr begins construction. He is occupied for 1-2 days — during which the planning table
is locked and Tharr has a talk line about the work:

```
THARR (condition: building_under_construction)
The work is underway. Give me another day. Gather what you need
for whatever comes next.
```

When construction finishes (the next morning, or the morning after):
- The building visually appears at its marker in the outpost
- The associated NPC claims it and becomes functional
- A new mechanic unlocks (buying/selling, cooking, farming)
- The planning table reopens for the next commission

This means the player cannot rush all three starter buildings on Day 2. The natural
rhythm is: commission one → spend 1-2 days gathering/adventuring while Tharr builds →
building rises → commission the next. The three starters go up across the first week,
not the first day.

### Step 8: NPC activation

**Trading Post commissions → Elara opens the store.**

```
ELARA
(standing in the newly built Trading Post)
It is not much, but it is mine. Bring what you have to sell,
and I will see what I can offer in return.

Seeds, provisions, and whatever else the frontier demands. The
stock will grow as the outpost does.
```

The player learns: buying and selling, the gold economy, seed purchasing for farming.

**Kitchen commissions → Fenwick starts cooking.**

```
FENWICK
(standing at the hearth, already cooking something)
The kitchen is open. Bring me ingredients and I will turn them
into something worth eating. A well-fed party fights better,
works harder, and complains less. Mostly less.
```

The player learns: meal buffs (day-long benefits from eating), the crafting/recipe system.

---

## Day 3-5 — "The Frontier"

By Day 3 the player has at least one building up, understands gathering and contributing,
and has seen the planning table. Now the tutorial opens the rest of the game.

### Step 9: First combat (guided)

**Trigger:** The player ventures deeper into the Verdant Fringe, past the safe gathering
zone near the gate.

A roaming enemy is visible on the territory map. The first encounter is tuned easy (2-3
goblins or rats). If the player avoided combat on Day 1, this is their first fight.

After the first combat victory:

```
THARR (next talk, condition: first_combat_victory)
You survived your first encounter. The forest will send worse.
Keep your weapons sharp and your squad rested. Treat Wounds
before you press deeper — a wound carried into a second fight
is twice as dangerous.
```

The player learns: combat, loot/gold drops, attrition (HP carries between fights), Treat
Wounds (the out-of-combat healing mechanic).

### Step 10: Farmhouse and the soil

**Trigger:** Farmhouse commissioned.

Tharr or a talk-pool line from the player's own observation:

```
THARR (condition: farmhouse_built)
The fields are cleared enough to start. The soil is poor but
it will answer to steady work. Plant what you can, water it
daily, and the harvest will come.
```

The player learns: tilling, planting, watering, crop growth over days, harvesting.

Farming provides a renewable resource loop that supplements gathering: crops sell for gold
at the Trading Post, cook into meals at the Kitchen, or contribute to building bundles.

---

## Day 5+ — Open play

By Day 5 the player has:
- Repaired the lodging (sleeping unlocked)
- Seen the planning table (building system unlocked)
- Built 1-2 buildings (Trading Post, Kitchen, or Farmhouse)
- Fought at least one encounter (combat understood)
- Gathered, sold, cooked, or farmed (economy loop understood)

The tutorial does not formally end. Instead, the quest log transitions from single-task
tutorial objectives to the broader restoration goals:

- "Commission the remaining starting buildings" (Trading Post / Kitchen / Farmhouse)
- "Upgrade the Command Post" (unlocks the Elderwood, the next territory)
- "Clear the forest expedition" (triggers Arkus's arrival → Smithy unlockable)

The game has taught its mechanics. From here, the player explores at their own pace.

---

## Quest log structure

Tutorial quests appear in the quest log with clear objectives and progress tracking.

| Quest | Objectives | Trigger | Completion |
|---|---|---|---|
| Speak with Tharr | Talk to Tharr at the Command Post | Intro cutscene ends | Dialogue plays |
| Repair the Lodging | Gather timber (0/15), Gather stone (0/10), Return to Tharr | "Speak with Tharr" complete | Lodging repairs, sleep unlocked |
| Rest for the Night | Sleep at the outpost | Lodging repaired | First rest, day advances |
| The Planning Table | Visit the planning table | Day 2, talk to Tharr | Build panel opens |
| Commission a Building | Choose and fund a building at the table | Planning table visited | First building rises |
| (varies by building) | Building-specific intro from the NPC | Building commissions | NPC functional, mechanic unlocked |

Later quests (Arkus rescue, Command Post upgrade, etc.) flow from the organic progression
and are not part of the guided tutorial — they emerge from gameplay.

---

## Story flags (tutorial-specific)

| Flag | Set by | Consumed by |
|---|---|---|
| `intro_complete` | Intro cutscene Scene 2 | Tharr's first talk (requires this) |
| `lodging_repaired` | Lodging repair quest | Sleep unlock, Fenwick rest line, Day 2 trigger |
| `first_rest` | First sleep | Tharr Day 2 planning table dialogue |
| `planning_table_shown` | Tharr shows the table | Elara/Fenwick building-hint lines |
| `first_combat_victory` | First encounter won | Tharr combat debrief line |
| `farmhouse_built` | Farmhouse commissioned | Tharr farming intro line |
| `trading_post_built` | Trading Post commissioned | Elara store-open line |
| `kitchen_built` | Kitchen commissioned | Fenwick cooking-open line |

---

## Tone notes

- **Tharr is the primary tutorial voice.** He is practical and direct. He tells you what needs
  doing, where to find what you need, and then he lets you go do it. He does not over-explain.
- **Elara and Fenwick supplement, not duplicate.** Each teaches their own domain (trading,
  cooking) when their building goes up. They do not repeat Tharr's lessons.
- **No hand-holding past Day 2.** The tutorial teaches gather → build → rest → fight. After
  that, the game trusts the player to explore. Deeper mechanics (runes, Treat Wounds DC
  choices, party composition, friendship) surface through play, not tutorials.
- **The quest log is the safety net.** If the player gets lost, the quest log always has the
  next objective. But the NPCs make the next step obvious enough that most players will not
  need it.
