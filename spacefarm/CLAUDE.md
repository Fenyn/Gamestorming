# Spacefarm

2D top-down sci-fi farming game set aboard the Titan, a massive alien ship. Stardew Valley farming meets first-contact survival. Working title -- Godot 4.6, GDScript.

## Narrative Context

Near-future Earth detects an alien vessel and sends a 16-person crew aboard the shuttle Hermes to investigate. Upon boarding, the alien ship (dubbed the Titan) activates and jumps to a distant star system, stranding the crew. The player is the squad's botanist, responsible for growing food to keep everyone alive. Areas of the Titan unlock as the crew repairs systems and learns to operate alien technology. See `docs/premise.md` for the full world bible.

## Documentation

| Document | Purpose |
|---|---|
| `docs/premise.md` | World bible -- setting, situation, ships, themes, tone |
| `docs/terminology_map.md` | Old-to-new term mapping, code vs display naming rules |
| `docs/ship_layout.md` | The Titan as game world -- rooms, zones, unlock progression |
| `docs/crew_manifest.md` | 16 crew members -- mission roles and gameplay functions |
| `docs/progression.md` | Story arc, directive system, dual AI, alien language |
| `docs/content_status.md` | What's DECIDED vs TBD vs BLOCKED -- check before content work |

## Naming Discipline

Display text (display_name, ai_message, description, lore_hint, UI labels) uses new terminology. Code identifiers (variable names, room_ids, file paths, signal names) keep current names until a coordinated rename pass. When writing new code, use new terms for both. When in doubt, check `docs/terminology_map.md`.

## GDScript Rules

- Always explicit type annotations â€” never `:=` with untyped sources
- Autoload scripts must NOT use `class_name`
- All other scripts should use `class_name`
- Signals defined at top of script with typed parameters
- Private members prefixed with `_`
- Objects placed in `.tscn` files â€” dynamic children use `packed_scene.instantiate()`, not `Node.new()`
- `@onready var x: Type = %UniqueName` for internal node references
- `@export_group()` for organizing Resource inspector fields

## Architecture

### Autoloads (6)

- **EventBus** -- Pure signal hub, zero logic
- **InputManager** -- Aggregates input, InputContext mode switching (GAMEPLAY / MENU / CUTSCENE)
- **GameState** -- Player inventory, progression, unlocks, save/load orchestration
- **TimeManager** -- Day/hour clock via TickEmitter, day-of-week and season helpers
- **Database** -- Preloads all .tres resources (crops, recipes, milestones, contacts), typed getters
- **CrewManager** -- Crew relationships, gift tracking, talk/decay logic, idle chatter, birthday checks

### godot-base Addon

Shared addon via junction at `addons/godot_base/`. Used modules:
- `BaseStateMachine` + `BaseState` â€” crop tile states, machine states
- `TickEmitter` â€” TimeManager hour ticks
- `ScreenFade` â€” day/scene transitions
- `SaveFileHandler` â€” game persistence
- `InputContext` â€” input mode filtering
- `SfxPool` â€” audio
- `StyleFactory` â€” UI styling
- `WeightedTable` â€” RNG

### Data

Resource class definitions in `resources/` (with `class_name`). Instances as `.tres` in `data/`.

### Scenes

Organized by system domain under `scenes/`. Scripts live alongside their scenes.

## Core Systems

- **Crops**: 10 types across 4 tiers, each with unique growth mechanic
- **Processing**: Multi-step chains (raw -> basic -> advanced)
- **Directives**: Milestone requirements issued by the Hermes AI (early game) and Titan AI (late game). Satisfactory Space Elevator equivalent.
- **Sub-milestones**: Optional research unlocks for automation and tool upgrades
- **Automation**: [TBD re-theme] Farming automation (ground-level) and logistics automation (flying) -- currently nano-worms/nano-bees, pending alien-context redesign
- **Energy**: GameState.energy (100 max); till 2 / water 1 / harvest 1. Sleeping in bed restores full; working past 22:00 shutdown wakes at 75%
- **Sleep loop**: bed ends day early; day summary panel during fade; save-on-sleep includes crop tile snapshots (GameState.save_game / restore_crop_tiles)
- **Biome gating**: CropData.biome must match the bay's BaseRoom.biome to plant; ring bays unlock via directive module rewards (grow_ring_b/c/d in Station.MODULE_DOORS)
- **Terminal**: Story delivery via log entries from the Hermes AI (early) and decoded Titan data (late)
- **Crew**: 16 mission specialists aboard the Titan -- real NPCs with vendor/service roles (see `docs/crew_manifest.md`)

## Tuning Constants

Located in `scripts/autoload/time_manager.gd`:
- `SECONDS_PER_GAME_HOUR = 10.0` (dev speed; release: 42.0 to match Stardew pacing)
- `HOURS_PER_DAY = 20` (6am-2am)
- `DAYS_PER_SEASON = 28` (4 weeks per season)
- `DAYS_PER_WEEK = 7` (Monday-Sunday, derived from day number)
- `DAY_START_HOUR = 6`
- `DAY_END_HOUR = 26` (2am)
- `SEASON_NAMES = ["Radiance", "Blaze", "Dusk", "Frost"]` (jump-driven, not Earth seasons)

## Deferred Features

- Tier 3-4 crops (Nebula Moss, Void Bloom, Archive Fern)
- Directives 3-4 (tied to Titan AI awakening and Act 2-3 story arc)
- Track 3-4 sub-milestones (automation, alien tech mastery)
- Audio
- Titan exterior exploration: EVA operations on the ship's hull and damaged outer sections (replaces forage concept)
- NPC vendor/service systems, crew schedules, social/relationship mechanics
- Alien language display and translation progression
- Titan AI interface and communication system

## Room Visuals & Collision

Rooms are tiled via `resources/room_tileset.tres` (LimeZu Modern Interiors Room Builder sheets, 48x48). Wall tiles carry full-tile collision through the tileset's physics layer — the painted walls ARE the collision; `BaseRoom` spawns no collision bodies. Exit zones and entrance markers are baked into each room scene; sealed airlocks stay solid wall until `unlock_airlock()` erases the door tiles and creates the exit at runtime.

The tileset and all room tilemaps are generated by `tools/room_painter.gd`:

    godot --headless --path . --script tools/room_painter.gd

Room sizes/floor tiles/wall bands/biomes are configured in that script's `ROOMS` table. Room dimensions must stay multiples of 48 with even tile counts so the 96px (2-tile) door gaps stay centered. Floor tiles were chosen with `tools/floor_seam_analysis.gd` and `tools/tile_hue_scan.gd` (lowest wrap-seam error, on-hue). Regression-check with `tools/validate_rooms.gd` (painted layers, tile collision, exit reciprocity incl. sealed airlocks); render previews with `tools/screenshot_rooms.gd`.

## Ship Layout

Rooms sit on a 4000px grid in `station.tscn`; exits teleport between them (each room is its own screen). Code room_ids are unchanged; display names reflect the Titan setting (see `docs/terminology_map.md`). Full layout details in `docs/ship_layout.md`.

The grow wing is four connected biome chambers walkable in a loop:

- **Grow Chamber Alpha — Verdant** (grow_bay, 30x20 tiles, 6 plots) — Commons east; also corridor south
- **Grow Chamber Beta — Arid** (grow_bay_b, 22x14, 4 plots) — east of Alpha
- **Grow Chamber Gamma — Fungal** (grow_bay_c, 22x14, 4 plots) — south of Beta
- **Grow Chamber Delta — Cryo** (grow_bay_d, 22x14, 4 plots) — west of Gamma, south of Alpha

Biome chambers have a walkway ring inside the walls with the biome terrain field inset. Habitat rooms: Commons (hub) 16x12, Cargo Hold 16x12, Workshop (processing_lab) 16x10, Research Lab (advanced_processing) 14x10, Bio-Lab (hybridization_lab) 12x8, Crew Quarters (living_quarters) 12x8, Maintenance Corridor (service_tunnel) 6x16. Crops are biome-gated (CropData.biome vs BaseRoom.biome); Beta/Gamma/Delta start sealed and unlock via directives.
