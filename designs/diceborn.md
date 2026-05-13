# Diceborn

A roguelite dice combat game. Roll five dice Yahtzee-style, turn the combination you make into an attack or defense, fight enemies on a Slay-the-Spire-style run map. Survive a sequence of combats, build a dice loadout, beat the act boss. Working title; theme deferred.

**Engine:** Godot 4.6 (2D UI + 3D physics dice in SubViewport)
**Assets:** Programmer art for prototype; theme/style deferred
**Genre:** Roguelite / Dice combat
**Inspirations:** Slay the Spire (run shape, intents), Dice Throne (combinations as abilities), Yahtzee (the roll itself)

---

## Core Loop

```
Enter combat → enemy telegraphs intent
  ↓
Your turn: roll 5 dice, lock some, reroll up to 2x
  ↓
Final combination → triggers an action (attack / block / utility)
  ↓
Enemy turn: resolves telegraphed intent → damages you / debuffs / heals self
  ↓
Repeat until one HP hits 0
  ↓
Win → loot (charm OR die upgrade OR consumable OR gold) → back to map
Map → choose next node (combat / elite / shop / rest / event / boss)
  ↓
Beat act boss → next act with higher numbers → eventual run end
Die → meta unlocks → new run
```

**Primary resources (per combat):**
- **HP** — yours and the enemy's
- **Rerolls** — 2 per turn baseline (3 total rolls)
- **Block** — STS-style temporary armor, expires at start of your next turn

**Primary resources (per run):**
- **HP** — persists between combats; small heals at rest sites
- **Gold** — earned per combat, spent at shops
- **Consumables** — limited inventory slots

**Prestige:** Meta-currency on death unlocks new charms / dice / consumables for the pool.

---

## Rolling — Yahtzee Rhythm

| Step | Action |
|---|---|
| 1 | First roll: all 5 dice tumble in the physics tray |
| 2 | Click dice to toggle lock |
| 3 | Reroll unlocked dice (rerolls remaining: 2 → 1 → 0) |
| 4 | Commit early any time, OR reroll until rerolls run out |
| 5 | The final combination determines your action — resolve it |
| 6 | Enemy turn |

Dice are `RigidBody3D` objects in a SubViewport, rendered into the 2D HUD. Tactile, tumbling, settle-and-read. (Pattern lifted from `life-magic/scripts/ui/wizard_3d.gd`.)

---

## Combinations → Actions

This is the Dice Throne shape: every combination is a thing-you-can-do. Players never "fail to score" — even nothing-rolls do something small. The combination ladder defines power level.

| Combination | Example | Default Action | Power |
|---|---|---|---|
| **High Die** (no pattern) | `6 4 3 2 1` | Flick — tiny damage = highest die pip | Filler |
| **Pair** | `5 5 _ _ _` | Block = pair value × 2 | Defensive option |
| **Two Pair** | `5 5 3 3 _` | Strike — moderate damage | Workhorse |
| **Three of a Kind** | `5 5 5 _ _` | Heavy Strike — bigger damage, scales with pip | Real threat |
| **Small Straight** | `1 2 3 4 _` | Utility — draw consumable / cycle a die / debuff | Tempo |
| **Full House** | `5 5 5 3 3` | Cleave — damage to all enemies | AoE |
| **Four of a Kind** | `5 5 5 5 _` | Crusher — burst damage, ignores block | Burst |
| **Large Straight** | `1 2 3 4 5` | Tactical — big damage + apply weak/vulnerable | Setup combo |
| **Yahtzee** | `5 5 5 5 5` | Ultimate — massive damage + signature effect | The moment |

**Damage formula** (working draft, tunable):
```
damage = base_for_combination × (1 + sum_of_relevant_pips / 10) × charm_multipliers
```
Higher pips = more damage, so a Three-of-a-Kind 6s is meaningfully stronger than 1s.

**Combination upgrades** (the specialize-or-generalize axis, Balatro-style):
- "Level 2 Full House" → adds +X damage every time you trigger a Full House
- Levels persist for the rest of the run
- A run might commit to leveling Small Straights, then stacking dice modifications that make straights reliable
- Some upgrades **change the action** (e.g. "Full House now hits twice for half damage" — better with on-hit charms)

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
**Elites:** Bigger HP, 3+ intents, a signature mechanic. Drop a guaranteed charm.
**Bosses:** Act-defining unique mechanics (e.g. "every turn one of your dice is locked at 1 until rerolled"). Drop a major reward.

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
| **Elite** | Hard fight, guaranteed charm + gold |
| **Shop** | Buy charms / consumables / die upgrades / remove a die |
| **Rest** | Heal 30% HP OR upgrade a die OR level a combination |
| **Event** | Random encounter — risk/reward, narrative beats once theme lands |
| **Boss** | Act-ender — defines what built the deck/loadout needs to handle |

Player picks a path through the map. Standard STS pacing: you can't take every node, you have to commit.

**Vertical slice scope:** 4–6 nodes, 1 elite, 1 boss. ~15 minute slice. Enough to feel turn-to-turn rolling AND between-combat build choices.

---

## Build Axes — Four Modifier Categories

The roguelite identity. All four pools live simultaneously. No specific items committed yet — these are the *shapes* the design supports.

### 1. Charms / Relics — passive effects (Balatro Jokers / STS Relics)

Slot-limited collection of passives. Examples of the *shape*:
- "+3 damage on every Full House"
- "First reroll each turn is free"
- "Gain 5 block at start of each turn"
- "When you roll a Yahtzee, heal 5 HP"

### 2. Die Upgrades — modify individual dice

Specific dice in your set get marked up. Each becomes physically distinct in the tray (different material / glow).
- **Weighted** — biased toward high faces
- **Foil** — adds flat damage when included in a triggered combination
- **Holo** — adds multiplier when included
- **Face-changed** — replace one or more faces (e.g. die with two 6s, no 1s)
- **Wild** — substitutes for any value when forming combinations
- **Echo** — when its face matches another die, triggers a bonus

### 3. Add / Remove Dice — alter the set

Changes the fundamental probability space.
- Start with 5d6
- Buy a 6th die (combinations form from any 5 of your 6)
- Swap a d6 for a d8 (higher range, harder to straight)
- Remove a die at rest sites (smaller pool, more controllable)
- Cursed dice — extra die that always rolls something annoying, but pays out elsewhere

### 4. Consumables — one-shot effects (Tarots / Potions)

Used at specific moments. Carry-limited slots.
- "Reroll any one die to any face"
- "Level up a combination by one"
- "Turn one die into a wild for this turn"
- "Add a free reroll to this turn"
- "Skip an enemy's next intent"
- "Heal 10 HP"

---

## The Combinatorial Pitch

A run is interesting because the four axes interact with the combination-as-action layer.

Example build: *Level Full House twice → charm "Full House also applies Vulnerable" → swap a d6 for a die that rolls only 4–6 → Holo two more dice → I throw Cleaves every turn, soften everything, win Act 1.*

Another: *Level Small Straight three times → die-face-change two dice so the pool can always straight → consumable "turn die into a wild" → Small Straight becomes my engine, I draw consumables every turn, I outlast bosses.*

Another: *Don't specialize. Charm "+X damage to the lowest-power combination you played last turn" → mixed-output build that punishes whatever the enemy didn't expect.*

---

## Tone — "Just One More Roll"

The pull is the run's emergent build. The drama is dice tumbling and reading the result against an enemy intent. The hook is whether the charms you've picked up combine into a build that breaks the run's curve.

**Visual:**
- 2D UI with physics-rolled 3D dice tumbling in a small tray
- Enemy on the right with HP bar, intent icon, and status pips
- Charms on the side as a build sheet
- Damage / block numbers fly off dice when the combination resolves

**Sound:**
- Physical dice clacking against tray walls
- A satisfying "settle" tick when each die comes to rest
- Combination resolution sound that scales with the ladder (Pair = soft, Yahtzee = thunder)
- Enemy intent telegraph "click" when it locks in

**The hooks:**
- "If I commit to Full House this run and the next charm rewards AoE, the boss is dead"
- "Almost a Yahtzee — burn a consumable to clinch it?"
- "Did the boss's intent-lock break my build? Can I still salvage with a Small Straight engine?"
- "Run 7: I finally understand why Echo dice matter"

---

## Open Questions (Deferred Until Prototype Plays)

- **Theme & art** — generic dice for prototype; pick after combat feels good.
- **Project name** — "Diceborn" is a working title.
- **Specific item lists** — categories are scoped; concrete charms / dice / consumables wait until the combination-to-action system is real.
- **Numbers** — damage formula, HP totals, enemy intent values all tunable after first playable.
- **Act count / map size** — vertical slice is one act; full game length TBD.
- **Player HP scaling** — flat per run? Upgradeable via meta? TBD.
- **Death severity** — full reset (STS) vs partial carryover? Default to full reset for prototype.
