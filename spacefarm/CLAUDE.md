# Spacefarm

2D top-down space station farming game. Stardew Valley farming meets Factorio/Satisfactory tech progression. Working title â€” Godot 4.6, GDScript.

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

### Autoloads (5)

- **EventBus** â€” Pure signal hub, zero logic
- **InputManager** â€” Aggregates input, InputContext mode switching (GAMEPLAY / MENU / CUTSCENE)
- **GameState** â€” All persistent data (inventory, progression, unlocks)
- **TimeManager** â€” Orbital day/night cycle via TickEmitter
- **Database** â€” Preloads all .tres resources, provides typed getters

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
- **Processing**: Multi-step chains (raw â†’ basic â†’ advanced â†’ probe materials)
- **Directives**: AI-issued milestone requirements (Satisfactory Space Elevator equivalent)
- **Sub-milestones**: Optional research unlocks for automation and tool upgrades
- **Nano-worms**: Farming automation (ground-level)
- **Nano-bees**: Logistics automation (flying)
- **Terminal**: Story delivery via escalating log entries
- **Contacts**: AI-simulated NPCs for social simulation

## Tuning Constants

Located in `scripts/autoload/time_manager.gd`:
- `SECONDS_PER_GAME_HOUR = 10.0` (use 30 for release pacing)
- `HOURS_PER_DAY = 16`
- `DAYS_PER_SEASON = 14`
- `DAY_START_HOUR = 6`
- `DAY_END_HOUR = 22`

## Deferred Features

- Tier 3-4 crops (Nebula Moss, Void Bloom, Archive Fern)
- Directives 3-4 (Continuity Protocol, Project Genesis)
- Track 3-4 sub-milestones (full automation, self-replicating)
- Save/load system
- Audio
- Proper pixel art assets
