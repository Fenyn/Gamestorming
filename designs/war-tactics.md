# War Tactics — Prototype Plan

## Context

New entry in the Gamestorming monorepo: a WWII squad-tactics roguelike. A
mysterious fog separates a soldier squad from the front line; they fight
their way through waves of enemy forces across a node-based map, returning
to a Forward Base between encounters to heal, equip, and prepare.

This document is both the **summary GDD** (matching the style in `designs/`)
and the **Godot prototype plan**. It scopes the prototype to a playable vertical
slice — a single battle plus stubbed map and Forward Base — so the core feel
(AP turns, skill-check shooting, cover, medal pickups, permadeath) can be
evaluated before any of the heavier meta systems are built.

User-confirmed decisions:
- **View:** 2D **isometric** pixel art on a diamond-tile grid. Confirmed by artist sample: small ~24px-tall character sprites, muted military green/brown/grey palette, 3/4 perspective.
- **Scope:** Battle + map + base stubs (no meta progression, no skill trees, no recruitment)
- **Hit minigame:** Two variants — wobbly cursor (rifle) and timing-bar (sniper)
- **Tone:** Grounded WWII military. No horror, no non-human enemies.
- **Art pipeline:** Collaborating artist provides final sprites and assets. Prototype is built with greybox placeholders (isometric diamonds + colored blocks) to prove mechanics before art arrives.
- **Architecture basis:** Godot 4 community best practices (GDQuest, official docs, Shaggy Dev, Febucci) — not just mirroring this monorepo's existing patterns. See **Best-Practice References** section.
- **Status:** Plan-only. No implementation work until explicitly greenlit.

---

# Summary GDD

**Working Title:** War Tactics
**Engine:** Godot 4.6 (2D isometric, Forward Plus)
**Genre:** Turn-based tactics / Roguelike
**Art style:** Isometric pixel art, muted military palette (greens, browns, greys). Small character sprites (~24px tall) on diamond tiles. Reference: artist sample provided.
**Assets:** Provided by collaborating artist (final sprites/tiles/UI). Prototype uses isometric greybox placeholders — `Polygon2D` diamonds and colored blocks — so gameplay is provable independent of art delivery.
**Inspirations:** XCOM, Into the Breach, Darkest Dungeon, Slay the Spire (map). Visual reference closer to *Tiny Wars* / *Cassette Beasts* / *Wargroove*.

## Elevator Pitch

Your WWII squad walks into a fog and emerges behind enemy lines. Move, shoot,
grenade, and overwatch across grid-based battles where every shot is a small
skill-check minigame, every medal on the ground is worth dying for, and every
soldier you lose stays dead. Between battles, return to the Forward Base to
heal and re-equip, then pick your next encounter on the fog-map.

## Core Loop

```
Forward Base → choose map node → Battle → Upgrade (post-battle) → Forward Base
                                    ↓
                            (squad wipe = run over → meta unlocks)
```

**Primary resources:** XP (per-run, spent on heal/skills), Medals (battlefield pickups, stat buffs)
**Prestige resource:** Requisition Slips (post-wipe, unlock gear at Forward Base)

## Encounter Types (full vision)

| Type | Win Condition |
|---|---|
| Battle | Kill all enemies |
| Defense | Survive N turns / hold objective |
| Demolition | Plant a bomb on a target |
| Medical Tent | Free heal, no combat |
| Forward Base | Re-encounter the hub mid-run |
| Assassination | Kill a specific enemy |

**Prototype only ships `Battle`.**

## Battle System

**Grid:** Square tiles, top-down. Each unit has AP (default 2-3) spent on:
- **Move** (per-tile cost)
- **Ranged attack** (weapon-specific minigame determines hit)
- **AoE attack** (grenade — preview tiles, no minigame)
- **Melee** (adjacent only, separate roll)
- **Overwatch** (end turn watching a cone; auto-fire during enemy turn)
- **Class abilities** (skill-tree gated — deferred past prototype)

**Hit resolution — skill-check minigames (no % rolls):**
- **Rifle:** wobbly cursor drifts over target; click to fire. Hit % converts to wobble magnitude/speed.
- **Sniper:** timing bar; press when indicator hits the sweet spot. Hit % converts to sweet-spot width.
- Future weapons get their own minigames.

**Cover:** A unit adjacent to a cover tile (tree, wall, sandbag) gets a defense
bonus against attacks originating from the direction of the cover. Implemented
as a per-edge flag on the unit each turn.

**Medals (battlefield pickups):** Spawn on enemy death or scattered on map.
A unit moving over a medal collects it. Uncollected medals **disappear at
battle end**. Types: +Move, +Damage, +Defense, +Accuracy, +Melee. Persistent
unit stat buffs — the central risk/reward mechanic.

**Permadeath:** Unit at 0 HP is gone for the run.

**Enemy gear drops:** Sometimes drop on enemy kill. In post-battle Upgrade
phase, equipping a drop replaces a unit's current item (old item discarded)
and unlocks the new item for purchase at Forward Base. Unequipped drops
convert to XP.

**POWs:** Rescuable units mid-battle, joinable to squad post-battle. *Stretch goal.*

## Forward Base (Hub)

Stubbed in prototype: a single scene with three buttons (Heal All, Equip Loadout,
Continue). Full vision:
- Assign units to active squad
- Recruit new units
- Manage equipment (gun / grenade / helmet / specialized tool / booster)
- Spend Requisition Slips on unlocked gear
- Heal units (XP cost)
- Sell battlefield gear
- Store gear

## Map

Slay-the-Spire-style branching node graph between Forward Base and final goal.
Prototype: 3-node linear path, all `Battle` type, hand-authored.

## Upgrades

- **Skill trees** per unit class, leveled by XP. *Deferred past prototype.*
- **Medals** distributed to units between battles. *Distribution UI deferred — prototype auto-applies on pickup.*
- **Healing** between rounds costs XP.

## Items (full vision)

Slots: gun, grenade, helmet, specialized tool (medic bag, radio, scope), booster.
Boosters: Bottomless Canteen (+2 move), Steel Undershirt (-1 move, +1 DR), etc.

**Prototype:** every unit ships with rifle OR sniper, one grenade, no booster.

## Meta Unlocks

On squad wipe: total XP → Requisition Slips. Spent at Forward Base on permanent
gear unlocks. *Deferred past prototype.*

## Tone

Grounded WWII military. Cold, foggy, tense. Period sound — radios, distant
artillery, boots on mud, bolt actions. Pixel art. Fog is a tactical and
narrative device: it limits sight lines, separates the squad from
reinforcement, and explains the run structure (no retreat, no resupply
until the fog parts). Enemies are conventional opposing-force soldiers.

---

# Prototype Build Plan

## Scope (what ships in v0)

✅ Single `Battle` encounter, hand-authored map
✅ Squad of 3 pre-built units (Rifleman, Sniper, Grenadier)
✅ AP turn system, end-turn button
✅ Grid movement with path preview
✅ Ranged attack with two minigames (wobble + timing)
✅ Grenade AoE with tile preview
✅ Overwatch (cone, auto-fire on enemy entry)
✅ Cover system (directional defense bonus)
✅ Medal pickups (5 types, immediate stat buff, vanish at battle end)
✅ Permadeath
✅ 1 enemy archetype with simple AI (move toward nearest squad member, shoot in range)
✅ 3-node linear map screen
✅ Stub Forward Base (heal all, continue)
✅ Win screen / wipe screen

❌ Skill trees, Requisition Slips, recruitment, POWs, gear drops, multiple encounter types,
   booster items, multiple enemy types, fog-of-war, save/load

## Architecture

Follow Godot 4 community best practices, not just monorepo conventions. Three
patterns anchor the architecture:

1. **Scene-local folder organization** — each scene lives in its own folder
   alongside its exclusive scripts, resources, and assets. (Official docs:
   "group assets as close to scenes as possible".) Shared cross-scene data
   lives in sibling folders by data type. `snake_case` everywhere — Web
   exports are case-sensitive.
2. **Minimal autoloads, signal-bus for cross-cutting events** — keep
   autoloads under ~6 to avoid the God-object anti-pattern. Use the **Events
   bus** pattern (autoload that only emits signals) for decoupling distant
   nodes. Local communication uses direct signals or parent-child references,
   not the bus.
3. **Node-based state machines** for unit action states and battle phases —
   each state is a child node with `enter()`, `exit()`, `update()`; states
   call `transition_to(next)` themselves. This is the dominant Godot 4
   pattern (GDQuest, Shaggy Dev) and beats enum-switch for anything past
   trivial.

### Autoloads (target: 5, hard cap: 6)

| Autoload | Responsibility | Why a singleton |
|---|---|---|
| `Events` | Signal-only bus for cross-scene events (`battle_won`, `node_selected`, `unit_died`, `medal_collected`). No state. | Decouples Battle ↔ Map ↔ Base scenes. |
| `RunState` | Per-run data: squad roster, current map node, XP pool. Reset on `_ready()` of a new run. | Persists across scene swaps within one run. |
| `MetaState` | Future home for cross-run unlocks (Requisition Slips). Stub in prototype. | Persists across runs (would save to disk). |
| `Database` | Loads and caches `.tres` data resources (units, weapons, medals, enemies). | Avoids re-loading; one source of truth. |
| `Grid` | Wraps a single `AStarGrid2D` (cartesian tile space) for the active battle. Provides **isometric** `tile_to_world` / `world_to_tile`, pathfinding, LOS, cover-edge queries. Repointed at each new battle. | Many systems query it; passing references is painful. |

**Explicitly NOT autoloads** (anti-pattern in this monorepo's `mythos`):
- `TurnManager` → lives as a node inside `battle.tscn` (scene-local concern)
- `BattleManager` → IS the `battle.tscn` root script
- `CombatManager` → folded into the unit-action state machines

### Scene-local folder layout

```
war-tactics/
├── project.godot
├── export_presets.cfg
├── icon.svg
├── CLAUDE.md
├── globals/                        # autoloads (singletons only)
│   ├── events.gd
│   ├── run_state.gd
│   ├── meta_state.gd
│   ├── database.gd
│   └── grid.gd
├── data/                           # shared .tres resources (cross-scene)
│   ├── units/{rifleman,sniper,grenadier}.tres
│   ├── weapons/{rifle,sniper_rifle,grenade}.tres
│   ├── medals/{move,damage,defense,accuracy,melee}.tres
│   └── enemies/grunt.tres
├── scripts/                        # shared base classes / data scripts
│   ├── unit_class.gd               # extends Resource
│   ├── weapon_data.gd              # extends Resource
│   ├── medal_data.gd               # extends Resource
│   └── enemy_archetype.gd          # extends Resource
├── main/
│   ├── main.tscn                   # root; loads battle/map/base
│   └── main.gd
├── battle/
│   ├── battle.tscn                 # BattleScene root (acts as BattleManager)
│   ├── battle.gd
│   ├── unit/
│   │   ├── unit.tscn
│   │   ├── unit.gd                 # composes mover + attacker + health
│   │   └── states/                 # node-based FSM
│   │       ├── state.gd            # base State
│   │       ├── state_machine.gd
│   │       ├── idle.gd
│   │       ├── moving.gd
│   │       ├── attacking.gd
│   │       ├── overwatch.gd
│   │       └── dead.gd
│   ├── enemy/
│   │   ├── enemy.tscn              # reuses unit.tscn + ai brain
│   │   └── ai_brain.gd
│   ├── turn/
│   │   ├── turn_machine.gd         # phase FSM: player_turn → enemy_turn → ...
│   │   └── states/{player_turn,enemy_turn,resolving,won,lost}.gd
│   ├── grid_overlay/
│   │   ├── grid_overlay.tscn       # move-range / attack-range / grenade-preview highlights
│   │   └── grid_overlay.gd
│   ├── medal/
│   │   ├── medal.tscn
│   │   └── medal.gd
│   ├── minigame/
│   │   ├── wobble.tscn
│   │   ├── wobble.gd
│   │   ├── timing.tscn
│   │   └── timing.gd
│   ├── hud/
│   │   ├── hud.tscn
│   │   └── hud.gd
│   └── levels/
│       └── level_01.tscn           # hand-authored grid + props + spawn points
├── map/
│   ├── map.tscn
│   └── map.gd
├── base/
│   ├── forward_base.tscn
│   └── forward_base.gd
└── addons/                         # third-party plugins (empty for now)
```

### Greybox visual approach (isometric)

Until artist assets land, every visual is a flat primitive in isometric projection.
**Tile size proposal:** 64×32 px (standard 2:1 iso). Final tile size confirmed with
artist before M2.

| Game object | Greybox stand-in |
|---|---|
| Floor tile | `Polygon2D` diamond (64×32), muted grey-green fill, dark border |
| Variant tiles (dirt, sand, stone) | Same diamond, palette-shifted fill, no logic difference |
| Cover tile | Diamond + a short upright `Polygon2D` block on top, edge-colored to show cover direction |
| Squad unit | Upright rectangle (16×24 footprint) in blue, single-letter label (`R`/`S`/`G`) |
| Enemy | Upright rectangle in red, label `E` |
| Selected unit | Yellow diamond outline (`Line2D`) under the unit's tile |
| Move-range highlight | Translucent green diamond overlay per reachable tile |
| Attack-range / overwatch cone | Translucent red diamond overlay per targetable tile (no real "cone" — use tile list) |
| Grenade preview | Translucent orange diamonds in the AoE pattern |
| Medal pickup | Small gold square hovering above tile center, type initial above it |
| Map node | `TextureButton` placeholder = grey circle with node-type icon (text for now) |
| Forward Base UI | Default Godot `Button` / `Label` controls, no styling |
| Action bar (HUD) | 5 grey rectangles in a row, matching the slotted bar visible in the artist reference |
| Minigame (wobble) | Black overlay panel with a target circle and a drifting cursor `Polygon2D` |
| Minigame (timing) | Black overlay panel with a moving indicator bar and a green sweet-spot rect |

**Isometric rendering rules:**
- Use a single `Node2D` battle root with `y_sort_enabled = true` so units, cover, and props depth-sort correctly by their Y position. Each tile/unit's `position.y` is its iso-projected Y.
- Logical grid stays cartesian (an N×M `AStarGrid2D` in tile space). A pure helper converts `Vector2i tile_coords ↔ Vector2 world_pos` using the iso projection matrix:
  - `world = Vector2(tile.x - tile.y, (tile.x + tile.y) * 0.5) * Vector2(TILE_W / 2, TILE_H)`
- Mouse picking inverts that projection (or uses `Area2D` colliders on tiles, which is simpler — recommended).
- Godot 4 has `TileMap` isometric mode, but for a greybox prototype, instantiating diamond `Polygon2D` tiles in code is simpler and avoids `.tres` tile authoring. Swap to `TileMap` (or `TileMapLayer` in 4.6) when artist tiles arrive.

**Art-swap discipline:** every greybox primitive lives in its own scene
(`unit.tscn`, `medal.tscn`, `cover_tile.tscn`, etc.) with the visual as a single
named child node (e.g., `$Visual`). Artist deliverables swap in by replacing
`$Visual` only — no script changes, no scene restructure. Logic layer stays pure.

### Unit as composition, not inheritance

`unit.tscn` is a small scene composed of child nodes — no deep class hierarchy:

```
Unit (CharacterBody2D)
├── Sprite2D
├── Health (Node)              # hp, on_damage, on_death signal
├── Mover (Node)               # consumes AP, walks AStarGrid2D path
├── Attacker (Node)            # holds WeaponData; opens minigame; resolves damage
├── CoverSensor (Node)         # queries Grid for adjacent cover edges each turn
├── MedalBag (Node)            # accumulates collected medals → applies stat buffs
└── StateMachine (Node)
    ├── Idle
    ├── Moving
    ├── Attacking
    ├── Overwatch
    └── Dead
```

Class data (`WeaponData`, `UnitClass`) lives in `.tres` resources and is
**injected** at spawn time, not subclassed. To add a new unit type later:
author a new `.tres`, don't write a new script.

### AStarGrid2D usage

One `AStarGrid2D` per battle, owned by the `Grid` autoload but reinitialized on
`battle_loaded`:
- `region = Rect2i(0, 0, width, height)`
- `cell_size = Vector2(TILE_SIZE, TILE_SIZE)`
- `diagonal_mode = DIAGONAL_MODE_AT_LEAST_ONE_WALKABLE` (standard tactics behavior — no corner-cutting through walls)
- `jumping_enabled = false` (small grids; the gain isn't worth the path-shape quirks)
- Mark solid tiles via `set_point_solid()` during level load
- `get_id_path()` for unit movement; cap by current AP × tile cost

### State-machine usage

**Two FSMs, both node-based, both following the GDQuest pattern (states transition themselves via `state_machine.transition_to(name)`):**

1. **Battle turn FSM** (`battle/turn/turn_machine.gd`): `PlayerTurn → Resolving → EnemyTurn → Resolving → PlayerTurn` (loop), with `Won` / `Lost` terminal states.
2. **Per-unit action FSM** (`battle/unit/states/`): `Idle → Moving → Idle → Attacking → Idle → Overwatch → Idle → Dead`. Minigames are launched from `Attacking.enter()` and the state waits on the minigame's `resolved(hit: bool)` signal.

### Signal flow

- **Local signals (preferred):** Health → Unit, Mover → Unit, Attacker → Unit, FSM internal.
- **Events bus (cross-scene only):** `Events.battle_won`, `Events.battle_lost`, `Events.node_selected(node_id)`, `Events.unit_died(unit)`, `Events.medal_collected(unit, medal)`.
- **Rule of thumb:** if source and listener are in the same scene tree within 2-3 hops, use a direct signal. Anything farther goes through `Events`.

## Build Order (5 milestones)

### M1 — Isometric Grid + Movement (foundation)
- `project.godot` with Forward Plus, autoloads stubbed
- `BattleScene` root is a `Node2D` with `y_sort_enabled = true`
- Hard-coded 12×12 grid of diamond `Polygon2D` tiles spawned in code
- `Grid` autoload: cartesian `AStarGrid2D` + iso projection helpers, `Area2D` per tile for mouse picking
- 1 unit (greybox blue rect), click-to-select, click-tile-to-move
- Path preview on hover (highlighted diamonds)
- AP indicator on unit (small label), deducted per tile

**Done when:** you can click a unit, see its move range as highlighted diamonds, click a tile, watch it walk in iso projection and burn AP. Y-sort correctly puts units in front of tiles behind them.

### M2 — Turn System + Shooting Minigames
- `TurnManager`: PlayerTurn → EnemyTurn cycle, end-turn button
- Squad of 3 units, click to select
- Add Rifleman (wobble minigame) and Sniper (timing minigame)
- Click enemy in range → minigame popup → result applies damage
- HP bars, unit death (sprite swap to "down")

**Done when:** you can move all 3 units, shoot a static dummy enemy via either minigame, and kill it.

### M3 — Enemy AI + Cover + Grenades + Overwatch
- 1 enemy archetype: move toward nearest squad member, shoot when in range
- Cover tiles in level data; directional defense bonus computed at attack time
- Grenadier unit: select grenade → tile preview → AoE damage (no minigame, fixed damage)
- Overwatch: end unit turn watching a cone; `EventBus.unit_moved` triggers auto-fire if enemy enters cone

**Done when:** a real fight happens. Enemies move and shoot back. Cover matters. Grenades clear groups.

### M4 — Medals + Win/Loss + Map + Base Stub
- Medals spawn on enemy death (random type)
- Walk-over collection, immediate stat buff applied to unit
- Medals cleared on battle end
- Win condition: all enemies dead → win screen → return to map
- Loss condition: all squad dead → wipe screen → restart
- Map scene: 3-node linear path, click node → load battle
- Forward Base stub: "Heal All" button (XP cost), "Continue" → map

**Done when:** full loop is playable. Battle → win → base → next battle → wipe → restart.

### M5 — CI + Artist Handoff Readiness
- Greybox polish: readable labels on every unit / medal / cover tile, clear selection state, animated minigames
- Confirm every visual is isolated in its own scene child (so art swap is a one-file change)
- Document the visual interface for the artist in `war-tactics/ART_HANDOFF.md`: tile size, expected sprite dimensions, animation frames needed per unit state (idle / moving / attacking / hit / dead), UI sizes
- Add `war-tactics` to `.github/workflows/build-all.yml` matrix (line 24)
- Create `export_presets.cfg` with Web preset
- Add README table row + `index.html` card

**Done when:** `git push` produces a playable greybox build at `fenyn.github.io/Gamestorming/war-tactics/`, AND the artist has a doc telling them exactly what dimensions/states to deliver.

## Critical Files to Create

See the **Scene-local folder layout** under Architecture for the full tree.
The non-obvious ones:

- `globals/events.gd` — signal-only autoload. Pattern: `signal battle_won` / `signal node_selected(node_id: int)`. No methods, no state.
- `globals/grid.gd` — wraps `AStarGrid2D`. Methods: `setup(rect, solid_tiles)`, `path(from, to)`, `tile_to_world(t)`, `world_to_tile(p)`, `has_line_of_sight(a, b)`, `cover_edges(tile)`.
- `battle/unit/states/state.gd` — base class for FSM states. API: `enter()`, `exit()`, `update(delta)`, `handle_input(event)`, with a `state_machine` reference to call `transition_to(name)`.
- `battle/turn/turn_machine.gd` — same FSM pattern at the battle scope.
- `data/*/`.tres files — author in editor, not by hand-writing files.

## Best-Practice References

The architecture choices above derive from these sources (skim before
implementing each section):

- **Project organization** — [Godot 4.6 official docs](https://docs.godotengine.org/en/4.6/tutorials/best_practices/project_organization.html): assets-near-scenes, snake_case, addons/ for third-party, .gdignore for excluded folders.
- **Autoloads + Events bus** — [GDQuest: The Events bus singleton](https://www.gdquest.com/tutorial/godot/design-patterns/event-bus-singleton/) and [Febucci: Godot Signals Architecture 2026](https://blog.febucci.com/2024/12/godot-signals-architecture/). Key rules: signal-only bus, ≤5-10 autoloads, no scene-state in autoloads, avoid bubbling more than 2-3 hops.
- **Node-based state machines** — [GDQuest: Finite State Machine in Godot 4](https://www.gdquest.com/tutorial/godot/design-patterns/finite-state-machine/) and [The Shaggy Dev: Starter state machines](https://shaggydev.com/2023/10/08/godot-4-state-machines/). States as child nodes; states call `transition_to()` themselves.
- **AStarGrid2D** — [Godot AStarGrid2D class docs](https://docs.godotengine.org/en/stable/classes/class_astargrid2d.html) and [Shaggy Dev: Easier pathfinding with AStarGrid2D](https://shaggydev.com/2022/12/19/godot-astargrid2d/). Use `DIAGONAL_MODE_AT_LEAST_ONE_WALKABLE` for tactics-correct behavior. Pathfinding runs in cartesian tile space; only rendering is isometric.
- **Isometric in Godot 4** — official [TileMap isometric mode](https://docs.godotengine.org/en/stable/tutorials/2d/using_tilemaps.html) (move to `TileMapLayer` in 4.6) for the final art pass. For greybox, hand-spawn `Polygon2D` diamonds and use `y_sort_enabled = true` on the battle root for depth sorting.
- **Tactics game architecture** — [GDQuest Tactical RPG Movement series](https://www.gdquest.com/tutorial/godot/2d/tactical-rpg-movement/) is the canonical Godot 2D tactics tutorial. [Shaggy Dev tactics-engine devlog](https://shaggydev.com/2023/07/04/tactics-engine-devlog/) covers structure and action management.
- **Resources for data** — `@export`ed `Resource` subclasses for unit classes, weapons, medals. Avoid script subclasses for content variation; only subclass when behavior differs.

## Patterns to Reuse from This Monorepo

- **Web export + cross-origin-isolation service worker** — already wired in `.github/workflows/build-all.yml`. Adding `war-tactics` to the matrix at line 24 is the only build-pipeline change needed.
- **Export preset shape** — copy `coinshot/export_presets.cfg` as the starting Web preset and edit paths.
- **README + index.html landing entry** — add a table row and a card block to match the existing four games.
- **CLAUDE.md scaffold** — `mythos/CLAUDE.md` is a good shape template (Architecture / Data / Rules / Code Style / Commands), but the *content* should reflect the architecture above, not mythos's autoload-heavy approach.
- **GDD doc style** — match the `designs/end-of-the-line.md` / `designs/stonekeep.md` section structure (already done in the GDD section above).

## Anti-Patterns to Avoid (lessons from the monorepo)

- **Don't autoload every manager.** `mythos/project.godot` registers 7 autoloads (TurnManager, CombatManager, SpellManager, NetworkManager, etc.). For war-tactics, `TurnManager` and `BattleManager` are scene-local concerns and belong inside `battle.tscn`, not as globals. Keep autoloads to the 5 listed.
- **Don't store scene-specific state in autoloads.** `RunState` resets at the start of each run; `Grid` reinitializes per battle. Otherwise state leaks between runs.
- **Don't use enum + giant `match` for turn phases.** Use the node FSM. It scales when you add Defense / Demolition encounter types later.
- **Don't subclass `Unit` for each class.** Compose with `WeaponData` + `UnitClass` resources injected at spawn.

## Verification

**Local:**
1. Open `/home/user/Gamestorming/war-tactics/project.godot` in Godot 4.6.
2. F5 → main scene loads → click "New Run" → Forward Base appears.
3. Click "Continue" → map screen → click first node → battle loads with 3 squad units + 2-3 enemies.
4. Move each unit, fire each weapon (verify both minigames trigger), throw a grenade, set overwatch, end turn.
5. Walk a unit through cover, get attacked from that direction, confirm reduced damage.
6. Kill an enemy, see medal spawn, walk over it, confirm stat buff applied to that unit.
7. Win battle → return to map → progress to next node.
8. Take a hit deliberately, let squad wipe → wipe screen → restart.

**Build pipeline:**
1. Push to `claude/godot-game-prototype-XHumN` → confirm CI matrix picks up `war-tactics`.
2. Merge to `main` → confirm build artifact exports cleanly to `fenyn.github.io/Gamestorming/war-tactics/`.
3. Load in browser, repeat steps 2–8 from local verification.

**Done means:** the build URL plays a full Battle→Map→Base→Battle→Wipe loop with both shooting minigames, cover, grenades, overwatch, and medal pickups working — all in greybox.

## Out of Scope (explicit list — do not build)

Final art, animations, sound polish, skill trees, Requisition Slips meta, recruitment, POWs, gear drops + equipping flow, multiple encounter types beyond Battle, booster items, multiple enemy archetypes, fog-of-war, save/load, particle effects.

## What's Ready for "Greenlight to Build"

When you say go, the following are decided and don't need re-discussion:

- Folder layout (scene-local) and autoload roster (5 globals)
- Architecture (composition units, two node-FSMs, AStarGrid2D)
- Resource shapes for unit/weapon/medal/enemy data
- Build order (5 milestones, M1 → M5)
- Greybox visual standards for every game object
- Best-practice sources to consult per system

Open items that should be answered before or during M5 (not blocking M1-M4):

- **Confirm iso tile dimensions with artist.** Plan assumes 64×32 px (2:1). Artist sample suggests this is right but verify before M1 commits to it — changing later means re-doing greybox proportions.
- **Sprite dimensions per unit.** Sample shows ~24px tall characters; confirm exact height + footprint anchor (feet at tile center).
- **Animation frame counts per state.** Idle / walk (4-dir or 8-dir?) / attack / hit / dead. Artist decides; we'll write the `unit.tscn` to accommodate an `AnimatedSprite2D` with named animations.
- **Tile variants.** Sample shows grass, dirt, stone, sand. Are these purely cosmetic or do they affect movement cost? Plan defaults to cosmetic-only (uniform cost) to keep `AStarGrid2D` simple.
- **Action-bar HUD spec.** Sample shows a 5-slot bar at top. Confirm whether each slot maps to an AP point, an ability slot, or a turn-order indicator.
- **Sound source** (royalty-free pack vs custom — separate decision).
- **Branch strategy:** commit greybox build to `main` (so it appears at `fenyn.github.io/Gamestorming/war-tactics/`) or hold on the feature branch until art lands.
