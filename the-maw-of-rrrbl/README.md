# The Maw of Rrrbl

A builder-incremental game: place marble track pieces in 3D, watch orbs roll,
earn Sparks from distance traveled, and feed The Maw until it implodes and
resets the world.

- **Engine:** Godot 4.6 (Forward Plus), GDScript
- **Status:** prototype
- **Run:** Open `the-maw-of-rrrbl/project.godot` in Godot 4.6 and press F5.

## Controls

- **Left click** — place selected piece / click a Dreamer Portal
- **R** — rotate ghost piece
- **Tab** — cycle ghost connection point
- **Esc** — cancel selection
- **Ctrl+Z** — undo last placement
- **Right drag** — orbit camera; **Middle drag** — pan; **Wheel** — zoom
- **F5 / F9** — save / load track blueprint

## Notes

- Core loop: build track → orbs auto-spawn and roll → distance = Sparks → buy pieces/upgrades → Maw fills → implosion (prestige) → Void Marbles → rebuild bigger.
- Uses the Kenney Marble Kit (CC0) for track pieces — the `kenney_marble-kit/` folder is gitignored and must be downloaded separately.
- Orb variety (Glass, Stone, Whisper, Clutch, Gilt, Void, The Eye) with distinct physics/value traits; design details in `DESIGN.md`.
