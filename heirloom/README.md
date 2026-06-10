# Heirloom

A first-person rural life sim set in mid-2000s Washington state. Inherit your grandfather's homestead, work odd jobs to cover the monthly land payment, and rebuild his rusted-out '69 Camaro one part at a time.

- **Engine:** Godot 4.6 (Forward Plus), GDScript
- **Status:** playable prototype
- **Run:** Open `heirloom/project.godot` in Godot 4.6 and press F5.

## Controls
- WASD — move, mouse — look, Space — jump
- E — interact
- Left click — pick up / place items
- F — eat
- Shift — sprint (drains fatigue faster)
- B — toggle bicycle (2x speed, can't carry items)
- Esc — pause menu

## Notes
- PSX-style low-poly: survival needs, economy with a monthly $200 land bill, 16 homestead upgrades, an 11-part Camaro rebuild chain, and two NPCs with friendship levels.
- Uses the Terrain3D addon; `assets/`, `terrain_data/`, and `addons/` (except `godot_base`) are gitignored — local asset packs (PSX Mega Pack I/II, PSX Nature, psxpack-1.0) are required for full visuals.
- The shared `godot_base` addon is tracked in-repo. Saves are JSON to `user://`, autosaving on sleep.
