# Diceborn

A roguelite dice combat game. You have a **board of ability cards**, each with sockets that accept specific dice. Roll five dice Yahtzee-style, then drag dice into sockets at your own pace — when an ability's sockets are all filled, it fires and consumes the dice. Rerolls are a budget you spend across the turn. Fight enemies on a Slay-the-Spire-style run map and grow your board across the run. Working title; theme deferred.

**Engine:** Godot 4.6 (2D UI + 3D physics dice in SubViewport)
**Assets:** Programmer art for prototype; theme/style deferred
**Genre:** Roguelite / Dice combat
**Inspirations:** Slay the Spire (run shape, intents), Dice Throne (abilities), Balatro (rerolls as resource, ability leveling), Yahtzee (the roll itself)

---

## Core Loop

```
Enter combat → enemy telegraphs intent
  ↓
Your turn opens:
  • All FREE dice (unsocketed) auto-roll
  • Reroll budget refreshes (e.g. 2)
  • SOCKETED dice from earlier turns stay where they are
  ↓
Play at your own pace, in any order:
  • Drag a free die into any compatible socket
  • When all sockets on an ability fill → it FIRES, dice consumed, sockets clear
  • Spend a reroll → all currently-free dice tumble again
  • Pull a consumable
  ↓
End turn when satisfied (or when rerolls are gone and nothing more fits)
  ↓
Enemy turn: resolves telegraphed intent
  ↓
Repeat until one HP hits 0
  ↓
Win → loot (ability OR charm OR die upgrade OR consumable OR gold) → back to map
Map → choose next node (combat / elite / shop / rest / event / boss)
  ↓
Beat act boss → next act with higher numbers → eventual run end
Die → meta unlocks → new run
```

**The core tension:** sockets persist across turns. A 5-socket ultimate can charge over 2–3 turns while you spam a 1-socket Strike every turn. Do you starve your big ability to keep tempo, or commit dice now and weather the next enemy hit?

**Primary resources (per combat):**
- **HP** — yours and the enemy's
- **Rerolls** — refreshes each turn (default 2 beyond the free auto-roll)
- **Block** — STS-style temporary armor, expires at start of your next turn

**Primary resources (per run):**
- **HP** — persists between combats; small heals at rest sites
- **Gold** — earned per combat, spent at shops
- **Consumables** — limited inventory slots
- **Your ability board** — grows and mutates as you progress

**Prestige:** Meta-currency on death unlocks new abilities / charms / dice / consumables / characters for the pool.

---

## The Dice

| Property | Default |
|---|---|
| Starting pool | 5d6 |
| Roll model | `RigidBody3D` in a SubViewport (pattern from `life-magic/scripts/ui/wizard_3d.gd`) |
| Free dice | Tumble in the tray, can be socketed or rerolled |
| Socketed dice | Visually snap into the ability card, immune to rerolls |
| Auto-roll | All free dice roll at start of each of your turns |

That's it. No "lock toggle" — socketing *is* locking. The board is the only commitment surface.

---

## The Ability Board

The center of the screen. A row (or grid) of **ability cards** you've collected. Each card has a name, an effect, and 1–5 sockets. Dice snap into sockets; when full, the card fires.

**Anatomy of an ability card:**

```
┌─────────────────────────────┐
│  HEAVY STRIKE               │
│  [ ▢ ][ ▢ ][ ▢ ]            │   ← three sockets, "must all match"
│  Deal 8 + (3 × pip) damage  │
└─────────────────────────────┘
```

**Socket requirements** (the design space):

| Requirement | Example | Notes |
|---|---|---|
| **Any** | accepts any die | The basic Pip / utility socket |
| **Specific face** | accepts only a `6` | Highest-impact, hardest to fill |
| **Range** | accepts `4–6` | "High die" |
| **Parity** | accepts only even / only odd | Easier to upgrade into |
| **Match other sockets** | accepts whatever already filled the matched sockets | The classic "pair / three of a kind" pattern |
| **Sequence with other sockets** | accepts N+1 of an already-socketed N | Straights |
| **Sum** | accepts dice that sum to X across the card | Lets the player route any combo |

A "Pair Block" is two `Match-other` sockets. A "Three of a Kind Strike" is three. A "Small Straight" is four `Sequence` sockets. A "Yahtzee Ultimate" is five `Match`. But abilities can also be weirder: "Spend any two even dice" is a perfectly cromulent ability.

**Firing:** when the last socket fills, the card resolves immediately (visually: dice fly off, effect animates), then sockets reset to empty.

**Slot cap:** the board holds N abilities at once (start with ~4, grow to ~6). Picking up a 7th forces a swap or destroy.

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

Upgrades come from rest sites, events, shops, and elite/boss rewards. The same ability can take many shapes by the end of a run — and characters (future scope) start with different mutation pools, so a "Berserker" might only loosen toward high dice, while a "Tactician" only adds sockets.

---

## Enemies — Simple HP Sponges with Intents

Slay-the-Spire-style. Enemies have HP, telegraphed intent each turn, and a small behavior pattern. Keep it dumb-but-readable.

| Intent | Display | Behavior |
|---|---|---|
| **Attack** | Sword + number | Deal that much damage on its turn |
| **Defend** | Shield + number | Gain block |
| **Buff** | Up-arrow | Self-buff (strength/regen/etc.) |
| **Debuff** | Down-arrow | Apply weak/vulnerable to you |
| **Special** | ? | Telegraphed unique move (e.g. boss combo) |

**Trash enemies:** 1–2 intents on a loop, low HP, exist to drain resources between elites.
**Elites:** Bigger HP, 3+ intents, a signature mechanic. Drop a guaranteed ability or charm.
**Bosses:** Act-defining unique mechanics that mess with the board (e.g. "every turn, one random socket on your board becomes empty"). Drop a major reward.

**Status effects** (small, reused both directions):
- **Weak** — your damage halved this turn
- **Vulnerable** — incoming damage +50%
- **Strength** — +X to all damage from a source
- **Regen** — heal at turn end

---

## The Run — Slay the Spire Map

A branching node map per act. Three acts to start. (Vertical slice = first act only.)

| Node | Effect |
|---|---|
| **Combat** | Trash fight, modest reward |
| **Elite** | Hard fight, guaranteed ability or charm + gold |
| **Shop** | Buy abilities / charms / consumables / die upgrades / remove a die |
| **Rest** | Heal 30% HP OR mutate an ability OR upgrade a die |
| **Event** | Random encounter — risk/reward, narrative beats once theme lands |
| **Boss** | Act-ender — defines what your board needs to handle |

Player picks a path through the map. Standard STS pacing: you can't take every node, you have to commit.

**Vertical slice scope:** 4–6 nodes, 1 elite, 1 boss. ~15 minute slice. Enough to feel turn-to-turn socketing AND between-combat build choices.

---

## Build Axes — Five Modifier Pools

The roguelite identity. All five pools live simultaneously. No specific items committed — these are the *shapes* the design supports.

### 1. Abilities — the board itself

The headline axis. You start with a small set (e.g. Strike, Block, Heavy Strike, Cleave) and collect more. Each is a complete unit: sockets + effect. The board *is* your build.

### 2. Ability Mutations — modify cards on your board

See the section above. Loosen sockets, add sockets, change effects. The slow-burn axis that personalizes your starting abilities.

### 3. Charms / Relics — passive effects (Balatro Jokers / STS Relics)

Slot-limited passives. Examples of the *shape*:
- "+3 damage on every ability that fires this turn"
- "First reroll each turn is free"
- "When an ability fires with all-even dice, draw a consumable"
- "Sockets fill 'wild' on the first turn of combat"

### 4. Die Upgrades — modify individual dice

Specific dice get marked up. Each becomes physically distinct in the tray.
- **Weighted** — biased toward high faces
- **Foil** — fires a bonus effect whenever socketed
- **Holo** — multiplies the firing ability's effect
- **Face-changed** — replace one or more faces (e.g. die with two 6s, no 1s)
- **Wild** — fits any socket
- **Echo** — when socketed, also counts toward another socket on the same card

### 5. Add / Remove Dice — alter the pool

The action-economy axis. More dice = more sockets you can fill per turn = more abilities firing.
- Start with 5d6
- Add a 6th die → can charge a 5-socket Ultimate while still firing a 1-socket Strike each turn
- Add a d8 → higher pip ceiling, harder to straight
- Remove a die at rest sites — smaller pool, cleaner choices
- Cursed dice — extra die that always rolls something annoying, but pays out elsewhere

### 6. Consumables — one-shot effects (Tarots / Potions)

Used at any moment. Carry-limited slots.
- "Reroll any one die to any face"
- "Mutate an ability (one tier)"
- "Wild any one die for this turn"
- "Refresh your reroll budget"
- "Skip an enemy's next intent"
- "Heal 10 HP"

---

## The Combinatorial Pitch

A run is interesting because the axes compound on the board. Every build is a story about how the abilities reshape themselves.

Example **Charge Engine**: *Pick up "Apocalypse" (5 sockets, must all be 6s, massive damage). Mutate twice to loosen sockets to "any 5+". Face-change two dice to be high-only. Charm "ability firings deal +5 splash damage." Spend 2 turns loading Apocalypse and fire it every third turn while chipping with Pip cards in between.*

Example **Tempo Spammer**: *Mutate Strike from "1 any socket" into "1 any-die socket" + a charm "first ability of each turn costs no dice." Now every turn opens with a free Strike, then I spend dice on actual abilities. 7 dice means 3 firings per turn.*

Example **Straight Specialist**: *Take "Cascade" (4 sockets, must form 1-2-3-4). Mutate to allow 2-3-4-5 too. Face-change two dice to fill the gaps. Add a die. Every turn I fire Cascade plus a free Pip from the spare die.*

Example **Tinkerer**: *Don't commit to any ability. Mutate everything once. Pile up charms that buff "any ability firing." Generalist build that wins on action volume.*

---

## Tone — "Just One More Roll"

The pull is the run's emergent board. The drama is dice tumbling, finding a 6 you've been waiting for, and snapping it into the last socket. The hook is whether your mutated board outpaces the act-3 boss.

**Visual:**
- 2D UI. Ability cards in a row across the middle of the screen; sockets visible on each card.
- Free dice tumble in a physics tray below; player drags them up into sockets.
- Socketed dice visually pop into the card outline (slight glow / settle anim).
- Card firing: dice flash, fly off, effect animates (damage numbers, block icon, etc.), sockets reset.
- Enemy on the right with HP bar, intent icon, status pips.
- Charms on the side as a build sheet; reroll counter visible near the tray.

**Sound:**
- Physical dice clacking against tray walls
- A satisfying "settle" tick when each die comes to rest
- A "click-snap" when a die enters a socket
- A "fanfare" scaling with ability tier when a card fires
- Enemy intent telegraph "click" when it locks in

**The hooks:**
- "If I socket this 6 into Apocalypse now, I'm one die away from firing it next turn"
- "Drop Pip Strike from my board for Cascade — the Cascade mutation makes it auto-fill"
- "Boss empties a socket every turn — better take low-socket abilities into this fight"
- "Run 7: I finally see why Echo dice break the socket economy"

---

## Open Questions (Deferred Until Prototype Plays)

- **Theme & art** — generic dice for prototype; pick after the board feels good.
- **Project name** — "Diceborn" is a working title.
- **Characters** — different starting boards and mutation pools. Out of scope for vertical slice; one default character first.
- **Specific item lists** — concrete abilities / charms / mutations / consumables wait until the socket system is real and tunable.
- **Numbers** — damage formula, HP totals, enemy intents, reroll budget all tunable after first playable.
- **Ability slot cap** — starts at ~4, grows to ~6; final cap TBD.
- **Mutation cap per ability** — should there be a limit, or can a card be mutated infinitely? Default: limit, TBD.
- **Act count / map size** — vertical slice is one act; full game length TBD.
- **Death severity** — full reset (STS) vs partial carryover? Default to full reset for prototype.
