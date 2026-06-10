# Green Bean

A tactile first-person barista simulator: ring up orders on an in-world POS, print tickets with cup codes, and assemble drinks by hand through camera-locked mini-games. Online multiplayer (ENet P2P) is planned but not yet implemented.

- **Engine:** Godot 4.6 (Forward Plus), GDScript
- **Status:** greybox (Phase 1a complete — solo espresso stand, untextured primitives)
- **Run:** Open `green-bean/project.godot` in Godot 4.6 and press F5. The title screen offers New Game / Continue.

## Controls
- WASD — move, Space — jump, mouse — look (crosshair doubles as cursor on in-world screens)
- E — interact with stations (locks camera into the station mini-game); Esc/E — exit mini-game
- Left click — pick up / place items, press POS buttons, drive mini-game inputs

## Notes
- Fully diegetic design: one carried item at a time (Skyrim-style), SubViewport POS screen, physical tickets.
- Mini-games (grind, press, pour, steam, stir) have passive phases with unattended failure states (shot death, milk scald).
- Customers have dual patience meters; drinks are graded with a star review, day ends with a letter grade.
- Uses the shared `godot_base` addon (`addons/godot_base`). Multiplayer host/join is deferred to Phase 1c.
