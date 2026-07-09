# Bulwark

A Stardew Valley × Pathfinder 2e prototype: a squad of 4 restores a ruined frontier outpost, farms for resources, and fights tactical PF2e battles in the surrounding territories.

- **Engine:** Godot 4.6 (Forward Plus), C# (.NET)
- **Status:** scaffold / prototype
- **Run:** Open `bulwark/project.godot` in the .NET-enabled Godot 4.6 build and press F5.

## Notes
- **Requires the external PF2e rules engine at `F:\dev\Pf2e.Core`** (netstandard2.1) — the project references it directly and will not build or run without it.
- Data is loaded from the OS-absolute path `F:\dev\Pf2e.Core\Data\pf2e-source\packs\pf2e` (not `res://`).
- Autoloads: `DataManager` (pack/content loading), `GameState` (single authoritative mutable state root), `SceneRouter` (mode transitions between Outpost, Territory, and Combat).
- See `CLAUDE.md` for engineering conventions.
