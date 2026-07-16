# Bulwark — Building Scene Authoring Guide

Step-by-step for painting staged building scenes. Worked examples: the Command Post (4 tier
looks) and the Trading Post (broken → repaired → upgraded). Template: `scenes/buildings/farmhouse.tscn`.
System contract: `design/building_visuals.md`.

## The rules that matter (read once)

- **Child ORDER under `%Stages` is the stage index.** Names (`Stage0`, `Stage1`…) are for
  humans; the code counts children. Never reorder after authoring.
- **Stage index ↔ tier** comes from data (`Buildings.cs` → each tier's `StageIndex`), not the
  scene. Command Post tiers 1–4 map to stages 1–4; Trading Post tiers 1–2 map to stages 1–2.
  Stage 0 is always the ruined/pre-commission look.
- **One origin for everything.** The `%Building_<id>` marker in outpost.tscn is the building's
  "feet" (bottom-center). Author every stage relative to that: art extends upward in −Y
  (farmhouse: a 96-wide building spans x −48..48, y −64..0).
- **Exactly one stage is visible at runtime** — toggle visibility freely in the editor to
  compare stages; the loader overrides it on placement.
- **Collision:** the shared `%Footprint` StaticBody2D blocks tiles at every stage. If a stage
  CHANGES the outline, give that stage its own StaticBody2D+shape inside the stage node — the
  system auto-disables collision under hidden stages. Every shape is its own resource — never
  share a sub_resource between differently sized shapes.
- A stage/overlay child can be a whole Node2D subtree: sprites, animated Winlu props
  (scenes/props/), PointLight2D, particles. Anything CanvasItem-rooted works.

## Part 1 — Command Post (`scenes/buildings/command_post.tscn`)

Tier meanings from the economy design: T1 planning table (start state — this is what shows on
day one), T2 Elderwood unlock, T3 Sunken Reach unlock, T4 Resurrection.

1. **Duplicate the template.** FileSystem dock → right-click `scenes/buildings/farmhouse.tscn`
   → Duplicate → `command_post.tscn`. Open it, rename the root node `CommandPost` (keep the
   BuildingInstance script attached).
2. **Add the missing stage.** The template ships Stage0–Stage3; the Command Post needs
   Stage0–Stage4 (five children). Duplicate Stage3, it lands last in order — that's Stage4.
3. **Paint each stage.** Replace each placeholder ColorRect with a Node2D group of sprites.
   Suggested arc: Stage0 collapsed HQ ruin (never shows in-game — the CP starts at tier 1 —
   but author it anyway; the order contract needs the child, and it documents the "before").
   Stage1 patched hall + planning table. Stage2 war-room wing / map table (Elderwood). Stage3
   expedition annex (Sunken Reach). Stage4 the resurrection dais — a place that looks like it
   can argue with death (bogwood dais, candles, light).
4. **Footprint.** Size the `%Footprint` CollisionShape2D to the walkable-blocking outline. If
   Stage3/4 physically widen the building, delete the shared shape's coverage assumption and
   put a StaticBody2D + uniquely-sized shape inside each stage node instead.
5. **Scaffold (optional but recommended).** Add a `Scaffold` Node2D sibling of `%Stages`,
   unique name it (right-click → % Access as Unique Name). Paint beams/tarps/stone piles.
   NOTE: Command Post upgrades are currently INSTANT (only trading_post/farmhouse/smithy/
   infirmary have construction days wired). To make CP upgrades take Tharr-time, add
   `{ "command_post", 2 }` to the SetConstructionDays dictionary in GameState._Ready.
6. **Marker.** In outpost.tscn (your scene): add a Marker2D named `Building_command_post`,
   right-click → % Access as Unique Name, position it at the building's feet-point.
7. **Verify.** F6 the building scene (standalone-safe), then F5: the Command Post appears at
   Stage1 from day one.

## Part 2 — Trading Post (`scenes/buildings/trading_post.tscn`)

The broken → repaired → upgraded arc. Data: T1 general store (StageIndex 1), T2 expanded
store (StageIndex 2). Commission = 90 wood + 60 stone + 60g; 2 build days.

1. **Duplicate the template** → `trading_post.tscn`, root `TradingPost`.
2. **Three stages** (delete the template's Stage3):
   - `Stage0` — THE BROKEN LOOK. Collapsed storefront, fallen beams, weeds. This is the ruin
     Elara spots in the intro ("Is that a trading post?" / "It was."). Visible in the world
     from day one, before any commission.
   - `Stage1` — repaired general store: mended roof, door, a modest sign, goods crates.
   - `Stage2` — expanded store: wider frontage, awning, display stalls, hanging stock.
3. **Scaffold.** Add the unique-named `Scaffold` node — shown automatically during the 2-day
   commission build AND the 2-day tier-2 upgrade window (the store keeps trading during the
   upgrade; only the new tier's perks wait).
4. **Overlays (optional).** Add an `Overlays` container (unique name) with a `Winter` child —
   snow on the roofline, automatic every winter, zero data edits. Festival dressing or a
   permanent story change later = paint the child + one `VisualRule` line in Buildings.cs.
5. **Footprint + marker** `Building_trading_post`, same as Part 1.
6. **Verify the full arc in-game (F5):** day one shows the Stage0 ruin → commission at the
   planning table → scaffold rises, Tharr's busy line + build-panel countdown + calendar
   completion mark → completion toast → Stage1, Elara opens the store → (later) fund the
   tier-2 bundle, Upgrade → scaffold again for 2 days, store still open → Stage2.

## Quick reference

| Building | Scene | Marker | Stages needed | Notes |
|---|---|---|---|---|
| Command Post | scenes/buildings/command_post.tscn | %Building_command_post | Stage0–Stage4 | Starts at Stage1 day one; upgrades instant unless construction days added |
| Trading Post | scenes/buildings/trading_post.tscn | %Building_trading_post | Stage0–Stage2 | Stage0 ruin visible pre-commission; scaffold on commission + upgrade |
| (any other) | scenes/buildings/<id>.tscn | %Building_<id> | Stage0..max StageIndex in its tier data | Same recipe |

Missing marker or scene = skipped with a log line; state still works, art arrives whenever
you get to it.
