# The Maw of Rrrbl

A builder-incremental game. Place marble track pieces, watch orbs roll, earn Sparks from distance traveled, feed The Maw until it implodes and resets the world.

**Engine:** Godot 4.6 (3D)
**Assets:** Kenney Marble Kit (162 pieces, CC0)
**Genre:** Incremental / Idle + Builder hybrid
**Inspirations:** Gnorp Apologue, Berry Bury Berry, Tower Wizard

---

## Core Loop

```
Player places track pieces → orbs auto-spawn and roll → distance traveled = Sparks
Sparks → buy new piece types, orb upgrades, more copies
Orbs feed The Maw → Maw fills → IMPLOSION (prestige) → Void Marbles → rebuild bigger
```

**Primary resource:** Sparks (proportional to distance per orb)
**Prestige resource:** Void Marbles (earned on implosion)

---

## Building System

The player physically places track pieces in 3D. Pieces snap together at connection points. Track flows downward (gravity) but can curve, loop, spiral, jump in any direction.

1. Piece palette shows available types and counts
2. Select a piece → ghost preview snaps to valid connection points
3. Confirm placement → piece locks in
4. Orbs auto-spawn at the top and roll through
5. Earn Sparks based on distance before orb reaches the end or falls off

**Progression constraints:**
- Piece inventory: limited types/copies at start, earn more over time
- Build volume: small area initially, expands with prestige
- Height: more vertical space unlocked over time

**The satisfying loop:** Build → Watch → "orb flew off at that curve" → Adjust → Watch → "yes!" → Extend → Earn more

---

## Piece Categories

| Category | Examples from Kit | Role |
|----------|------------------|------|
| **Straights & Curves** | straight, curve, curve-wide, bend | Reliable distance |
| **Ramps & Jumps** | ramp-start, slant, bump | Airtime = bonus distance, risk of missing landing |
| **S-Curves & Waves** | s-curve-left, wave-a/b/c | Dense distance in compact space |
| **Splits** | split, split-double, split-large | One orb → multiple paths |
| **Tunnels** | tunnel | Hidden distance segment |
| **Speed Pieces** | slant-long (steep drops) | Build velocity for jumps/loops |
| **Decorative** | supports, banners, trees | Visual flair, no gameplay function (initially) |

**Per-piece upgrades:**
- More copies available to place (Sparks)
- Quality tiers: smoother surface (less speed loss), wider catch radius (Void Marbles)

---

## Orb Types

Orbs spawn automatically. Called "orbs" not "marbles." Some are wrong.

| Orb | Appearance | Trait |
|-----|-----------|-------|
| **Glass Orb** | Clear, normal | Balanced speed/weight |
| **Stone Orb** | Dense, dark, warm | Slow, heavy, never flies off curves |
| **Whisper Orb** | Translucent, faint glow | Fast, light, easily launched off track |
| **Clutch** | Fused cluster | Breaks into 3 at splits |
| **Gilt Orb** | Gold, too many reflections | 3x Spark value, rare |
| **Void Orb** | Black, absorbs light | Scales with Maw cycles |
| **The Eye** | Blinks | ??? |

Where do they come from? The game never says.

**Weird Orbs (upgrade path):** Parallel progression of increasingly strange orbs. Unlock/discover them. Each has unique properties and may alter The Maw's behavior.

---

## Strategic Depth

**Risk/reward of track design:**
- Simple track = every orb completes = reliable income
- Complex track = high distance potential = orbs can fail
- Sweet spot depends on orb type + piece layout

**Emergent builds:**
- "Speedrun": steep drops → speed pieces → mega ramp → big air
- "Reliable grinder": long S-curves and bends, nothing risky
- "Splitter farm": early splits, maximize orb count
- "Hybrid": safe base + one risky branch for bonus distance

**Spatial puzzle:** Limited volume → spirals/waves pack more distance per unit space

---

## Prestige — The Maw

A swirling void at the bottom of the build space. Always there. Always hungry.

**Mechanic:**
- Orbs that complete the track (or fall off) drop into The Maw
- Each orb consumed fills The Maw's meter
- More efficient track = more orbs completing = Maw fills faster
- Cannot stop it without stopping income

**Visual escalation:**
- Calm dark swirl → spinning faster → warping space → pulling nearby pieces → glowing
- Sound: faint hum → building drone → wet consumption sounds

**When full → IMPLOSION:**
- Everything sucked inward. Track, orbs, all pulled into the void.
- Brief darkness.
- The Maw goes dormant. Spits out Void Marbles.
- You rebuild.

**What resets:** Placed pieces, Sparks, orb upgrades
**What persists:** Void Marbles, unlocked piece types, build space, orb types, blueprints

**Void Marble shop:**
- New piece categories
- Expand build volume
- Orb types
- Piece inventory limits
- Permanent passive bonuses
- Blueprint slots

**Blueprints:** Save track layouts, auto-rebuild post-implosion (costs Sparks).

---

## The Maw — Escalation Across Cycles

Each cycle, The Maw starts larger/more active at rest.

- Cycle 1-3: Normal marble game. The Maw is just a dark swirl.
- Cycle 4-6: Orbs have more character. Tier 3+ pieces look organic.
- Cycle 7-10: The Maw warps space. The Eye unlocks. Sky shifts.
- Cycle 10+: Maw affects physics (gravitational pull). Background hums.

---

## Tone — Lovecraftian Backdrop

A cheerful marble run builder. The eldritch elements are never acknowledged.

| Layer | What the player sees | The unsettling part |
|-------|---------------------|---------------------|
| Orbs | Pretty marbles | One blinks. Where do they come from? |
| The Maw | Collection point | Alive. Hungry. Grows. |
| Late pieces | Better stats | Look grown, not built. Veining. |
| Sound | Clicks and rolls | Faint whispers. Wet sounds. |
| UI text | Upgrade descriptions | "The orbs arrive faster now." |
| Background | Sky | Stars move. Wrong colors. |

The game never breaks the fourth wall. No horror stings. Just a marble game with eldritch undertones. The dissonance IS the tone.

---

## Technical Architecture (Godot 4.6)

**Track pieces:** StaticBody3D + MeshInstance3D + CollisionShape3D + Marker3D (connection points)
**Orbs:** RigidBody3D, continuous CD, PhysicsMaterial per type
**Camera:** Orbitable 3D, default 2.5D angle
**Connection system:** Marker3D in/out nodes per piece, Area3D for snap detection
**Save:** JSON (game state) + Resource (blueprints)

**Key systems:**
1. Piece palette UI (Control nodes)
2. Snap/connection placement system
3. Orb spawner + distance tracker
4. Spark economy manager
5. Maw meter + implosion sequence
6. Prestige/Void Marble shop
7. Blueprint serialize/deserialize
8. Save/load persistence
