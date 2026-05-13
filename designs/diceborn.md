# Diceborn

A roguelite score-chase dice game. Roll five dice Yahtzee-style, score points from poker-like combinations, beat each floor's target. Build a run by upgrading specific combos, modifying individual dice, swapping dice in and out of your set, and collecting passive charms. Working title; theme deferred.

**Engine:** Godot 4.6 (2D UI + 3D physics dice in SubViewport)
**Assets:** Programmer art for prototype; theme/style deferred
**Genre:** Roguelite / Score-chase dice
**Inspirations:** Balatro, Yahtzee, Dice Throne (combinations shape), Slay the Spire (run structure)

---

## Core Loop

```
Roll 5 dice → lock some, reroll up to 2 more times → score a combination → repeat
Hit floor's target score within N turns → win the floor → choose a reward
3 floors → boss → next "ante" with higher targets → eventual run end
Die / quit → earn meta-currency → unlock new charms/dice/consumables → new run
```

**Primary resources (per run):**
- **Turns** — fixed budget per floor; running out before hitting target = lose run
- **Rerolls** — 2 per turn baseline (3 total rolls); modifier-extendable
- **Gold** — earned per floor, spent in between-floor shops

**Prestige resource:** TBD (something like Balatro's vouchers/stickers — permanent unlocks across runs).

---

## Rolling — Yahtzee Rhythm

| Step | Action |
|---|---|
| 1 | First roll: all 5 dice tumble in the physics tray |
| 2 | Click dice to toggle lock |
| 3 | Reroll unlocked dice (rerolls remaining: 2 → 1 → 0) |
| 4 | Commit early any time, OR reroll until rerolls run out |
| 5 | Score the final combination — points added to floor total |
| 6 | Next turn |

Dice are real `RigidBody3D` objects in a SubViewport, rendered into the 2D HUD. Tactile, tumbling, settle-and-read. (Pattern lifted from `life-magic/scripts/ui/wizard_3d.gd`.)

---

## Scoring — Escalating Combinations

Dice Throne-shaped combination ladder: rarer/harder patterns score more. Players specialize via upgrades that level up specific combinations (the Balatro "play this hand to level it up" axis).

| Combination | Example | Base Score | Notes |
|---|---|---|---|
| **Pair** | `5 5 _ _ _` | Low | The "I rolled nothing" floor |
| **Two Pair** | `5 5 3 3 _` | Low+ | Stepping stone |
| **Three of a Kind** | `5 5 5 _ _` | Mid | First "real" score |
| **Small Straight** | `1 2 3 4 _` | Mid+ | Utility / setup |
| **Full House** | `5 5 5 3 3` | High | Combo-rich |
| **Four of a Kind** | `5 5 5 5 _` | High+ | Burst |
| **Large Straight** | `1 2 3 4 5` | Very High | Builder favorite |
| **Yahtzee** (5 of a kind) | `5 5 5 5 5` | Top | Run-defining "moment" |

**Score formula** (working draft, tunable):
```
score = base_for_combination × (1 + sum_of_dice_pips / 10) × charm_multipliers
```
The pip-sum factor means a Yahtzee of 6s beats a Yahtzee of 1s; mirrors Balatro's chips-times-mult feel without literally copying it.

**Combination upgrades** (the specialize-or-generalize axis):
- "Level 2 Full House" → adds +X base score every time you score a Full House
- Levels persist for the rest of the run
- Picking up a level for a niche combo (e.g. Small Straight) and then building dice modifications to reliably hit it is a viable build path

---

## The Run — Linear Floors with Bosses

Each run is a sequence of floors. Each floor has a **target score** to beat within a **turn budget**.

| Floor | Target Difficulty | Reward Type |
|---|---|---|
| Floor 1 trash | Low | Charm OR Consumable |
| Floor 2 trash | Low+ | Combination upgrade |
| Floor 3 boss | Mid (with twist condition) | Major: charm + dice modification choice |
| Shop / Rest | — | Spend gold; choose rest (heal turns/rerolls) or upgrade |
| Floor 4–6 | Escalating | Mixed |
| Floor 7 boss | Hard (heavier twist) | Major |
| ... | ... | ... |

**Boss twists** make bosses feel different from trash floors. Examples (not committed):
- "Only odd-numbered combinations count toward score"
- "Each turn, one random die face is locked at 1 until rerolled"
- "Turn budget is halved, but base scores are doubled"

**Vertical slice scope:** 1 floor + 1 boss. ~10 minute slice. Enough to feel the loop; not enough content to commit theme/balance.

---

## Build Axes — Four Modifier Categories

The roguelite identity. Players combine modifiers from four pools, all live simultaneously. No specific items committed yet — these are the categories the design supports.

### 1. Charms / Relics — passive effects (Balatro Jokers)

Slot-limited collection of passive modifiers. Examples of the *shape* of effect, not committed items:
- "+10 base score on every Full House"
- "First reroll each turn is free"
- "If all 5 dice show even numbers, score ×1.5"
- "Score 5 extra for every locked die at score-time"

### 2. Die Upgrades — modify individual dice (enchanted cards)

Applied to specific dice in your set. The die becomes physically distinct in the tray (different material/glow).
- **Weighted** — biased toward high faces
- **Foil** — adds flat score when included in a scored combination
- **Holo** — adds multiplier when included
- **Face-changed** — replace one or more faces (e.g. die with two 6s and no 1)
- **Wild** — substitutes for any value when matching patterns
- **Echo** — when its face matches another die, triggers a bonus

### 3. Add / Remove Dice — alter the dice set

Changes the fundamental probability space.
- Start with 5d6
- Buy a 6th die (score with any 5 of your 6)
- Swap a d6 for a d8 (higher pip range, harder to straight)
- Remove a die you don't like (smaller pool, more controllable)

### 4. Consumables — one-shot effects (Tarots / Planets)

Used at specific moments. Carry-limited slots.
- "Reroll any one die to any face"
- "Level up a combination by one"
- "Turn one die into a wild for this turn"
- "Add a free reroll to this turn"
- "Convert this turn's score to gold 1:1"

---

## The Combinatorial Pitch

A run is interesting because the four axes interact:
- **Charms** that reward specific combos
- **Combination upgrades** that scale those specific combos
- **Die upgrades / set changes** that warp probability toward those combos
- **Consumables** that paper over bad luck on key turns

A run might be: *"Level Full House twice → charm 'doubles Full House score on full-pip hands' → swap one d6 for a die with face `5 5 5 6 6 6` → Holo-upgrade two more dice → goal is to roll Full Houses of high faces every turn."* That's a build.

---

## Future Pivot Option — Dice Throne Combat

The score-target loop is the **primary direction**. The architecture should leave room to pivot to Dice Throne-style combat later if score-chase doesn't feel right.

**What that pivot would look like** (informational, not the current scope):
- Floors become enemy duels with HP instead of score targets
- Combinations become abilities (Pair = block, Yahtzee = ultimate damage)
- Charms apply during combat; same shape, different effects
- Enemies have telegraphed intents (Slay the Spire style)

The pivot is feasible because the four-axis modifier system, dice physics, and combination-ladder all transfer wholesale. Only the per-turn "what does the combination do" mapping changes.

---

## Tone — "Just One More Roll"

The pull is the run's emergent build. The drama is in the dice settling and reading the result. The hook is "if my next charm interacts with my last one, the run might break the score curve."

**Visual:**
- 2D UI with physics-rolled 3D dice tumbling in a small tray
- Score numbers fly off the dice when they land in a scoring combo
- Charms and combination levels visible as a build sheet at the side
- Floor target as a bar that fills with each scored turn

**Sound:**
- Physical dice clacking against tray walls
- A satisfying "settle" tick when each die comes to rest
- Score-rack ascending pings as combinations resolve
- Quiet floor between turns; tension as turns dwindle

**The hooks:**
- "If I level Full House once more and pick up Holo dice, I clear the next floor in 2 turns"
- "Almost a Yahtzee — one consumable would clinch it"
- "Did the boss-twist break my build? Can I salvage with this charm?"
- "Run 7: I finally understand why Echo dice matter"

---

## Open Questions (Deferred Until Prototype Plays)

- **Theme & art** — generic dice for prototype; pick after the loop is fun.
- **Project name** — "Diceborn" is a working title.
- **Specific item lists** — categories are scoped; concrete items wait until pattern matcher + scoring math are real.
- **Score formula** — the chips-times-pip-multiplier draft will need playtest tuning.
- **Run length** — number of floors per run TBD.
- **Prestige currency design** — needs the run-end loop to exist first.
- **Multi-target vs single-pile** — currently score is one running total per floor; could imagine multiple "lanes" later.
