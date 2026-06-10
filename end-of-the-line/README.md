# End of the Line

A logistics incremental with sentient trains: buy builders that autonomously expand your rail network and trains that auto-deliver goods for Gold, all inside a 3-day time loop — at reset you earn Tickets, and veteran trains remember.

- **Engine:** Godot 4.6 (Forward Plus), GDScript
- **Status:** prototype
- **Run:** Open `end-of-the-line/project.godot` in Godot 4.6 and press F5.

## Controls
- Mouse-driven UI (no custom input map defined) — buy panel, ticket shop, HUD

## Notes
- Uses the **Kenney Train Kit** (CC0), vendored in `kenney_train-kit/`.
- Autoloads: `EventBus`, `GameState`, `NetworkManager` (the rail network graph — not multiplayer), `TrainManager`, `BuilderManager`.
- Map nodes (mine, farm, factory, town, port) and train/builder types are data-driven `.tres` resources.
- Full design doc: `designs/end-of-the-line.md`.
