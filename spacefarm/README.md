# Spacefarm

2D top-down sci-fi farming game set aboard the Titan, a massive alien ship.
A crew of 16 astronauts must survive after their first-contact mission goes sideways.

- **Engine:** Godot 4.6 (Forward Plus), GDScript
- **Status:** greybox prototype
- **Run:** Open `spacefarm/project.godot` in Godot 4.6 and press F5.

## Controls

- **WASD** — move
- **E / Left click** — interact
- **1-5** — select tool
- **Tab** — inventory
- **M** — map
- **Esc** — pause

## Notes

- 10 crop types across 4 tiers, each with a unique growth mechanic; multi-step processing chains (raw -> basic -> advanced).
- M.A.I.A. (the Hermes shuttle AI) issues "Directives" as milestone goals; the Titan's alien AI awakens as the crew repairs ship systems.
- Orbital day/night cycle driven by TimeManager (tuning constants in `scripts/autoload/time_manager.gd`).
- Uses the shared `godot_base` addon (junction at `addons/godot_base/`) — state machine, TickEmitter, ScreenFade, SaveFileHandler, InputContext, SfxPool, StyleFactory, WeightedTable.
- See `docs/` for world bible, crew manifest, ship layout, and progression design.
