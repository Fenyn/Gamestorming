# Spacefarm

2D top-down space-station farming game: Stardew Valley farming meets
Factorio/Satisfactory tech progression, with a Von Neumann probe twist.

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

- 10 crop types across 4 tiers, each with a unique growth mechanic; multi-step processing chains (raw → basic → advanced → probe materials).
- AI-issued "Directives" as milestone goals, plus optional research sub-milestones; nano-worms (farming) and nano-bees (logistics) for automation.
- Orbital day/night cycle driven by TimeManager (tuning constants in `scripts/autoload/time_manager.gd`).
- Uses the shared `godot_base` addon (junction at `addons/godot_base/`) — state machine, TickEmitter, ScreenFade, SaveFileHandler, InputContext, SfxPool, StyleFactory, WeightedTable.
