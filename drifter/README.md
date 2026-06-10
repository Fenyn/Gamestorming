# Drifter

A roguelite dice combat game on a barren alien planet: roll five physics dice Yahtzee-style, drag them into ability sockets to fire attacks, and push deeper through a Slay-the-Spire-style expedition map.

- **Engine:** Godot 4.6 (Forward Plus), GDScript
- **Status:** prototype
- **Run:** Open `drifter/project.godot` in Godot 4.6 and press F5.

## Controls
- Mouse — drag dice into ability sockets (native Godot drag-and-drop)
- Space — end turn
- R — reroll

## Notes
- 2D pixel art (Penusbmic Planet One / DARK packs) with real 3D `RigidBody3D` dice rolled in a SubViewport (JDSherbert D6 pack).
- Three autoloads: `EventBus` (signals), `GameState` (meta persistence), `RunState` (current expedition); managers are scene-owned.
- Data-driven via custom Resource classes in `scripts/data/` with `.tres` instances in `resources/`.
