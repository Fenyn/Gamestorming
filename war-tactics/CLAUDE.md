# War Tactics

WWII squad-tactics roguelike. Godot 4.6, 2D isometric pixel art, Forward Plus.

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

- **5 autoloads (hard cap 6):** Events (signal bus), RunState (per-run data), MetaState (cross-run unlocks stub), Database (resource cache stub), Grid (AStarGrid2D + iso projection)
- **Scene-local folders:** each scene lives alongside its scripts and resources
- **Composition over inheritance:** units composed of child nodes (Health, Mover, Attacker, etc.), not subclassed per unit type
- **Node-based state machines:** for unit action states and battle turn phases (states as child nodes with enter/exit/update)
- **Signal bus for cross-scene only:** local communication uses direct signals; Events bus only for decoupling distant scenes (Battle ↔ Map ↔ Base)

## Isometric Rendering

- Tile size: 64×32 px (2:1 iso)
- Projection: `world = Vector2((tile.x - tile.y) * 32, (tile.x + tile.y) * 16)`
- Layering via z_index: TileLayer (0) < OverlayLayer (1) < EntityLayer (2)
- EntityLayer uses `y_sort_enabled = true` for depth-sorting units among each other
- Greybox visuals: Polygon2D diamonds for tiles, colored rectangles for units

## Project Layout

```
war-tactics/
├── project.godot
├── CLAUDE.md
├── globals/          # autoloads only
├── main/             # root scene + screen management
├── battle/           # battle scene, units, overlays, levels
│   ├── unit/
│   ├── grid_overlay/
│   └── levels/
├── map/              # node-map screen (stub)
└── base/             # forward base screen (stub)
```
