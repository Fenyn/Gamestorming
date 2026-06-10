# Mythos

A lane-combat card game with city building. Summon units into lanes, grow your city's resource economy, and destroy the opponent's Grand Lodge (HQ) to win.

- **Engine:** Godot 4.6 (Forward Plus), GDScript
- **Status:** prototype
- **Run:** Open `mythos/project.godot` in Godot 4.6 and press F5.

## Controls
Mouse-driven: left click (select/play) and right click are the only mapped input actions.

## Notes
- Turn phases: Draw → City → Spells → Battle → Summon → Build, with lane-by-lane combat resolution. 30-card decks (units + buildings); spells sit on an always-available 5-position countdown track.
- Card data is `.tres` resources in `resources/cards/nordic/` (UnitData / BuildingData / SpellData); the board is built procedurally in code.
- ENet P2P `NetworkManager` autoload exists (dual-simulation lockstep planned).
- See `Mythos Design Doc.md` in this directory for the full design.
