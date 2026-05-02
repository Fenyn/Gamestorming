# Essence Tree — Progression Design

## Overview

Replace the flat blessing list with a branching **Essence Tree** — a visual
node graph where players spend Essence (prestige currency) to unlock and
upgrade permanent bonuses. Inspired by CIFI's Loop Mods tree: 150+ multi-level
nodes across 10 category branches, each branch radiating from a central root,
with chained prerequisites creating strategic depth.

### Design goals

1. **Strategic choice.** Players can't buy everything after one prestige — they
   must choose which branch to invest in, creating distinct build identities.
2. **Visual progression.** A zoomable/pannable node graph shows the full tree
   with locked nodes dimmed, giving players clear long-term goals.
3. **Incremental depth.** Nodes have multiple levels, so players revisit the
   tree each prestige cycle to deepen existing branches or start new ones.
4. **Thematic coherence.** Branches map to the game's heart-rate / nature
   themes, not generic "damage +5%."

### Core principles (inviolable)

- **1:1 heartbeat.** The game tick IS the player's heartbeat. No node may
  alter the HR-to-tick relationship, the HR speed factor curve, or the HR
  safety cap. These are physics, not upgrades.
- **No HR incentives.** No node may reward being in a specific HR zone or
  penalize another. The dynamic heartbeat — whatever pace the player is
  living at — is the game's core identity.
- **Health safety is not gameplay.** The HR cap percentage, max HR formula,
  and resting HR estimate exist for safety. They are never exposed as
  upgradeable parameters.
- **Verified actions only.** Effects gated on movement/steps must come from
  Health Connect or equivalent APIs. No self-reported or tap-to-confirm
  mechanics.

---

## Prestige & Currency

### When can the player prestige?

**Old design:** Full Spectrum milestone (all 5 tiers active = 200M+ mana).
This is far too late — the tree IS the progression system, not a postgame
reward. Prestige should be a frequent, lightweight action.

**New design:** Prestige unlocks when the player **purchases their first
Lifebound Familiar** (tier 2 generator). This requires ~5000 total mana
earned to unlock the tier, plus enough mana to buy one (15K). In practice
this takes 20-30 minutes — long enough that the player has seen Heartmotes
and Pulse Glyphs cascading, understands the production chain, and just
experienced the "generators producing generators" moment for the first
time. The prestige option appears right when the game's core loop clicks.

The player is never *forced* to prestige. They can keep pushing for higher
tiers to earn more essence per cycle. But the option is there once they've
grasped the fundamentals, and the tree makes short runs rewarding.

### Essence formula

**Old:** `floor(sqrt(total_mana_earned / 1,000,000))` — first essence at 1M
mana. Way too late.

**New:** `floor(sqrt(total_mana_earned / 1000)) * (1 + essence_bonus)`

| Total Mana Earned | Base Essence | With Echo L3 (+30%) |
|-------------------|-------------|---------------------|
| 1,000 | 1 | 1 |
| 4,000 | 2 | 2 |
| 10,000 | 3 | 3 |
| 50,000 | 7 | 9 |
| 100,000 | 10 | 13 |
| 500,000 | 22 | 28 |
| 1,000,000 | 31 | 40 |
| 10,000,000 | 100 | 130 |
| 100,000,000 | 316 | 410 |
| 1,000,000,000 | 1000 | 1300 |

**Short vs long runs:** A quick 15-minute cycle to 10K mana yields 3
essence. A committed 2-hour push to 1M mana yields 31 essence. The sqrt
curve means short runs are more *efficient per minute* for cheap nodes,
but long runs are necessary for expensive trunk-4 purchases. This creates
the same short-vs-long strategic tension that CIFI's loop system provides.

### Essence accumulation

Essence is **never reset**. It accumulates across all Life Cycles and is
the sole currency for the tree. The current flat-cost model stays for early
nodes; later nodes introduce scaling costs (cost increases per level).

---

## Generator Tiers (8 total)

The cascade chain extends from 5 to 8 tiers. The existing 5 tiers (0-4)
stay as-is. Three new tiers (5-7) extend the endgame and give the tree's
Verdant branch more to work with. Each higher tier feeds the one below it.

| Tier | Name | Base Cost | Cost Mult | Base Prod | Produces | Gate |
|------|------|-----------|-----------|-----------|----------|------|
| 0 | Heartmotes | 15 | 1.12 | 1.0 | Mana | None (free) |
| 1 | Pulse Glyphs | 300 | 1.14 | 0.5 | Tier 0 | Mana threshold (200) |
| 2 | Lifebound Familiars | 15K | 1.16 | 0.15 | Tier 1 | Mana threshold (5K) + unlocks prestige |
| 3 | Verdant Wardens | 5M | 1.19 | 0.05 | Tier 2 | **Warden Gate** (15 essence) |
| 4 | Heartfont Spires | 1.5B | 1.21 | 0.02 | Tier 3 | **Spire Gate** (35 essence) |
| 5 | Aether Conduits | 500B | 1.23 | 0.008 | Tier 4 | **Aether Gate** (60 essence) |
| 6 | Worldpulse Anchors | 200T | 1.25 | 0.003 | Tier 5 | **Worldpulse Gate** (90 essence) |
| 7 | Primordial Hearts | 100Qa | 1.27 | 0.001 | Tier 6 | **Primordial Gate** (120 essence) |

Tiers 0-2 are the "free loop" — available through mana thresholds alone.
Tiers 3-7 are gated behind Essence Tree nodes (Verdant branch). This
means the tree directly controls how deep the cascade can grow. The
player grinds short resets with tiers 0-2, accumulates essence, unlocks
tier 3, rides the production wave, grinds again for tier 4, etc. Each
gate is a breakthrough moment that transforms the game.

---

## Tree Structure

Five branches radiate from a central **Root Node**. Each branch has a
**trunk** (linear chain of 3-5 nodes) and **side paths** that fork off trunk
nodes. Side paths are optional specializations; the trunk carries the
"main line" progression for that branch.

```
                        [ROOT]
                          |
          ┌───────┬───────┼───────┬───────┐
          │       │       │       │       │
       VERDANT  PULSE   BLOOM  VITAL   ARCANE
       (Gen)   (Surge)  (Sanc) (Health) (Meta)
          │       │       │       │       │
         ...     ...     ...     ...     ...
```

### Branch: Verdant (Generators)

Focus: raw production, cascade mechanics, generator scaling, and unlocking
the three endgame generator tiers (5-7).

```
[Mana Magnetism]──→[Cascade Resonance]──→[Tier Mastery]──→[Infinite Growth]
        │                   │                   │
        ↓                   ↓                   ↓
  [Head Start]        [Echo Amplifier]    [Aether Gate]
        │                                       │
        ↓                                       ↓
  [Generator Memory]                      [Worldpulse Gate]
                                                │
  [Warden Gate]                                 ↓
        │                                 [Primordial Gate]
  [Spire Gate]
```

| Node | Trunk/Side | Max Lvl | Base Cost | Cost Scaling | Effect |
|------|-----------|---------|-----------|-------------|--------|
| Mana Magnetism | Trunk 1 | 10 | 3 | flat | +5% all production per level |
| Head Start | Side (from Magnetism) | 5 | 2 | flat | +200 starting mana per level |
| Generator Memory | Side (from Head Start) | 3 | 6 | flat | Unlock tier N at cycle start (level = tiers unlocked) |
| Warden Gate | Side (from Magnetism) | 1 | 15 | — | Unlock tier 3 (Verdant Wardens) generators |
| Spire Gate | Side (from Warden Gate) | 1 | 35 | — | Unlock tier 4 (Heartfont Spires) generators |
| Cascade Resonance | Trunk 2 | 8 | 8 | +2/lvl | +8% cascade echo chance per level |
| Echo Amplifier | Side (from Resonance) | 5 | 12 | +3/lvl | When cascade echo triggers, +20% bonus per level |
| Tier Mastery | Trunk 3 | 5 | 20 | +5/lvl | +15% production for highest unlocked tier per level |
| Aether Gate | Side (from Tier Mastery) | 1 | 60 | — | Unlock tier 5 (Aether Conduits) generators |
| Worldpulse Gate | Side (from Aether Gate) | 1 | 90 | — | Unlock tier 6 (Worldpulse Anchors) generators |
| Primordial Gate | Side (from Worldpulse Gate) | 1 | 120 | — | Unlock tier 7 (Primordial Hearts) generators |
| Infinite Growth | Trunk 4 | 3 | 50 | +15/lvl | Remove max level cap from one per-tier upgrade per level (tiers 0-2) |

**Prereqs:** Each trunk node requires the previous trunk node at level 1+.
Side nodes require their parent. Tier gates form two chains:
- **Early gates** (from Mana Magnetism): Warden (15) → Spire (35) = 50
  total essence for tiers 3-4. Reachable within the first ~18 cycles.
- **Late gates** (from Tier Mastery): Aether (60) → Worldpulse (90) →
  Primordial (120) = 270 total essence for tiers 5-7. Deep endgame
  investment spanning many cycles.

---

### Branch: Pulse (Surges)

Focus: surge frequency, power, duration, and new surge types.

Surges use the game's existing HR thresholds (e.g. +20 BPM, +30 BPM). No
node in this branch introduces a higher HR requirement — new surge types use
the same or lower thresholds as existing surges, with different effects.

```
[Surge Frequency]──→[Sustained Pulse]──→[Surge Mastery]──→[Convergence Surge]
        │                   │
        ↓                   ↓
  [Quick Recovery]    [Dual Surge]
```

| Node | Trunk/Side | Max Lvl | Base Cost | Cost Scaling | Effect |
|------|-----------|---------|-----------|-------------|--------|
| Surge Frequency | Trunk 1 | 3 | 5 | flat | -10% surge cooldown per level (cap 30%) |
| Quick Recovery | Side | 3 | 6 | flat | Surge offer window +5 sec per level |
| Sustained Pulse | Trunk 2 | 5 | 10 | +2/lvl | +15% surge effect duration per level |
| Dual Surge | Side (from Sustained) | 1 | 30 | — | Can have 2 surge effects active simultaneously |
| Surge Mastery | Trunk 3 | 5 | 18 | +4/lvl | +20% surge effect power per level |
| Convergence Surge | Trunk 4 | 1 | 65 | — | New surge type: completing a surge also triggers a sanctum growth burst (uses existing +20 BPM threshold) |

---

### Branch: Bloom (Sanctums)

Focus: sanctum growth, bloom bonuses, plot upgrades.

```
[Sanctum Mastery]──→[Deep Roots]──→[Eternal Garden]──→[Overgrowth]
        │                │
        ↓                ↓
  [Auto-Tend]      [Bloom Cascade]
        │
        ↓
  [Vital Seedling]
```

| Node | Trunk/Side | Max Lvl | Base Cost | Cost Scaling | Effect |
|------|-----------|---------|-----------|-------------|--------|
| Sanctum Mastery | Trunk 1 | 5 | 4 | flat | +10% bloom bonus per level |
| Auto-Tend | Side | 1 | 20 | — | Auto-allocate attunement during growth |
| Vital Seedling | Side (from Auto-Tend) | 3 | 8 | +3/lvl | Seeds cost -15% per level |
| Deep Roots | Trunk 2 | 5 | 10 | +3/lvl | +10% growth speed per level |
| Bloom Cascade | Side (from Deep Roots) | 3 | 16 | +5/lvl | Full bloom triggers a production burst (+30 sec equivalent per level) |
| Eternal Garden | Trunk 3 | 3 | 25 | +8/lvl | Bloom count bonuses are +25% stronger per level |
| Overgrowth | Trunk 4 | 1 | 60 | — | Unlock a 4th sanctum slot on Seedbed and 3rd on Forge |

---

### Branch: Vital (Vitality / Movement)

Focus: making each heartbeat more valuable and making the vitality currency
more versatile. No node touches the HR-to-tick ratio, the HR speed factor
curve, or the safety cap — those are physics, not gameplay.

The natural incentive to exercise is already built in: more heartbeats =
more ticks = more production. Nodes in this branch amplify what each beat
*produces*, so a 30-minute walk doesn't just give you more beats — each of
those beats is richer. This rewards exercise safely without altering the
1:1 heartbeat or pushing toward specific HR zones.

```
[Vital Strength]──→[Beat Enrichment]──→[Living Investment]──→[Vital Bloom]
        │                   │
        ↓                   ↓
  [Endurance]         [Step Compounding]
```

| Node | Trunk/Side | Max Lvl | Base Cost | Cost Scaling | Effect |
|------|-----------|---------|-----------|-------------|--------|
| Vital Strength | Trunk 1 | 3 | 4 | flat | +20% vitality earning rate per level (more vit per 1000 steps) |
| Endurance | Side | 5 | 6 | +2/lvl | Vitality expiry extended by +6 hours per level (max +30 hr) |
| Beat Enrichment | Trunk 2 | 5 | 10 | +2/lvl | Each beat produces +3% more mana across all generators per level (stacks with other multipliers) |
| Step Compounding | Side (from Beat Enrichment) | 3 | 12 | +3/lvl | Every 5000 steps in a single day grants a bonus +0.5 vitality per level (rewards sustained activity, not intensity) |
| Living Investment | Trunk 3 | 5 | 18 | +4/lvl | Spending vitality on upgrades returns +10% of the cost as mana per level |
| Vital Bloom | Trunk 4 | 1 | 55 | — | Vitality can be spent to instantly advance one sanctum slot by 25% growth (new action, cost: 2 vitality) |

---

### Branch: Arcane (Meta / Prestige)

Focus: essence earning, prestige efficiency, endgame unlocks.

```
[Essence Echo]──→[Cycle Momentum]──→[Arcanum Key]──→[Transcendence]
       │                │
       ↓                ↓
 [Swift Rebirth]  [Memory Palace]
```

| Node | Trunk/Side | Max Lvl | Base Cost | Cost Scaling | Effect |
|------|-----------|---------|-----------|-------------|--------|
| Essence Echo | Trunk 1 | 3 | 10 | flat | +10% essence earned per prestige per level |
| Swift Rebirth | Side | 3 | 8 | +3/lvl | First 5 minutes of a new cycle, +50% production per level |
| Cycle Momentum | Trunk 2 | 5 | 14 | +4/lvl | +2% all production per life cycle completed, per level (e.g., lvl 3 + 5 cycles = +30%) |
| Memory Palace | Side (from Momentum) | 3 | 20 | +5/lvl | Retain 5% of upgrade levels through prestige per level (rounded down) |
| Arcanum Key | Trunk 3 | 1 | 16 | — | Unlock the Research system (existing blessing, now a tree node) |
| Transcendence | Trunk 4 | 1 | 80 | — | Second prestige layer: sacrifice essence for Astral Shards (future expansion hook) |

---

## Node Data Model

Extend the existing `BlessingData` resource or create a new `EssenceNodeData`:

```
id: String               — unique key (e.g. "cascade_resonance")
display_name: String      — shown in UI
description: String       — tooltip text
branch: String            — "verdant" | "pulse" | "bloom" | "vital" | "arcane"
position: Vector2         — grid position in tree layout
max_level: int            — max upgradeable level
base_cost: int            — essence cost at level 1
cost_scaling: int         — added to cost per level (0 = flat cost)
effect_type: String       — maps to game system
effect_value: float       — per-level magnitude
prerequisite_ids: Array[String] — nodes that must be level 1+ to unlock
prerequisite_levels: Array[int] — minimum level required for each prereq
icon: String              — texture path for node icon
```

**Cost formula:** `base_cost + cost_scaling * current_level`

This keeps early nodes cheap (flat cost like current blessings) while making
deep nodes require accumulation across multiple prestige cycles.

---

## Progression Pacing

### First prestige (Cycle 1, ~1-3 essence)

The player reaches tier 1 generators (Cascade Begins milestone) within
10-30 minutes. They can prestige immediately for 1-2 essence, or push
further. A typical first prestige at ~4000-10000 mana yields 2-3 essence.

First buy: Head Start (2) or Mana Magnetism (3). One node, immediate
impact. The tree opens with that single glowing node — the player can see
the full shape of what's ahead but only has one foothold.

### Quick loops (Cycles 2-6, ~2-5 essence each)

Short 10-20 minute cycles. Each run is faster than the last thanks to
accumulated tree bonuses. The player buys 1-2 cheap nodes per cycle,
spreading across trunk-1 nodes in different branches. By cycle 6 they've
touched 3-4 branches and spent ~20-30 total essence.

This is the "CIFI short run" phase — frequent resets, small gains, broad
investment. The tree fills outward from root.

### Medium runs (Cycles 7-15, ~7-20 essence each)

The player starts pushing deeper in each cycle because tree bonuses make
higher tiers accessible. Runs last 30-60 minutes. They start buying
trunk-2 nodes and side paths, developing a build identity.

### Long runs (Cycles 15-30, ~20-50 essence each)

Multi-hour sessions reaching tier 4-5 generators. Trunk-3 and tier gate
nodes become affordable. The player unlocks Aether Conduits (tier 5) as a
major milestone gated by the tree, not just by mana.

### Deep runs (Cycles 30+, ~50-100+ essence each)

Pushing into tiers 6-7 with deep tree investment. Trunk-4 capstone nodes.
Transcendence teases the next layer.

---

## Essence Budget Per Cycle

Formula: `floor(sqrt(total_mana_earned / 1000)) * (1 + essence_bonus)`

| Total Mana | Base Essence | Typical Cycle Phase |
|------------|-------------|---------------------|
| 1,000 | 1 | First possible prestige |
| 4,000 | 2 | Quick early prestige |
| 10,000 | 3 | Comfortable first run |
| 50,000 | 7 | Pushed to tier 2 |
| 100,000 | 10 | Solid mid-cycle |
| 500,000 | 22 | Deep run with tier 3 |
| 1,000,000 | 31 | Long run |
| 10,000,000 | 100 | Very deep with tier 4+ |
| 100,000,000 | 316 | Endgame push |
| 1,000,000,000 | 1000 | Tier 7 territory |

**Short vs long run tradeoff:** Three quick cycles to 10K mana each
(~10 minutes, 3 essence each = 9 essence in 30 min) vs one long cycle to
500K mana (~30 min, 22 essence). Long runs are more efficient for raw
essence, but short runs let you apply tree bonuses sooner. The optimal
strategy shifts as the tree fills — early game favors short loops, late
game favors deep pushes.

**Total tree cost (all nodes maxed):** ~1100 essence (increased from ~850
due to tier gate chain: 30+60+100 = 190 for tiers 5-7). Full completion
spans 40-60 cycles across weeks of play.

---

## UI Architecture

### Tree View (new scene: `essence_tree.tscn`)

- **Camera2D** with pan (drag) and zoom (scroll/pinch)
- **Node2D** canvas containing:
  - Connection lines (Line2D or `_draw()` calls between nodes)
  - Node buttons (TextureButton or custom Control per node)
- Five branches arranged radially from center root
- Locked nodes: dimmed, show "???" until prereq is met
- Unlocked but unpurchased: full color, show cost
- Purchased: glowing border, show current level / max level
- Trunk nodes are larger than side nodes

### Node Tooltip (on hover/tap)

- Name, description, current level / max level
- Current effect value and next-level effect value
- Cost to upgrade
- Prerequisites (with checkmark if met)

### Purchase Flow

1. Tap unlocked node → tooltip expands with "Upgrade" button
2. Confirm purchase → essence deducted, level increments
3. Node visual updates (glow pulse, level counter)
4. If this unlocks new nodes, they animate from dim to visible

### Navigation

- Accessed from Grimoire hub (replaces current "Blessings" tile)
- Back button returns to Grimoire
- Branch labels at the edge of each branch for quick-jump

---

## Migration from Current Blessings

All 9 existing blessings map into the tree:

| Current Blessing | Tree Node | Branch |
|-----------------|-----------|--------|
| Mana Magnetism | Mana Magnetism | Verdant (Trunk 1) | 4→3 |
| Head Start | Head Start | Verdant (Side) | 3→2 |
| Generator Memory | Generator Memory | Verdant (Side) | 8→6 |
| Essence Echo | Essence Echo | Arcane (Trunk 1) | 15→10 |
| Surge Frequency | Surge Frequency | Pulse (Trunk 1) | 7→5 |
| Vital Strength | Vital Strength | Vital (Trunk 1) | 6→4 |
| Sanctum Mastery | Sanctum Mastery | Bloom (Trunk 1) | 4 (unchanged) |
| Auto-Tend | Auto-Tend | Bloom (Side) | 25→20 |
| Arcanum Key | Arcanum Key | Arcane (Trunk 3) | 20→16 |

Existing save data migrates cleanly: current blessing levels become tree node
levels. New nodes start at level 0.

---

## Implementation Order

1. **Data layer:** `EssenceNodeData` resource + data instances for all nodes
2. **Manager:** `EssenceTreeManager` autoload (replaces `PrestigeManager`
   blessing logic, keeps prestige execution)
3. **Effects:** Wire each node's `effect_type` into existing game systems
4. **Tree UI:** Interactive node graph scene with pan/zoom
5. **Migration:** Convert existing blessing save data to tree format
6. **New nodes:** Add the 18 new nodes beyond the original 9 blessings
7. **Polish:** Animations, particles on purchase, branch glow progression
