# Forage Spawns & Harvestable Trees

Goal: territory resources come in two placement flavors — **authored nodes** (placed by hand in the
.tscn: trees, ore veins, permanent patches) and **forage spawns** (small gatherables the world seeds
randomly each day, Stardew-style). Trees become first-class choppable resource nodes with real art.

## Reference: how Stardew Valley does forage (from decompiled behavior, roughly)

- Each outdoor location has a **seasonal forage table**: a list of (item, spawn chance) per season,
  in the location data.
- **Daily spawn pass** at day start: a location makes ~1–4 spawn attempts. Each attempt picks a
  random tile, checks validity (tile unoccupied, terrain spawnable, not blocked), then rolls the
  item's listed chance.
- **Soft cap**: a location stops spawning once it holds roughly 6 uncollected forage objects — so
  neglected maps don't fill up.
- **Cleanup**: uncollected forage is swept on a weekly cadence (every 7th day) and everything clears
  on season change — stale items never accumulate, and the map feels freshly stocked after a sweep.
- Trees/bushes are **not** forage: they are persistent terrain features with their own growth/chop
  rules (salmonberry/blackberry weeks are scheduled bush events, not random spawns). Artifact dig
  spots are a third, separate system.

## Bulwark adaptation

### Authored nodes (hand-placed)
- Resource node prefabs (tree variants, rock, copper vein, berry bush, herb patch, …) are scenes
  under `scenes/territory/nodes/`, placed directly in territory .tscn files in the editor
  (repo rule: objects live in .tscn, scripts never spawn what an author can place).
- Each prefab carries its `ResourceNodeDefinition` id (exported). Save identity = territory id +
  node name (names unique per scene). Chopped/harvested state persists exactly like today's
  marker-spawned nodes.
- Trees: new Axe node definitions (data-only in `ResourceNodes.cs`), yields anchored Stardew-scale
  (a full tree ≈ 10–12 wood, one-shot per day-respawn rules below). 3D greybox art for now — a
  cylinder trunk plus a sphere/cone canopy per prefab, swappable one scene at a time. Trunk-base
  collision only (a `CylinderShape3D` around the trunk); the canopy stays walk-under and depth
  sorting is the 3D depth buffer's job.

### Forage spawns (random daily)
- Per-territory **forage table** on `TerritoryDefinition`: list of (nodeId, weight), optional
  season filter field (reserved if seasons aren't in GameState yet).
- **Daily pass** on day change, per unlocked territory:
  - If live forage count ≥ cap (default 6) → skip.
  - Roll N = 1–4 attempts; each picks a random valid cell and spawns the weighted node prefab.
  - Valid cell = inside the territory's authored walkable ground rect (its `%Ground` floor collider,
    shrunk by one ring), not a cell claimed by a world object (trigger footprints, obstacle bodies,
    plus a 1-cell margin), ≥ 2 cells from any other node/marker/trail-exit.
- **Determinism**: RNG seeded by (save seed, day, territory id) — reload gives the same spawns.
- **Sweep**: uncollected forage clears every 7th day before the daily pass (and on season change
  when seasons land).
- Spawned forage uses the **same node prefabs** as authored nodes, instantiated at runtime
  (dynamic children via PackedScene are the sanctioned exception to editor placement).
- Persistence: live forage list (node id, cell, spawn day, harvested flag) in SaveData per
  territory.

### Debris (Stardew-style clutter — third category)
Stardew's farm/map clutter (stones, twigs, weeds) is a separate accumulation system from forage:
one-hit destructibles yielding 1 stone / 1 wood / fiber that build up over time and never despawn
on their own — clearing them IS the gameplay. Bulwark mirrors that:
- Three debris node defs (data-only): loose stones (Pick → 1 stone), fallen branch (Axe → 1 wood),
  scrub weeds (Hand → 1 fiber). Quick harvests (5 min), never respawn in place — new debris comes
  from the spawn pass.
- Debris runs as a **second pass** in ForageSystem with its own table, own cap (~12 live), and own
  attempts (2–4/day). Debris is NOT swept on the 7th day — it accumulates to cap until the player
  clears it (that's the Stardew feel); forage keeps its weekly sweep.
- **Initial seeding**: first-ever visit to a territory pre-sprinkles 8–12 debris so the map starts
  lived-in, then daily top-ups. Same determinism and persistence as forage.
- Same valid-cell rules, but debris may spawn closer to the trail (1-cell clearance) — clutter
  belongs underfoot.

### What stays authored vs. forage
- Authored: trees, ore veins (copper/iron/coal), elderwood/bog tree stands, permanent bushes,
  quest-gated rares (ward salt, ley glade, nightcap).
- Forage-eligible (v1, forest): herb patch, berry bush, wild mushroom patch, fallen wood,
  forest root patch, bramble patch — the cheap Hand/Axe commons.

## Risks / open questions
- Tree respawn policy (decided): trees respawn after a random 7–14 days (roll at chop time,
  store the respawn day in save state; deterministic from the save RNG). Tree count is high
  enough that the long window is fine. Definitions carry a RespawnDays range (min/max,
  generalizing RespawnsDaily; fixed-cadence nodes use min == max, 0 = never).
- Forage density (cap 6, 1–4 attempts) copied from Stardew; revisit once the forest is played.
- Seasons: table field reserved; wire to the calendar when GameState exposes season.
