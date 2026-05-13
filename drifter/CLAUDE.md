# Drifter

Roguelite dice combat game. Godot 4.6, 2D pixel art + 3D physics dice in SubViewport.

## GDScript Rules

- Always explicit type annotations — never `:=` with untyped sources
- Autoload scripts must NOT use `class_name`
- All other scripts should use `class_name`
- Signals defined at top of script with typed parameters
- Private members prefixed with `_`
- Objects placed in `.tscn` files — dynamic children use `packed_scene.instantiate()`, not `Node.new()`
- `@onready var x: Type = %UniqueName` for internal node references
- `@export_group()` for organizing Resource inspector fields

## Architecture

- **3 autoloads only:** EventBus (signals), GameState (meta persistence), RunState (current expedition)
- **Scene-owned managers:** TurnManager (child of CombatScreen), MapController (child of ExpeditionMap)
- **Data:** Custom Resource classes in `scripts/data/`, instances as `.tres` in `resources/`
- **Theme:** StyleBoxTexture with DARK UI 9-slice sprites, not programmatic StyleBoxFlat
- **Drag-and-drop:** Native Godot `_get_drag_data` / `_can_drop_data` / `_drop_data`
- **Dice:** 3D RigidBody3D in SubViewport, dark metal + teal glow material

## Asset Credits

- Penusbmic (itch.io) — Planet One environment, Hero Sprite, DARK Character Pack 3, DARK Mech Mini Boss, DARK UI
- JDSherbert (itch.io) — 3D Dice Pack D6
