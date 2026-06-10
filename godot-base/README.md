# Godot Base

Shared addon providing reusable base systems for all Gamestorming prototypes.
Godot 4.6, GDScript only. Every module is standalone with zero inter-module
dependencies — projects use only what they need.

The addon lives at `addons/godot_base/`; this project's `project.godot` exists
only so the addon can be developed and tested in isolation.

## Modules

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

Autoload templates in `templates/` are copy-and-customize, not loaded directly:
copy them into the consuming project's `scripts/autoload/` and add
game-specific signals/actions.

## Installing into a project

Consumers (spacefarm, war-tactics, heirloom, life-magic, green-bean, worldseed)
include the addon via an NTFS junction:

```powershell
New-Item -ItemType Junction -Path <project>\addons\godot_base -Target G:\Godot\Gamestorming\godot-base\addons\godot_base
```

Then enable "Godot Base" in Project > Project Settings > Plugins.

Notes on the junction mechanism:

- Git tracks the files *through* the junction, so each consumer commits its own copy of the addon.
- A fresh clone materializes real directories instead of junctions. On a new machine, delete the copied directory and re-create the junction if you want edits in `godot-base` to propagate to all consumers.
