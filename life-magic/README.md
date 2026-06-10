# Life Magic

An idle/incremental game powered by your heartbeat. You are a wizard channeling life magic from your tower; the game's tick speed scales with your real heart rate — rest and the magic flows gently, exercise and it surges.

- **Engine:** Godot 4.6 (GL Compatibility), GDScript
- **Status:** playable
- **Run:** Open `life-magic/project.godot` in Godot 4.6 and press F5.

## Controls
Touch/mouse-driven UI (mobile portrait, 420x800, touch emulated from mouse). Debug keys:
- M — add 1,000 mana
- N — add 1,000,000 mana
- Scroll wheel — adjust simulated BPM (Manual mode)

## Notes
- Heart-rate modes: Demo (built-in simulated workout, runs immediately), Manual (scroll wheel), Device (WebSocket bridge — run `python tools/hr_simulator.py`, then pick Device mode; `ws://localhost:9876`).
- Five-tier cascading generators, Sanctum sigils with attunement, upgrades, surges, milestones, prestige, and a tutorial — all data-driven via `.tres` resources.
- Mobile target: Android export presets, an APK build, and a `wear/` module are in-tree. Uses the shared `godot_base` addon.
