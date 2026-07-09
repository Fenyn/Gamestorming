# Combat map export conventions (Crocotile 3D -> Godot)

Combat grid maps are authored as 3D environments in **Crocotile 3D** and exported as **glTF**.
The 2.5D combat scene (`res://scenes/combat/combat.tscn`) places 2D billboard unit sprites on top of
this 3D floor, so the map only needs to supply the walk surface and set dressing — the grid math is
fixed in code (`res://scripts/combat/GridSpace.cs`).

## Hard conventions (must match, or units float / desync from tiles)

| Rule            | Value                                                                   |
|-----------------|-------------------------------------------------------------------------|
| Format          | glTF binary, `.glb`                                                      |
| Scale           | **1 tile = 1 meter** (1 Godot unit)                                      |
| Grid tile (x,y) | occupies world **x .. x+1 on X** and **y .. y+1 on Z**                   |
| Floor surface   | walkable floor top at **world y = 0**                                    |
| Origin          | grid tile **(0,0)'s corner** sits at the world origin (0,0,0)            |
| Up axis         | +Y up (Godot default); grid rows run along **+Z**, columns along **+X**  |

A tile's center — where a unit stands — is therefore `(x + 0.5, 0, y + 0.5)`.
A 12 x 10 encounter spans world X `0..12` and Z `0..10`; its center (camera pivot) is `(6, 0, 5)`.

## How to drop a map into the scene

1. Export the map from Crocotile as `<name>.glb` into `res://assets/maps/`.
2. Open `res://scenes/combat/combat.tscn`.
3. Under **`MapRoot`**, delete (or hide) `PlaceholderFloor` and instance your `.glb`
   (drag it in, or add a `Node3D`/imported scene).
4. Align the map so tile (0,0)'s corner is at world origin and the floor top is at y = 0.
   With the conventions above, the imported map needs **no offset** — position it at `(0, 0, 0)`.
5. Press play. Units, highlights, and the orbit camera are all driven from the grid size in the
   `CombatSetup`, so no further wiring is needed.

## Notes / future work

- Current maps are treated as **flat** (units sit at y = 0 and picking ray-casts the y = 0 plane).
  Maps with elevation will need a floor **collider** and a physics raycast in `GridSpace` instead of
  the flat-plane intersection — flagged in code where the plane cast happens.
- Keep textures at nearest-neighbor filtering to match the pixel/low-poly look.
