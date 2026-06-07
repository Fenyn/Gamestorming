# Autobattler — PF2e TFT-style Prototype

Godot 4.6 C# (.NET 8) prototype. TFT/Underlords-style autobattler using the PF2e Remaster rules engine at full fidelity.

## Architecture

- **Language**: C# (NOT GDScript — this project references Pf2e.Core)
- **Rules engine**: `F:\dev\Pf2e.Core` (netstandard2.1) — complete PF2e combat, AI, 659 creatures
- **Data path**: `F:\dev\Pf2e.Core\Data\pf2e-source\packs\pf2e` (OS-absolute, not res://)

## Key Integration Points

- `AIBattleSimulator(BattleGrid, BattleRunner)` — runs AI-vs-AI encounters
- `BattleRunner.SetPresenter(Func<BattleEvent, Task>)` — async event presenter for animations
- `CreatureFactory.Create(EnemyDefinition, teamId)` — instantiates combat-ready creatures
- `GameDataLoader.LoadAll(string)` + `CreatureImporter.ImportAll(string)` — data loading

## Namespace Aliases

Pf2e.Core defines `PF2e.Vector2Int`, `PF2e.Vector3`, `PF2e.Color` which conflict with Godot types.
In bridge files use: `using PF2eVec = PF2e.Vector2Int;`

## Conventions

- Autoloads: DataManager (data loading + creature catalog)
- No class_name equivalent needed in C# (class name IS the identifier)
- Scenes in `scenes/`, scripts in `scripts/` organized by system
- Creature tiering: PF2e level -1..1 = Tier 1, 2..3 = Tier 2, 4..5 = Tier 3, 6..8 = Tier 4, 9..12 = Tier 5
