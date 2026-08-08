# Bulwark — PF2e Frontier Outpost Prototype

Godot 4.6 C# (.NET 8). Stardew Valley × Pathfinder 2e: squad of 4 restores a ruined border outpost, farms for resources, and fights tactical PF2e battles in surrounding territories.

## Architecture

- **Language**: C# only (references Pf2e.Core; the GDScript godot_base addon is NOT used)
- **Rules engine**: `F:\dev\Pf2e.Core` (netstandard2.1) — full PF2e Remaster combat, AI, PC building
- **Data path**: `F:\dev\Pf2e.Core\Data\pf2e-source\packs\pf2e` (OS-absolute, not res://)
- **Namespace aliases**: Pf2e.Core defines `PF2e.Vector2Int` etc. that conflict with Godot types — in bridge files use `using PF2eVec = PF2e.Vector2Int;`

## Engineering standards

Layering (dependencies point down only):

    UI (Control scenes)  →  Game systems (plain C#)  →  Pf2e.Core
    World (Node3D scenes) ↗

- Game logic lives in plain C# classes, not Nodes. Nodes are thin adapters: read input, render state, forward calls.
- Autoload discipline: exactly three — DataManager (pack/content loading), GameState (single authoritative mutable state root), SceneRouter (mode transitions). Nothing else global.
- Command/query separation on GameState: mutations only via intent-named commands (PlantCrop, SpendResources, RepairBuilding) that validate and emit change events. UI never mutates state directly (future co-op seam).
- Signals up, calls down. No GetParent() casts, no GetNode("../..").
- One scene = one responsibility, composed by instancing. Scenes run standalone (F6) with null-safe fallbacks.
- Node access via %UniqueName; exported fields for tunables.
- UI is passive: renders from state-change events, raises intent events. No game rules in Control scripts.
- Data-driven content: crops, buildings, quests, variant combos, encounter tables are declarative definitions in scripts/data/ — adding content touches data only.
- C#: .NET naming, nullable enabled, one class per file, folders mirror namespaces (Bulwark.Combat, Bulwark.Cozy, Bulwark.Save, Bulwark.Quests, Bulwark.Dialogue, Bulwark.Settings, Bulwark.Territory, Bulwark.Data, Bulwark.UI, Bulwark.Autoload).
- Engine types never leak into UI code; UI consumes view-model shaped data from system classes.
- Error channels: plain-C# systems signal failure through return values / results (or the PF2e `Log` seam), never `GD.Print`. Godot-side classes (Nodes, loaders, autoloads) use `GD.PushError`/`GD.PushWarning` for genuine problems (missing/malformed content, broken references) so they surface in the editor's error panel; `GD.Print` is for chatter only (progress, adopted-instance notices). Content-load referential integrity is validated fail-fast by `DataValidation.RunAll` (dev builds only).

## Scene/asset conventions

- Objects placed in .tscn (authored, not spawned by script); dynamic children via PackedScene.instantiate().
- Unique collision shapes per differently-sized node (no shared sub_resources).
- No UTF-8 BOM in any Godot text file (.tscn/.tres/.csproj/project.godot). Texture filter nearest.
- World scenes are 3D greybox (Node3D roots: outpost, the three territories, the intro scenes). 1 cell = 1 m; cell (x,y) is world (x+0.5, 0, y+0.5). Each carries a `%Ground` StaticBody3D (physics layer 1, "Terrain") holding the AUTHORED floor + perimeter collision — nothing is baked at runtime, the .tscn is the law. Markers are Marker3D, triggers Area3D, node access via %UniqueName. Greybox meshes are placeholder: swap them per scene without touching the functional nodes.
- Characters and actors are Mana Seed billboard sprites: Sprite3D with Y-billboard, nearest filtering, `pixel_size = 0.05`, feet at y=0, camera-relative facing driven from `scripts/data/ManaSeedSheet.cs` (8×8 grid of 64×64 cells; rows 0-3 stand S/N/E/W, rows 4-7 the 6-frame walk). PlayerController, VillagerNpc, UnitVisual3D and CutsceneActor all share that pattern. Y-billboards foreshorten the further a subject sits off the camera axis — frame shots with the subject near it.
- Buildings: one scene per building under scenes/buildings/, following the `%Stages` / `%Scaffold` / `%Overlays` / `%Footprint` contract in `BuildingInstance` (a hidden Node3D's colliders still collide — per-stage collision must be `.Disabled`-toggled). Pre-placed instances are adopted by SceneFilePath, never by node name.
- Combat battle maps are procedurally generated, not authored: Pf2e.Core's `PF2e.MapGen` produces the layout, `scripts/combat/map/TerrainMeshBuilder.cs` builds the mesh, palettes live in `scripts/data/MapThemes.cs`. Gotcha: a `Transform3D(...)` literal in a .tscn lists the basis ROW-major, while the C#/GDScript constructor takes column vectors — hand-writing one from columns silently transposes it.
- Cutscenes: `CutsceneDirector` runs a 10-command grammar (fade, wait, enter, exit, move, face, camera, sfx, prop, emote) over Node3D actors and a Camera3D; `CutsceneHostScene` is the reusable host (dialogue box + fade overlay on CanvasLayers). Dialogue JSON in data/dialogues/ is engine-agnostic. Legacy px speeds convert at `CutsceneDirector.PixelsPerMetre` (÷48) to m/s.
- Day/night: `Bulwark.Fx.DayNightGradient.EvaluateTint(minuteOfDay)` is the surviving colour ramp; it has no consumer yet and awaits a 3D one (DirectionalLight3D colour / WorldEnvironment ambient).
- snake_case for scenes/resources, PascalCase for C# files.
