# Drifter

A roguelite dice combat game set on a barren alien world. You are a **drifter** — a stranded explorer surviving on a hostile planet, venturing out from a makeshift camp on **expeditions** into the wastes. Combat plays out through an **ability board**: cards with sockets that accept specific dice. Roll five dice Yahtzee-style, then drag dice into sockets at your own pace — when an ability's sockets are all filled, it fires and consumes the dice. Rerolls are a budget you spend across the turn. Fight creatures on a Slay-the-Spire-style expedition map and grow your board across the run.

**Engine:** Godot 4.6 (2D pixel art + 3D physics dice in SubViewport)
**Genre:** Roguelite / Dice combat
**Setting:** Barren alien planet — sci-fi survival, lone explorer
**Inspirations:** Slay the Spire (run shape, intents), Dice Throne (abilities), Balatro (rerolls as resource, ability leveling), Yahtzee (the roll itself)

---

## Art — Penusbmic Pixel Art Packs

All art sourced from Penusbmic's sci-fi / DARK pixel art line (itch.io). Additional packs from the same artist can be mixed in later.

### Planet One — Environment (16×16 tileset)

| Asset | Use in game |
|---|---|
| Parallax sky layers (day / dusk / blood-moon) | Expedition backdrop — shift palette as expedition deepens (day → dusk → blood-moon for apex) |
| Barren terrain tiles, scrub vegetation | Ground plane for combat and camp scenes |
| Tent / canopy awnings | Shelter node — rest & repair between encounters |
| Cargo containers (incl. "37" box) | Trader node — buy/sell salvage, or loot drops after encounters |
| Spotlight cone | Camp perimeter lighting, signals safe zone |
| Circular ring structure | Anomaly node — risk/reward random event |
| Poles, antennae, sign posts | Waypoint markers on expedition map |
| Fencing / barriers | Camp perimeter, encounter arena edges |
| Small mechanical drones | Camp ambient detail, or scannable props in events |
| Camp furniture, benches | Shelter scene dressing |

### Hero Sprite (128×64 frames)

| Animation | Use in game |
|---|---|
| Idle | Default combat stance (left side of screen) |
| 3-hit melee combo | Fires when a melee ability module activates — combo length scales with input difficulty (easy requirement = hit 1, hard match/sequence = full 3-hit chain) |
| Supercharged slash (energy arc VFX) | Reserved for ultimates or abilities with the hardest input requirements (e.g. 5-match, full straight) |
| Ranged orb (projectile + trail) | Fires when a ranged ability module activates |
| Blaster light / heavy | Quick-fire ranged abilities (1–2 socket modules) |
| Dash / teleport blink | Evasion or shield ability VFX |
| Jetpack on/off/fall | Transition anim entering/leaving expedition map, or dodge ability |
| Damaged, knockback | Plays when the drifter takes a hit on the creature's turn |
| Death | Expedition-over anim |
| Run, hop, landing | Map traversal between nodes |
| Ladder climb | Vertical map traversal or event interaction |

### DARK Character Pack 3 — Enemies

| Creature | Size | Role | Animations | In-game identity |
|---|---|---|---|---|
| **Ghoul** | 62×33 | Trash melee | Wake/emerge, walk, lunge burst, hit, death (red dissolve), spawn, static idle | **Lurker** — erupts from the ground, lunges at the drifter. 1–2 intents on a loop. |
| **Spitter** | 57×39 | Trash ranged | Idle, walk, spit attack, hit, death + separate projectile (travel, burst×2) | **Spewer** — squat blob that lobs acid at range. Projectile VFX included. |
| **Summoner** | 46×44 | Elite | Idle, move, summon cast, hit, death | **Hive Caller** — summons Lurkers/Spewers mid-fight. Signature mechanic: each summon cast adds a creature to the encounter. Drop guaranteed salvage. |

### DARK Mech Mini Boss — Boss

| Creature | Size | Animations | In-game identity |
|---|---|---|---|
| **Turtle Mech** | 171×101 | Idle, walk, cannon blast, magnetic punch, shoot prep → shoot loop, hit, death (long explosion) + separate projectile (energy ball, explode) | **The Warden** — armored mech apex creature. Multi-intent boss: cannon blast (ranged, telegraph with shoot prep), magnetic punch (melee slam), sustained fire (shoot loop). Expedition-ending fight. |

### Not covered by packs (custom or deferred)

- **UI chrome** — ability module frames, socket shapes, HP/shield bars, intent icons, reroll counter → Godot Control nodes + small custom pixel icons
- **Dice / power cells** — 3D meshes in SubViewport, no 2D sprite needed
- **Map node icons** — small custom icons (use poles/antennae/ring from Planet One as visual anchors)
- **Loot / item icons** — small custom sprites for scrap, stims, implants
- **Status effect pips** — tiny icon set (4–6 icons)

---

## Core Loop

```
Launch expedition from camp → enter the wastes
  ↓
Encounter creature → it telegraphs intent
  ↓
Your turn opens:
  • All FREE cells (unsocketed) auto-roll
  • Reroll budget refreshes (e.g. 2)
  • SOCKETED cells from earlier turns stay where they are (rare)
  ↓
Play at your own pace, in any order:
  • Drag a free cell into any compatible socket
  • When all sockets on a module fill → it FIRES, cells consumed, sockets clear
  • Spend a reroll → all currently-free cells tumble again
  • Use a stim
  ↓
End turn when satisfied (or when rerolls are gone and nothing more fits)
  ↓
Creature turn: resolves telegraphed intent
  ↓
Repeat until one HP hits 0
  ↓
Win → salvage (module OR implant OR cell upgrade OR stim OR scrap) → continue expedition
Expedition map → choose next zone (encounter / elite / trader / shelter / anomaly / apex)
  ↓
Beat the apex creature → next sector with harder fauna → eventual extraction
Die → salvage persists as data logs → new expedition
```

**The core tension:** you have 5 cells and ~4 modules. You can't fire everything every turn. The Yahtzee decision plays out on your board: do you spend rerolls chasing a hard requirement for a big payoff, or settle for firing easy modules and keep tempo? Do you dump two cells into a 2-socket shield, or save them for the 3-match module that needs a pair you haven't rolled yet?

Sockets *can* persist across turns — if you partially fill a tough module and can't finish it, those cells stay put and you pick up where you left off next turn. But this is the exception, not the rhythm. Most modules fire within the turn you start filling them.

**Primary resources (per encounter):**
- **HP** — yours and the creature's
- **Rerolls** — refreshes each turn (default 2 beyond the free auto-roll)
- **Shield** — temporary energy barrier, expires at start of your next turn

**Primary resources (per expedition):**
- **HP** — persists between encounters; small heals at shelters
- **Scrap** — salvaged per encounter, spent at traders
- **Stims** — consumable items, limited carry slots
- **Your ability board** — grows and mutates as you progress

**Prestige:** On death, partial salvage converts to **data logs** — meta-currency that unlocks new ability modules / implants / dice / stims / loadouts for the pool.

---

## The Dice — "Power Cells"

Thematically, the dice are **power cells** — small glowing cubes the drifter feeds into their gear. Mechanically identical to dice; the 3D physics sell the "tumble and slot" fantasy.

| Property | Default |
|---|---|
| Starting pool | 5 cells (d6) |
| Roll model | `RigidBody3D` in a SubViewport (pattern from `life-magic/scripts/ui/wizard_3d.gd`) |
| Free cells | Tumble in the charging tray, can be socketed or rerolled |
| Socketed cells | Visually snap into the ability module, immune to rerolls |
| Auto-roll | All free cells tumble at start of each of your turns |

No "lock toggle" — socketing *is* locking. The board is the only commitment surface.

---

## The Ability Board — "Loadout Rack"

The center of the screen. A row (or grid) of **ability modules** the drifter has scavenged and installed. Each module has a name, an effect, and 1–5 cell sockets. Power cells snap into sockets; when full, the module fires.

**Anatomy of an ability module:**

```
┌─────────────────────────────┐
│  PLASMA LANCE               │
│  [ ▢ ][ ▢ ][ ▢ ]            │   ← three sockets, "must all match"
│  Deal 8 + (3 × pip) damage  │
└─────────────────────────────┘
```

**Socket requirements** (the design space):

| Requirement | Example | Notes |
|---|---|---|
| **Any** | accepts any cell | The basic utility socket |
| **Specific face** | accepts only a `6` | Highest-impact, hardest to fill |
| **Range** | accepts `4–6` | "High cell" |
| **Parity** | accepts only even / only odd | Easier to upgrade into |
| **Match other sockets** | accepts whatever already filled the matched sockets | The classic "pair / three of a kind" pattern |
| **Sequence with other sockets** | accepts N+1 of an already-socketed N | Straights |
| **Sum** | cells must sum to X across the module | Lets the player route any combo |

A "Pair Barrier" is two `Match-other` sockets. A "Three of a Kind Lance" is three. A "Small Straight" is four `Sequence` sockets. A "Yahtzee Ultimate" is five `Match`. But modules can also be weirder: "Spend any two even cells" is a perfectly cromulent module.

**Firing:** when the last socket fills, the module resolves immediately (visually: cells flash, drifter plays attack anim, effect resolves), then sockets reset to empty.

**Slot cap:** the board holds N modules at once (start with ~4, grow to ~6). Picking up a 7th forces a swap or destroy.

---

## Ability Mutations — the Per-Ability Upgrade Axis

Abilities aren't fixed. Upgrades change *socket requirements*, *socket count*, *and/or effects*. This is the Balatro hand-leveling axis, but it can structurally rewrite an ability instead of just buffing numbers.

| Mutation type | Example before → after |
|---|---|
| **Loosen socket** | `must be 6` → `must be 5 or 6` → `must be 4+` |
| **Tighten socket** | `any` → `must be even` (pairs with an effect buff) |
| **Add socket** | 3 sockets → 4 sockets (and effect scales up) |
| **Remove socket** | 5 sockets → 4 sockets (effect halved but fires more often) |
| **Swap requirement** | `must match` → `must be sequence` (changes the build it fits in) |
| **Effect buff** | `Deal 8 damage` → `Deal 8 damage + apply Vulnerable` |

Upgrades come from shelters, anomalies, traders, and elite/apex rewards. The same module can take many shapes by the end of an expedition — and future characters could start with different mutation pools, so one loadout archetype might only loosen toward high cells while another only adds sockets.

---

## Creatures — Hostile Fauna with Intents

Slay-the-Spire-style. Creatures have HP, telegraphed intent each turn, and a small behavior pattern. Keep it dumb-but-readable.

| Intent | Icon | Behavior |
|---|---|---|
| **Attack** | Claw + number | Deal that much damage on its turn |
| **Defend** | Shell + number | Gain armor |
| **Buff** | Up-arrow | Self-buff (strength/regen/etc.) |
| **Debuff** | Down-arrow | Apply weak/vulnerable to the drifter |
| **Special** | ? | Telegraphed unique move (summon, sustained fire, etc.) |

**Lurker (Ghoul):** Trash melee. 1–2 intents on a loop (attack / attack+buff). Low HP. Erupts from the ground (wake anim), lunges at the drifter. Exists to drain resources between elites.

**Spewer (Spitter):** Trash ranged. 1–2 intents (attack from range / defend). Low HP. Lobs acid projectiles (uses projectile travel + burst VFX). Pairs with Lurkers to create melee+ranged pressure.

**Hive Caller (Summoner):** Elite. Higher HP, 3+ intents: summon (spawns a Lurker or Spewer), buff, attack. Signature mechanic: each summon cast adds a creature to the encounter — kill it fast or get swarmed. Drops guaranteed ability module or implant + scrap.

**The Warden (Turtle Mech):** Boss. Expedition-ending fight. Multi-phase intents: cannon blast (ranged, telegraphed by shoot prep anim), magnetic punch (melee slam), sustained fire (shoot loop — multi-hit over a turn). Can mess with the board (e.g. "magnetic pulse: one random socketed cell is ejected"). Drops a major reward.

**Status effects** (small, reused both directions):
- **Weak** — damage dealt halved this turn
- **Vulnerable** — incoming damage +50%
- **Strength** — +X to all damage from a source
- **Regen** — heal at turn end

---

## The Expedition — Map Structure

Each run is an **expedition** into the wastes. One biome (Planet One barren landscape), with palette shifts marking progression — day sky early on, dusk mid-expedition, blood-moon for the boss zone. A branching node map per expedition. (Vertical slice = one expedition, ~15 minutes.)

| Node | Visual anchor (from Planet One) | Effect |
|---|---|---|
| **Encounter** | Terrain clearing, barriers | Trash fight (Lurkers / Spewers), modest salvage |
| **Elite** | Ring structure | Hard fight (Hive Caller), guaranteed module or implant + scrap |
| **Trader** | Cargo containers | Buy/sell modules / implants / stims / cell upgrades / remove a cell |
| **Shelter** | Tent + camp furniture | Heal 30% HP OR mutate a module OR upgrade a cell |
| **Anomaly** | Ring structure + spotlight | Random encounter — risk/reward, scan the unknown |
| **Apex** | Blood-moon sky shift | Expedition-ender — The Warden. Defines what your board needs to handle |

Player picks a path through the map. Hero run/hop/jetpack anims play during map traversal. Standard STS pacing: you can't take every node, you have to commit.

**Vertical slice scope:** 4–6 nodes, 1 elite, 1 apex. ~15 minute expedition. Enough to feel turn-to-turn socketing AND between-encounter build choices.

---

## Build Axes — Six Modifier Pools

The roguelite identity. All six pools live simultaneously. No specific items committed — these are the *shapes* the design supports.

### 1. Ability Modules — the board itself

The headline axis. You start with a small loadout (e.g. Plasma Jab, Barrier, Plasma Lance, Arc Sweep) and salvage more. Each module is a complete unit: sockets + effect. The board *is* your build.

### 2. Module Mutations — modify modules on your board

See the section above. Loosen sockets, add sockets, change effects. The slow-burn axis that personalizes your starting loadout. Earned at shelters, anomalies, and elite/apex rewards.

### 3. Implants — passive effects (Balatro Jokers / STS Relics)

Slot-limited passives the drifter has scavenged and wired into their suit. Examples of the *shape*:
- "+3 damage on every module that fires this turn"
- "First reroll each turn is free"
- "When a module fires with all-even cells, generate a stim"
- "Sockets fill 'wild' on the first turn of an encounter"

### 4. Cell Upgrades — modify individual power cells

Specific cells get modified at traders or shelters. Each becomes physically distinct in the tray.
- **Weighted** — biased toward high faces
- **Foil** — fires a bonus effect whenever socketed
- **Holo** — multiplies the firing module's effect
- **Face-changed** — replace one or more faces (e.g. cell with two 6s, no 1s)
- **Wild** — fits any socket
- **Echo** — when socketed, also counts toward another socket on the same module

### 5. Add / Remove Cells — alter the pool

The action-economy axis. More cells = more sockets you can fill per turn = more modules firing.
- Start with 5 cells (d6)
- Add a 6th cell → fire more modules per turn, or comfortably fill a 4-socket module and still have cells left over
- Add a d8 cell → higher pip ceiling, harder to straight
- Remove a cell at shelters — smaller pool, cleaner choices
- Corrupted cells — extra cell that always rolls something annoying, but pays out elsewhere

### 6. Stims — one-shot consumables

Used at any moment during your turn. Carry-limited slots.
- "Reroll any one cell to any face"
- "Mutate a module (one tier)"
- "Wild any one cell for this turn"
- "Refresh your reroll budget"
- "Skip a creature's next intent"
- "Repair 10 HP"

---

## The Combinatorial Pitch

An expedition is interesting because the axes compound on the board. Every loadout is a story about how the modules reshape themselves.

Example **Glass Cannon**: *Salvage "Orbital Strike" (3 sockets, must all match, massive damage). Mutate to loosen from exact-match to "any 4+". Face-change two cells to be high-only. Implant "module firings deal +5 splash." Now most turns you fire Orbital Strike with one reroll and still have 2 cells left for Barrier. Supercharged slash plays on fire — earned it.*

Example **Tempo Spammer**: *Mutate Plasma Jab from "1 any socket" into "1 any-cell socket" + an implant "first module of each turn costs no cells." Now every turn opens with a free Jab, then you spend all 5 cells across your other modules. 3–4 firings per turn, every turn.*

Example **Straight Specialist**: *Take "Cascade" (4 sockets, must form a sequence). Mutate to accept 2-3-4-5 as well as 1-2-3-4. Face-change two cells to fill the gaps. Most turns you dump 4 cells into Cascade and fire it, with 1 spare for a Jab. One reroll usually gets you there.*

Example **Tinkerer**: *Don't commit to any one module. Mutate everything once. Pile up implants that buff "any module firing." Generalist loadout that wins on firing volume — 5 cells across 3–4 cheap modules every turn.*

---

## Tone — "Just One More Roll"

The pull is the expedition's emergent loadout. The drama is cells tumbling, finding a 6 you've been waiting for, and snapping it into the last socket. The hook is whether your mutated board can take down the Warden before it shreds you.

**Visual:**
- 2D pixel art (penusbmic style). Planet One barren landscape as backdrop, palette shifting day → dusk → blood-moon as expedition deepens.
- Drifter (hero sprite) on the left in idle stance. Plays attack anims (combo/blaster/slash) when modules fire. Plays damaged/knockback when hit.
- Creature on the right with HP bar, intent icon, status pips. Plays idle loop; attack anim on its turn.
- Ability modules in a row across the middle of the screen; sockets visible on each module.
- Free cells tumble in a physics tray below (3D SubViewport); player drags them up into sockets.
- Socketed cells visually pop into the module frame (slight glow / settle anim).
- Module firing: cells flash, fly off, drifter plays the mapped attack anim, effect resolves (damage numbers, shield icon, etc.), sockets reset.
- Implants on the side as a loadout sheet; reroll counter visible near the tray.

**Sound:**
- Physical dice clacking against tray walls
- A satisfying "settle" tick when each cell comes to rest
- A "click-snap" when a cell enters a socket
- A "fanfare" scaling with input difficulty when a module fires
- Creature intent telegraph "click" when it locks in

**The hooks:**
- "I rolled a pair of 5s — do I fire Plasma Lance (3-match, need one more 5) or split them across Barrier and Jab for safe tempo?"
- "One reroll left. If I hit a 4 I complete Cascade and fire it this turn. If I miss I've wasted two cells on a half-loaded module."
- "The Warden's magnetic pulse ejects a socketed cell — I need modules that fire fast before it disrupts me"
- "Expedition 7: I finally see why Echo cells break the socket economy"

---

## Open Questions (Deferred Until Prototype Plays)

- **Characters** — different starting loadouts and mutation pools. Out of scope for vertical slice; one drifter first.
- **Specific item lists** — concrete modules / implants / mutations / stims wait until the socket system is real and tunable.
- **Numbers** — damage formula, HP totals, creature intents, reroll budget all tunable after first playable.
- **Module slot cap** — starts at ~4, grows to ~6; final cap TBD.
- **Mutation cap per module** — should there be a limit, or can a module be mutated infinitely? Default: limit, TBD.
- **Expedition count / map size** — vertical slice is one expedition; full game length TBD.
- **Death severity** — full reset (STS) vs partial carryover? Default to full reset for prototype.
- **Multi-turn persistence** — socketed cells carry over between turns, but how often should this actually matter? If most modules fire in one turn, is persistence just a comfort feature or does it need dedicated design space (e.g. modules that explicitly reward slow-loading)?
