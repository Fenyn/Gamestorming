# Godot Base

Shared addon providing reusable base systems for all Gamestorming prototypes. Godot 4.6, GDScript only.

## GDScript Rules

- Always explicit type annotations — never `:=` with untyped sources
- Autoload scripts must NOT use `class_name` — autoload name is the global ID
- All non-autoload scripts should use `class_name`
- Signals defined at top of script with typed parameters
- Private members prefixed with `_`
- Objects placed in `.tscn` files — dynamic children use `packed_scene.instantiate()`, not `Node.new()`
- `@onready var x: Type = %UniqueName` for internal node references

## Architecture

This is a Godot addon at `addons/godot_base/`. Every module is standalone — zero inter-module dependencies. Projects use only what they need.

### Modules

| Module | Class | Type | Purpose |
|--------|-------|------|---------|
| `state_machine/` | `BaseStateMachine`, `BaseState` | Node (composable) | Node-based state machine with lifecycle methods |
| `save/` | `SaveFileHandler` | RefCounted (utility) | JSON save/load with versioned migration |
| `audio/` | `SfxPool` | Node (composable) | Pooled AudioStreamPlayer with loop management |
| `input/` | `InputContext`, `InputConfig` | RefCounted, Resource | Multi-mode input filtering and sensitivity config |
| `transitions/` | `ScreenFade`, `SceneChanger` | ColorRect, Node | Tween-based fade overlay and scene transitions |
| `scene_infrastructure/` | `ScreenManager`, `MainMenuBase` | Node, Control | Dictionary-based screen container and main menu scaffold |
| `components/` | `HealthComponent` | Node (composable) | HP tracking with signals for damage/heal/death |
| `utils/` | `WeightedTable`, `TickEmitter`, `StyleFactory` | RefCounted, Node, static | Weighted RNG, fixed-interval ticks, StyleBoxFlat builder |
| `templates/` | — | Template files | Copy-and-customize autoload scaffolds (EventBus, InputManager) |

### Integration

Projects include this addon by symlinking or copying `addons/godot_base/` into their `addons/` directory, then enabling "Godot Base" in Project > Project Settings > Plugins.

Template files (`templates/`) are meant to be copied into the consuming project's `scripts/autoload/` and customized with game-specific signals/actions.

## Project Layout

```
godot-base/
├── project.godot
├── CLAUDE.md
└── addons/godot_base/
    ├── plugin.cfg
    ├── plugin.gd
    ├── state_machine/
    ├── save/
    ├── audio/
    ├── input/
    ├── transitions/
    ├── scene_infrastructure/
    ├── components/
    ├── utils/
    └── templates/
```
