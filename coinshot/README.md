# Coinshot

A Mistborn-inspired first-person traversal prototype: steel-push and iron-pull on metal anchors, drop coins to launch yourself skyward. Traversal only — no combat or enemies.

- **Engine:** Godot 4.6 (Forward Plus), GDScript
- **Status:** playable
- **Run:** Open `coinshot/project.godot` in Godot 4.6 and press F5.

## Controls
- WASD — move, mouse — look
- Left mouse — lock target, right mouse — add anchor
- Space — push (steel), E — pull (iron)
- Q — drop coin, F — toss coin
- Mouse wheel — burn intensity up/down
- Tab — toggle mist-vision, R — respawn, [ / ] — prev/next level, Esc — quit

## Notes
- Uses **Jolt physics** (`physics/3d/physics_engine="JoltPhysics3D"`) with gravity tuned to 18 m/s² for mass-aware push/pull.
- Push/pull is pure Newton's 3rd law: light coins fly, heavy anchored girders fling the player instead.
- Mist-vision renders blue lines to nearby metal anchors through walls (no depth test), brighter for heavier anchors.
- No external assets — geometry is built from Godot primitives.
