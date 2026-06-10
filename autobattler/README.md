# Autobattler

A TFT/Underlords-style Pathfinder 2e autobattler prototype: build a team of PF2e creatures and watch AI-vs-AI combat resolved by a full-fidelity PF2e Remaster rules engine.

- **Engine:** Godot 4.6 (Forward Plus), C# (.NET) + GDScript
- **Status:** prototype
- **Run:** Open `autobattler/project.godot` in the .NET-enabled Godot 4.6 build and press F5.

## Controls
- Mouse-driven UI (no custom input map defined)

## Notes
- **Requires the external PF2e rules engine at `F:\dev\Pf2e.Core`** (netstandard2.1) — the project references it directly and will not build or run without it.
- Creature data is loaded from the OS-absolute path `F:\dev\Pf2e.Core\Data\pf2e-source\packs\pf2e` (not `res://`).
- Combat runs through `AIBattleSimulator` / `BattleRunner` with an async presenter for animations; creatures are tiered 1-5 by PF2e level (-1 through 12).
- Single autoload: `DataManager` (data loading + creature catalog).
