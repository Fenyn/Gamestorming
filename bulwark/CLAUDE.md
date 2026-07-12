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
    World (Node2D scenes) ↗

- Game logic lives in plain C# classes, not Nodes. Nodes are thin adapters: read input, render state, forward calls.
- Autoload discipline: exactly three — DataManager (pack/content loading), GameState (single authoritative mutable state root), SceneRouter (mode transitions). Nothing else global.
- Command/query separation on GameState: mutations only via intent-named commands (PlantCrop, SpendResources, RepairBuilding) that validate and emit change events. UI never mutates state directly (future co-op seam).
- Signals up, calls down. No GetParent() casts, no GetNode("../..").
- One scene = one responsibility, composed by instancing. Scenes run standalone (F6) with null-safe fallbacks.
- Node access via %UniqueName; exported fields for tunables.
- UI is passive: renders from state-change events, raises intent events. No game rules in Control scripts.
- Data-driven content: crops, buildings, quests, variant combos, encounter tables are declarative definitions in scripts/data/ — adding content touches data only.
- C#: .NET naming, nullable enabled, one class per file, folders mirror namespaces (Bulwark.Combat, Bulwark.Cozy, Bulwark.Outpost, Bulwark.Data, Bulwark.UI, Bulwark.Autoload).
- Engine types never leak into UI code; UI consumes view-model shaped data from system classes.

## Scene/asset conventions

- The user hand-paints all tilemaps and scene visuals in the Godot editor. Claude delivers TileSet .tres resources, blockout scenes with functional nodes (markers, triggers, TileMapLayers), and systems code only.
- Objects placed in .tscn via editor; dynamic children via PackedScene.instantiate().
- Unique collision shapes per differently-sized node (no shared sub_resources).
- No UTF-8 BOM in any Godot text file (.tscn/.tres/.csproj/project.godot).
- Winlu 48×48 tile packs: MZ-autotile editions live at `F:\UnityNVME\Art\Sprites\Winlu`; Godot-native "Other Engines" editions live at `F:\UnityNVME\Art\Sprites\WinluGodot` and are PREFERRED when available (pre-expanded terrain sheets, wired via TileSetBuilder's PreExpanded catalog — no MZ autotile expansion needed). Use the MZ library only for packs without a Godot edition. Imported sheets go under assets/tilesets/<pack>/ with TileSet .tres resources separate from scenes. Texture filter nearest.
- HD-2D ambiance: scenes/fx/hd2d_stack.tscn (WorldEnvironment canvas glow + CanvasModulate time-of-day tint via Hd2dStack.Apply + full-screen tilt-shift/vignette/grade pass, assets/shaders/hd2d_post.gdshader) — instanced in outpost and forest; hdr_2d is on project-wide. Atmosphere scenes in scenes/fx/ (fireflies, dust_motes, falling_leaves, embers, cloud_shadows, light_shaft). PointLight2D textures must be plain PNGs (AtlasTexture is rejected) — Winlu glow blobs baked to assets/fx/glow_warm.png / glow_cool.png. The hdr_2d screen buffer is linear: grade in gamma space in post shaders.
- Animated Winlu entity props (door, gate, chest, lever, lamp, fireplace) are placeable scenes in scenes/props/ — scripts in scripts/props/ (Bulwark.Props), SpriteFrames styles in assets/props/. Swap a style by assigning a different assets/props/*.tres to the scene's %Sprite. Winlu sheet anatomy (origin filenames): `!` object sheets = 4×2 blocks of [3 identical columns × 4 rows], cell 48×96, rows top→bottom are the animation stages (door closed→open); `!$` sheets = one character, cell = width/3 × height/4, columns are loop frames (fire/flame) — except big gates, which play all 12 cells in reading order.
- snake_case for scenes/resources, PascalCase for C# files.
