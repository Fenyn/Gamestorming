using System;
using System.Collections.Generic;
using System.Linq;
using Godot;

namespace Bulwark.Dev;

/// <summary>
/// Headless tool that assembles TileSet <c>.tres</c> resources from the vendored Winlu sheets plus the
/// generated autotile atlases (<see cref="AutotileExpander"/>), using the Godot TileSet API and
/// ResourceSaver. Run via <c>scenes/dev/tileset_builder.tscn</c>.
///
/// <b>Generalized (wave 2):</b> each destination <c>.tres</c> is a declarative <see cref="Output"/>:
/// its custom-data layers, terrain sets, plain 1:1 sources (collision / farmable / pair rules) and
/// generated terrain atlases (source id + terrain-set assignment + wall collision + ruin/season pair).
/// The build engine is output-agnostic; adding a wave-2 tileset = append an <see cref="Output"/> (and
/// its pack in <see cref="AutotileExpander.Packs"/>). Two outputs ship today:
///  - <c>outpost_tileset.tres</c> — base exterior + destroyed + colorways + <b>winter</b> (additive).
///  - <c>interior_tileset.tres</c> — the Winlu Fantasy Interior pack (independent, source ids from 10).
///
/// Compatibility: regenerating the outpost is <b>strictly additive</b>. Pre-existing sources (10-126)
/// and terrain sets 0-4 keep exact ids / textures / tile layouts / terrain order. Each build snapshots
/// the old <c>.tres</c> and asserts every pre-existing source's texture + tile count is unchanged
/// (<c>COMPAT ... PASS</c>). New winter content uses source ids 130+ and terrain sets 5-6.
///
/// pair conventions: a tile's <c>ruin_pair</c> / <c>season_pair</c> int holds the SOURCE ID of its
/// counterpart (restored↔ruined, summer↔winter) at the SAME atlas coordinates. 0 = no pair.
/// </summary>
public partial class TileSetBuilder : Node
{
    private const int Cell = 48;

    // A1 liquid terrains carry a 3-frame TileSetAtlasSource animation (frames 12 tiles apart). Set
    // false to fall back to static frame-0 liquid tiles if animation + terrain painting ever conflict.
    private const bool EnableLiquidAnim = true;

    private enum Collide { None, OpaqueRightHalf, OpaqueAll }
    private enum WallColl { None, BottomHalf, All }

    // --- declarative model ------------------------------------------------------------------------

    private sealed class PlainSrc
    {
        public required int Id;
        public required string Res;          // res:// png
        public Collide Collision = Collide.None;
        public bool FarmableByColor = false; // detect soil cells (A5)
        public int RuinPair = 0;             // paired source id (0 = none)
        public int SeasonPair = 0;           // summer/winter counterpart source id (0 = none)
    }

    private sealed class GenAtlas
    {
        public required string AtlasKey;      // AutotileExpander atlas key
        public required int SourceId;
        public string TerrainSetKey = "";     // "" = plain (tiles + pairs only, no terrain)
        public WallColl Wall = WallColl.None; // wall-material collision policy
        public int RuinPair = 0;
        public int SeasonPair = 0;
    }

    // --- PRE-EXPANDED sources (Winlu Godot-native sheets, no MZ assembly) --------------------------
    // A vendored sheet already laid out in Godot terrain blocks. The builder registers it verbatim as
    // a TileSetAtlasSource and wires peering straight from AutotileExpander's pre-expanded tables. Each
    // source carries one or more terrain-block groups (a rectangular family of same-kind blocks) plus
    // optional plain-tile regions (misc / animation-band art with no terrain).

    private enum PreKind { Floor, WallSide, WallTop }

    /// <summary>3-frame tile animation for A1 liquids (frames sit <see cref="ColStride"/> tiles apart).</summary>
    private sealed class PreAnim { public required int Frames; public required int ColStride; public required float FrameDuration; }

    /// <summary>A rectangular family of pre-expanded terrain blocks, all the same kind / terrain set.
    /// Blocks are enumerated in <see cref="BlockOrigins"/> order — that order drives terrain-id
    /// allocation within the set (so grass/dirt stay at index 0/1).</summary>
    private sealed class PreGroup
    {
        public required PreKind Kind;
        public required string SetKey;
        public required string NamePrefix;
        public required List<Vector2I> BlockOrigins;   // top-left tile of each block's used region
        public Func<int, bool>? Collides = null;       // per-block-index -> full-square collision
        public bool FarmableSoil = false;              // farmable on blocks whose fill tile reads as soil
        public bool SkipEmpty = false;                 // skip a block whose fill tile is fully transparent
        public int RuinPair = 0;                       // ruin_pair custom-data on every created tile
        public PreAnim? Anim = null;                   // floor liquid animation (null = static)
    }

    /// <summary>A tile-space rectangle promoted to plain tiles (create on non-empty cells, no terrain).</summary>
    private sealed class PrePlain { public required int X; public required int Y; public required int W; public required int H; }

    private sealed class PreExpSrc
    {
        public required int Id;
        public required string Res;
        public required List<PreGroup> Groups;
        public List<PrePlain> Plain = new();
    }

    private sealed class TerrainSetDef
    {
        public required string Key;
        public required int Index;
        public required TileSet.TerrainMode Mode;
        public required string Name;          // documentation only (matches README)
    }

    private sealed class CustomLayer { public required string Name; public required Variant.Type Type; }

    private sealed class Output
    {
        public required string OutPath;
        public required List<CustomLayer> Layers;
        public required List<TerrainSetDef> Sets;   // ordered by Index
        public required List<PlainSrc> Plain;       // ordered
        public required List<GenAtlas> Gen;         // ordered — drives terrain creation order
        public List<PreExpSrc> PreExp = new();      // ordered — drives terrain creation order per set
        public bool Rebaseline = false;             // COMPAT: allow sources removed/added this run
    }

    private const string E = "res://assets/tilesets/winlu_exterior/";
    private const string EG = "res://assets/tilesets/winlu_exterior/green/";
    private const string ER = "res://assets/tilesets/winlu_exterior/red/";
    private const string D = "res://assets/tilesets/winlu_destroyed/";
    private const string W = "res://assets/tilesets/winlu_winter/";
    private const string I = "res://assets/tilesets/winlu_interior/";
    private const string ID = "res://assets/tilesets/winlu_interior_destroyed/";
    private const string SW = "res://assets/tilesets/winlu_swamp/";
    private const string DUN = "res://assets/tilesets/winlu_dungeon/";
    private const string MUSH = "res://assets/tilesets/winlu_mushroom/";
    private const string DES = "res://assets/tilesets/winlu_desert/";
    private const string OW = "res://assets/tilesets/winlu_overworld/";
    private const string ORC = "res://assets/tilesets/winlu_orc/";
    private const string G = AutotileExpander.GenDir;

    // ==============================================================================================
    // OUTPOST output (base exterior + destroyed + colorways + winter). Strictly additive.
    // ==============================================================================================
    private static Output BuildOutpost() => new()
    {
        OutPath = "res://assets/tilesets/outpost_tileset.tres",
        // The outpost switched its ground/water/building/wall terrains from MZ-expanded atlases to
        // Winlu's pre-expanded Godot-native sheets this run: sources 16/17/18/40/41/42/50/51/90/91/
        // 99/100/101/120/121/122/123/125/172/173 are retired and 200-216 added. COMPAT is rebaselined
        // for this output (surviving pre-existing sources are still checked strictly).
        Rebaseline = true,
        Layers = new()
        {
            new() { Name = "farmable", Type = Variant.Type.Bool },
            new() { Name = "ruin_pair", Type = Variant.Type.Int },
            new() { Name = "season_pair", Type = Variant.Type.Int },
        },
        Sets = new()
        {
            new() { Key = "ground",        Index = 0, Mode = TileSet.TerrainMode.CornersAndSides, Name = "Ground" },
            new() { Key = "green",         Index = 1, Mode = TileSet.TerrainMode.CornersAndSides, Name = "Ground (green)" },
            new() { Key = "red",           Index = 2, Mode = TileSet.TerrainMode.CornersAndSides, Name = "Ground (red)" },
            new() { Key = "walls",         Index = 3, Mode = TileSet.TerrainMode.Sides,           Name = "Buildings (A3)" },
            new() { Key = "walls_red",     Index = 4, Mode = TileSet.TerrainMode.Sides,           Name = "Buildings (A3 red)" },
            new() { Key = "winter_ground", Index = 5, Mode = TileSet.TerrainMode.CornersAndSides, Name = "Ground (winter)" },
            new() { Key = "winter_walls",  Index = 6, Mode = TileSet.TerrainMode.Sides,           Name = "Buildings (winter)" },
            new() { Key = "a4_walls",      Index = 7, Mode = TileSet.TerrainMode.Sides,           Name = "Walls (A4)" },
            new() { Key = "a4_walltops",   Index = 8, Mode = TileSet.TerrainMode.CornersAndSides, Name = "Wall tops (A4)" },
            new() { Key = "walls_destroyed",     Index = 9,  Mode = TileSet.TerrainMode.Sides, Name = "Buildings destroyed (A3)" },
            new() { Key = "walls_red_destroyed", Index = 10, Mode = TileSet.TerrainMode.Sides, Name = "Buildings destroyed (A3 red)" },
        },
        Plain = OutpostPlain(),
        Gen = new()
        {
            // Red A3 building walls (set 4) + its destroyed ruin counterpart (plain). Base A3 (set 3)
            // is now the pre-expanded source 204; base ground/water (set 0) and colorways (sets 1,2)
            // are pre-expanded sources 200-203 / 210-216 (see PreExp below).
            new() { AtlasKey = "wall_a3_red",         SourceId = 124, TerrainSetKey = "walls_red", Wall = WallColl.BottomHalf, RuinPair = 126 },
            new() { AtlasKey = "wall_a3_red_destroyed", SourceId = 126, TerrainSetKey = "walls_red_destroyed", Wall = WallColl.BottomHalf, RuinPair = 124 },
            // Winter terrains (sets 5,6) — unchanged, still MZ-expanded from the winter pack.
            new() { AtlasKey = "ground_a2_snow", SourceId = 170, TerrainSetKey = "winter_ground" },
            new() { AtlasKey = "wall_a3_snow",   SourceId = 171, TerrainSetKey = "winter_walls", Wall = WallColl.BottomHalf },
        },
        PreExp = OutpostPreExp(),
    };

    // ==============================================================================================
    // PRE-EXPANDED outpost sources (200-216). Winlu's Godot-native sheets, wired straight to terrains.
    // List order drives terrain-id allocation per set: within each set the A2 ground group is listed
    // first so Grass stays terrain 0 and Dirt terrain 1 (blockout builders paint set 0 with those).
    // ==============================================================================================
    private static List<PreExpSrc> OutpostPreExp()
    {
        // Block-origin helpers (origins in TILES, top-left of each block's used region).
        List<Vector2I> FloorGrid(int cols, int rows, int pitchX, int pitchY) =>
            Enumerable.Range(0, rows).SelectMany(r => Enumerable.Range(0, cols)
                .Select(c => new Vector2I(c * pitchX, r * pitchY))).ToList();

        // a2_terrain: 4x8 floor blocks, pitch 13x5. Raster order (brow*4+bcol) -> grass=0, dirt=1.
        var a2 = new PreExpSrc
        {
            Id = 200, Res = E + "a2_terrain.png",
            Groups = new() { new PreGroup {
                Kind = PreKind.Floor, SetKey = "ground", NamePrefix = "grd",
                BlockOrigins = FloorGrid(4, 8, 13, 5), FarmableSoil = true } },
        };
        // a2_forest_terrain: 3x3 floor blocks, pitch 13x5. Distinct forest-floor colorways (verified
        // NOT pixel-identical to base blocks — kept). Empty blocks skipped defensively.
        var a2f = new PreExpSrc
        {
            Id = 201, Res = E + "a2_forest_terrain.png",
            Groups = new() { new PreGroup {
                Kind = PreKind.Floor, SetKey = "ground", NamePrefix = "forest",
                BlockOrigins = FloorGrid(3, 3, 13, 5), SkipEmpty = true } },
        };
        // a2_shadow: one 12x4 semi-transparent drop-shadow overlay block.
        var a2s = new PreExpSrc
        {
            Id = 202, Res = E + "a2_shadow.png",
            Groups = new() { new PreGroup {
                Kind = PreKind.Floor, SetKey = "ground", NamePrefix = "shadow",
                BlockOrigins = new() { new Vector2I(0, 0) } } },
        };
        // a1_liquids: 8 animated liquid terrains (frame-0 blocks); misc + waterfall bands as plain
        // tiles. Liquid block-rows at tile-rows 0,10,15,20,25,30,35,40 (5-tile pitch, 3 anim frames).
        int[] liquidRows = { 0, 10, 15, 20, 25, 30, 35, 40 };
        var a1 = new PreExpSrc
        {
            Id = 203, Res = E + "a1_liquids.png",
            Groups = new() { new PreGroup {
                Kind = PreKind.Floor, SetKey = "ground", NamePrefix = "liquid",
                BlockOrigins = liquidRows.Select(r => new Vector2I(0, r)).ToList(),
                Anim = EnableLiquidAnim ? new PreAnim { Frames = 3, ColStride = 12, FrameDuration = 0.35f } : null } },
            Plain = new()
            {
                new PrePlain { X = 0, Y = 5, W = 24, H = 4 },    // dock-floor + lily-pad misc band
                new PrePlain { X = 0, Y = 45, W = 36, H = 3 },   // waterfall band (4 groups x 9 wide, 3 frames)
            },
        };
        // a3_walls: 4x8 wall materials, pitch 4x4 (3x3 used). material = 4*brow+bcol. Materials 0-15
        // (top 4 block-rows) are ROOFS (no collision); 16-31 (bottom 4) are WALLS (full collision).
        var a3origins = Enumerable.Range(0, 8).SelectMany(br => Enumerable.Range(0, 4)
            .Select(bc => new Vector2I(bc * 4, br * 4))).ToList();
        var a3 = new PreExpSrc
        {
            Id = 204, Res = E + "a3_walls.png",
            Groups = new() { new PreGroup {
                Kind = PreKind.WallSide, SetKey = "walls", NamePrefix = "a3",
                BlockOrigins = a3origins, Collides = mi => mi >= 16, RuinPair = 34 } },
        };
        // Destroyed base A3 (768x1536): Winlu's Godot-native destroyed sheet, cell-for-cell with the
        // pristine a3_walls (204) — verified 288/288 opaque cells. Identical PreExp spec (same block
        // origins, same PreWallSideNeighbors peering, same roof/wall collision split) so the ruin_pair
        // swap 204<->34 lands the same peering config at each atlas coordinate. -> set 9.
        var a3d = new PreExpSrc
        {
            Id = 34, Res = D + "fantasy_outside_a3_destroyed.png",
            Groups = new() { new PreGroup {
                Kind = PreKind.WallSide, SetKey = "walls_destroyed", NamePrefix = "a3d",
                BlockOrigins = a3origins, Collides = mi => mi >= 16, RuinPair = 204 } },
        };
        // a4_walls: 24 materials, 8 block-rows x 3 materials. Each material = a wall-TOP 3x3 block at
        // tile_x = matcol*8 then a wall-FACE 3x3 block at tile_x = matcol*8+4 (tile_y = brow*4). Faces
        // -> set 7 (match-sides), tops -> set 8 (corners+sides). Full collision on all. Some lower-row
        // materials are irregular special art (framed openings / banners) — wired anyway.
        var a4faces = new List<Vector2I>();
        var a4tops = new List<Vector2I>();
        for (int br = 0; br < 8; br++)
            for (int mc = 0; mc < 3; mc++)
            {
                a4tops.Add(new Vector2I(mc * 8, br * 4));
                a4faces.Add(new Vector2I(mc * 8 + 4, br * 4));
            }
        var a4 = new PreExpSrc
        {
            Id = 205, Res = E + "a4_walls.png",
            Groups = new()
            {
                new PreGroup { Kind = PreKind.WallSide, SetKey = "a4_walls",    NamePrefix = "a4face", BlockOrigins = a4faces, Collides = _ => true },
                new PreGroup { Kind = PreKind.WallTop,  SetKey = "a4_walltops", NamePrefix = "a4top",  BlockOrigins = a4tops,  Collides = _ => true },
            },
        };

        // Green colorway: a2_terrain_green (4x3 grid, 3 empty blocks skipped) -> set 1; a1_liquids_green
        // (3 liquid rows) -> set 1. A2 first so green Grass stays terrain 0.
        var a2g = new PreExpSrc
        {
            Id = 211, Res = EG + "a2_terrain_green.png",
            Groups = new() { new PreGroup {
                Kind = PreKind.Floor, SetKey = "green", NamePrefix = "grn",
                BlockOrigins = FloorGrid(4, 3, 13, 5), FarmableSoil = true, SkipEmpty = true } },
        };
        var a1g = new PreExpSrc
        {
            Id = 210, Res = EG + "a1_liquids_green.png",
            Groups = new() { new PreGroup {
                Kind = PreKind.Floor, SetKey = "green", NamePrefix = "grnliquid",
                BlockOrigins = new[] { 0, 5, 10 }.Select(r => new Vector2I(0, r)).ToList(), SkipEmpty = true,
                Anim = EnableLiquidAnim ? new PreAnim { Frames = 3, ColStride = 12, FrameDuration = 0.35f } : null } },
        };
        // Red colorway (same geometry as green) -> set 2.
        var a2r = new PreExpSrc
        {
            Id = 216, Res = ER + "a2_terrain_red.png",
            Groups = new() { new PreGroup {
                Kind = PreKind.Floor, SetKey = "red", NamePrefix = "red",
                BlockOrigins = FloorGrid(4, 3, 13, 5), FarmableSoil = true, SkipEmpty = true } },
        };
        var a1r = new PreExpSrc
        {
            Id = 215, Res = ER + "a1_liquids_red.png",
            Groups = new() { new PreGroup {
                Kind = PreKind.Floor, SetKey = "red", NamePrefix = "redliquid",
                BlockOrigins = new[] { 0, 5, 10 }.Select(r => new Vector2I(0, r)).ToList(), SkipEmpty = true,
                Anim = EnableLiquidAnim ? new PreAnim { Frames = 3, ColStride = 12, FrameDuration = 0.35f } : null } },
        };

        // Order matters: within each terrain set the A2 ground group must be allocated before the A1
        // liquid group so Grass=0 / Dirt=1 hold for base (set 0) and colorways (sets 1,2).
        return new() { a2, a2f, a2s, a1, a2g, a1g, a2r, a1r, a3, a3d, a4 };
    }

    private static List<PlainSrc> OutpostPlain() => new()
    {
        // --- exterior ground / architecture / objects (season_pair -> winter counterpart) ---
        new() { Id = 10, Res = E + "fantasy_outside_a5.png", FarmableByColor = true, SeasonPair = 130 },
        new() { Id = 11, Res = E + "fantasy_outside_b.png", Collision = Collide.OpaqueRightHalf, RuinPair = 31, SeasonPair = 131 },
        new() { Id = 12, Res = E + "fantasy_outside_c.png", RuinPair = 32, SeasonPair = 132 },
        new() { Id = 13, Res = E + "fantasy_outside_d_noshadow.png", SeasonPair = 134 },
        new() { Id = 14, Res = E + "fantasy_roofs.png", RuinPair = 33, SeasonPair = 135 },
        new() { Id = 15, Res = E + "fantasy_roofs_2.png" },
        // (16/17/18 retired: fantasy_outside_a2 / a2_2 / a1 MZ sheets replaced by pre-expanded
        //  a2_terrain / a2_forest_terrain / a1_liquids — sources 200/201/203.)
        // --- exterior props ---
        new() { Id = 20, Res = E + "signs.png", RuinPair = 35, SeasonPair = 140 },
        new() { Id = 21, Res = E + "gate_wood1.png", Collision = Collide.OpaqueAll, RuinPair = 36, SeasonPair = 147 },
        new() { Id = 22, Res = E + "big_trees.png", SeasonPair = 142 },            // canopy left collision-free (see README)
        new() { Id = 23, Res = E + "decoration.png" },
        new() { Id = 24, Res = E + "decoration_vegetation.png" },
        new() { Id = 25, Res = E + "statue.png", Collision = Collide.OpaqueAll, SeasonPair = 159 },
        // --- destroyed counterparts ---
        new() { Id = 31, Res = D + "fantasy_outside_b_destroyed.png", Collision = Collide.OpaqueRightHalf, RuinPair = 11 },
        new() { Id = 32, Res = D + "fantasy_outside_c_destroyed.png", RuinPair = 12 },
        new() { Id = 33, Res = D + "fantasy_roofs_destroyed.png", RuinPair = 14 },
        // Source 34 (fantasy_outside_a3_destroyed) is now a PRE-EXPANDED terrain (set 9), paired
        // cell-for-cell to the pristine a3_walls (source 204) — see OutpostPreExp().
        new() { Id = 35, Res = D + "signs_destroyed.png", RuinPair = 20 },
        new() { Id = 36, Res = D + "gate_wood1_destroyed.png", Collision = Collide.OpaqueAll, RuinPair = 21 },
        new() { Id = 37, Res = D + "big_decoration_destroyed.png" },
        // --- NEW plain sources: 52-83 base exterior sheets/props ---
        // (50/51 retired: raw fantasy_outside_a3 / a4 MZ sheets replaced by pre-expanded a3_walls /
        //  a4_walls — terrain sources 204/205. The a3/a4 snow winter sheets keep their season_pair 0.)
        new() { Id = 52, Res = E + "fantasy_outside_d.png", SeasonPair = 133 },
        new() { Id = 53, Res = E + "big_decoration.png", SeasonPair = 141 },
        new() { Id = 54, Res = E + "big_drawbridge.png", Collision = Collide.OpaqueAll, SeasonPair = 145 },
        new() { Id = 55, Res = E + "big_drawbridge_animated.png", Collision = Collide.OpaqueAll, SeasonPair = 146 },
        new() { Id = 56, Res = E + "bigger_drawbridge_animated.png", Collision = Collide.OpaqueAll },
        new() { Id = 57, Res = E + "big_misc.png" },
        new() { Id = 58, Res = E + "big_trees_3.png", SeasonPair = 144 },
        new() { Id = 59, Res = E + "big_trees_noshadow.png", SeasonPair = 143 },
        new() { Id = 60, Res = E + "cliff_decoration.png", SeasonPair = 151 },
        new() { Id = 61, Res = E + "cliff_decoration_blue.png" },
        new() { Id = 62, Res = E + "cliff_decoration_red.png" },
        new() { Id = 63, Res = E + "door_fence.png" },
        new() { Id = 64, Res = E + "gate_cathedral1.png", Collision = Collide.OpaqueAll },
        new() { Id = 65, Res = E + "gate_stone1.png", Collision = Collide.OpaqueAll, SeasonPair = 148 },
        new() { Id = 66, Res = E + "giant_tree_no_glowing.png", SeasonPair = 150 },  // canopy free; trunk collision in-editor
        new() { Id = 67, Res = E + "glowing_tree.png" },
        new() { Id = 68, Res = E + "roof_center.png" },
        new() { Id = 69, Res = E + "smith.png", Collision = Collide.OpaqueAll, SeasonPair = 149 },
        new() { Id = 70, Res = E + "waterwheel.png", Collision = Collide.OpaqueAll },
        new() { Id = 71, Res = E + "waterwheel_vertical.png", Collision = Collide.OpaqueAll },
        new() { Id = 72, Res = E + "diagonal_walls_top.png", SeasonPair = 160 },
        new() { Id = 73, Res = E + "diagonal_water.png" },
        new() { Id = 74, Res = E + "fantasy_chest.png", SeasonPair = 152 },
        new() { Id = 75, Res = E + "fantasy_chimney.png", SeasonPair = 153 },
        new() { Id = 76, Res = E + "fantasy_door1.png", SeasonPair = 154 },
        new() { Id = 77, Res = E + "fantasy_door2.png", SeasonPair = 155 },
        new() { Id = 78, Res = E + "fantasy_door_fence.png" },
        new() { Id = 79, Res = E + "fantasy_switches.png" },
        new() { Id = 80, Res = E + "flags_banner.png", SeasonPair = 156 },
        new() { Id = 81, Res = E + "lamp.png", SeasonPair = 157 },
        new() { Id = 82, Res = E + "roof_windows.png", SeasonPair = 158 },
        new() { Id = 83, Res = E + "waterfall_animation.png" }, // static; animation frames exist in sheet
        // --- green colorway (plain) ---
        // (90/91 retired: fantasy_outside_a1_green / a2_green replaced by pre-expanded
        //  a1_liquids_green / a2_terrain_green — terrain sources 210/211.)
        new() { Id = 92, Res = EG + "fantasy_outside_a4_green.png" },
        new() { Id = 93, Res = EG + "fantasy_outside_a5_green.png", FarmableByColor = true },
        new() { Id = 94, Res = EG + "fantasy_outside_b_green.png", Collision = Collide.OpaqueRightHalf, RuinPair = 116 },
        new() { Id = 95, Res = EG + "fantasy_outside_d_green.png" },
        new() { Id = 96, Res = EG + "fantasy_outside_d_green_noshadow.png" },
        new() { Id = 97, Res = EG + "big_trees_green.png" },
        new() { Id = 98, Res = EG + "big_trees_green_noshadow.png" },
        // --- red colorway (plain) ---
        // (99/100/101 retired: fantasy_outside_a1_red / a2_red / a2_2_red replaced by pre-expanded
        //  a1_liquids_red / a2_terrain_red — terrain sources 215/216.)
        new() { Id = 102, Res = ER + "fantasy_outside_a3_red.png" },
        new() { Id = 103, Res = ER + "fantasy_outside_a4_red.png" },
        new() { Id = 104, Res = ER + "fantasy_outside_a5_red.png", FarmableByColor = true },
        new() { Id = 105, Res = ER + "fantasy_outside_b_red.png", Collision = Collide.OpaqueRightHalf, RuinPair = 117 },
        new() { Id = 106, Res = ER + "fantasy_outside_d_red.png" },
        new() { Id = 107, Res = ER + "fantasy_outside_d_red_noshadow.png" },
        new() { Id = 108, Res = ER + "big_trees_red.png" },
        new() { Id = 109, Res = ER + "big_trees_red_noshadow.png" },
        // --- destroyed extras (plain) ---
        new() { Id = 110, Res = D + "roof_destroyed_texture.png" },
        new() { Id = 111, Res = D + "fantasy_outside_a3_destroyed_raw.png" },
        new() { Id = 112, Res = D + "fantasy_outside_a3_destroyed_v2.png" },
        new() { Id = 113, Res = D + "fantasy_outside_a3_destroyed_v2_red.png" },
        new() { Id = 114, Res = D + "fantasy_outside_a3_red_destroyed.png" },     // Godot pre-expanded red (768x1536)
        new() { Id = 115, Res = D + "fantasy_outside_a3_red_destroyed_raw.png" },
        new() { Id = 116, Res = D + "fantasy_outside_b_green_destroyed.png", Collision = Collide.OpaqueRightHalf, RuinPair = 94 },
        new() { Id = 117, Res = D + "fantasy_outside_b_red_destroyed.png", Collision = Collide.OpaqueRightHalf, RuinPair = 105 },

        // ==========================================================================================
        // NEW winter plain sources (130+). season_pair -> summer counterpart (bidirectional).
        // ==========================================================================================
        new() { Id = 130, Res = W + "fantasy_outside_a5_snow.png", FarmableByColor = true, SeasonPair = 10 },
        new() { Id = 131, Res = W + "fantasy_outside_b_snow.png", Collision = Collide.OpaqueRightHalf, SeasonPair = 11 },
        new() { Id = 132, Res = W + "fantasy_outside_c_snow.png", SeasonPair = 12 },
        new() { Id = 133, Res = W + "fantasy_outside_d_snow.png", SeasonPair = 52 },
        new() { Id = 134, Res = W + "fantasy_outside_d_snow_noshadow.png", SeasonPair = 13 },
        new() { Id = 135, Res = W + "fantasy_roofs_snow.png", SeasonPair = 14 },
        // 136-139 lose their season_pair: their summer counterparts (18/16/50/51, the raw A1/A2/A3/A4
        // MZ sheets) were retired with the pre-expanded switch. Winter still ships the MZ snow sheets.
        new() { Id = 136, Res = W + "fantasy_outside_a1_snow.png" },
        new() { Id = 137, Res = W + "fantasy_outside_a2_snow.png" },  // right-half decorative objects
        new() { Id = 138, Res = W + "fantasy_outside_a3_snow.png" },  // raw A3 (also terrained -> src 171)
        new() { Id = 139, Res = W + "fantasy_outside_a4_snow.png" },
        new() { Id = 140, Res = W + "signs_snow.png", SeasonPair = 20 },
        new() { Id = 141, Res = W + "big_decoration_snow.png", SeasonPair = 53 },
        new() { Id = 142, Res = W + "big_trees_snow.png", SeasonPair = 22 },
        new() { Id = 143, Res = W + "big_trees_snow_noshadow.png", SeasonPair = 59 },
        new() { Id = 144, Res = W + "big_trees_3_snow.png", SeasonPair = 58 },
        new() { Id = 145, Res = W + "big_drawbridge_snow.png", Collision = Collide.OpaqueAll, SeasonPair = 54 },
        new() { Id = 146, Res = W + "big_drawbridge_animated_snow.png", Collision = Collide.OpaqueAll, SeasonPair = 55 },
        new() { Id = 147, Res = W + "gate_wood1_snow.png", Collision = Collide.OpaqueAll, SeasonPair = 21 },
        new() { Id = 148, Res = W + "gate_stone1_snow.png", Collision = Collide.OpaqueAll, SeasonPair = 65 },
        new() { Id = 149, Res = W + "smith_snow.png", Collision = Collide.OpaqueAll, SeasonPair = 69 },
        new() { Id = 150, Res = W + "giant_tree_snow.png", SeasonPair = 66 },        // canopy free; trunk in-editor
        new() { Id = 151, Res = W + "cliff_decoration_snow.png", SeasonPair = 60 },
        new() { Id = 152, Res = W + "fantasy_chest_snow.png", SeasonPair = 74 },
        new() { Id = 153, Res = W + "fantasy_chimney_snow.png", SeasonPair = 75 },
        new() { Id = 154, Res = W + "fantasy_door1_snow.png", SeasonPair = 76 },
        new() { Id = 155, Res = W + "fantasy_door2_snow.png", SeasonPair = 77 },
        new() { Id = 156, Res = W + "flags_banner_snow.png", SeasonPair = 80 },
        new() { Id = 157, Res = W + "lamp_snow.png", SeasonPair = 81 },
        new() { Id = 158, Res = W + "roof_windows_snow.png", SeasonPair = 82 },
        new() { Id = 159, Res = W + "statue_snow.png", Collision = Collide.OpaqueAll, SeasonPair = 25 },
        new() { Id = 160, Res = W + "diagonal_walls_top_snow.png", SeasonPair = 72 },
        new() { Id = 161, Res = W + "diagonal_water_snow.png" },                     // unpaired: footprint diverges (ice)
        // winter-pack revisions of shared props (differ pixel-wise from base; no seasonal counterpart)
        new() { Id = 162, Res = W + "waterwheel_winter.png", Collision = Collide.OpaqueAll },
        new() { Id = 163, Res = W + "decoration_winter.png" },
        new() { Id = 164, Res = W + "fantasy_switches_winter.png" },
    };

    // ==============================================================================================
    // INTERIOR output (independent tileset, source ids from 10).
    // ==============================================================================================
    private static Output BuildInterior() => new()
    {
        OutPath = "res://assets/tilesets/interior_tileset.tres",
        // ruin_pair (int) added this run: the destroyed interior pack ships a cell-for-cell A2 floor
        // counterpart. Adding a custom-data layer + setting values does not change any pre-existing
        // source's tile count / texture, so COMPAT still PASSes strictly (no rebaseline).
        Layers = new()
        {
            new() { Name = "ruin_pair", Type = Variant.Type.Int },
        },
        Sets = new()
        {
            new() { Key = "interior_floors",   Index = 0, Mode = TileSet.TerrainMode.CornersAndSides, Name = "Floors" },
            new() { Key = "interior_walls",    Index = 1, Mode = TileSet.TerrainMode.Sides,           Name = "Walls" },
            new() { Key = "interior_patterns", Index = 2, Mode = TileSet.TerrainMode.CornersAndSides, Name = "Floor patterns (A4)" },
            new() { Key = "interior_floors_destroyed", Index = 3, Mode = TileSet.TerrainMode.CornersAndSides, Name = "Floors destroyed" },
        },
        Plain = new()
        {
            // tilesets
            new() { Id = 10, Res = I + "fantasy_inside_a5.png" },
            new() { Id = 11, Res = I + "fantasy_inside_a2.png", RuinPair = 70 },   // right-half decor / rugs; A2 floor sheet -> ruin_pair 70 (destroyed A2, cell-for-cell)
            new() { Id = 12, Res = I + "fantasy_inside_a3.png" },   // raw walls (terrained -> src 61)
            new() { Id = 13, Res = I + "fantasy_inside_a4.png" },   // floor patterns (parquet/tile bands)
            new() { Id = 14, Res = I + "fantasy_inside_b.png" },
            new() { Id = 15, Res = I + "fantasy_inside_c.png" },
            new() { Id = 16, Res = I + "fantasy_inside_c_white.png" },
            new() { Id = 17, Res = I + "fantasy_inside_d.png" },
            new() { Id = 18, Res = I + "fantasy_inside_e_cathedral.png" },
            new() { Id = 19, Res = I + "fantasy_inside_shops.png" },
            // furniture / props (solid = OpaqueAll; decals / hangings / decoration = None)
            new() { Id = 20, Res = I + "altar.png", Collision = Collide.OpaqueAll },
            new() { Id = 21, Res = I + "big_decoration2.png", Collision = Collide.OpaqueAll },
            new() { Id = 22, Res = I + "big_window.png" },
            new() { Id = 23, Res = I + "chandelier.png" },
            new() { Id = 24, Res = I + "chimney.png", Collision = Collide.OpaqueAll },
            new() { Id = 25, Res = I + "curtain.png" },
            new() { Id = 26, Res = I + "curtain2.png" },
            new() { Id = 27, Res = I + "fireplace.png", Collision = Collide.OpaqueAll },
            new() { Id = 28, Res = I + "fireplace1.png", Collision = Collide.OpaqueAll },
            new() { Id = 29, Res = I + "fireplace2.png", Collision = Collide.OpaqueAll },
            new() { Id = 30, Res = I + "fireplace3.png", Collision = Collide.OpaqueAll },
            new() { Id = 31, Res = I + "fireplace4.png", Collision = Collide.OpaqueAll },
            new() { Id = 32, Res = I + "fireplace_kitchen.png", Collision = Collide.OpaqueAll },
            new() { Id = 33, Res = I + "gate_cathedral2.png", Collision = Collide.OpaqueAll },
            new() { Id = 34, Res = I + "gate_cathedral2_sun.png", Collision = Collide.OpaqueAll },
            new() { Id = 35, Res = I + "lights_glowing.png" },
            new() { Id = 36, Res = I + "smith_inside.png", Collision = Collide.OpaqueAll },
            new() { Id = 37, Res = I + "symbol.png" },
            new() { Id = 38, Res = I + "wall_decoration.png" },
            new() { Id = 39, Res = I + "alchemy_table.png", Collision = Collide.OpaqueAll },
            new() { Id = 40, Res = I + "clock.png" },
            new() { Id = 41, Res = I + "decoration.png" },
            new() { Id = 42, Res = I + "decoration2.png" },
            new() { Id = 43, Res = I + "decoration2_blue.png" },
            new() { Id = 44, Res = I + "decoration2_brown.png" },
            new() { Id = 45, Res = I + "decoration2_red.png" },
            new() { Id = 46, Res = I + "decoration_static.png" },
            new() { Id = 47, Res = I + "fantasy_chest.png", Collision = Collide.OpaqueAll },
            new() { Id = 48, Res = I + "fantasy_door1.png" },
            new() { Id = 49, Res = I + "fantasy_door3.png" },
            new() { Id = 50, Res = I + "fantasy_door4.png" },
            new() { Id = 51, Res = I + "fantasy_door5.png" },
            new() { Id = 52, Res = I + "fantasy_switches.png" },
            new() { Id = 53, Res = I + "fantasy_wandpillar.png", Collision = Collide.OpaqueAll },
            new() { Id = 54, Res = I + "flags_banner_inside.png" },
            new() { Id = 55, Res = I + "railing.png", Collision = Collide.OpaqueAll },
            new() { Id = 56, Res = I + "statue.png", Collision = Collide.OpaqueAll },
            new() { Id = 57, Res = I + "table_decoration.png", Collision = Collide.OpaqueAll },
            // --- destroyed interior pack (plain sources, ids 70-73). Collision mirrors pristine
            //     precedent: mixed architecture/furniture/debris & prop sheets stay free (refine
            //     in-editor). Only the A2 floor sheet is a cell-for-cell ruin counterpart (70<->11). ---
            new() { Id = 70, Res = ID + "fantasy_inside_a2_destroyed.png", RuinPair = 11 },  // ruined A2 floor sheet (also terrained -> src 80)
            new() { Id = 71, Res = ID + "fantasy_inside_destroyed.png" },                    // ruined furniture / debris / broken decor (no single pristine counterpart)
            new() { Id = 72, Res = ID + "chandelier_destroyed.png" },                        // single broken chandelier stamp (not a cell-for-cell pair)
            new() { Id = 73, Res = ID + "decoration_interior_destroyed.png" },               // ruined decoration stamps (not a cell-for-cell pair)
        },
        Gen = new()
        {
            new() { AtlasKey = "floor_inside_a2", SourceId = 60, TerrainSetKey = "interior_floors", RuinPair = 80 },
            new() { AtlasKey = "wall_inside_a3",  SourceId = 61, TerrainSetKey = "interior_walls", Wall = WallColl.All },
            // A4 floor patterns (24 terrains, set 2). No pristine/destroyed pairing (no destroyed A4).
            new() { AtlasKey = "pattern_inside_a4", SourceId = 62, TerrainSetKey = "interior_patterns" },
            // Destroyed A2 floors (16 terrains, set 3). Cell-for-cell with pristine floor src 60.
            new() { AtlasKey = "floor_inside_a2_destroyed", SourceId = 80, TerrainSetKey = "interior_floors_destroyed", RuinPair = 60 },
        },
    };

    // ==============================================================================================
    // SWAMP output (Tier-2 territory biome, independent tileset). No pairs / farmable.
    // ==============================================================================================
    private static Output BuildSwamp() => new()
    {
        OutPath = "res://assets/tilesets/swamp_tileset.tres",
        Layers = new(),   // territories: no farmable / ruin / season data
        Sets = new()
        {
            new() { Key = "swamp_ground", Index = 0, Mode = TileSet.TerrainMode.CornersAndSides, Name = "Ground" },
        },
        Plain = new()
        {
            // --- tilesets ---
            new() { Id = 10, Res = SW + "fantasy_swamp_a5.png" },                                    // floor accents / bank walls
            new() { Id = 11, Res = SW + "fantasy_outside_a2_swamp.png" },                            // A2 right-half decorative objects
            new() { Id = 12, Res = SW + "fantasy_outside_a1_swamp.png" },                            // A1 bog water / lily (plain)
            new() { Id = 13, Res = SW + "fantasy_outside_a1_swamp_blue.png" },                       // A1 colorway
            new() { Id = 14, Res = SW + "fantasy_outside_a1_swamp_green.png" },                      // A1 colorway
            new() { Id = 15, Res = SW + "fantasy_outside_a1_swamp_purple.png" },                     // A1 colorway
            new() { Id = 16, Res = SW + "fantasy_swamp_b.png", Collision = Collide.OpaqueRightHalf },// architecture / ruined towers
            new() { Id = 17, Res = SW + "fantasy_swamp_c.png" },                                     // cliffs / rock walls / docks
            new() { Id = 18, Res = SW + "fantasy_swamp_d.png" },                                     // swamp trees / vegetation
            new() { Id = 19, Res = SW + "fantasy_swamp_e.png" },                                     // swamp houses / roofs
            new() { Id = 20, Res = SW + "fantasy_swamp_interior.png" },                              // swamp interior furnishings
            // --- characters / props ---
            new() { Id = 21, Res = SW + "big_swamp_shrine.png", Collision = Collide.OpaqueAll },
            new() { Id = 22, Res = SW + "big_swamphouse.png", Collision = Collide.OpaqueAll },
            new() { Id = 23, Res = SW + "big_swamp_lamp.png" },
            new() { Id = 24, Res = SW + "big_swamp_decoration.png" },
            new() { Id = 25, Res = SW + "big_swamp_statues.png", Collision = Collide.OpaqueAll },
            new() { Id = 26, Res = SW + "big_swamphouse_roof.png" },
            new() { Id = 27, Res = SW + "swamp_path_sealed.png" },
            new() { Id = 28, Res = SW + "decoration_swamp.png" },
            new() { Id = 29, Res = SW + "fantasy_chest_swamp.png", Collision = Collide.OpaqueAll },
            new() { Id = 30, Res = SW + "fantasy_door_swamphouse.png" },
            new() { Id = 31, Res = SW + "fantasy_swamp_door.png" },
            new() { Id = 32, Res = SW + "diagonal_water_swamp.png" },
        },
        Gen = new()
        {
            new() { AtlasKey = "ground_a2_swamp", SourceId = 100, TerrainSetKey = "swamp_ground" },
            new() { AtlasKey = "water_a1_swamp",  SourceId = 101, TerrainSetKey = "swamp_ground" },
        },
    };

    // ==============================================================================================
    // DUNGEON output (Tier-3 caves, independent tileset). A4 wall-face band -> Walls terrain set.
    // ==============================================================================================
    private static Output BuildDungeon() => new()
    {
        OutPath = "res://assets/tilesets/dungeon_tileset.tres",
        Layers = new(),
        Sets = new()
        {
            new() { Key = "dungeon_ground", Index = 0, Mode = TileSet.TerrainMode.CornersAndSides, Name = "Ground" },
            new() { Key = "dungeon_walls",  Index = 1, Mode = TileSet.TerrainMode.Sides,           Name = "Walls" },
        },
        Plain = new()
        {
            // --- tilesets ---
            new() { Id = 10, Res = DUN + "fantasy_dungeon_a5.png" },                                 // floor accents
            new() { Id = 11, Res = DUN + "fantasy_dungeon_a2.png" },                                 // A2 right-half decorative objects
            new() { Id = 12, Res = DUN + "fantasy_dungeon_a1.png" },                                 // A1 water / lava (plain)
            new() { Id = 13, Res = DUN + "fantasy_dungeon_a1_darker.png" },                          // A1 darker colorway
            new() { Id = 14, Res = DUN + "fantasy_dungeon_a4.png" },                                 // raw A4 walls (face terrained -> src 102)
            new() { Id = 15, Res = DUN + "fantasy_dungeon_b.png", Collision = Collide.OpaqueRightHalf },// cave architecture
            new() { Id = 16, Res = DUN + "fantasy_dungeon_c.png" },                                  // bridges / ladders / pillars
            new() { Id = 17, Res = DUN + "fantasy_dungeon_d.png" },                                  // crystals / ore / decor
            new() { Id = 18, Res = DUN + "fantasy_dungeon_e.png" },                                  // dungeon props / coffins / cages
            // --- characters / props ---
            new() { Id = 20, Res = DUN + "cave_bridge.png" },
            new() { Id = 21, Res = DUN + "crystals.png" },
            new() { Id = 22, Res = DUN + "crystals2.png" },
            new() { Id = 23, Res = DUN + "decoration.png" },
            new() { Id = 24, Res = DUN + "decoration2.png" },
            new() { Id = 25, Res = DUN + "decoration2_blue.png" },
            new() { Id = 26, Res = DUN + "decoration2_brown.png" },
            new() { Id = 27, Res = DUN + "decoration2_red.png" },
            new() { Id = 28, Res = DUN + "decoration_3.png" },
            new() { Id = 29, Res = DUN + "decoration_4.png" },
            new() { Id = 30, Res = DUN + "decoration_5.png" },
            new() { Id = 31, Res = DUN + "decoration_static_2.png" },
            new() { Id = 32, Res = DUN + "diagonal_water_dungeon.png" },
            new() { Id = 33, Res = DUN + "dungeon_chains.png" },
            new() { Id = 34, Res = DUN + "dungeon_gate.png", Collision = Collide.OpaqueAll },
            new() { Id = 35, Res = DUN + "dungeon_portal_1.png" },                                   // animated portal (frames in sheet)
            new() { Id = 36, Res = DUN + "dungeon_secrets.png" },
            new() { Id = 37, Res = DUN + "dungeon_statue.png", Collision = Collide.OpaqueAll },
            new() { Id = 38, Res = DUN + "dungeon_statue1.png", Collision = Collide.OpaqueAll },
            new() { Id = 39, Res = DUN + "fantasy_chest.png", Collision = Collide.OpaqueAll },
            new() { Id = 40, Res = DUN + "fantasy_chest2.png", Collision = Collide.OpaqueAll },
            new() { Id = 41, Res = DUN + "fantasy_door4.png" },
            new() { Id = 42, Res = DUN + "fantasy_door5.png" },
            new() { Id = 43, Res = DUN + "fantasy_door6.png" },
            new() { Id = 44, Res = DUN + "fantasy_dungeon_traps.png" },
            new() { Id = 45, Res = DUN + "fantasy_dungeon_traps2.png" },
            new() { Id = 46, Res = DUN + "fantasy_dungeon_traps3.png" },
            new() { Id = 47, Res = DUN + "fantasy_hanging_cage.png" },
            new() { Id = 48, Res = DUN + "fantasy_switches2.png" },
            new() { Id = 49, Res = DUN + "gate_dungeon1.png", Collision = Collide.OpaqueAll },
            new() { Id = 50, Res = DUN + "gate_dungeon_skull.png", Collision = Collide.OpaqueAll },
            new() { Id = 51, Res = DUN + "lights_glowing.png" },
            new() { Id = 52, Res = DUN + "switch3.png" },
            new() { Id = 53, Res = DUN + "teleporter.png" },                                         // animated (frames in sheet)
            new() { Id = 54, Res = DUN + "wagon.png", Collision = Collide.OpaqueAll },
            new() { Id = 55, Res = DUN + "waterfall_animation.png" },                                // static first frame (animated)
        },
        Gen = new()
        {
            new() { AtlasKey = "ground_a2_dungeon", SourceId = 100, TerrainSetKey = "dungeon_ground" },
            new() { AtlasKey = "water_a1_dungeon",  SourceId = 101, TerrainSetKey = "dungeon_ground" },
            new() { AtlasKey = "wall_a4dun",        SourceId = 102, TerrainSetKey = "dungeon_walls", Wall = WallColl.All },
        },
    };

    // ==============================================================================================
    // MUSHROOM output (Tier-3 caves variant, independent tileset). No wall-format sheet -> no Walls set.
    // ==============================================================================================
    private static Output BuildMushroom() => new()
    {
        OutPath = "res://assets/tilesets/mushroom_tileset.tres",
        Layers = new(),
        Sets = new()
        {
            new() { Key = "mushroom_ground", Index = 0, Mode = TileSet.TerrainMode.CornersAndSides, Name = "Ground" },
        },
        Plain = new()
        {
            // --- tilesets (no A5 in this pack) ---
            new() { Id = 10, Res = MUSH + "fantasy_mushroom_a2.png" },                               // A2 right-half decorative objects
            new() { Id = 11, Res = MUSH + "fantasy_mushroom_a1.png" },                               // A1 water (plain)
            new() { Id = 12, Res = MUSH + "fantasy_mushroom_b.png", Collision = Collide.OpaqueRightHalf },// cave walls / mushroom arches
            new() { Id = 13, Res = MUSH + "fantasy_mushroom_c.png" },                                // mushroom clusters / vegetation
            new() { Id = 14, Res = MUSH + "fantasy_mushroom_d.png" },                                // giant mushroom arches / tunnels
            // --- characters / props ---
            new() { Id = 20, Res = MUSH + "mushroom_glowing.png" },                                  // glowing mushroom cluster (may animate)
            new() { Id = 21, Res = MUSH + "diagonal_water_mushroom.png" },
        },
        Gen = new()
        {
            new() { AtlasKey = "ground_a2_mush", SourceId = 100, TerrainSetKey = "mushroom_ground" },
            new() { AtlasKey = "water_a1_mush",  SourceId = 101, TerrainSetKey = "mushroom_ground" },
        },
    };

    // ==============================================================================================
    // DESERT output (Tier-4 territory). ONE combined resource: exterior (ext_) + interior (int_)
    // sheets, the interior being dungeon-like desert rooms of the same tier. No pairs / farmable.
    // ==============================================================================================
    private static Output BuildDesert() => new()
    {
        OutPath = "res://assets/tilesets/desert_tileset.tres",
        Layers = new(),   // territories: no farmable / ruin / season data
        Sets = new()
        {
            new() { Key = "ext_ground", Index = 0, Mode = TileSet.TerrainMode.CornersAndSides, Name = "Ground (exterior)" },
            new() { Key = "ext_roofs",  Index = 1, Mode = TileSet.TerrainMode.Sides,           Name = "Roofs (exterior A3)" },
            new() { Key = "int_floors", Index = 2, Mode = TileSet.TerrainMode.CornersAndSides, Name = "Floors (interior)" },
            new() { Key = "int_walls",  Index = 3, Mode = TileSet.TerrainMode.Sides,           Name = "Walls (interior A3)" },
        },
        Plain = new()
        {
            // --- exterior tilesets ---
            new() { Id = 10, Res = DES + "ext_fantasy_desert_a1.png" },                                 // A1 oasis water / lily (plain)
            new() { Id = 11, Res = DES + "ext_fantasy_desert_a2.png" },                                 // A2 right-half decorative objects
            new() { Id = 12, Res = DES + "ext_fantasy_desert_a4.png" },                                 // A4 walls (plain; irregular per pack warning)
            new() { Id = 13, Res = DES + "ext_fantasy_desert_a5.png" },                                 // A5 floor accents / bank walls
            new() { Id = 14, Res = DES + "ext_fantasy_desert_b.png", Collision = Collide.OpaqueRightHalf }, // architecture / windows / balconies
            new() { Id = 15, Res = DES + "ext_fantasy_desert_c.png" },                                  // pottery / market stalls / furniture
            new() { Id = 16, Res = DES + "ext_fantasy_desert_d.png" },                                  // domes / arches / columns / obelisks
            new() { Id = 17, Res = DES + "ext_fantasy_desert_e.png" },                                  // palms / cacti / rocks / vegetation
            new() { Id = 18, Res = DES + "ext_fantasy_desert_f.png" },                                  // tents / pyramid / ruins / sandstone
            // --- exterior characters / props ---
            new() { Id = 20, Res = DES + "ext_big_desert_boat.png" },
            new() { Id = 21, Res = DES + "ext_big_secret_cave.png" },
            new() { Id = 22, Res = DES + "ext_big_trees_desert.png" },                                  // canopy free; trunk collision in-editor
            new() { Id = 23, Res = DES + "ext_cave_desert1.png" },
            new() { Id = 24, Res = DES + "ext_desert_roof.png" },
            new() { Id = 25, Res = DES + "ext_desert_roofing.png" },
            new() { Id = 26, Res = DES + "ext_desert_smith.png", Collision = Collide.OpaqueAll },
            new() { Id = 27, Res = DES + "ext_desert_statue.png", Collision = Collide.OpaqueAll },
            new() { Id = 28, Res = DES + "ext_desert_statue2.png", Collision = Collide.OpaqueAll },
            new() { Id = 29, Res = DES + "ext_desert_window.png" },
            new() { Id = 30, Res = DES + "ext_gate_desert_pyramid.png", Collision = Collide.OpaqueAll },
            new() { Id = 31, Res = DES + "ext_gate_desert1.png", Collision = Collide.OpaqueAll },
            new() { Id = 32, Res = DES + "ext_gate_desert2.png", Collision = Collide.OpaqueAll },
            new() { Id = 33, Res = DES + "ext_gate_desert3.png", Collision = Collide.OpaqueAll },
            new() { Id = 34, Res = DES + "ext_decoration_desert.png" },
            new() { Id = 35, Res = DES + "ext_diagonal_water.png" },
            new() { Id = 36, Res = DES + "ext_fantasy_door7.png" },
            new() { Id = 37, Res = DES + "ext_fantasy_door8.png" },
            new() { Id = 38, Res = DES + "ext_flags_banner_desert.png" },
            new() { Id = 39, Res = DES + "ext_signs_desert.png" },
            new() { Id = 40, Res = DES + "ext_waterfall_animation.png" },                               // static first frame (animated)
            // --- interior tilesets ---
            new() { Id = 50, Res = DES + "int_fantasy_inside2_a1.png" },                                // A1 interior water / lava (plain)
            new() { Id = 51, Res = DES + "int_fantasy_inside2_a2.png" },                                // A2 right-half decorative rugs/objects
            new() { Id = 52, Res = DES + "int_fantasy_inside2_a3.png" },                                // raw walls (also terrained -> src 105)
            new() { Id = 53, Res = DES + "int_fantasy_inside2_a4.png" },                                // floor pattern bands (parquet/tile)
            new() { Id = 54, Res = DES + "int_fantasy_inside2_a5.png" },                                // A5 wall/floor accent band
            new() { Id = 55, Res = DES + "int_fantasy_inside2_b.png", Collision = Collide.OpaqueRightHalf }, // architecture / windows / drapes
            new() { Id = 56, Res = DES + "int_fantasy_inside2_c.png" },                                 // furniture (tables/chairs/shelves/beds)
            new() { Id = 57, Res = DES + "int_fantasy_inside2_d.png" },                                 // columns / thrones / stairs
            new() { Id = 58, Res = DES + "int_fantasy_inside2_e.png" },                                 // jars / sarcophagi / hangings / hieroglyphs
            // --- interior characters / props (shared props reuse the ext_ sources above) ---
            new() { Id = 60, Res = DES + "int_decoration_ceiling.png" },
            new() { Id = 61, Res = DES + "int_fireplace_kitchen2.png", Collision = Collide.OpaqueAll },
            new() { Id = 62, Res = DES + "int_fireplace_kitchen3.png", Collision = Collide.OpaqueAll },
            new() { Id = 63, Res = DES + "int_wall_decoration_desert.png" },
            new() { Id = 64, Res = DES + "int_decoration_desert_2.png" },
            new() { Id = 65, Res = DES + "int_fantasy_chest3.png", Collision = Collide.OpaqueAll },
            new() { Id = 66, Res = DES + "int_fantasy_door9.png" },
        },
        Gen = new()
        {
            new() { AtlasKey = "ground_a2_desert",     SourceId = 100, TerrainSetKey = "ext_ground" },
            new() { AtlasKey = "water_a1_desert",      SourceId = 101, TerrainSetKey = "ext_ground" },
            new() { AtlasKey = "roof_a3_desert",       SourceId = 102, TerrainSetKey = "ext_roofs" },   // roofs: no collision
            new() { AtlasKey = "floor_a2_desert_int",  SourceId = 103, TerrainSetKey = "int_floors" },
            new() { AtlasKey = "water_a1_desert_int",  SourceId = 104, TerrainSetKey = "int_floors" },
            new() { AtlasKey = "wall_a3_desert_int",   SourceId = 105, TerrainSetKey = "int_walls", Wall = WallColl.All },
        },
    };

    // ==============================================================================================
    // OVERWORLD output (region/travel map). Tiles are map-icons (mountains/forests/towns) -> collision
    // is meaningless here, so NO auto-collision on any source. No pairs / farmable.
    // ==============================================================================================
    private static Output BuildOverworld() => new()
    {
        OutPath = "res://assets/tilesets/overworld_tileset.tres",
        Layers = new(),
        Sets = new()
        {
            new() { Key = "world_ground", Index = 0, Mode = TileSet.TerrainMode.CornersAndSides, Name = "Ground" },
        },
        Plain = new()
        {
            // --- tilesets ---
            new() { Id = 10, Res = OW + "fantasy_world_a1.png" },                                       // A1 ocean / water (plain)
            new() { Id = 11, Res = OW + "fantasy_world_a2.png" },                                       // A2 right-half tree/forest map-icons
            new() { Id = 12, Res = OW + "fantasy_world_b.png" },                                        // terrain / water / cliff transition pieces
            new() { Id = 13, Res = OW + "fantasy_world_buildings.png" },                                // towns / castles / walls / bridges / pyramids
            new() { Id = 14, Res = OW + "fantasy_world_mountains.png" },                                // mountains / hills / rock spires
            new() { Id = 15, Res = OW + "fantasy_world_vegetation.png" },                               // forests / trees / ponds / caves
            // --- characters / props (map decorations) ---
            new() { Id = 20, Res = OW + "cloud_thunder.png" },
            new() { Id = 21, Res = OW + "cloud1.png" },
            new() { Id = 22, Res = OW + "cloud1_black.png" },
            new() { Id = 23, Res = OW + "cloud1_black_shadow.png" },
            new() { Id = 24, Res = OW + "cloud1_dark.png" },
            new() { Id = 25, Res = OW + "cloud1_dark_shadow.png" },
            new() { Id = 26, Res = OW + "cloud1_dark2.png" },
            new() { Id = 27, Res = OW + "cloud1_dark2_shadow.png" },
            new() { Id = 28, Res = OW + "cloud1_shadow.png" },
            new() { Id = 29, Res = OW + "fantasy_vehicle_dragon.png" },
            new() { Id = 30, Res = OW + "fantasy_vehicle_dragon2.png" },
            new() { Id = 31, Res = OW + "fantasy_vehicle_dragon3.png" },
            new() { Id = 32, Res = OW + "overworld_bigtree.png" },
            new() { Id = 33, Res = OW + "overworld_castle_magic.png" },
            new() { Id = 34, Res = OW + "overworld_castle_mountain.png" },
            new() { Id = 35, Res = OW + "overworld_castle1.png" },
            new() { Id = 36, Res = OW + "overworld_castle1_desert.png" },
            new() { Id = 37, Res = OW + "overworld_castle2.png" },
            new() { Id = 38, Res = OW + "overworld_castle3.png" },
            new() { Id = 39, Res = OW + "overworld_flying.png" },
            new() { Id = 40, Res = OW + "overworld_magicshield.png" },
            new() { Id = 41, Res = OW + "overworld_mountain1.png" },
            new() { Id = 42, Res = OW + "overworld_mountain2.png" },
            new() { Id = 43, Res = OW + "overworld_village_sea.png" },
            new() { Id = 44, Res = OW + "overworld_village1.png" },
            new() { Id = 45, Res = OW + "overworld_worldtree.png" },
            new() { Id = 46, Res = OW + "overworld_decoration.png" },
            new() { Id = 47, Res = OW + "overworld_towers.png" },
            new() { Id = 48, Res = OW + "fantasy_vehicle.png" },
        },
        Gen = new()
        {
            new() { AtlasKey = "ground_a2_world", SourceId = 100, TerrainSetKey = "world_ground" },
            new() { AtlasKey = "water_a1_world",  SourceId = 101, TerrainSetKey = "world_ground" },
        },
    };

    // ==============================================================================================
    // ORC output (enemy encampment set-pieces). A2 ground + A1 pond + A3 (bottom-row) palisade walls.
    // No pairs / farmable. Colorways (A1/A2/A5 green/greenV2/earth, C_dark) kept as plain sources.
    // ==============================================================================================
    private static Output BuildOrc() => new()
    {
        OutPath = "res://assets/tilesets/orc_tileset.tres",
        Layers = new(),
        Sets = new()
        {
            new() { Key = "orc_ground", Index = 0, Mode = TileSet.TerrainMode.CornersAndSides, Name = "Ground" },
            new() { Key = "orc_walls",  Index = 1, Mode = TileSet.TerrainMode.Sides,           Name = "Walls" },
        },
        Plain = new()
        {
            // --- tilesets ---
            new() { Id = 10, Res = ORC + "fantasy_orc_a1_green.png" },                                  // A1 water / lava (plain)
            new() { Id = 11, Res = ORC + "fantasy_orc_a1_greenv2.png" },                                // A1 colorway V2
            new() { Id = 12, Res = ORC + "fantasy_orc_a2.png" },                                        // A2 right-half decorative objects
            new() { Id = 13, Res = ORC + "fantasy_orc_a2_greenv2.png" },                                // A2 colorway V2
            new() { Id = 14, Res = ORC + "fantasy_orc_a2_inside.png" },                                 // A2 interior floor variant
            new() { Id = 15, Res = ORC + "fantasy_orc_a3.png" },                                        // raw walls (bottom rows; terrained -> src 102)
            new() { Id = 16, Res = ORC + "fantasy_orc_a4_inside.png" },                                 // A4 interior walls (sparse; plain)
            new() { Id = 17, Res = ORC + "fantasy_orc_b.png", Collision = Collide.OpaqueRightHalf },    // palisades / fences / watchtowers
            new() { Id = 18, Res = ORC + "fantasy_orc_c.png" },                                         // orc tents / huts
            new() { Id = 19, Res = ORC + "fantasy_orc_c_dark.png" },                                    // tents / huts colorway
            new() { Id = 20, Res = ORC + "fantasy_orc_d_badlands.png" },                                // badlands cliffs / rock walls
            new() { Id = 21, Res = ORC + "fantasy_orc_e.png" },                                         // forge / throne / crates / fences
            new() { Id = 22, Res = ORC + "fantasy_orc_inside.png" },                                    // orc interior furniture
            new() { Id = 23, Res = ORC + "fantasy_orc_inside_walls.png" },                              // orc interior walls / roofs
            new() { Id = 24, Res = ORC + "fantasy_ork_a5_earth.png" },                                  // A5 accent band (earth)
            new() { Id = 25, Res = ORC + "fantasy_ork_a5_green.png" },                                  // A5 accent band (green)
            new() { Id = 26, Res = ORC + "fantasy_ork_a5_greenv2.png" },                                // A5 accent band (green V2)
            // --- characters / props ---
            new() { Id = 30, Res = ORC + "lights_glowing.png" },
            new() { Id = 31, Res = ORC + "orc_chandelier.png" },
            new() { Id = 32, Res = ORC + "orc_decoration_big.png" },                                    // !$ large decoration column
            new() { Id = 33, Res = ORC + "orc_decoration_bed.png" },
            new() { Id = 34, Res = ORC + "orc_decoration_shaman_big.png" },                             // !$ large shaman decoration
            new() { Id = 35, Res = ORC + "orc_fire.png" },
            new() { Id = 36, Res = ORC + "orc_fireplace.png", Collision = Collide.OpaqueAll },
            new() { Id = 37, Res = ORC + "orc_flags_banner.png" },
            new() { Id = 38, Res = ORC + "orc_flags_banner_v2.png" },
            new() { Id = 39, Res = ORC + "orc_misc.png" },
            new() { Id = 40, Res = ORC + "orc_pit_gate.png", Collision = Collide.OpaqueAll },
            new() { Id = 41, Res = ORC + "orc_pit_nogate.png" },
            new() { Id = 42, Res = ORC + "orc_pot.png", Collision = Collide.OpaqueAll },
            new() { Id = 43, Res = ORC + "orc_roof_decoration.png" },
            new() { Id = 44, Res = ORC + "orc_tent_decoration.png" },
            new() { Id = 45, Res = ORC + "orc_tent_roof_down_left.png" },
            new() { Id = 46, Res = ORC + "orc_tent_roof_down_left_dark.png" },
            new() { Id = 47, Res = ORC + "orc_tent_roof_right_up.png" },
            new() { Id = 48, Res = ORC + "orc_tent_roof_right_up_dark.png" },
            new() { Id = 49, Res = ORC + "orc_tower_wall_decoration_big.png" },                         // !$ large tower-wall decoration
            new() { Id = 50, Res = ORC + "orc_wall_gate.png", Collision = Collide.OpaqueAll },
            new() { Id = 51, Res = ORC + "orc_wall_parts.png" },                                        // palisade wall parts (refine collision in-editor)
            new() { Id = 52, Res = ORC + "orc_watchtower_roof.png" },
            new() { Id = 53, Res = ORC + "smith_orc.png", Collision = Collide.OpaqueAll },
            new() { Id = 54, Res = ORC + "fantasy_chimney_orc.png" },
            new() { Id = 55, Res = ORC + "fantasy_door1_orc.png" },
            new() { Id = 56, Res = ORC + "orc_decoration.png" },                                        // ! standard decoration sheet
            new() { Id = 57, Res = ORC + "orc_decoration_l.png" },
            new() { Id = 58, Res = ORC + "orc_decoration_shaman.png" },                                 // ! standard shaman decoration
            new() { Id = 59, Res = ORC + "orc_hanging_meat.png" },
            new() { Id = 60, Res = ORC + "orc_pit_decoration.png" },
            new() { Id = 61, Res = ORC + "orc_tower_wall_decoration.png" },                             // ! standard tower-wall decoration
        },
        Gen = new()
        {
            new() { AtlasKey = "ground_a2_orc", SourceId = 100, TerrainSetKey = "orc_ground" },
            new() { AtlasKey = "water_a1_orc",  SourceId = 101, TerrainSetKey = "orc_ground" },
            new() { AtlasKey = "wall_a3_orc",   SourceId = 102, TerrainSetKey = "orc_walls", Wall = WallColl.All },
        },
    };

    private static readonly List<Output> Outputs = new()
    {
        BuildOutpost(), BuildInterior(), BuildSwamp(), BuildDungeon(), BuildMushroom(),
        BuildDesert(), BuildOverworld(), BuildOrc(),
    };

    // atlasKey -> its specs (grouped once).
    private static readonly Dictionary<string, List<AutotileExpander.GenAutotile>> GenByAtlas =
        AutotileExpander.AllGen.GroupBy(s => s.AtlasKey).ToDictionary(g => g.Key, g => g.ToList());

    private static readonly Vector2[] FullSquare =
    {
        new(-24, -24), new(24, -24), new(24, 24), new(-24, 24),
    };

    // per-build accumulators (reset per output)
    private int _farmableCount, _collisionCount, _peeringCount;
    private Dictionary<int, int> _tilesPerSource = new();
    private Dictionary<int, (string tex, int count)> _before = new();
    private HashSet<string> _layerNames = new();

    public override void _Ready()
    {
        try
        {
            foreach (var o in Outputs) BuildAndSave(o);
            GD.Print("[TileSetBuilder] DONE");
        }
        catch (Exception e)
        {
            GD.PushError($"[TileSetBuilder] FAILED: {e}");
            GD.Print($"[TileSetBuilder] FAILED: {e.Message}\n{e.StackTrace}");
        }
        GetTree().Quit();
    }

    private void BuildAndSave(Output o)
    {
        _farmableCount = _collisionCount = _peeringCount = 0;
        _tilesPerSource = new();
        _before = new();
        _layerNames = o.Layers.Select(l => l.Name).ToHashSet();

        GD.Print($"[TileSetBuilder] === {o.OutPath} ===");
        CaptureBefore(o.OutPath);
        var ts = Build(o);
        PreservePatterns(ts, o.OutPath);
        Error err = ResourceSaver.Save(ts, o.OutPath);
        GD.Print($"[TileSetBuilder] saved {o.OutPath} err={err}");
        VerifyReload(o.OutPath);
        CompareAfter(o.OutPath, o.Rebaseline);
    }

    private TileSet Build(Output o)
    {
        var ts = new TileSet { TileShape = TileSet.TileShapeEnum.Square, TileSize = new Vector2I(Cell, Cell) };
        ts.AddPhysicsLayer();

        for (int i = 0; i < o.Layers.Count; i++)
        {
            ts.AddCustomDataLayer();
            ts.SetCustomDataLayerName(i, o.Layers[i].Name);
            ts.SetCustomDataLayerType(i, o.Layers[i].Type);
        }

        // Terrain sets in index order (names are documentation only; not serialized, matching the
        // original resource).
        foreach (var set in o.Sets.OrderBy(s => s.Index))
        {
            ts.AddTerrainSet();
            ts.SetTerrainSetMode(set.Index, set.Mode);
        }
        var setIndexByKey = o.Sets.ToDictionary(s => s.Key, s => s.Index);

        foreach (var s in o.Plain) AddPlainSource(ts, s);
        AddGenAtlases(ts, o, setIndexByKey);
        AddPreExpSources(ts, o, setIndexByKey);

        GD.Print($"[TileSetBuilder] sources={ts.GetSourceCount()} terrainSets={ts.GetTerrainSetsCount()} " +
                 $"terrains0={ts.GetTerrainsCount(0)} collisionTiles={_collisionCount} " +
                 $"farmableTiles={_farmableCount} peeringBits={_peeringCount}");
        return ts;
    }

    private void SetData(TileData td, string layer, Variant value)
    {
        if (_layerNames.Contains(layer)) td.SetCustomData(layer, value);
    }

    private void AddPlainSource(TileSet ts, PlainSrc def)
    {
        var tex = GD.Load<Texture2D>(def.Res);
        if (tex == null) throw new InvalidOperationException($"missing texture {def.Res}");
        // Analyse pixels from the original PNG (avoids import-compression surprises).
        Image img = Image.LoadFromFile(ProjectSettings.GlobalizePath(def.Res));
        if (img.GetFormat() != Image.Format.Rgba8) img.Convert(Image.Format.Rgba8);

        var src = new TileSetAtlasSource { Texture = tex, TextureRegionSize = new Vector2I(Cell, Cell) };
        ts.AddSource(src, def.Id);

        int cols = img.GetWidth() / Cell;
        int rows = img.GetHeight() / Cell;
        int created = 0;
        for (int y = 0; y < rows; y++)
        {
            for (int x = 0; x < cols; x++)
            {
                float opaque = OpaqueFraction(img, x, y);
                if (opaque < 0.02f) continue; // skip empty cells
                var coords = new Vector2I(x, y);
                src.CreateTile(coords);
                created++;
                TileData td = src.GetTileData(coords, 0);

                bool solid = def.Collision switch
                {
                    Collide.OpaqueAll => opaque > 0.5f,
                    Collide.OpaqueRightHalf => x >= cols / 2 && opaque > 0.6f,
                    _ => false,
                };
                if (solid)
                {
                    td.AddCollisionPolygon(0);
                    td.SetCollisionPolygonPoints(0, 0, FullSquare);
                    _collisionCount++;
                }

                if (def.FarmableByColor && IsSoil(img, x, y))
                {
                    SetData(td, "farmable", true);
                    _farmableCount++;
                }
                if (def.RuinPair != 0) SetData(td, "ruin_pair", def.RuinPair);
                if (def.SeasonPair != 0) SetData(td, "season_pair", def.SeasonPair);
            }
        }
        _tilesPerSource[def.Id] = created;
    }

    /// <summary>Create every generated-atlas source, expand its tiles, wire terrains + peering +
    /// collision + pairs. Terrain ids allocate per set in Gen-list order (preserves original order).</summary>
    private void AddGenAtlases(TileSet ts, Output o, Dictionary<string, int> setIndexByKey)
    {
        var nextTerrain = new Dictionary<int, int>();

        foreach (var atlas in o.Gen)
        {
            if (!GenByAtlas.TryGetValue(atlas.AtlasKey, out var specs))
                throw new InvalidOperationException($"no generated specs for atlas {atlas.AtlasKey}");

            string res = G + atlas.AtlasKey + ".png";
            var tex = GD.Load<Texture2D>(res);
            if (tex == null) throw new InvalidOperationException($"missing generated texture {res}");
            var src = new TileSetAtlasSource { Texture = tex, TextureRegionSize = new Vector2I(Cell, Cell) };
            ts.AddSource(src, atlas.SourceId);
            _tilesPerSource[atlas.SourceId] = 0;

            bool wall = specs[0].Format == AutotileExpander.GenFormat.Wall;
            bool hasTerrain = atlas.TerrainSetKey.Length > 0;
            int setIndex = hasTerrain ? setIndexByKey[atlas.TerrainSetKey] : -1;

            foreach (var spec in specs)
            {
                int terrainId = -1;
                if (hasTerrain)
                {
                    if (!nextTerrain.TryGetValue(setIndex, out terrainId)) terrainId = 0;
                    ts.AddTerrain(setIndex);
                    ts.SetTerrainName(setIndex, terrainId, spec.TerrainName);
                    ts.SetTerrainColor(setIndex, terrainId, TerrainColor(setIndex, terrainId));
                    nextTerrain[setIndex] = terrainId + 1;
                }

                bool blockCollides = atlas.Wall switch
                {
                    WallColl.All => true,
                    WallColl.BottomHalf => (spec.IndexInAtlas / 8) >= 2,
                    _ => false,
                };

                int shapes = wall ? AutotileExpander.WallShapeCount : AutotileExpander.ShapeCount;
                for (int s = 0; s < shapes; s++)
                {
                    Vector2I coords = wall
                        ? AutotileExpander.WallTilePixel(spec.IndexInAtlas, s)
                        : AutotileExpander.TilePixel(spec.IndexInAtlas, s);
                    src.CreateTile(coords);
                    _tilesPerSource[atlas.SourceId]++;
                    TileData td = src.GetTileData(coords, 0);

                    if (hasTerrain)
                    {
                        td.TerrainSet = setIndex;
                        td.Terrain = terrainId;
                        if (wall)
                        {
                            var nb = AutotileExpander.DecodeWallNeighbors(s);
                            SetBit(td, TileSet.CellNeighbor.TopSide, nb.N, terrainId);
                            SetBit(td, TileSet.CellNeighbor.RightSide, nb.E, terrainId);
                            SetBit(td, TileSet.CellNeighbor.BottomSide, nb.S, terrainId);
                            SetBit(td, TileSet.CellNeighbor.LeftSide, nb.W, terrainId);
                        }
                        else
                        {
                            var nb = AutotileExpander.DecodeNeighbors(s);
                            SetBit(td, TileSet.CellNeighbor.TopSide, nb.N, terrainId);
                            SetBit(td, TileSet.CellNeighbor.RightSide, nb.E, terrainId);
                            SetBit(td, TileSet.CellNeighbor.BottomSide, nb.S, terrainId);
                            SetBit(td, TileSet.CellNeighbor.LeftSide, nb.W, terrainId);
                            SetBit(td, TileSet.CellNeighbor.TopRightCorner, nb.Ne, terrainId);
                            SetBit(td, TileSet.CellNeighbor.BottomRightCorner, nb.Se, terrainId);
                            SetBit(td, TileSet.CellNeighbor.BottomLeftCorner, nb.Sw, terrainId);
                            SetBit(td, TileSet.CellNeighbor.TopLeftCorner, nb.Nw, terrainId);
                        }
                    }

                    if (blockCollides)
                    {
                        td.AddCollisionPolygon(0);
                        td.SetCollisionPolygonPoints(0, 0, FullSquare);
                        _collisionCount++;
                    }

                    if (spec.Farmable)
                    {
                        SetData(td, "farmable", true);
                        _farmableCount++;
                    }
                    if (atlas.RuinPair != 0) SetData(td, "ruin_pair", atlas.RuinPair);
                    if (atlas.SeasonPair != 0) SetData(td, "season_pair", atlas.SeasonPair);
                }
            }
        }
    }

    /// <summary>Register every PRE-EXPANDED source (Winlu Godot-native sheet): add the source, wire its
    /// terrain-block groups (peering straight from the pre-expanded tables), and promote plain regions.
    /// Terrain ids allocate per set across all sources in list order (grass/dirt stay 0/1).</summary>
    private void AddPreExpSources(TileSet ts, Output o, Dictionary<string, int> setIndexByKey)
    {
        if (o.PreExp.Count == 0) return;
        var nextTerrain = new Dictionary<int, int>();

        foreach (var pre in o.PreExp)
        {
            var tex = GD.Load<Texture2D>(pre.Res);
            if (tex == null) throw new InvalidOperationException($"missing pre-expanded texture {pre.Res}");
            Image img = Image.LoadFromFile(ProjectSettings.GlobalizePath(pre.Res));
            if (img.GetFormat() != Image.Format.Rgba8) img.Convert(Image.Format.Rgba8);

            var src = new TileSetAtlasSource { Texture = tex, TextureRegionSize = new Vector2I(Cell, Cell) };
            ts.AddSource(src, pre.Id);
            _tilesPerSource[pre.Id] = 0;

            foreach (var grp in pre.Groups)
            {
                int setIndex = setIndexByKey[grp.SetKey];
                bool floor = grp.Kind == PreKind.Floor;
                bool corners = grp.Kind != PreKind.WallSide; // Floor + WallTop peer corners; WallSide sides only
                int blockIndex = -1;
                foreach (var origin in grp.BlockOrigins)
                {
                    blockIndex++;
                    // fill / centre tile: floor block-relative index 33 -> (9,2); 3x3 wall centre -> (1,1)
                    Vector2I fill = origin + (floor ? new Vector2I(9, 2) : new Vector2I(1, 1));
                    if (grp.SkipEmpty && OpaqueFraction(img, fill.X, fill.Y) < 0.02f)
                    {
                        GD.Print($"[TileSetBuilder]   PRE {pre.Id} {grp.NamePrefix}: skipped empty block #{blockIndex} at {origin}");
                        continue;
                    }

                    if (!nextTerrain.TryGetValue(setIndex, out int terrainId)) terrainId = 0;
                    ts.AddTerrain(setIndex);
                    ts.SetTerrainName(setIndex, terrainId, $"{grp.NamePrefix}_{blockIndex}");
                    ts.SetTerrainColor(setIndex, terrainId, TerrainColor(setIndex, terrainId));
                    nextTerrain[setIndex] = terrainId + 1;

                    bool farm = grp.FarmableSoil && IsSoil(img, fill.X, fill.Y);
                    bool coll = grp.Collides?.Invoke(blockIndex) ?? false;

                    if (floor)
                    {
                        for (int ir = 0; ir < 4; ir++)
                            for (int ic = 0; ic < 12; ic++)
                            {
                                int rel = ir * 12 + ic;
                                if (AutotileExpander.IsPreFloorBlank(rel)) continue;
                                var coords = origin + new Vector2I(ic, ir);
                                CreatePreTile(src, pre.Id, coords, setIndex, terrainId,
                                    AutotileExpander.PreFloorNeighbors(rel), corners: true, coll, farm, grp.RuinPair);
                                if (grp.Anim != null) SetTileAnim(src, coords, grp.Anim);
                            }
                    }
                    else
                    {
                        for (int ir = 0; ir < 3; ir++)
                            for (int ic = 0; ic < 3; ic++)
                            {
                                var nb = grp.Kind == PreKind.WallTop
                                    ? AutotileExpander.PreWallTopNeighbors(ic, ir)
                                    : AutotileExpander.PreWallSideNeighbors(ic, ir);
                                var coords = origin + new Vector2I(ic, ir);
                                CreatePreTile(src, pre.Id, coords, setIndex, terrainId, nb, corners, coll, farm, grp.RuinPair);
                            }
                    }
                }
            }

            // Plain-tile regions (misc / animation-band art with no terrain — e.g. dock, lily, waterfall).
            foreach (var pr in pre.Plain)
                for (int y = pr.Y; y < pr.Y + pr.H; y++)
                    for (int x = pr.X; x < pr.X + pr.W; x++)
                    {
                        if (OpaqueFraction(img, x, y) < 0.02f) continue;
                        var coords = new Vector2I(x, y);
                        if (src.GetTileAtCoords(coords) != new Vector2I(-1, -1)) continue; // already a terrain tile
                        src.CreateTile(coords);
                        _tilesPerSource[pre.Id]++;
                    }
        }
    }

    private void CreatePreTile(TileSetAtlasSource src, int sourceId, Vector2I coords, int setIndex, int terrainId,
        AutotileExpander.Neighbors nb, bool corners, bool collide, bool farm, int ruinPair)
    {
        src.CreateTile(coords);
        _tilesPerSource[sourceId]++;
        TileData td = src.GetTileData(coords, 0);
        td.TerrainSet = setIndex;
        td.Terrain = terrainId;
        SetBit(td, TileSet.CellNeighbor.TopSide, nb.N, terrainId);
        SetBit(td, TileSet.CellNeighbor.RightSide, nb.E, terrainId);
        SetBit(td, TileSet.CellNeighbor.BottomSide, nb.S, terrainId);
        SetBit(td, TileSet.CellNeighbor.LeftSide, nb.W, terrainId);
        if (corners)
        {
            SetBit(td, TileSet.CellNeighbor.TopRightCorner, nb.Ne, terrainId);
            SetBit(td, TileSet.CellNeighbor.BottomRightCorner, nb.Se, terrainId);
            SetBit(td, TileSet.CellNeighbor.BottomLeftCorner, nb.Sw, terrainId);
            SetBit(td, TileSet.CellNeighbor.TopLeftCorner, nb.Nw, terrainId);
        }
        if (collide)
        {
            td.AddCollisionPolygon(0);
            td.SetCollisionPolygonPoints(0, 0, FullSquare);
            _collisionCount++;
        }
        if (farm) { SetData(td, "farmable", true); _farmableCount++; }
        if (ruinPair != 0) SetData(td, "ruin_pair", ruinPair);
    }

    /// <summary>Wire a 3-frame horizontal tile animation (frames <c>ColStride</c> tiles apart).</summary>
    private static void SetTileAnim(TileSetAtlasSource src, Vector2I coords, PreAnim anim)
    {
        src.SetTileAnimationColumns(coords, anim.Frames);
        src.SetTileAnimationSeparation(coords, new Vector2I(anim.ColStride - 1, 0));
        src.SetTileAnimationFramesCount(coords, anim.Frames);
        for (int f = 0; f < anim.Frames; f++)
            src.SetTileAnimationFrameDuration(coords, f, anim.FrameDuration);
    }

    private void SetBit(TileData td, TileSet.CellNeighbor n, bool same, int terrainId)
    {
        if (!same) return;
        td.SetTerrainPeeringBit(n, terrainId);
        _peeringCount++;
    }

    // Set 0 keeps the original single-arg color hash; other sets space hues out per set.
    private static Color TerrainColor(int setIndex, int terrainId) =>
        ColorFromId(setIndex == 0 ? terrainId : setIndex * 97 + terrainId);

    // --- pixel helpers ---

    private static float OpaqueFraction(Image img, int cellX, int cellY)
    {
        int px = cellX * Cell, py = cellY * Cell;
        int opaque = 0;
        for (int y = 0; y < Cell; y++)
            for (int x = 0; x < Cell; x++)
                if (img.GetPixel(px + x, py + y).A > 0.5f) opaque++;
        return opaque / (float)(Cell * Cell);
    }

    /// <summary>Average-color soil test: tan/brown, warm, not gray, not green.</summary>
    private static bool IsSoil(Image img, int cellX, int cellY)
    {
        int px = cellX * Cell, py = cellY * Cell;
        float r = 0, g = 0, b = 0, n = 0;
        for (int y = 4; y < Cell - 4; y += 2)
            for (int x = 4; x < Cell - 4; x += 2)
            {
                Color c = img.GetPixel(px + x, py + y);
                if (c.A < 0.5f) continue;
                r += c.R; g += c.G; b += c.B; n++;
            }
        if (n < 10) return false;
        r /= n; g /= n; b /= n;
        return r > 0.42f && r > g && g > b && (r - b) > 0.08f && b < 0.46f && g < 0.55f;
    }

    private static Color ColorFromId(int id)
    {
        float h = (id * 0.13f) % 1.0f;
        return Color.FromHsv(h, 0.55f, 0.85f);
    }

    private void VerifyReload(string outPath)
    {
        var loaded = GD.Load<TileSet>(outPath);
        if (loaded == null) throw new InvalidOperationException("reload returned null");
        GD.Print($"[TileSetBuilder] RELOAD sources={loaded.GetSourceCount()} " +
                 $"terrainSets={loaded.GetTerrainSetsCount()} terrains0={loaded.GetTerrainsCount(0)} " +
                 $"customLayers={loaded.GetCustomDataLayersCount()} physicsLayers={loaded.GetPhysicsLayersCount()}");
        foreach (var (id, count) in _tilesPerSource.OrderBy(kv => kv.Key))
            GD.Print($"[TileSetBuilder]   source {id}: {count} tiles");
    }

    /// <summary>Snapshot every source's texture path + tile count from the OLD .tres before rebuild.</summary>
    private void CaptureBefore(string outPath)
    {
        if (!Godot.FileAccess.FileExists(outPath)) { GD.Print("[TileSetBuilder] BEFORE: no existing .tres"); return; }
        var old = ResourceLoader.Load<TileSet>(outPath, cacheMode: ResourceLoader.CacheMode.Ignore);
        if (old == null) { GD.Print("[TileSetBuilder] BEFORE: could not load existing .tres"); return; }
        for (int i = 0; i < old.GetSourceCount(); i++)
        {
            int id = old.GetSourceId(i);
            if (old.GetSource(id) is TileSetAtlasSource a)
                _before[id] = (a.Texture?.ResourcePath ?? "", a.GetTilesCount());
        }
        GD.Print($"[TileSetBuilder] BEFORE: captured {_before.Count} sources; terrains0={old.GetTerrainsCount(0)}");
    }

    /// <summary>
    /// Carry the user's saved TileMap patterns from the OLD .tres into the freshly built TileSet.
    /// Patterns are authored in the editor while painting and live inside the TileSet resource, so
    /// without this step every regeneration would silently destroy the user's pattern library.
    /// Cells referencing a source id that no longer exists are reported (the additive COMPAT
    /// guarantee should make that impossible; the pattern is still preserved as-is).
    /// </summary>
    private static void PreservePatterns(TileSet fresh, string outPath)
    {
        if (!Godot.FileAccess.FileExists(outPath)) { GD.Print("[TileSetBuilder] PATTERNS: no existing .tres, nothing to preserve"); return; }
        var old = ResourceLoader.Load<TileSet>(outPath, cacheMode: ResourceLoader.CacheMode.Ignore);
        if (old == null) { GD.PushWarning("[TileSetBuilder] PATTERNS: could not load existing .tres — patterns NOT preserved!"); return; }

        int count = old.GetPatternsCount();
        int orphanCells = 0;
        for (int i = 0; i < count; i++)
        {
            TileMapPattern pattern = old.GetPattern(i);
            foreach (Vector2I cell in pattern.GetUsedCells())
            {
                int sourceId = pattern.GetCellSourceId(cell);
                if (!fresh.HasSource(sourceId))
                {
                    orphanCells++;
                    GD.PushWarning($"[TileSetBuilder] PATTERNS: pattern {i} cell {cell} references missing source {sourceId}");
                }
            }
            fresh.AddPattern(pattern);
        }
        GD.Print($"[TileSetBuilder] PATTERNS: carried over {count} pattern(s), {orphanCells} orphan cell(s)");
    }

    /// <summary>Assert every pre-existing source (texture path + tile count) survives unchanged. When
    /// <paramref name="rebaseline"/> is set (an output whose source roster legitimately changed this
    /// run), sources removed since the baseline are reported as expected removals rather than mismatches
    /// — but every SURVIVING pre-existing source is still checked strictly.</summary>
    private void CompareAfter(string outPath, bool rebaseline)
    {
        if (_before.Count == 0) { GD.Print("[TileSetBuilder] AFTER: no baseline to compare"); return; }
        var now = ResourceLoader.Load<TileSet>(outPath, cacheMode: ResourceLoader.CacheMode.Ignore);
        int checkedCount = 0, mismatches = 0, removed = 0;
        foreach (var (id, before) in _before.OrderBy(kv => kv.Key))
        {
            if (now.GetSource(id) is not TileSetAtlasSource a)
            {
                if (rebaseline) { GD.Print($"[TileSetBuilder] AFTER: source {id} removed (rebaselined; was {before.tex})"); removed++; }
                else { GD.Print($"[TileSetBuilder] AFTER: source {id} MISSING (was {before.tex}, {before.count} tiles)"); mismatches++; }
                continue;
            }
            string tex = a.Texture?.ResourcePath ?? "";
            int count = a.GetTilesCount();
            bool ok = tex == before.tex && count == before.count;
            if (!ok) { GD.Print($"[TileSetBuilder] AFTER: source {id} CHANGED tex {before.tex}->{tex} count {before.count}->{count}"); mismatches++; }
            checkedCount++;
        }
        string suffix = rebaseline ? $", {removed} rebaselined removal(s)" : "";
        GD.Print($"[TileSetBuilder] COMPAT: checked {checkedCount} surviving pre-existing sources, {mismatches} mismatches{suffix} " +
                 $"({(mismatches == 0 ? "PASS - all surviving pre-existing sources intact" : "FAIL")})");
    }
}
