using System;
using System.Collections.Generic;
using System.Linq;
using Godot;

namespace Bulwark.Dev;

/// <summary>
/// Expands RPG Maker MZ autotile blocks (A1 water / A2 floors — "floor format"; A3 buildings /
/// A4 wall faces — "wall format") into flat Godot atlas PNGs, one 48x48 tile per blob configuration,
/// so Godot's terrain autotiler can drive them.
///
/// MZ floor block: 2x3 tiles (96x144 px), assembled from 24px quadrant minitiles per the canonical
/// <see cref="FloorAutotileTable"/> (48 blobs). MZ wall block: 2x2 tiles (96x96 px), 16 combos per
/// <see cref="WallAutotileTable"/>. Both tables lifted verbatim from RPG Maker Tilemap.js.
///
/// <b>Generalized (wave 2):</b> the expander is data-driven. Each art pack contributes a list of
/// <see cref="GenAutotile"/> specs (one per autotile block) via a <see cref="Pack"/> entry in
/// <see cref="Packs"/>. The generation engine (tables + <see cref="ExpandBlock"/> /
/// <see cref="ExpandWallBlock"/> + atlas sizing) is pack-agnostic. Adding a wave-2 pack is a matter
/// of appending a <see cref="Pack"/> — no engine changes. The outpost pack reproduces the original
/// generated atlases byte-for-byte (same atlas keys, block sources, indices and sizing).
///
/// Run headless via <c>scenes/dev/autotile_expander.tscn</c>: writes generated atlases under
/// <c>assets/tilesets/generated/</c> plus contact sheets for visual self-verification.
///
/// Exposes <see cref="DecodeNeighbors"/> / <see cref="DecodeWallNeighbors"/> so
/// <see cref="TileSetBuilder"/> assigns Godot terrain peering bits from the same tables the pixels
/// were assembled from.
/// </summary>
public partial class AutotileExpander : Node
{
    // --- MZ constants ---
    public const int TileSize = 48;
    public const int HalfTile = 24;
    public const int BlockW = 96;   // 2 tiles
    public const int BlockH = 144;  // 3 tiles
    public const int ShapeCount = 48;

    /// <summary>Per generated floor autotile: 12 tiles wide x 4 tiles tall = 48 shapes packed contiguously.</summary>
    public const int AutotileTilesW = 12;
    public const int AutotileTilesH = 4;
    /// <summary>Floor autotiles per atlas row.</summary>
    public const int AutotilesPerRow = 2;

    /// <summary>
    /// RPG Maker MV/MZ FLOOR_AUTOTILE_TABLE. 48 shapes; each is [TL, TR, BL, BR], each quadrant a
    /// [col,row] into the 4x6 (24px) minitile grid of the block. Source: rpg_core Tilemap.js.
    /// </summary>
    public static readonly int[][][] FloorAutotileTable =
    {
        new[]{ new[]{2,4}, new[]{1,4}, new[]{2,3}, new[]{1,3} }, //0
        new[]{ new[]{2,0}, new[]{1,4}, new[]{2,3}, new[]{1,3} }, //1
        new[]{ new[]{2,4}, new[]{3,0}, new[]{2,3}, new[]{1,3} }, //2
        new[]{ new[]{2,0}, new[]{3,0}, new[]{2,3}, new[]{1,3} }, //3
        new[]{ new[]{2,4}, new[]{1,4}, new[]{2,3}, new[]{3,1} }, //4
        new[]{ new[]{2,0}, new[]{1,4}, new[]{2,3}, new[]{3,1} }, //5
        new[]{ new[]{2,4}, new[]{3,0}, new[]{2,3}, new[]{3,1} }, //6
        new[]{ new[]{2,0}, new[]{3,0}, new[]{2,3}, new[]{3,1} }, //7
        new[]{ new[]{2,4}, new[]{1,4}, new[]{2,1}, new[]{1,3} }, //8
        new[]{ new[]{2,0}, new[]{1,4}, new[]{2,1}, new[]{1,3} }, //9
        new[]{ new[]{2,4}, new[]{3,0}, new[]{2,1}, new[]{1,3} }, //10
        new[]{ new[]{2,0}, new[]{3,0}, new[]{2,1}, new[]{1,3} }, //11
        new[]{ new[]{2,4}, new[]{1,4}, new[]{2,1}, new[]{3,1} }, //12
        new[]{ new[]{2,0}, new[]{1,4}, new[]{2,1}, new[]{3,1} }, //13
        new[]{ new[]{2,4}, new[]{3,0}, new[]{2,1}, new[]{3,1} }, //14
        new[]{ new[]{2,0}, new[]{3,0}, new[]{2,1}, new[]{3,1} }, //15
        new[]{ new[]{0,4}, new[]{1,4}, new[]{0,3}, new[]{1,3} }, //16
        new[]{ new[]{0,4}, new[]{3,0}, new[]{0,3}, new[]{1,3} }, //17
        new[]{ new[]{0,4}, new[]{1,4}, new[]{0,3}, new[]{3,1} }, //18
        new[]{ new[]{0,4}, new[]{3,0}, new[]{0,3}, new[]{3,1} }, //19
        new[]{ new[]{2,2}, new[]{1,2}, new[]{2,3}, new[]{1,3} }, //20
        new[]{ new[]{2,2}, new[]{1,2}, new[]{2,3}, new[]{3,1} }, //21
        new[]{ new[]{2,2}, new[]{1,2}, new[]{2,1}, new[]{1,3} }, //22
        new[]{ new[]{2,2}, new[]{1,2}, new[]{2,1}, new[]{3,1} }, //23
        new[]{ new[]{2,4}, new[]{3,4}, new[]{2,3}, new[]{3,3} }, //24
        new[]{ new[]{2,4}, new[]{3,4}, new[]{2,1}, new[]{3,3} }, //25
        new[]{ new[]{2,0}, new[]{3,4}, new[]{2,3}, new[]{3,3} }, //26
        new[]{ new[]{2,0}, new[]{3,4}, new[]{2,1}, new[]{3,3} }, //27
        new[]{ new[]{2,4}, new[]{1,4}, new[]{2,5}, new[]{1,5} }, //28
        new[]{ new[]{2,0}, new[]{1,4}, new[]{2,5}, new[]{1,5} }, //29
        new[]{ new[]{2,4}, new[]{3,0}, new[]{2,5}, new[]{1,5} }, //30
        new[]{ new[]{2,0}, new[]{3,0}, new[]{2,5}, new[]{1,5} }, //31
        new[]{ new[]{0,4}, new[]{3,4}, new[]{0,3}, new[]{3,3} }, //32
        new[]{ new[]{2,2}, new[]{1,2}, new[]{2,5}, new[]{1,5} }, //33
        new[]{ new[]{0,2}, new[]{1,2}, new[]{0,3}, new[]{1,3} }, //34
        new[]{ new[]{0,2}, new[]{1,2}, new[]{0,3}, new[]{3,1} }, //35
        new[]{ new[]{2,2}, new[]{3,2}, new[]{2,3}, new[]{3,3} }, //36
        new[]{ new[]{2,2}, new[]{3,2}, new[]{2,1}, new[]{3,3} }, //37
        new[]{ new[]{2,4}, new[]{3,4}, new[]{2,5}, new[]{3,5} }, //38
        new[]{ new[]{2,0}, new[]{3,4}, new[]{2,5}, new[]{3,5} }, //39
        new[]{ new[]{0,4}, new[]{1,4}, new[]{0,5}, new[]{1,5} }, //40
        new[]{ new[]{0,4}, new[]{3,0}, new[]{0,5}, new[]{1,5} }, //41
        new[]{ new[]{0,2}, new[]{3,2}, new[]{0,3}, new[]{3,3} }, //42
        new[]{ new[]{0,2}, new[]{1,2}, new[]{0,5}, new[]{1,5} }, //43
        new[]{ new[]{0,4}, new[]{3,4}, new[]{0,5}, new[]{3,5} }, //44
        new[]{ new[]{2,2}, new[]{3,2}, new[]{2,5}, new[]{3,5} }, //45
        new[]{ new[]{0,2}, new[]{3,2}, new[]{0,5}, new[]{3,5} }, //46
        new[]{ new[]{0,0}, new[]{1,0}, new[]{0,1}, new[]{1,1} }, //47 isolated
    };

    /// <summary>8-neighbor "same terrain" set decoded from a blob shape.</summary>
    public struct Neighbors
    {
        public bool N, E, S, W, Ne, Se, Sw, Nw;
    }

    /// <summary>
    /// Decode a shape's four quadrant minitiles back into the 8-neighbor connectivity that produced
    /// it. Each quadrant's (col,row) encodes its two adjacent sides and diagonal (see class remarks);
    /// corners count only when their two sides are both present (blob rule), which the fill-quadrant
    /// minitile already reflects.
    /// </summary>
    public static Neighbors DecodeNeighbors(int shape)
    {
        int[][] t = FloorAutotileTable[shape];
        var n = new Neighbors();
        // TL -> (W, N, NW)
        DecodeQuad(t[0][0], t[0][1], out bool w1, out bool n1, out bool c1);
        // TR -> (N, E, NE)  columns 1/3, rows mirrored
        DecodeQuadTr(t[1][0], t[1][1], out bool n2, out bool e2, out bool c2);
        // BL -> (S, W, SW)
        DecodeQuadBl(t[2][0], t[2][1], out bool s3, out bool w3, out bool c3);
        // BR -> (S, E, SE)
        DecodeQuadBr(t[3][0], t[3][1], out bool s4, out bool e4, out bool c4);
        n.W = w1 || w3;
        n.N = n1 || n2;
        n.E = e2 || e4;
        n.S = s3 || s4;
        n.Nw = c1;
        n.Ne = c2;
        n.Sw = c3;
        n.Se = c4;
        return n;
    }

    // Explicit minitile -> (sideA, sideB, corner) lookups. Each quadrant of a block draws from a
    // fixed set of 6 minitiles (fill, inner-corner, two edges, outer-corner, and the isolated-art
    // corner used only by shape 47). key = col*10 + row.
    // TL quadrant -> (W, N, NW)
    private static void DecodeQuad(int col, int row, out bool w, out bool n, out bool nw)
    {
        switch (col * 10 + row)
        {
            case 24: w = true;  n = true;  nw = true;  return; // (2,4) fill
            case 20: w = true;  n = true;  nw = false; return; // (2,0) inner
            case 22: w = true;  n = false; nw = false; return; // (2,2) N-absent (top edge)
            case 4:  w = false; n = true;  nw = false; return; // (0,4) W-absent (left edge)
            case 2:  w = false; n = false; nw = false; return; // (0,2) outer
            default: w = false; n = false; nw = false; return; // (0,0) isolated
        }
    }

    // TR quadrant -> (N, E, NE)
    private static void DecodeQuadTr(int col, int row, out bool n, out bool e, out bool ne)
    {
        switch (col * 10 + row)
        {
            case 14: n = true;  e = true;  ne = true;  return; // (1,4) fill
            case 30: n = true;  e = true;  ne = false; return; // (3,0) inner
            case 12: n = false; e = true;  ne = false; return; // (1,2) top edge
            case 34: n = true;  e = false; ne = false; return; // (3,4) right edge
            case 32: n = false; e = false; ne = false; return; // (3,2) outer
            default: n = false; e = false; ne = false; return; // (1,0) isolated
        }
    }

    // BL quadrant -> (S, W, SW)
    private static void DecodeQuadBl(int col, int row, out bool s, out bool w, out bool sw)
    {
        switch (col * 10 + row)
        {
            case 23: s = true;  w = true;  sw = true;  return; // (2,3) fill
            case 21: s = true;  w = true;  sw = false; return; // (2,1) inner
            case 25: s = false; w = true;  sw = false; return; // (2,5) bottom edge
            case 3:  s = true;  w = false; sw = false; return; // (0,3) left edge
            case 5:  s = false; w = false; sw = false; return; // (0,5) outer
            default: s = false; w = false; sw = false; return; // (0,1) isolated
        }
    }

    // BR quadrant -> (S, E, SE)
    private static void DecodeQuadBr(int col, int row, out bool s, out bool e, out bool se)
    {
        switch (col * 10 + row)
        {
            case 13: s = true;  e = true;  se = true;  return; // (1,3) fill
            case 31: s = true;  e = true;  se = false; return; // (3,1) inner
            case 15: s = false; e = true;  se = false; return; // (1,5) bottom edge
            case 33: s = true;  e = false; se = false; return; // (3,3) right edge
            case 35: s = false; e = false; se = false; return; // (3,5) outer
            default: s = false; e = false; se = false; return; // (1,1) isolated
        }
    }

    /// <summary>Output tile coords (48px cells) of shape <paramref name="shape"/> for floor autotile
    /// <paramref name="indexInAtlas"/>.</summary>
    public static Vector2I TilePixel(int indexInAtlas, int shape)
    {
        int atX = (indexInAtlas % AutotilesPerRow) * AutotileTilesW;
        int atY = (indexInAtlas / AutotilesPerRow) * AutotileTilesH;
        int tx = atX + (shape % AutotileTilesW);
        int ty = atY + (shape / AutotileTilesW);
        return new Vector2I(tx, ty);
    }

    // ==============================================================================================
    // WALL-format autotiles (RPG Maker MZ A3 "buildings" + A4 wall faces)
    // ==============================================================================================
    public const int WallShapeCount = 16;
    public const int WallBlockPx = 96;      // 2x2 tiles
    public const int WallTilesPerBlock = 4; // 4x4 output grid per block
    public const int WallBlocksPerRow = 4;  // atlas is 4 blocks (768px) wide

    /// <summary>
    /// RPG Maker MV/MZ WALL_AUTOTILE_TABLE (16 combos). Verbatim from rpg_core Tilemap.js. Each combo
    /// is [TL,TR,BL,BR], quadrant [col,row] in 24px minitile units within the 4x4-minitile block.
    /// </summary>
    public static readonly int[][][] WallAutotileTable =
    {
        new[]{ new[]{2,2}, new[]{1,2}, new[]{2,1}, new[]{1,1} }, //0
        new[]{ new[]{0,2}, new[]{1,2}, new[]{0,1}, new[]{1,1} }, //1
        new[]{ new[]{2,0}, new[]{1,0}, new[]{2,1}, new[]{1,1} }, //2
        new[]{ new[]{0,0}, new[]{1,0}, new[]{0,1}, new[]{1,1} }, //3
        new[]{ new[]{2,2}, new[]{3,2}, new[]{2,1}, new[]{3,1} }, //4
        new[]{ new[]{0,2}, new[]{3,2}, new[]{0,1}, new[]{3,1} }, //5
        new[]{ new[]{2,0}, new[]{3,0}, new[]{2,1}, new[]{3,1} }, //6
        new[]{ new[]{0,0}, new[]{3,0}, new[]{0,1}, new[]{3,1} }, //7
        new[]{ new[]{2,2}, new[]{1,2}, new[]{2,3}, new[]{1,3} }, //8
        new[]{ new[]{0,2}, new[]{1,2}, new[]{0,3}, new[]{1,3} }, //9
        new[]{ new[]{2,0}, new[]{1,0}, new[]{2,3}, new[]{1,3} }, //10
        new[]{ new[]{0,0}, new[]{1,0}, new[]{0,3}, new[]{1,3} }, //11
        new[]{ new[]{2,2}, new[]{3,2}, new[]{2,3}, new[]{3,3} }, //12
        new[]{ new[]{0,2}, new[]{3,2}, new[]{0,3}, new[]{3,3} }, //13
        new[]{ new[]{2,0}, new[]{3,0}, new[]{2,3}, new[]{3,3} }, //14
        new[]{ new[]{0,0}, new[]{3,0}, new[]{0,3}, new[]{3,3} }, //15
    };

    /// <summary>
    /// Decode a wall combo's 4-side connectivity. Low four bits of the combo index are edge-exposed
    /// flags: bit0=left, bit1=top, bit2=right, bit3=bottom. A cleared bit means that side connects to
    /// the same terrain (Godot "match sides" peering; walls have no corner peering).
    /// </summary>
    public static Neighbors DecodeWallNeighbors(int combo)
    {
        return new Neighbors
        {
            W = (combo & 1) == 0,
            N = (combo & 2) == 0,
            E = (combo & 4) == 0,
            S = (combo & 8) == 0,
        };
    }

    /// <summary>Output tile coords (48px cells) of wall combo <paramref name="combo"/> for block
    /// <paramref name="blockIndex"/> in a wall atlas.</summary>
    public static Vector2I WallTilePixel(int blockIndex, int combo)
    {
        int bCol = blockIndex % WallBlocksPerRow;
        int bRow = blockIndex / WallBlocksPerRow;
        int tx = bCol * WallTilesPerBlock + combo % WallTilesPerBlock;
        int ty = bRow * WallTilesPerBlock + combo / WallTilesPerBlock;
        return new Vector2I(tx, ty);
    }

    // ==============================================================================================
    // Pre-expanded Winlu Godot-native sheets (NOT MZ-assembled)
    // ==============================================================================================
    //
    // Newer Winlu packs ship autotile sheets already expanded to Godot's terrain layout, so no MZ
    // quadrant assembly is needed — <see cref="TileSetBuilder"/> registers the sheet verbatim and only
    // needs the per-tile peering. These tables give the "same terrain" 8-neighbour set for each tile
    // of a pre-expanded block, derived by exact pixel-match against an MZ assembly (ground truth).
    //
    // FLOOR block = 12x4 used tiles (block-relative index = ir*12 + ic). Corners-and-sides mode; a
    // corner peers only when both its adjacent sides peer (blob rule). Index 22 is BLANK (no tile).
    // WALL block = 3x3 used tiles (match-sides; only the 9 shipped side-combos, no thin/end-cap art).
    // WALL-TOP block = 3x3 used tiles (corners-and-sides), so wall faces can be capped.

    /// <summary>Block-relative floor tile index (ir*12+ic) that is fully surrounded (the "fill" tile).</summary>
    public const int PreFloorFillIndex = 33;

    /// <summary>True for the one blank slot (index 22) in a pre-expanded 12x4 floor block.</summary>
    public static bool IsPreFloorBlank(int blockRelIndex) => blockRelIndex == 22;

    private static readonly string[] PreFloorSpec =
    {
        // row 0 (ir=0)
        "S", "E,S", "W,E,S", "W,S", "N,E,S,W,NW", "E,S,W,SE", "E,S,W,SW", "N,E,S,W,NE", "E,S,SE", "N,E,S,W,SE,SW", "E,S,W,SE,SW", "S,W,SW",
        // row 1 (ir=1)
        "N,S", "N,E,S", "N,E,S,W", "N,S,W", "N,E,S,SE", "N,E,S,W,NE,SE,SW", "N,E,S,W,SE,SW,NW", "N,S,W,SW", "N,E,S,NE,SE", "N,E,S,W,NE,SW", "", "N,E,S,W,SW,NW",
        // row 2 (ir=2)
        "N", "N,E", "N,E,W", "N,W", "N,E,S,NE", "N,E,S,W,NE,SE,NW", "N,E,S,W,NE,SW,NW", "N,S,W,NW", "N,E,S,W,NE,SE", "N,E,S,W,NE,SE,SW,NW", "N,E,S,W,SE,NW", "N,S,W,SW,NW",
        // row 3 (ir=3)
        "", "E", "E,W", "W", "N,E,S,W,SW", "N,E,W,NE", "N,E,W,NW", "N,E,S,W,SE", "N,E,NE", "N,E,W,NE,NW", "N,E,S,W,NE,NW", "N,W,NW",
    };

    // WALL side (match-sides), indexed ir*3+ic.
    private static readonly string[] PreWallSideSpec =
    {
        "E,S", "W,E,S", "W,S",
        "N,E,S", "W,N,E,S", "W,N,S",
        "N,E", "W,N,E", "W,N",
    };

    // WALL-TOP (corners-and-sides), indexed ir*3+ic.
    private static readonly string[] PreWallTopSpec =
    {
        "E,S,W,SE", "E,S,W,SE,SW", "E,S,W,SW",
        "N,E,S,W,NE,SE", "N,E,S,W,NE,SE,SW,NW", "N,E,S,W,SW,NW",
        "N,E,S,NE", "N,E,S,W,NE,NW", "N,S,W,NW",
    };

    private static Neighbors ParseNeighbors(string spec)
    {
        var n = new Neighbors();
        if (string.IsNullOrEmpty(spec)) return n;
        foreach (var tok in spec.Split(','))
        {
            switch (tok)
            {
                case "N": n.N = true; break;
                case "S": n.S = true; break;
                case "E": n.E = true; break;
                case "W": n.W = true; break;
                case "NE": n.Ne = true; break;
                case "NW": n.Nw = true; break;
                case "SE": n.Se = true; break;
                case "SW": n.Sw = true; break;
                default: throw new InvalidOperationException($"bad neighbor token '{tok}'");
            }
        }
        return n;
    }

    /// <summary>Peering for a pre-expanded FLOOR tile at block-relative index (ir*12+ic).</summary>
    public static Neighbors PreFloorNeighbors(int blockRelIndex) => ParseNeighbors(PreFloorSpec[blockRelIndex]);

    /// <summary>Peering for a pre-expanded WALL-face tile at block-relative (ic,ir) in the 3x3 block.</summary>
    public static Neighbors PreWallSideNeighbors(int ic, int ir) => ParseNeighbors(PreWallSideSpec[ir * 3 + ic]);

    /// <summary>Peering for a pre-expanded WALL-TOP tile at block-relative (ic,ir) in the 3x3 block.</summary>
    public static Neighbors PreWallTopNeighbors(int ic, int ir) => ParseNeighbors(PreWallTopSpec[ir * 3 + ic]);

    // ==============================================================================================
    // Pack catalog (data-driven)
    // ==============================================================================================

    public enum GenFormat { Floor, Wall }

    /// <summary>One generated autotile block. Carries pixel origin so A4 band offsets that are not on
    /// a clean block grid can be expressed directly. TerrainName / TerrainSetKey / Farmable are read
    /// by <see cref="TileSetBuilder"/>; <see cref="TerrainSetKey"/> is a per-pack logical key that the
    /// builder maps to a concrete terrain-set index.</summary>
    public sealed class GenAutotile
    {
        public required string AtlasKey;
        public required GenFormat Format;
        public required string SourcePng;   // res:// path
        public required int SrcPxX;
        public required int SrcPxY;
        public required int IndexInAtlas;   // floor: autotile index; wall: block index
        public required string TerrainName;
        public required string TerrainSetKey; // "" = plain (tiles only, no terrain); else a set key
        public bool Farmable = false;
    }

    /// <summary>A declarative vendored art pack: a set of autotile blocks to expand. Plain 1:1 sheets,
    /// collision / farmable / pair rules and the destination .tres live in <see cref="TileSetBuilder"/>
    /// output configs; here we only enumerate the autotile blocks each pack expands.</summary>
    public sealed class Pack
    {
        public required string Name;
        public required IReadOnlyList<GenAutotile> Autotiles;
    }

    public const string GenDir = "res://assets/tilesets/generated/";
    private const string ExtDir = "res://assets/tilesets/winlu_exterior/";
    private const string DDir = "res://assets/tilesets/winlu_destroyed/";
    private const string WDir = "res://assets/tilesets/winlu_winter/";
    private const string IDir = "res://assets/tilesets/winlu_interior/";
    private const string IDDir = "res://assets/tilesets/winlu_interior_destroyed/";
    private const string SwDir = "res://assets/tilesets/winlu_swamp/";
    private const string DunDir = "res://assets/tilesets/winlu_dungeon/";
    private const string MushDir = "res://assets/tilesets/winlu_mushroom/";
    private const string DesDir = "res://assets/tilesets/winlu_desert/";
    private const string OwDir = "res://assets/tilesets/winlu_overworld/";
    private const string OrcDir = "res://assets/tilesets/winlu_orc/";

    /// <summary>All packs. Adding a wave-2 pack = append a <see cref="Pack"/> here (+ an output config
    /// in <see cref="TileSetBuilder"/>).</summary>
    public static IReadOnlyList<Pack> Packs => _packs;

    /// <summary>Flattened autotile specs across every pack, grouped downstream by atlas key.</summary>
    public static IReadOnlyList<GenAutotile> AllGen => _allGen;

    private static readonly HashSet<(int, int)> FarmableBlocks = new() { (1, 0), (0, 1), (2, 1) };

    private static readonly List<Pack> _packs = BuildPacks();
    private static readonly List<GenAutotile> _allGen = _packs.SelectMany(p => p.Autotiles).ToList();

    private static List<Pack> BuildPacks() => new()
    {
        new Pack { Name = "outpost", Autotiles = BuildOutpostGen() },
        new Pack { Name = "winter",  Autotiles = BuildWinterGen() },
        new Pack { Name = "interior", Autotiles = BuildInteriorGen() },
        // --- wave-2 territory biomes (three independent tilesets) ---
        new Pack { Name = "swamp",    Autotiles = BuildSwampGen() },
        new Pack { Name = "dungeon",  Autotiles = BuildDungeonGen() },
        new Pack { Name = "mushroom", Autotiles = BuildMushroomGen() },
        // --- wave-3 territory biomes (desert combined ext+int, overworld, orc) ---
        new Pack { Name = "desert",    Autotiles = BuildDesertGen() },
        new Pack { Name = "overworld", Autotiles = BuildOverworldGen() },
        new Pack { Name = "orc",       Autotiles = BuildOrcGen() },
    };

    // --- outpost pack (MZ-expanded atlases still needed by the outpost .tres) ---
    //
    // The base/green/red A2 grounds, base A1 water, base A3 walls, base destroyed A3 and base A4
    // bands were retired when the outpost switched to Winlu's Godot-native PRE-EXPANDED sheets
    // (a2_terrain / a2_forest_terrain / a2_shadow / a1_liquids / a3_walls / a4_walls, wired directly
    // by <see cref="TileSetBuilder"/> as PreExpanded sources 200-216 — no MZ assembly). What remains
    // here is only what the outpost .tres still consumes as generated atlases: the RED A3 building
    // terrain (source 124, set 4) + its destroyed ruin counterpart (source 126), and the winter
    // terrains (built in <see cref="BuildWinterGen"/>). The green/red A4 band atlases stay
    // verification-only (unwired; their raw sheets are plain sources 92/103).
    private static List<GenAutotile> BuildOutpostGen()
    {
        var list = new List<GenAutotile>();

        // Red A3 buildings (wall format, 32 blocks: 8 cols x 4 rows) -> set 4; destroyed ruin pair.
        AddWallSheet(list, ExtDir + "red/fantasy_outside_a3_red.png", "wall_a3_red", "walls_red", "a3r", cols: 8, rows: 4);
        AddWallSheet(list, DDir + "fantasy_outside_a3_red_destroyed_raw.png", "wall_a3_red_destroyed", "", "a3rd", cols: 8, rows: 4);

        // Green/red A4 wall bands (verification-only; not wired to any terrain set — raw A4 sheets are
        // plain sources 92/103). The base A4 band expansion is retired in favour of pre-expanded a4_walls.
        AddA4Bands(list, ExtDir + "green/fantasy_outside_a4_green.png", "a4g");
        AddA4Bands(list, ExtDir + "red/fantasy_outside_a4_red.png", "a4r");

        return list;
    }

    // --- winter pack (seasonal variant of the outpost exterior; added to outpost_tileset.tres) ---
    private static List<GenAutotile> BuildWinterGen()
    {
        var list = new List<GenAutotile>();
        // Snow ground -> new terrain set "winter_ground". Farmable soil equivalently (season logic
        // gates winter farming, not tiles).
        AddFloorGround(list, WDir + "fantasy_outside_a2_snow.png", "ground_a2_snow", "winter_ground", "a2s", farmable: true);
        // Snow buildings (A3) -> new terrain set "winter_walls".
        AddWallSheet(list, WDir + "fantasy_outside_a3_snow.png", "wall_a3_snow", "winter_walls", "a3s", cols: 8, rows: 4);
        return list;
    }

    // --- interior pack (new interior_tileset.tres) ---
    private static List<GenAutotile> BuildInteriorGen()
    {
        var list = new List<GenAutotile>();
        // Floors: A2 left 4x4 (floor format) -> set "interior_floors". No farmable (interior).
        AddFloorGround(list, IDir + "fantasy_inside_a2.png", "floor_inside_a2", "interior_floors", "ia2", farmable: false);
        // Walls: A3 32 blocks (wall format) -> set "interior_walls".
        AddWallSheet(list, IDir + "fantasy_inside_a3.png", "wall_inside_a3", "interior_walls", "ia3", cols: 8, rows: 4);
        // A4 floor-pattern bands (parquet/tile/rug) -> set "interior_patterns". The A4 sheet (768x720)
        // is the standard 3-group / 240px-pitch layout, but every wall-FACE band (the lower 96px of each
        // group) is opaque-black filler (RGB 0,0,0) — only the 144px wall-TOP band of each group holds
        // real floor patterns, 8 across x 3 groups = 24 floor-format blocks. Expand just those tops as
        // floor terrains (block origins at SrcPxX=c*96, SrcPxY=g*240); skip the black face bands.
        var a4tops = new List<Vector2I>();
        for (int g = 0; g < 3; g++)
            for (int c = 0; c < 8; c++)
                a4tops.Add(new Vector2I(c * WallBlockPx, g * 240));
        AddFloorBlocks(list, IDir + "fantasy_inside_a4.png", "pattern_inside_a4", "interior_patterns", "pat", a4tops, farmable: false);
        // Destroyed floors: A2_destroyed left 4x4 (floor format) -> set "interior_floors_destroyed".
        // Same block layout as pristine floor_inside_a2, so the generated atlas is cell-for-cell with it
        // (ruin_pair wired in TileSetBuilder). No farmable (interior).
        AddFloorGround(list, IDDir + "fantasy_inside_a2_destroyed.png", "floor_inside_a2_destroyed", "interior_floors_destroyed", "ia2d", farmable: false);
        return list;
    }

    // --- swamp pack (Tier-2 territory; new swamp_tileset.tres) ---
    private static List<GenAutotile> BuildSwampGen()
    {
        var list = new List<GenAutotile>();
        // A2 left 4x4 ground autotiles (grass/dirt/stone) -> set "swamp_ground". Territories: no farmable.
        AddFloorGround(list, SwDir + "fantasy_outside_a2_swamp.png", "ground_a2_swamp", "swamp_ground", "sa2", farmable: false);
        // A1 top-left pond block (floor format) -> bog water terrain in the ground set (like the outpost).
        AddWaterPond(list, SwDir + "fantasy_outside_a1_swamp.png", "water_a1_swamp", "swamp_ground", "bog");
        return list;
    }

    // --- dungeon pack (Tier-3 caves; new dungeon_tileset.tres) ---
    private static List<GenAutotile> BuildDungeonGen()
    {
        var list = new List<GenAutotile>();
        // A2 left 4x4 cave-floor autotiles -> set "dungeon_ground".
        AddFloorGround(list, DunDir + "fantasy_dungeon_a2.png", "ground_a2_dungeon", "dungeon_ground", "da2", farmable: false);
        // A1 top-left pond block -> cave-water terrain (lava/waterfalls skipped; see README).
        AddWaterPond(list, DunDir + "fantasy_dungeon_a1.png", "water_a1_dungeon", "dungeon_ground", "cavewater");
        // A4 walls: 3 groups of wall-top(144px floor)+wall-face(96px wall) bands. The face band expands to
        // "wall_a4dun" (24 wall materials) which is wired as the Walls terrain set; wall-top band
        // ("walltop_a4dun") is generated but left plain (raw A4 is plain source in the builder).
        AddA4Bands(list, DunDir + "fantasy_dungeon_a4.png", "a4dun");
        return list;
    }

    // --- mushroom pack (Tier-3 caves variant; new mushroom_tileset.tres) ---
    private static List<GenAutotile> BuildMushroomGen()
    {
        var list = new List<GenAutotile>();
        // A2 left 4x4 ground autotiles (moss/dirt/cobble) -> set "mushroom_ground".
        AddFloorGround(list, MushDir + "fantasy_mushroom_a2.png", "ground_a2_mush", "mushroom_ground", "ma2", farmable: false);
        // A1 top-left pond block -> cave-water terrain (purple bog / waterfalls skipped; see README).
        AddWaterPond(list, MushDir + "fantasy_mushroom_a1.png", "water_a1_mush", "mushroom_ground", "mushwater");
        return list;
    }

    // --- desert pack (Tier-4 territory; ONE combined ext+int desert_tileset.tres) ---
    private static List<GenAutotile> BuildDesertGen()
    {
        var list = new List<GenAutotile>();
        // Exterior: A2 left 4x4 sand/brick/cobble ground -> set "ext_ground". Territories: no farmable.
        AddFloorGround(list, DesDir + "ext_fantasy_desert_a2.png", "ground_a2_desert", "ext_ground", "dea2", farmable: false);
        // Exterior A1 top-left pond -> desert oasis water in the ground set.
        AddWaterPond(list, DesDir + "ext_fantasy_desert_a1.png", "water_a1_desert", "ext_ground", "dewater");
        // Exterior A3: only the TOP 2 block-rows hold roof/building materials (rows 2-3 are opaque-black
        // filler). Expand those 16 roof materials as the "ext_roofs" match-sides set (roofs -> no collision).
        AddWallSheet(list, DesDir + "ext_fantasy_desert_a3.png", "roof_a3_desert", "ext_roofs", "dea3", cols: 8, rows: 2);
        // Interior (dungeon-like desert rooms, same resource): A2 floor patterns -> set "int_floors".
        AddFloorGround(list, DesDir + "int_fantasy_inside2_a2.png", "floor_a2_desert_int", "int_floors", "dia2", farmable: false);
        // Interior A1 top-left pool -> interior water in the floor set.
        AddWaterPond(list, DesDir + "int_fantasy_inside2_a1.png", "water_a1_desert_int", "int_floors", "diwater");
        // Interior A3: all 4 block-rows are wall material -> "int_walls" set (full collision).
        AddWallSheet(list, DesDir + "int_fantasy_inside2_a3.png", "wall_a3_desert_int", "int_walls", "dia3", cols: 8, rows: 4);
        return list;
    }

    // --- overworld pack (region/travel map; new overworld_tileset.tres) ---
    private static List<GenAutotile> BuildOverworldGen()
    {
        var list = new List<GenAutotile>();
        // A2 left 4x4 overworld terrain autotiles (grass/sand/rock/snow) -> set "world_ground".
        AddFloorGround(list, OwDir + "fantasy_world_a2.png", "ground_a2_world", "world_ground", "woa2", farmable: false);
        // A1 top-left ocean/water pond -> water terrain in the ground set.
        AddWaterPond(list, OwDir + "fantasy_world_a1.png", "water_a1_world", "world_ground", "wowater");
        return list;
    }

    // --- orc pack (enemy encampment set-pieces; new orc_tileset.tres) ---
    private static List<GenAutotile> BuildOrcGen()
    {
        var list = new List<GenAutotile>();
        // A2 left 4x4 grass/dirt/stone ground -> set "orc_ground".
        AddFloorGround(list, OrcDir + "fantasy_orc_a2.png", "ground_a2_orc", "orc_ground", "oca2", farmable: false);
        // A1 (green colorway) top-left pond -> water terrain (lava columns not expanded; art stays plain).
        AddWaterPond(list, OrcDir + "fantasy_orc_a1_green.png", "water_a1_orc", "orc_ground", "ocwater");
        // A3 wall materials sit in the BOTTOM 2 block-rows (top 2 rows are transparent) -> blockRowOffset 2.
        // 16 palisade/stone wall materials -> "orc_walls" set (full collision).
        AddWallSheet(list, OrcDir + "fantasy_orc_a3.png", "wall_a3_orc", "orc_walls", "oca3", cols: 8, rows: 2, blockRowOffset: 2);
        return list;
    }

    /// <summary>Expand a single floor-format pond block at the sheet's top-left (0,0) as one water
    /// terrain (mirrors the outpost's A1 water; animated columns/waterfalls/lava are not expanded).</summary>
    private static void AddWaterPond(List<GenAutotile> list, string png, string atlasKey, string setKey, string name)
    {
        list.Add(new GenAutotile
        {
            AtlasKey = atlasKey, Format = GenFormat.Floor, SourcePng = png,
            SrcPxX = 0, SrcPxY = 0, IndexInAtlas = 0, TerrainName = name, TerrainSetKey = setKey,
        });
    }

    private static void AddFloorGround(List<GenAutotile> list, string png, string atlasKey, string setKey, string prefix, bool farmable)
    {
        int index = 0;
        for (int row = 0; row < 4; row++)
            for (int col = 0; col < 4; col++)
            {
                list.Add(new GenAutotile
                {
                    AtlasKey = atlasKey, Format = GenFormat.Floor, SourcePng = png,
                    SrcPxX = col * BlockW, SrcPxY = row * BlockH, IndexInAtlas = index,
                    TerrainName = $"{prefix}_c{col}r{row}", TerrainSetKey = setKey,
                    Farmable = farmable && FarmableBlocks.Contains((col, row)),
                });
                index++;
            }
    }

    /// <summary>Expand an arbitrary list of floor-format blocks (explicit pixel origins) into one atlas.
    /// Used for floor-pattern sheets whose blocks are not a clean 4x4 grid (e.g. interior A4's 3x8
    /// wall-top pattern bands). Block index (list order) drives terrain-id allocation.</summary>
    private static void AddFloorBlocks(List<GenAutotile> list, string png, string atlasKey, string setKey, string prefix, IReadOnlyList<Vector2I> origins, bool farmable)
    {
        for (int i = 0; i < origins.Count; i++)
            list.Add(new GenAutotile
            {
                AtlasKey = atlasKey, Format = GenFormat.Floor, SourcePng = png,
                SrcPxX = origins[i].X, SrcPxY = origins[i].Y, IndexInAtlas = i,
                TerrainName = $"{prefix}_{i}", TerrainSetKey = setKey, Farmable = farmable,
            });
    }

    /// <param name="blockRowOffset">Skip this many 96px block-rows from the sheet top before reading
    /// (for sheets whose wall materials do not start at row 0, e.g. Orc A3's bottom-aligned walls).
    /// IndexInAtlas stays 0-based so the generated atlas packs only the populated blocks.</param>
    private static void AddWallSheet(List<GenAutotile> list, string png, string atlasKey, string setKey, string prefix, int cols, int rows, int blockRowOffset = 0)
    {
        int index = 0;
        for (int row = 0; row < rows; row++)
            for (int col = 0; col < cols; col++)
            {
                list.Add(new GenAutotile
                {
                    AtlasKey = atlasKey, Format = GenFormat.Wall, SourcePng = png,
                    SrcPxX = col * WallBlockPx, SrcPxY = (row + blockRowOffset) * WallBlockPx, IndexInAtlas = index,
                    TerrainName = $"{prefix}_c{col}r{row}", TerrainSetKey = setKey,
                });
                index++;
            }
    }

    // A4: 3 groups. Group g occupies pixel rows [g*240, g*240+240). First 144px = wall-top band
    // (floor blocks 2x3, 8 across), next 96px = wall-face band (wall blocks 2x2, 8 across).
    private static void AddA4Bands(List<GenAutotile> list, string png, string prefix)
    {
        int topIndex = 0, faceIndex = 0;
        for (int g = 0; g < 3; g++)
        {
            int topY = g * 240;
            int faceY = g * 240 + 144;
            for (int c = 0; c < 8; c++)
            {
                list.Add(new GenAutotile
                {
                    AtlasKey = "walltop_" + prefix, Format = GenFormat.Floor, SourcePng = png,
                    SrcPxX = c * WallBlockPx, SrcPxY = topY, IndexInAtlas = topIndex++,
                    TerrainName = $"{prefix}top_g{g}c{c}", TerrainSetKey = "walltops",
                });
                list.Add(new GenAutotile
                {
                    AtlasKey = "wall_" + prefix, Format = GenFormat.Wall, SourcePng = png,
                    SrcPxX = c * WallBlockPx, SrcPxY = faceY, IndexInAtlas = faceIndex++,
                    TerrainName = $"{prefix}face_g{g}c{c}", TerrainSetKey = "walls",
                });
            }
        }
    }

    // --- Generation -------------------------------------------------------------------------------

    public override void _Ready()
    {
        try
        {
            Run();
            GD.Print("[AutotileExpander] DONE");
        }
        catch (Exception e)
        {
            GD.PushError($"[AutotileExpander] FAILED: {e}");
            GD.Print($"[AutotileExpander] FAILED: {e.Message}");
        }
        GetTree().Quit();
    }

    private void Run()
    {
        SanityCheckTable();

        string genAbs = ProjectSettings.GlobalizePath(GenDir);
        DirAccess.MakeDirRecursiveAbsolute(genAbs);

        var srcCache = new Dictionary<string, Image>();
        ExpandAtlases(_allGen, srcCache);

        // Ground-truth validation: our WALL expansion of the raw destroyed-A3 must reproduce the
        // "Other_Engines" Godot expansion Winlu ships (the current source 114). The base destroyed-A3
        // validation is retired with the base A3 expansion (the outpost now uses pre-expanded a3_walls).
        ValidateAgainstShipped("wall_a3_red_destroyed.png", DDir + "fantasy_outside_a3_red_destroyed.png");

        // Contact sheets for eyeball verification (scaled, all < 1900px). The base A2/A3/A4 contact
        // sheets are retired with their MZ source sheets (pre-expanded sheets need no MZ assembly).
        // Wave-2 verification contact sheets.
        WriteContactSheetPx(srcCache, WDir + "fantasy_outside_a2_snow.png", 96, 0, "contact_a2_snow");  // winter dirt block
        WriteContactSheetPx(srcCache, IDir + "fantasy_inside_a2.png", 0, 0, "contact_inside_floor");    // interior floor block col0
        WriteWallContact(srcCache, IDir + "fantasy_inside_a3.png", 0, 0, "contact_inside_wall");        // interior wall block col0
        WriteContactSheetPx(srcCache, IDir + "fantasy_inside_a4.png", 0, 0, "contact_inside_pattern");  // interior A4 pattern g0c0 (walltop band)
        WriteContactSheetPx(srcCache, IDDir + "fantasy_inside_a2_destroyed.png", 0, 0, "contact_inside_floor_destroyed"); // destroyed floor block col0
        // Wave-2 territory-biome verification contact sheets (one ground each, + dungeon wall).
        WriteContactSheetPx(srcCache, SwDir + "fantasy_outside_a2_swamp.png", 96, 0, "contact_a2_swamp");   // swamp ground block col1
        WriteContactSheetPx(srcCache, DunDir + "fantasy_dungeon_a2.png", 0, 0, "contact_a2_dungeon");       // dungeon floor block col0
        WriteContactSheetPx(srcCache, MushDir + "fantasy_mushroom_a2.png", 0, 0, "contact_a2_mush");        // mushroom ground block col0
        WriteWallContact(srcCache, DunDir + "fantasy_dungeon_a4.png", 0, 144, "contact_a4_dungeon_face");   // A4 group0 wall-face block col0
        // Wave-3 verification contact sheets (desert ext+int, overworld, orc).
        WriteContactSheetPx(srcCache, DesDir + "ext_fantasy_desert_a2.png", 0, 0, "contact_a2_desert");         // desert ext ground block col0
        WriteWallContact(srcCache, DesDir + "ext_fantasy_desert_a3.png", 0, 0, "contact_a3_desert_roof");       // desert ext roof block col0
        WriteContactSheetPx(srcCache, DesDir + "int_fantasy_inside2_a2.png", 0, 0, "contact_a2_desert_int");    // desert int floor block col0
        WriteWallContact(srcCache, DesDir + "int_fantasy_inside2_a3.png", 0, 0, "contact_a3_desert_int_wall");  // desert int wall block col0
        WriteContactSheetPx(srcCache, OwDir + "fantasy_world_a2.png", 0, 0, "contact_a2_overworld");            // overworld ground block col0
        WriteContactSheetPx(srcCache, OrcDir + "fantasy_orc_a2.png", 0, 0, "contact_a2_orc");                   // orc ground block col0
        WriteWallContact(srcCache, OrcDir + "fantasy_orc_a3.png", 0, 192, "contact_a3_orc_wall");               // orc A3 bottom-row wall block col0
    }

    /// <summary>Expand every atlas in <paramref name="specs"/> (floor or wall format). Pack-agnostic.</summary>
    private void ExpandAtlases(IReadOnlyList<GenAutotile> specs, Dictionary<string, Image> srcCache)
    {
        var byAtlas = new Dictionary<string, List<GenAutotile>>();
        foreach (var s in specs)
        {
            if (!byAtlas.TryGetValue(s.AtlasKey, out var l)) byAtlas[s.AtlasKey] = l = new();
            l.Add(s);
        }

        foreach (var (atlasKey, group) in byAtlas)
        {
            bool wall = group[0].Format == GenFormat.Wall;
            int maxIndex = 0;
            foreach (var s in group) maxIndex = Math.Max(maxIndex, s.IndexInAtlas);

            int atlasW, atlasH;
            if (wall)
            {
                int blockRows = (maxIndex / WallBlocksPerRow) + 1;
                atlasW = WallBlocksPerRow * WallTilesPerBlock * TileSize; // 768
                atlasH = blockRows * WallTilesPerBlock * TileSize;
            }
            else
            {
                int rows = (maxIndex / AutotilesPerRow) + 1;
                atlasW = AutotilesPerRow * AutotileTilesW * TileSize; // 1152
                atlasH = rows * AutotileTilesH * TileSize;
            }
            var atlas = Image.CreateEmpty(atlasW, atlasH, false, Image.Format.Rgba8);

            foreach (var s in group)
            {
                Image src = LoadSource(srcCache, s.SourcePng);
                if (wall) ExpandWallBlock(src, s.SrcPxX, s.SrcPxY, atlas, s.IndexInAtlas);
                else ExpandBlock(src, s.SrcPxX, s.SrcPxY, atlas, s.IndexInAtlas);
            }

            string outAbs = ProjectSettings.GlobalizePath(GenDir + atlasKey + ".png");
            Error err = atlas.SavePng(outAbs);
            GD.Print($"[AutotileExpander] wrote {atlasKey}.png ({atlasW}x{atlasH}, {group.Count} {(wall ? "wall" : "floor")} blocks) err={err}");
        }
    }

    /// <summary>Assemble all 16 wall combos of one 96x96 block into the atlas at block index.</summary>
    private static void ExpandWallBlock(Image src, int blockPxX, int blockPxY, Image atlas, int blockIndex)
    {
        for (int combo = 0; combo < WallShapeCount; combo++)
        {
            int[][] quads = WallAutotileTable[combo];
            Vector2I tile = WallTilePixel(blockIndex, combo);
            int destX = tile.X * TileSize;
            int destY = tile.Y * TileSize;
            for (int i = 0; i < 4; i++)
            {
                var srcRect = new Rect2I(blockPxX + quads[i][0] * HalfTile, blockPxY + quads[i][1] * HalfTile, HalfTile, HalfTile);
                var dst = new Vector2I(destX + (i % 2) * HalfTile, destY + (i / 2) * HalfTile);
                atlas.BlitRect(src, srcRect, dst);
            }
        }
    }

    /// <summary>Pixel-diff a freshly generated atlas against a shipped reference of identical size.</summary>
    private void ValidateAgainstShipped(string generatedName, string shippedRes)
    {
        string genAbs = ProjectSettings.GlobalizePath(GenDir + generatedName);
        string refAbs = ProjectSettings.GlobalizePath(shippedRes);
        var a = Image.LoadFromFile(genAbs);
        var b = Image.LoadFromFile(refAbs);
        if (a == null || b == null) { GD.Print($"[AutotileExpander] VALIDATE {generatedName}: could not load pair"); return; }
        if (a.GetFormat() != Image.Format.Rgba8) a.Convert(Image.Format.Rgba8);
        if (b.GetFormat() != Image.Format.Rgba8) b.Convert(Image.Format.Rgba8);
        if (a.GetWidth() != b.GetWidth() || a.GetHeight() != b.GetHeight())
        {
            GD.Print($"[AutotileExpander] VALIDATE {generatedName}: SIZE MISMATCH {a.GetWidth()}x{a.GetHeight()} vs {b.GetWidth()}x{b.GetHeight()}");
            return;
        }
        long diff = 0, maxd = 0;
        for (int y = 0; y < a.GetHeight(); y++)
            for (int x = 0; x < a.GetWidth(); x++)
            {
                Color ca = a.GetPixel(x, y), cb = b.GetPixel(x, y);
                int d = Math.Abs((int)(ca.R8 - cb.R8)) + Math.Abs((int)(ca.G8 - cb.G8)) +
                        Math.Abs((int)(ca.B8 - cb.B8)) + Math.Abs((int)(ca.A8 - cb.A8));
                if (d != 0) { diff++; if (d > maxd) maxd = d; }
            }
        double pct = 100.0 * diff / (a.GetWidth() * (double)a.GetHeight());
        GD.Print($"[AutotileExpander] VALIDATE {generatedName} vs shipped: diffPixels={diff} ({pct:F3}%) maxChannelSum={maxd}");
    }

    private Image LoadSource(Dictionary<string, Image> cache, string resPath)
    {
        if (cache.TryGetValue(resPath, out var img)) return img;
        string abs = ProjectSettings.GlobalizePath(resPath);
        img = Image.LoadFromFile(abs);
        if (img == null) throw new InvalidOperationException($"could not load {abs}");
        if (img.GetFormat() != Image.Format.Rgba8) img.Convert(Image.Format.Rgba8);
        cache[resPath] = img;
        return img;
    }

    /// <summary>Assemble all 48 shapes of one block into the atlas at the given autotile index.</summary>
    private static void ExpandBlock(Image src, int blockPxX, int blockPxY, Image atlas, int indexInAtlas)
    {
        for (int shape = 0; shape < ShapeCount; shape++)
        {
            int[][] quads = FloorAutotileTable[shape];
            Vector2I tile = TilePixel(indexInAtlas, shape);
            int destX = tile.X * TileSize;
            int destY = tile.Y * TileSize;
            for (int i = 0; i < 4; i++)
            {
                int qsx = quads[i][0];
                int qsy = quads[i][1];
                var srcRect = new Rect2I(blockPxX + qsx * HalfTile, blockPxY + qsy * HalfTile, HalfTile, HalfTile);
                var dst = new Vector2I(destX + (i % 2) * HalfTile, destY + (i / 2) * HalfTile);
                atlas.BlitRect(src, srcRect, dst);
            }
        }
    }

    /// <summary>Floor contact sheet from an explicit source pixel origin (48 shapes, 8x6, 4x scale).</summary>
    private void WriteContactSheetPx(Dictionary<string, Image> cache, string res, int srcPxX, int srcPxY, string name)
    {
        Image src = LoadSource(cache, res);
        var tiles = Image.CreateEmpty(8 * TileSize, 6 * TileSize, false, Image.Format.Rgba8);
        for (int shape = 0; shape < ShapeCount; shape++)
        {
            int[][] quads = FloorAutotileTable[shape];
            int destX = (shape % 8) * TileSize;
            int destY = (shape / 8) * TileSize;
            for (int i = 0; i < 4; i++)
            {
                var srcRect = new Rect2I(srcPxX + quads[i][0] * HalfTile, srcPxY + quads[i][1] * HalfTile, HalfTile, HalfTile);
                tiles.BlitRect(src, srcRect, new Vector2I(destX + (i % 2) * HalfTile, destY + (i / 2) * HalfTile));
            }
        }
        tiles.Resize(tiles.GetWidth() * 4, tiles.GetHeight() * 4, Image.Interpolation.Nearest);
        tiles.SavePng(ProjectSettings.GlobalizePath(GenDir + name + ".png"));
        GD.Print($"[AutotileExpander] wrote contact sheet {name}.png");
    }

    /// <summary>Wall contact sheet: 16 combos of one 96x96 block, laid 4x4, 8x scale.</summary>
    private void WriteWallContact(Dictionary<string, Image> cache, string res, int srcPxX, int srcPxY, string name)
    {
        Image src = LoadSource(cache, res);
        var tiles = Image.CreateEmpty(4 * TileSize, 4 * TileSize, false, Image.Format.Rgba8);
        for (int combo = 0; combo < WallShapeCount; combo++)
        {
            int[][] quads = WallAutotileTable[combo];
            int destX = (combo % 4) * TileSize;
            int destY = (combo / 4) * TileSize;
            for (int i = 0; i < 4; i++)
            {
                var srcRect = new Rect2I(srcPxX + quads[i][0] * HalfTile, srcPxY + quads[i][1] * HalfTile, HalfTile, HalfTile);
                tiles.BlitRect(src, srcRect, new Vector2I(destX + (i % 2) * HalfTile, destY + (i / 2) * HalfTile));
            }
        }
        tiles.Resize(tiles.GetWidth() * 8, tiles.GetHeight() * 8, Image.Interpolation.Nearest);
        tiles.SavePng(ProjectSettings.GlobalizePath(GenDir + name + ".png"));
        GD.Print($"[AutotileExpander] wrote wall contact sheet {name}.png");
    }

    /// <summary>Assert the decode round-trips the two anchor shapes (interior all-set, isolated none-set).</summary>
    private static void SanityCheckTable()
    {
        var full = DecodeNeighbors(0);
        if (!(full.N && full.E && full.S && full.W && full.Ne && full.Se && full.Sw && full.Nw))
            throw new InvalidOperationException("shape 0 (interior) should decode to all-8 neighbors set");
        var iso = DecodeNeighbors(47);
        if (iso.N || iso.E || iso.S || iso.W || iso.Ne || iso.Se || iso.Sw || iso.Nw)
            throw new InvalidOperationException("shape 47 (isolated) should decode to no neighbors set");

        // Pre-expanded peering anchors: floor fill = all 8; wall-face centre = all 4 sides; wall-top
        // centre = all 8.
        var ff = PreFloorNeighbors(PreFloorFillIndex);
        if (!(ff.N && ff.E && ff.S && ff.W && ff.Ne && ff.Se && ff.Sw && ff.Nw))
            throw new InvalidOperationException("pre-expanded floor fill (index 33) should peer all 8");
        var wf = PreWallSideNeighbors(1, 1);
        if (!(wf.N && wf.E && wf.S && wf.W))
            throw new InvalidOperationException("pre-expanded wall-face centre (1,1) should peer all 4 sides");
        var wt = PreWallTopNeighbors(1, 1);
        if (!(wt.N && wt.E && wt.S && wt.W && wt.Ne && wt.Se && wt.Sw && wt.Nw))
            throw new InvalidOperationException("pre-expanded wall-top centre (1,1) should peer all 8");
        GD.Print("[AutotileExpander] table sanity check passed");
    }
}
