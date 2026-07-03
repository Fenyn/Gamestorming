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
- `BaseStateMachine` + `BaseState` -- crop tile states, machine states, NPC AI states (Idle/Wander/Talking/Transit/Relocating)
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

- **Crops**: 10 types across 4 tiers, each with unique growth mechanic. Jump-driven seasons (Radiance/Blaze/Dusk/Frost) will determine what grows when.
- **Processing**: Multi-step chains (raw -> basic -> advanced), 3 machine types
- **Supply Board**: Community Center-style bundle system (replaced old cargo pod). Three sections: Provisions, Crew Requests, Ship Restoration. Data-driven via SupplyRequestData .tres files in `data/supply_requests/`
- **Crew NPCs**: 15 crew members (CharacterBody2D) with NavigationAgent2D pathfinding, 5-state machine (Idle/Wander/Talking/Transit/Relocating), room-graph traversal, phase-on-stuck. Spawned from ContactData .tres files in `data/contacts/`
- **Heart System**: CrewManager autoload. 10 hearts (250pts each), 5 gift tiers (loved/liked/neutral/disliked/hated), 2 gifts/week (reset Monday), -2 decay/day, 8x birthday multiplier. SocialConfig resource for tuning
- **Dialogue Panel**: Overlay for NPC conversations. Supports single lines, multi-step sequences, and choice buttons. Heart events trigger at hearts 2/4/6/8/10 with location+time conditions
- **NPC Schedules**: Day-of-week string keys + hour -> room_id. NPCs walk to exits and transit through intermediate rooms via BFS pathfinding. Deferred moves retry each frame if NPC is busy
- **Energy**: GameState.energy (100 max); till 2 / water 1 / harvest 1. Sleeping in bed restores full; working past shutdown wakes at 75%
- **Sleep loop**: bed ends day early; day summary panel during fade; save-on-sleep includes crop tile snapshots
- **Biome gating**: CropData.biome must match the bay's BaseRoom.biome to plant; bays unlock via supply board restoration bundles
- **Terminal**: Story delivery via log entries from Maia (early) and decoded Titan data (late)
- **Navigation**: Each BaseRoom auto-generates a NavigationRegion2D. NPCs pathfind within rooms via NavigationAgent2D

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

- **Phase 5: Ship Zones** -- new room scenes (Hangar, Triage Bay, Vivarium, Stellar Array, Data Vault, Command Nexus, Drive Core, The Sanctum), restoration bundle .tres files, Titan Fragment tracking
- **Phase 5b: Hermes Mining** -- laser mining minigame, asteroid field data, Hermes upgrade flow (needs UX design decision)
- **Phase 7: Crew Services** -- per-NPC service panels: ShopPanel (Quartermaster), UpgradePanel (Engineer), CookingPanel (Chef), ClinicPanel (Medic), ResearchPanel (Physicist), CollectionPanel (Xenobiologist)
- **Phase 8: Automation** -- replace removed worm/bee stubs with alien-context system (needs creative decision: alien symbiotes vs Titan subsystems vs crew tasks)
- **SeasonManager autoload** -- visual tints per season, time multipliers per star system, jump transitions, prediction data for Stellar Array
- **Tier 3-4 crops** (Nebula Moss, Void Bloom, Archive Fern) -- unlocked via Data Vault
- **Audio**
- **Alien language mechanic** -- glyph display, translation progression, Linguist NPC integration
- **Titan AI interface** -- second AI voice, alien directives, Command Nexus interaction
- **Content authoring** -- crew names, personalities, idle chatter, gift preferences, heart events, supply requests, story entries, crop season assignments. All systems built, zero content. See `docs/content_status.md`

## Room Visuals & Collision

Rooms are tiled via `resources/room_tileset.tres` (LimeZu Modern Interiors Room Builder sheets, 48x48). Wall tiles carry full-tile collision through the tileset's physics layer — the painted walls ARE the collision; `BaseRoom` spawns no collision bodies. Exit zones and entrance markers are baked into each room scene; sealed airlocks stay solid wall until `unlock_airlock()` erases the door tiles and creates the exit at runtime.

The tileset and all room tilemaps are generated by `tools/room_painter.gd`:

    godot --headless --path . --script tools/room_painter.gd

Room sizes/floor tiles/wall bands/biomes are configured in that script's `ROOMS` table. Room dimensions must stay multiples of 48 with even tile counts so the 96px (2-tile) door gaps stay centered. Floor tiles were chosen with `tools/floor_seam_analysis.gd` and `tools/tile_hue_scan.gd` (lowest wrap-seam error, on-hue). Regression-check with `tools/validate_rooms.gd` (painted layers, tile collision, exit reciprocity incl. sealed airlocks); render previews with `tools/screenshot_rooms.gd`.

## Ship Layout

Rooms sit on a 4000px grid in `station.tscn`; exits teleport between them (each room is its own screen). Code room_ids are unchanged; display names reflect the Titan setting (see `docs/terminology_map.md`). Full layout details in `docs/ship_layout.md`.

Grow bays use jump-driven seasons (not preset biomes) for crop variety. See `docs/ship_layout.md` for full room inventory and unlock progression.

- **Grow Bay 1** (grow_bay) — Small damaged alcove, 4 plots, jury-rigged. Starting area.
- **Grow Bay 2** (grow_bay_b) — Full alien cultivation array, 8+ plots, intact infrastructure, automation hooks. Unlock B (~3 hrs).
- **Grow Bay 3** (grow_bay_c) — Specialized alien substrate, supports unique crop types. Unlock F (~20 hrs).
- **Grow Bay 4** (grow_bay_d) — Currently in code but may be removed in Phase 5 layout rework.

Habitat rooms: Commons (hub) 16x12, Cargo Hold 16x12, The Forge (processing_lab) 16x10, Analysis Chamber (advanced_processing) 14x10, Splice Lab (hybridization_lab) 12x8, Crew Quarters (living_quarters) 12x8, Maintenance Corridor (service_tunnel) 6x16. Room unlocks use bundle-based restoration system (Community Center style).
