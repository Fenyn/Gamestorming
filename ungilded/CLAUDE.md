# Ungilded

Story-driven PF2e tactics game. Godot 4.6 C# (.NET 8). This project hosts the opening (Prologue). The spec is `designs/ungilded_opening.md` in the repo root. Build and spike commands are in README.md.

The rules engine is Pf2e.Core at `F:\dev\Pf2e.Core`, shared with Delve. Changes to Pf2e.Core must be additive and must keep Delve building.

The combat layer was copied from Delve on 2026-10-18 and now evolves on its own. Do not edit `delve/` from here.

On-screen text follows the repo rule "A screen is not a narrator" in `G:\Godot\Gamestorming\CLAUDE.md`.

## Writing

- Simplified Technical English: short sentences, active voice, one term per concept, no idioms or filler.
- Lead with the result. Omit process narration. No headers for simple answers.

## Composition

- Build objects from small child scenes. A unit token = sprite animator + HP bar + team ring.
- One job per component. The sprite animator knows nothing about characters or HP.
- Inheritance only for shared lifecycle (`OneShotFx`, `SpikeBase`).
- One responsibility per file. Split at ~300 lines or two concerns.
- Extract a shared helper on the second occurrence (`MeshBuffer`, `DamageColors`, `PixelSprite`).
- Per-kind behaviour lives in one data table (`SkillActionCatalog`, `BiomeThemes`), not scattered switches.

## Godot

- Structure and tunables in `.tscn` via `[Export]`. No `res://` strings or magic numbers in scripts.
- Resolve nodes with `%UniqueName` or `[Export]`. No string paths, no child type-scans.
- Components signal outward. A child never reaches its parent.
- Factories configure on spawn (`UnitVisual3D.Spawn`). No call-order contracts before `_Ready`.
- Cache shared materials, shaders, scenes. No `static readonly` loads.
- Data records (themes, presets) stay free of Godot types.
- Autoloads expose `Instance`, no `class_name`.
- One collision/mesh sub_resource per node size.

## Lifecycle

- Pf2e.Core globals are claimed and released through `EngineEncounterScope`. No static clears without an owner check.
- `CombatScene.StartEncounter` stays re-entrant. `ResetEncounter` frees everything an encounter made.
- Handlers on persistent nodes are wired once.

## Verify

- `dotnet build Ungilded.sln -c Debug --no-incremental`: 0 errors, 0 Ungilded warnings.
- Every README spike prints `SPIKE RESULT: PASS`. Add a check when coverage is missing.
- Visual changes: rendered `combat_smoke_spike` before and after.
- UTF-8, no BOM.
