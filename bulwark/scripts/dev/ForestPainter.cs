using System;
using System.Collections.Generic;
using Godot;

namespace Bulwark.Dev;

/// <summary>
/// ONE-SHOT headless painter that renders the Tier-1 forest territory as a finished, hand-painted-
/// looking scene and saves it as <c>scenes/territory/forest.tscn</c> via PackedScene.Pack (repo
/// convention: never hand-roll tile_map_data bytes). Replaces the throwaway blockout with:
/// a winding south-entry dirt trail, forest-floor litter/moss patches, an organic pond, a dense
/// staggered tree-line perimeter (hidden colliding B-sheet ring fully covered by opaque canopy),
/// interior groves, a giant landmark tree over the central clearing, decor scatter, and all the
/// functional nodes (PlayerSpawn / ExitTrigger / Node_* / Roamer_* markers driven by
/// Bulwark.Data.Territories.Forest) plus the hd2d/cloud/leaves ambiance instances.
///
/// Deterministic: a fixed-seed System.Random drives every scatter decision, so re-runs are stable.
/// Re-running OVERWRITES forest.tscn — tune constants here, not in the editor, until sign-off.
///   G:\Godot\Godot_v4.6.2-stable_mono_win64\Godot_v4.6.2-stable_mono_win64.exe --headless \
///     --path bulwark res://scenes/dev/forest_painter.tscn
/// </summary>
public partial class ForestPainter : Node
{
    private const string TilesetPath = "res://assets/tilesets/outpost_tileset.tres";
    private const string OutPath = "res://scenes/territory/forest.tscn";
    private const int Cell = 48;
    private const int MapW = 64;
    private const int MapH = 36;

    // Terrain set 0 contract (README "Terrain sets"): grass=0, dirt=1. Forest floor / shadow /
    // liquid indices are PROBED from the tileset at runtime (see ProbeTerrains) — never assumed.
    private const int GrassTerrain = 0;
    private const int DirtTerrain = 1;

    // Atlas sources (assets/tilesets/README.md).
    private const int SrcB = 11;          // fantasy_outside_b — right-half cells carry collision
    private const int SrcTreesNoShadow = 59; // big_trees_noshadow — tree stamps (shadow painted as terrain)
    private const int SrcD = 13;          // fantasy_outside_d_noshadow — trees, stumps, rocks, logs
    private const int SrcGiantTree = 66;  // giant_tree_no_glowing — landmark
    private const int SrcDecor = 23;      // campfire / torch frames
    private const int SrcVeg = 24;        // flowers / tufts / mushrooms singles
    private const int SrcForestFloor = 201;
    private const int SrcShadow = 202;
    private const int SrcLiquids = 203;

    private static readonly Vector2I RingTile = new(9, 1); // opaque colliding B-sheet cell

    // South trail corridor (band + ring gap). ExitTrigger sits at cell x=32,y=34.
    private const int GapX0 = 29, GapX1 = 34;

    private TileSet _ts = null!;
    private TileMapLayer _ground = null!, _groundDecor = null!, _walls = null!;
    private TileMapLayer _props = null!, _overhead = null!, _overheadDecor = null!, _overheadAccent = null!;
    private readonly Random _rng = new(20260715);
    private readonly Dictionary<int, Image> _images = new();
    private readonly Dictionary<(int, Vector2I), float> _opacity = new();

    private int _tLitter, _tMoss, _tShadow, _tWater;

    private readonly HashSet<Vector2I> _water = new();
    private readonly HashSet<Vector2I> _trail = new();
    private readonly HashSet<Vector2I> _band = new();
    private readonly HashSet<Vector2I> _blocked = new();   // walls+props base cells
    private readonly HashSet<Vector2I> _prefabTrunks = new(); // baked tree-prefab trunk-base cells
    private readonly HashSet<Vector2I> _shadowCells = new();
    private readonly List<Vector2I> _treeAnchors = new();
    private int _treeCounter;

    private double[] _depthN = null!, _depthS = null!, _depthW = null!, _depthE = null!;

    // ------------------------------------------------------------------ stamp catalog

    private readonly record struct Stamp(int Src, int X0, int Y0, int X1, int Y1, int BaseFrom, int AnchorX, int AnchorY);

    // Trees: rows >= BaseFrom go to Walls (collide via wall-baker), rest to Overhead.
    private static readonly Dictionary<string, Stamp> Tree = new()
    {
        ["round"] = new(SrcTreesNoShadow, 8, 6, 11, 11, 10, 9, 11),
        ["pineT"] = new(SrcTreesNoShadow, 8, 0, 11, 5, 5, 9, 5),
        ["pineS"] = new(SrcTreesNoShadow, 4, 6, 7, 10, 10, 5, 10),
        ["bush"] = new(SrcTreesNoShadow, 0, 9, 3, 11, 9, 1, 11),
        ["orange"] = new(SrcTreesNoShadow, 8, 12, 11, 17, 16, 9, 17),
        ["orangeW"] = new(SrcTreesNoShadow, 4, 12, 7, 17, 16, 5, 17),
        ["pink"] = new(SrcTreesNoShadow, 8, 18, 11, 23, 22, 9, 23),
        ["pinkW"] = new(SrcTreesNoShadow, 4, 18, 7, 23, 22, 5, 23),
        ["pineR"] = new(SrcTreesNoShadow, 0, 18, 3, 23, 23, 1, 23),
        ["med"] = new(SrcD, 0, 0, 2, 2, 2, 1, 2),
        ["curvy"] = new(SrcD, 4, 2, 7, 6, 5, 5, 6),
        ["giant"] = new(SrcGiantTree, 26, 0, 38, 11, 9, 32, 11),
    };

    // Interior/grove trees are baked as PLACED RESOURCE-NODE PREFAB INSTANCES (design/forage.md):
    // real choppable nodes, editable in the editor, save identity = territory id + node name
    // (tree_01…). The perimeter band trees STAY tile stamps — scenery/collision, not choppable.
    private static readonly Dictionary<string, string> TreePrefabs = new()
    {
        ["round"] = "res://scenes/territory/nodes/tree_round.tscn",
        ["pineT"] = "res://scenes/territory/nodes/tree_pine_tall.tscn",
        ["pineS"] = "res://scenes/territory/nodes/tree_pine_small.tscn",
        ["orange"] = "res://scenes/territory/nodes/tree_autumn.tscn",
        ["pink"] = "res://scenes/territory/nodes/tree_pink.tscn",
        ["med"] = "res://scenes/territory/nodes/tree_med.tscn",
        ["curvy"] = "res://scenes/territory/nodes/tree_curvy.tscn",
    };

    // Trunk-less full-canopy domes for the perimeter fringe (all cells to OverheadDecor). Unlike
    // canopy-TOP crops (rounded up, flat-cut down — the source of the old straight seams), these
    // are rounded on ALL four sides, so anchoring is orientation-free. CX0..CX1 / CY0..CY1 mark the
    // near-fully-opaque core cells that must land on the covered boundary cell.
    private readonly record struct Dome(int Src, int X0, int Y0, int X1, int Y1, int CX0, int CX1, int CY0, int CY1);

    private static readonly Dome[] FringeDomes =
    {
        new(SrcTreesNoShadow, 0, 9, 3, 11, 1, 2, 10, 10), // green bush dome 4x3
        new(SrcD, 0, 9, 4, 12, 1, 3, 10, 11),             // big leafy dome 5x4
    };

    private static readonly Dome AccentDome =
        new(SrcTreesNoShadow, 0, 15, 3, 17, 1, 2, 16, 16); // autumn dome 4x3

    // Props (rocks/logs/stumps/fire): everything to Props (y-sorted, no collision — low objects).
    private static readonly Dictionary<string, Stamp> Prop = new()
    {
        ["boulderA"] = new(SrcD, 8, 5, 8, 5, 0, 8, 5),
        ["boulderB"] = new(SrcD, 9, 5, 9, 6, 0, 9, 6),
        ["boulderC"] = new(SrcD, 10, 5, 10, 5, 0, 10, 5),
        ["rockLow"] = new(SrcD, 10, 6, 10, 6, 0, 10, 6),
        ["pebbles"] = new(SrcD, 11, 5, 11, 5, 0, 11, 5),
        ["slab"] = new(SrcD, 11, 4, 12, 4, 0, 11, 4),
        ["slabBig"] = new(SrcD, 9, 4, 10, 4, 0, 9, 4),
        ["logBroken"] = new(SrcD, 11, 6, 11, 6, 0, 11, 6),
        ["logVert"] = new(SrcD, 12, 5, 12, 6, 0, 12, 6),
        ["logShroom"] = new(SrcD, 13, 5, 13, 6, 0, 13, 6),
        ["logHollow"] = new(SrcD, 14, 5, 15, 5, 0, 14, 5),
        ["logDiag"] = new(SrcD, 14, 6, 15, 7, 0, 14, 7),
        ["logMossy"] = new(SrcD, 14, 4, 15, 4, 0, 14, 4),
        // NOTE: the stumps live in COLUMN 4 of the D sheet — column 3 is the med tree's foliage
        // overflow (placing (3,0)/(3,1) painted orphan canopy cells in the open field).
        ["stumpTop"] = new(SrcD, 4, 0, 4, 0, 0, 4, 0),
        ["stumpLogs"] = new(SrcD, 4, 1, 4, 1, 0, 4, 1),
        ["stumpBirch"] = new(SrcD, 3, 14, 4, 15, 0, 3, 15),
        ["campfire"] = new(SrcDecor, 6, 2, 6, 3, 0, 6, 3),
        ["torch"] = new(SrcDecor, 9, 2, 9, 3, 0, 9, 3),
    };

    // GroundDecor scatter singles (source, atlas coords picked from the sheets).
    private static readonly Vector2I[] TuftTiles = { new(0, 11), new(1, 11), new(2, 11), new(3, 11), new(4, 11), new(5, 11) };
    private static readonly Vector2I[] SpikyTiles = { new(0, 13), new(1, 13), new(2, 13), new(3, 13), new(4, 13), new(5, 13) };
    private static readonly Vector2I[] YellowFlowerTiles = { new(3, 1), new(4, 1), new(5, 1), new(6, 1), new(7, 1), new(8, 1) };
    private static readonly Vector2I[] BlueFlowerTiles = { new(0, 1), new(1, 1), new(2, 1) };
    private static readonly Vector2I[] RedFlowerTiles = { new(3, 3), new(4, 3), new(5, 3), new(1, 3) };
    private static readonly Vector2I[] MushroomTiles = { new(9, 9), new(10, 9), new(11, 9), new(9, 15), new(10, 15), new(11, 15), new(10, 13) };
    private static readonly Vector2I[] HerbTiles = { new(0, 7), new(2, 7), new(4, 7), new(0, 9), new(2, 9) };
    private static readonly Vector2I[] FernTilesD = { new(9, 7), new(10, 7), new(11, 7) }; // source 13
    private static readonly Vector2I[] ReedTilesD = { new(12, 7), new(13, 7) };            // source 13

    // Giant-tree interior canopy cells — perimeter band fill (validated fully opaque at runtime).
    private static readonly Vector2I[] FillCandidates =
    {
        new(16, 3), new(17, 3), new(18, 3), new(19, 3), new(20, 3),
        new(16, 4), new(17, 4), new(18, 4), new(19, 4), new(20, 4), new(21, 4),
        new(17, 5), new(18, 5), new(19, 5),
    };
    private readonly List<Vector2I> _fillTiles = new();

    // ------------------------------------------------------------------ layout: functional cells

    private static readonly Dictionary<string, Vector2I> NodeCells = new()
    {
        ["rock_1"] = new Vector2I(18, 7),
        ["rock_2"] = new Vector2I(52, 8),
        ["rock_3"] = new Vector2I(44, 27),
        ["herb_1"] = new Vector2I(10, 12),
        ["herb_2"] = new Vector2I(37, 14),
        ["berry_1"] = new Vector2I(9, 26),
        ["berry_2"] = new Vector2I(24, 6),
        ["berry_3"] = new Vector2I(55, 19),
        ["wood_1"] = new Vector2I(15, 18),
        ["wood_2"] = new Vector2I(47, 29),
    };

    private static readonly Dictionary<string, Vector2I> RoamerCells = new()
    {
        ["gob_1"] = new Vector2I(21, 10),
        ["gob_2"] = new Vector2I(45, 11),
        ["gob_3"] = new Vector2I(33, 21),
        ["gob_4"] = new Vector2I(12, 28),
        ["gob_5"] = new Vector2I(51, 25),
    };

    // Interior trees: (variant, trunk-base cell).
    private static readonly (string V, int X, int Y)[] InteriorTrees =
    {
        // west grove (around wood_1 / pond south)
        ("round", 9, 16), ("pineS", 13, 14), ("med", 12, 19), ("curvy", 17, 21), ("round", 15, 23),
        // north-center stand (west of the giant tree)
        ("pineT", 20, 8), ("round", 24, 11), ("med", 21, 13), ("pineS", 26, 14),
        // northeast grove (around gob_2 / rock_2)
        ("curvy", 44, 7), ("round", 47, 9), ("pineS", 50, 7), ("orange", 49, 13),
        // mid-east stand
        ("round", 41, 13), ("pineT", 45, 15), ("med", 40, 19),
        // southwest grove (around gob_4)
        ("round", 20, 27), ("pineS", 23, 30), ("med", 17, 26), ("curvy", 20, 23),
        // southeast grove (around wood_2)
        ("round", 43, 30), ("pineT", 47, 32), ("med", 51, 29), ("round", 54, 31),
        // east accent pair near berry_3
        ("pink", 54, 17), ("round", 57, 22),
        // loners breaking sightlines
        ("med", 36, 28), ("round", 39, 31), ("pineS", 8, 22), ("round", 7, 28),
        ("pineS", 57, 13), ("med", 6, 17),
    };

    private static readonly (int X, int Y)[] Bushes =
    {
        (18, 10), (42, 18), (12, 25), (52, 21), (46, 19),
    };

    // Perimeter trees: trunks just inside the band so the tree-line reads as trees, not a hedge.
    private static readonly (string V, int X, int Y)[] PerimeterTrees =
    {
        ("pineT", 6, 5), ("round", 14, 5), ("med", 22, 4), ("curvy", 45, 5), ("round", 52, 5), ("pineT", 59, 6),
        ("round", 4, 11), ("pineT", 5, 19), ("round", 4, 27),
        ("pineT", 59, 12), ("round", 58, 20), ("pineT", 60, 28),
        ("round", 6, 32), ("pineT", 14, 33), ("round", 22, 32), ("round", 40, 33), ("pineT", 48, 32), ("round", 56, 33),
        // exit corridor flanks
        ("round", 28, 34), ("med", 36, 33),
    };

    private static readonly (string P, int X, int Y)[] PropsPlaced =
    {
        ("boulderB", 20, 6), ("boulderA", 53, 10), ("slab", 42, 26), ("boulderC", 8, 18),
        ("logDiag", 24, 19), ("logShroom", 16, 20), ("logHollow", 13, 21), ("logVert", 46, 31),
        ("stumpBirch", 13, 17), ("stumpTop", 35, 18), ("stumpLogs", 23, 28), ("logBroken", 41, 21),
        ("logMossy", 34, 15), ("rockLow", 30, 30), ("pebbles", 29, 27), ("pebbles", 33, 23),
        ("pebbles", 26, 21), ("slabBig", 14, 10), ("boulderC", 47, 21), ("stumpTop", 10, 30),
        ("logBroken", 55, 27), ("rockLow", 50, 16), ("campfire", 31, 16), ("stumpLogs", 30, 15),
        ("torch", 30, 33), ("torch", 34, 33),
    };

    // Clearings kept free of trunks and heavy scatter: (cx, cy, rx, ry).
    private static readonly (double X, double Y, double Rx, double Ry)[] Clearings =
    {
        (33, 17, 6.5, 4.2),   // central (campfire + giant tree landmark)
        (48, 25, 4.5, 3.2),   // secondary (fork destination)
        (32, 32, 3.5, 2.6),   // spawn pocket
    };

    // ------------------------------------------------------------------ entry

    public override void _Ready()
    {
        try
        {
            // RETIRED: forest.tscn is hand-maintained now (2026-07). Re-running would wipe the
            // user's edits and every placed node prefab. Same guard as TerritoryBlockoutBuilder:
            // only "-- --force" after the scene file is deleted/renamed makes sense, and even then
            // think twice — fold changes into the editor scene instead.
            bool force = System.Array.IndexOf(OS.GetCmdlineUserArgs(), "--force") >= 0;
            if (Godot.FileAccess.FileExists(OutPath) && !force)
            {
                GD.Print($"[ForestPainter] REFUSED: {OutPath} exists and is hand-maintained. " +
                         "This painter is retired; pass '-- --force' only if you truly mean to repaint from scratch.");
                GetTree().Quit(1);
                return;
            }

            Build();
            GD.Print("[ForestPainter] DONE");
        }
        catch (Exception e)
        {
            GD.PushError($"[ForestPainter] FAILED: {e}");
            GD.Print($"[ForestPainter] FAILED: {e.Message}\n{e.StackTrace}");
            GetTree().Quit(1);
            return;
        }
        GetTree().Quit();
    }

    private void Build()
    {
        _ts = GD.Load<TileSet>(TilesetPath) ?? throw new InvalidOperationException("could not load tileset");
        ProbeTerrains();
        ValidateFillTiles();

        // Y-sorted root: the baked tree prefabs (z=5, origin at the trunk base) must sort against
        // the player (z=5) so canopies draw over the player standing behind a tree.
        var root = new Bulwark.Territory.ForestScene { Name = "Forest", YSortEnabled = true };
        _ground = MakeLayer(root, "Ground", 0, false);
        _groundDecor = MakeLayer(root, "GroundDecor", 0, false);
        _walls = MakeLayer(root, "Walls", 0, true);
        _props = MakeLayer(root, "Props", 0, true);
        _overhead = MakeLayer(root, "Overhead", 10, true);
        _overheadDecor = MakeLayer(root, "OverheadDecor", 10, true);
        _overheadAccent = MakeLayer(root, "OverheadAccent", 10, true);

        BuildBandContours();
        PaintGround();
        PaintPerimeterRing();
        PaintBandFill();
        StampGiantTree();
        StampTrees(root);
        StampFringe();
        PaintShadows();
        StampProps();
        ScatterDecor();
        AddFunctionalNodes(root);
        AddFx(root);
        Validate();

        var packed = new PackedScene();
        Error perr = packed.Pack(root);
        if (perr != Error.Ok) throw new InvalidOperationException($"pack failed: {perr}");
        Error serr = ResourceSaver.Save(packed, OutPath);
        if (serr != Error.Ok) throw new InvalidOperationException($"save failed: {serr}");
        GD.Print($"[ForestPainter] saved {OutPath}: ground={_ground.GetUsedCells().Count} decor={_groundDecor.GetUsedCells().Count} " +
                 $"walls={_walls.GetUsedCells().Count} props={_props.GetUsedCells().Count} " +
                 $"overhead={_overhead.GetUsedCells().Count} overheadDecor={_overheadDecor.GetUsedCells().Count} " +
                 $"overheadAccent={_overheadAccent.GetUsedCells().Count}");
    }

    // ------------------------------------------------------------------ terrain probing

    /// <summary>Resolve forest-floor / shadow / water terrain ids by probing known fill tiles
    /// (block-relative index 33 = fully-surrounded fill at ir=2,ic=9) instead of trusting math.</summary>
    private void ProbeTerrains()
    {
        _tLitter = ProbeTerrain(SrcForestFloor, new Vector2I(13 + 9, 2)); // forest block (1,0) — leaf litter
        _tMoss = ProbeTerrain(SrcForestFloor, new Vector2I(13 + 9, 7));   // forest block (1,1) — green mottled moss
                                                                          // (block (2,0)'s near-black borders read as holes)
        _tShadow = ProbeTerrain(SrcShadow, new Vector2I(9, 2));
        _tWater = ProbeTerrain(SrcLiquids, new Vector2I(9, 2));           // liquid block row 0 — pond water
        GD.Print($"[ForestPainter] terrains: grass={GrassTerrain}('{_ts.GetTerrainName(0, GrassTerrain)}') " +
                 $"dirt={DirtTerrain}('{_ts.GetTerrainName(0, DirtTerrain)}') litter={_tLitter}('{_ts.GetTerrainName(0, _tLitter)}') " +
                 $"moss={_tMoss}('{_ts.GetTerrainName(0, _tMoss)}') shadow={_tShadow}('{_ts.GetTerrainName(0, _tShadow)}') " +
                 $"water={_tWater}('{_ts.GetTerrainName(0, _tWater)}') of {_ts.GetTerrainsCount(0)} in set 0");
    }

    private int ProbeTerrain(int srcId, Vector2I coords)
    {
        if (_ts.GetSource(srcId) is not TileSetAtlasSource src || !src.HasTile(coords))
            throw new InvalidOperationException($"probe tile missing: source {srcId} at {coords}");
        TileData td = src.GetTileData(coords, 0);
        if (td.TerrainSet != 0 || td.Terrain < 0)
            throw new InvalidOperationException($"probe tile source {srcId} {coords} not on terrain set 0");
        return td.Terrain;
    }

    private void ValidateFillTiles()
    {
        foreach (Vector2I c in FillCandidates)
            if (Opacity(SrcGiantTree, c) >= 0.985f)
                _fillTiles.Add(c);
        if (_fillTiles.Count < 3)
            throw new InvalidOperationException($"only {_fillTiles.Count} opaque canopy fill tiles — band would leak");
        GD.Print($"[ForestPainter] canopy fill tiles: {_fillTiles.Count}/{FillCandidates.Length} fully opaque");
    }

    // ------------------------------------------------------------------ ground

    private void BuildBandContours()
    {
        _depthN = Contour(MapW);
        _depthS = Contour(MapW);
        _depthW = Contour(MapH);
        _depthE = Contour(MapH);
        for (int y = 0; y < MapH; y++)
            for (int x = 0; x < MapW; x++)
                if (InBand(x, y, 0))
                    _band.Add(new Vector2I(x, y));
    }

    /// <summary>Smoothed 2.0–4.2 cell tree-line depth along one edge (control point every 8 cells).</summary>
    private double[] Contour(int len)
    {
        int n = len / 8 + 2;
        var ctrl = new double[n];
        for (int i = 0; i < n; i++) ctrl[i] = 2.0 + _rng.NextDouble() * 2.2;
        var line = new double[len];
        for (int i = 0; i < len; i++)
        {
            double t = i / 8.0;
            int i0 = (int)t;
            double f = t - i0;
            f = f * f * (3 - 2 * f); // smoothstep
            line[i] = ctrl[i0] * (1 - f) + ctrl[i0 + 1] * f;
        }
        return line;
    }

    private bool InBand(int x, int y, double grow)
    {
        if (x < _depthW[y] + grow || (MapW - 1 - x) < _depthE[y] + grow || y < _depthN[x] + grow)
            return true;
        bool inGap = x >= GapX0 && x <= GapX1;
        return !inGap && (MapH - 1 - y) < _depthS[x] + grow;
    }

    private void PaintGround()
    {
        // 1. grass everywhere
        var grass = new Godot.Collections.Array<Vector2I>();
        for (int y = 0; y < MapH; y++)
            for (int x = 0; x < MapW; x++)
                grass.Add(new Vector2I(x, y));
        _ground.SetCellsTerrainConnect(grass, 0, GrassTerrain);

        // 2. leaf litter: under the perimeter band (+2 noisy cells) and under every grove
        var litter = new HashSet<Vector2I>();
        for (int y = 0; y < MapH; y++)
            for (int x = 0; x < MapW; x++)
                if (InBand(x, y, 1.6 + _rng.NextDouble() * 1.4))
                    litter.Add(new Vector2I(x, y));
        (double X, double Y, double R)[] litterBlobs =
        {
            (13, 17, 4.6), (22, 10, 4.2), (46, 8, 4.4), (43, 17, 3.6),
            (20, 28, 4.4), (46, 30, 4.2), (10, 25, 3.4), (36, 8, 4.8),
        };
        foreach (var b in litterBlobs)
            AddBlob(litter, b.X, b.Y, b.R, 0.30, 0.18);
        _ground.SetCellsTerrainConnect(ToArr(litter), 0, _tLitter);

        // 3. moss accents under the densest stands
        var moss = new HashSet<Vector2I>();
        (double X, double Y, double R)[] mossBlobs =
        {
            (15, 21, 2.7), (45, 9, 2.8), (21, 29, 2.6), (48, 30, 2.5),
        };
        foreach (var b in mossBlobs)
            AddBlob(moss, b.X, b.Y, b.R, 0.14, 0.08); // compact pads, no 1-wide worms
        _ground.SetCellsTerrainConnect(ToArr(moss), 0, _tMoss);

        // 4. the trail: south exit -> S-curves -> central clearing, with an east fork
        Vector2[] main =
        {
            new(32.0f, 36.5f), new(31.6f, 33.0f), new(30.2f, 30.4f), new(27.8f, 28.2f),
            new(25.7f, 25.4f), new(25.4f, 22.6f), new(27.4f, 20.2f), new(30.4f, 18.5f), new(33.0f, 17.2f),
        };
        Vector2[] fork =
        {
            new(26.8f, 22.4f), new(29.8f, 23.9f), new(33.2f, 22.3f), new(36.8f, 23.3f),
            new(39.8f, 24.9f), new(43.4f, 23.5f), new(47.5f, 25.0f),
        };
        PaintPath(main);
        PaintPath(fork);
        _ground.SetCellsTerrainConnect(ToArr(_trail), 0, DirtTerrain);

        // 5. pond (northwest quadrant) — organic blob; water collision is baked at runtime
        double p1 = _rng.NextDouble() * Math.Tau, p2 = _rng.NextDouble() * Math.Tau;
        for (int y = 2; y < 15; y++)
        {
            for (int x = 4; x < 20; x++)
            {
                double dx = x + 0.5 - 11.5, dy = (y + 0.5 - 8.2) * 1.35;
                double dist = Math.Sqrt(dx * dx + dy * dy);
                double th = Math.Atan2(dy, dx);
                double r = 4.0 * (1 + 0.28 * Math.Sin(3 * th + p1) + 0.16 * Math.Sin(5 * th + p2));
                if (dist <= r)
                    _water.Add(new Vector2I(x, y));
            }
        }
        _water.RemoveWhere(c => _trail.Contains(c));
        _ground.SetCellsTerrainConnect(ToArr(_water), 0, _tWater);
    }

    private void PaintPath(Vector2[] pts)
    {
        double s = 0;
        for (int i = 0; i < pts.Length - 1; i++)
        {
            Vector2 a = pts[i], b = pts[i + 1];
            Vector2 m0 = i > 0 ? (b - pts[i - 1]) * 0.5f : b - a;
            Vector2 m1 = i < pts.Length - 2 ? (pts[i + 2] - a) * 0.5f : b - a;
            for (double t = 0; t <= 1.0; t += 0.04)
            {
                float ft = (float)t;
                float h00 = 2 * ft * ft * ft - 3 * ft * ft + 1, h10 = ft * ft * ft - 2 * ft * ft + ft;
                float h01 = -2 * ft * ft * ft + 3 * ft * ft, h11 = ft * ft * ft - ft * ft;
                Vector2 p = h00 * a + h10 * m0 + h01 * b + h11 * m1;
                s += 0.04;
                double r = 1.02 + 0.26 * (0.5 + 0.5 * Math.Sin(s * 2.1));
                int x0 = (int)Math.Floor(p.X - r), x1 = (int)Math.Ceiling(p.X + r);
                int y0 = (int)Math.Floor(p.Y - r), y1 = (int)Math.Ceiling(p.Y + r);
                for (int cy = y0; cy <= y1; cy++)
                {
                    for (int cx = x0; cx <= x1; cx++)
                    {
                        if (cx < 1 || cx >= MapW - 1 || cy < 1 || cy >= MapH) continue;
                        double ddx = cx + 0.5 - p.X, ddy = cy + 0.5 - p.Y;
                        if (ddx * ddx + ddy * ddy <= r * r)
                            _trail.Add(new Vector2I(cx, cy));
                    }
                }
            }
        }
    }

    private void AddBlob(HashSet<Vector2I> set, double cx, double cy, double r, double amp3, double amp5)
    {
        double p = _rng.NextDouble() * Math.Tau;
        double p2 = _rng.NextDouble() * Math.Tau;
        for (int y = (int)(cy - r - 2); y <= cy + r + 2; y++)
        {
            for (int x = (int)(cx - r - 2); x <= cx + r + 2; x++)
            {
                if (x < 0 || x >= MapW || y < 0 || y >= MapH) continue;
                double dx = x + 0.5 - cx, dy = y + 0.5 - cy;
                double th = Math.Atan2(dy, dx);
                double rr = r * (1 + amp3 * Math.Sin(3 * th + p) + amp5 * Math.Sin(5 * th + p2));
                if (dx * dx + dy * dy <= rr * rr)
                    set.Add(new Vector2I(x, y));
            }
        }
    }

    // ------------------------------------------------------------------ perimeter + trees

    /// <summary>Hidden colliding ring (B-sheet opaque cells) on every border cell except the south
    /// trail gap. Fully covered by opaque canopy fill afterwards (verified in Validate()).</summary>
    private void PaintPerimeterRing()
    {
        for (int x = 0; x < MapW; x++)
        {
            _walls.SetCell(new Vector2I(x, 0), SrcB, RingTile);
            if (x < GapX0 || x > GapX1)
                _walls.SetCell(new Vector2I(x, MapH - 1), SrcB, RingTile);
        }
        for (int y = 1; y < MapH - 1; y++)
        {
            _walls.SetCell(new Vector2I(0, y), SrcB, RingTile);
            _walls.SetCell(new Vector2I(MapW - 1, y), SrcB, RingTile);
        }
    }

    private void StampGiantTree()
    {
        PlaceStamp(Tree["giant"], new Vector2I(36, 12), _walls);
        _treeAnchors.Add(new Vector2I(36, 12));
        AddShadowEllipse(36, 11.4, 4.6, 2.1);
    }

    private void StampTrees(Node2D root)
    {
        foreach (var (v, x, y) in PerimeterTrees)
        {
            PlaceStamp(Tree[v], new Vector2I(x, y), _walls);
            _treeAnchors.Add(new Vector2I(x, y));
            AddTreeShadow(v, x, y);
        }
        // Interior/grove trees: baked prefab instances, not tiles (see TreePrefabs).
        foreach (var (v, x, y) in InteriorTrees)
        {
            PlaceTreePrefab(root, v, new Vector2I(x, y));
            _treeAnchors.Add(new Vector2I(x, y));
            AddTreeShadow(v, x, y);
        }
        foreach (var (x, y) in Bushes)
            PlaceStamp(Tree["bush"], new Vector2I(x, y), _walls);
    }

    /// <summary>Bake one interior tree as a placed resource-node prefab instance with a stable
    /// unique name (tree_01…) at the trunk-base cell center. The trunk cell is reserved against
    /// scatter/markers and validated off the trail (the prefab carries its own base collision).</summary>
    private void PlaceTreePrefab(Node2D root, string variant, Vector2I cell)
    {
        if (!TreePrefabs.TryGetValue(variant, out string? path))
            throw new InvalidOperationException($"no tree prefab mapped for variant '{variant}'");
        var scene = GD.Load<PackedScene>(path)
            ?? throw new InvalidOperationException($"missing tree prefab {path}");

        var tree = scene.Instantiate<Node2D>();
        tree.Name = $"tree_{++_treeCounter:00}";
        tree.Position = CellCenter(cell.X, cell.Y);
        root.AddChild(tree);
        tree.Owner = root;

        _prefabTrunks.Add(cell);
        _blocked.Add(cell); // keep scatter singles from crowding the trunk base
    }

    /// <summary>Shadow pads only under wide canopies — slender trees (pines/med) produce 1-wide
    /// shadow worms with the hard-edged shadow terrain, so they get none.</summary>
    private void AddTreeShadow(string variant, int x, int y)
    {
        double rx = variant switch
        {
            "round" or "orange" or "orangeW" or "pink" or "pinkW" => 2.0,
            "curvy" => 1.9,
            _ => 0,
        };
        if (rx > 0)
            AddShadowEllipse(x + 0.5, y + 0.3, rx, rx * 0.5);
    }

    /// <summary>Opaque giant-tree canopy fill on EVERY band cell, painted BEFORE the trees so later
    /// stamps can only replace it with fully-opaque cells (PlaceStamp's overwrite rule). Structural
    /// guarantee: the hidden colliding ring can never peek through and no grass notch can open
    /// inside the band (the old fill-last pass skipped cells already holding a semi-transparent
    /// blob edge, which punched square see-through holes).</summary>
    private void PaintBandFill()
    {
        foreach (Vector2I c in _band)
            _overhead.SetCell(c, SrcGiantTree, _fillTiles[_rng.Next(_fillTiles.Count)]);
    }

    /// <summary>Organic tree-line silhouette: a trunk-less full-canopy dome on OverheadDecor over
    /// EVERY band-boundary cell (8-neighbourhood, so staircase corners are included), anchored with
    /// an opaque core cell ON the boundary cell and the rounded 1-cell fringe spilling toward the
    /// open side. Because the domes are rounded on all sides, every edge and corner reads leafy —
    /// the old canopy-TOP crops had flat-cut bottoms that faced the field on the N/E/W edges.</summary>
    private void StampFringe()
    {
        Vector2I[] dirs8 =
        {
            new(1, 0), new(-1, 0), new(0, 1), new(0, -1),
            new(1, 1), new(1, -1), new(-1, 1), new(-1, -1),
        };
        var boundary = new List<(Vector2I C, Vector2I Open)>();
        foreach (Vector2I c in _band)
        {
            var open = Vector2I.Zero;
            bool edge = false;
            foreach (Vector2I d in dirs8)
            {
                Vector2I n = c + d;
                if (n.X >= 0 && n.X < MapW && n.Y >= 0 && n.Y < MapH && !_band.Contains(n))
                {
                    edge = true;
                    open += d;
                }
            }
            if (edge) boundary.Add((c, open.Clamp(-Vector2I.One, Vector2I.One)));
        }

        foreach (var (c, open) in boundary)
            PlaceDome(FringeDomes[_rng.Next(FringeDomes.Length)], c, open, _overheadDecor);

        // autumn accents on their OWN layer above the green domes, so each renders with its full
        // art — semi-transparent leafy edges blending over the green mass (mixing two colourways
        // on one layer can only ever produce hard cell-quantized colour boundaries). Picks stay
        // clear of the map border (a dome clipped by the edge survives only as a torn sliver) and
        // of each other (adjacent accents merge into one blocky slab).
        var inner = boundary.FindAll(b =>
            b.C.X >= 4 && b.C.X < MapW - 4 && b.C.Y >= 4 && b.C.Y < MapH - 4);
        var picked = new List<Vector2I>();
        for (int tries = 0; tries < 60 && picked.Count < 7 && inner.Count > 0; tries++)
        {
            var (c, open) = inner[_rng.Next(inner.Count)];
            bool tooClose = false;
            foreach (Vector2I p in picked)
                if (Math.Abs(p.X - c.X) <= 6 && Math.Abs(p.Y - c.Y) <= 6) { tooClose = true; break; }
            if (tooClose) continue;
            PlaceDome(AccentDome, c, open, _overheadAccent);
            picked.Add(c);
        }
    }

    /// <summary>Anchor the dome so an opaque core cell covers <paramref name="c"/> and the leafy
    /// fringe (1 cell beyond the core range) spills toward the open side; when an axis has no open
    /// direction the core choice on that axis doubles as placement jitter. Overlaps composite
    /// HIGHEST-OPACITY-WINS (order-independent — first-placed-wins let a neighbour dome's near-empty
    /// corner cell permanently block the leafy fringe there, leaving the fill seam naked).</summary>
    private void PlaceDome(Dome d, Vector2I c, Vector2I open, TileMapLayer layer)
    {
        if (_ts.GetSource(d.Src) is not TileSetAtlasSource src)
            throw new InvalidOperationException($"missing source {d.Src}");
        int coreX = open.X > 0 ? d.CX1 : open.X < 0 ? d.CX0 : _rng.Next(d.CX0, d.CX1 + 1);
        int coreY = open.Y > 0 ? d.CY1 : open.Y < 0 ? d.CY0 : _rng.Next(d.CY0, d.CY1 + 1);
        for (int ay = d.Y0; ay <= d.Y1; ay++)
        {
            for (int ax = d.X0; ax <= d.X1; ax++)
            {
                var coords = new Vector2I(ax, ay);
                if (!src.HasTile(coords)) continue;
                var w = new Vector2I(c.X + ax - coreX, c.Y + ay - coreY);
                if (w.X < 0 || w.X >= MapW || w.Y < 0 || w.Y >= MapH) continue;

                int existing = layer.GetCellSourceId(w);
                if (existing != -1 &&
                    Opacity(d.Src, coords) <= Opacity(existing, layer.GetCellAtlasCoords(w)))
                    continue;
                layer.SetCell(w, d.Src, coords);
            }
        }
    }

    private void PaintShadows()
    {
        _shadowCells.RemoveWhere(c => _water.Contains(c) || c.X < 0 || c.X >= MapW || c.Y < 0 || c.Y >= MapH);
        _groundDecor.SetCellsTerrainConnect(ToArr(_shadowCells), 0, _tShadow);
    }

    private void AddShadowEllipse(double cx, double cy, double rx, double ry)
    {
        double p = _rng.NextDouble() * Math.Tau;
        for (int y = (int)(cy - ry - 1); y <= cy + ry + 1; y++)
            for (int x = (int)(cx - rx - 1); x <= cx + rx + 1; x++)
            {
                double th = Math.Atan2(y + 0.5 - cy, x + 0.5 - cx);
                double n = 1 + 0.30 * Math.Sin(2 * th + p);
                double dx = (x + 0.5 - cx) / (rx * n), dy = (y + 0.5 - cy) / (ry * n);
                if (dx * dx + dy * dy <= 1.0)
                    _shadowCells.Add(new Vector2I(x, y));
            }
    }

    private void StampProps()
    {
        foreach (var (p, x, y) in PropsPlaced)
            PlaceStamp(Prop[p], new Vector2I(x, y), _props);
    }

    /// <summary>Stamp a multi-cell object. Rows &gt;= BaseFrom land on <paramref name="baseLayer"/>
    /// (trunk/base), the rest on Overhead (canopy). Cells clip at the map border. Occupied base
    /// cells are never overwritten; occupied overhead cells are only overwritten by fully-opaque
    /// leaf cells (prevents torn canopies where stamps overlap).</summary>
    private void PlaceStamp(Stamp s, Vector2I anchor, TileMapLayer baseLayer, TileMapLayer? overheadOverride = null)
    {
        if (_ts.GetSource(s.Src) is not TileSetAtlasSource src)
            throw new InvalidOperationException($"missing source {s.Src}");
        TileMapLayer over = overheadOverride ?? _overhead;
        for (int ay = s.Y0; ay <= s.Y1; ay++)
        {
            for (int ax = s.X0; ax <= s.X1; ax++)
            {
                var coords = new Vector2I(ax, ay);
                if (!src.HasTile(coords)) continue;
                var w = new Vector2I(anchor.X + ax - s.AnchorX, anchor.Y + ay - s.AnchorY);
                if (w.X < 0 || w.X >= MapW || w.Y < 0 || w.Y >= MapH) continue;

                bool isBase = ay >= s.BaseFrom;
                TileMapLayer target = isBase ? baseLayer : over;
                if (target.GetCellSourceId(w) != -1)
                {
                    if (isBase || Opacity(s.Src, coords) < 0.98f)
                        continue;
                }
                target.SetCell(w, s.Src, coords);
                if (isBase)
                    _blocked.Add(w);
            }
        }
    }

    // ------------------------------------------------------------------ scatter

    private void ScatterDecor()
    {
        int placed = 0;
        // grass tufts everywhere
        placed += ScatterUniform(TuftTiles, SrcVeg, 260);
        // blue flowers sprinkled wide
        placed += ScatterUniform(BlueFlowerTiles, SrcVeg, 26);
        // yellow flowers in the clearings
        foreach (var (cx, cy, rx, ry) in Clearings)
            for (int i = 0; i < 14; i++)
                placed += TryScatter(RandInEllipse(cx, cy, rx, ry), YellowFlowerTiles, SrcVeg);
        // red/orange flowers hugging the trail
        var trailList = new List<Vector2I>(_trail);
        for (int i = 0; i < 26; i++)
        {
            Vector2I t = trailList[_rng.Next(trailList.Count)];
            var c = new Vector2I(t.X + _rng.Next(-3, 4), t.Y + _rng.Next(-3, 4));
            if (!_trail.Contains(c))
                placed += TryScatter(c, RedFlowerTiles, SrcVeg);
        }
        // ferns + mushrooms clustered near trees
        for (int i = 0; i < 100; i++)
        {
            Vector2I a = _treeAnchors[_rng.Next(_treeAnchors.Count)];
            var c = new Vector2I(a.X + _rng.Next(-4, 5), a.Y + _rng.Next(-3, 4));
            placed += TryScatter(c, FernTilesD, SrcD);
        }
        for (int i = 0; i < 60; i++)
        {
            Vector2I a = _treeAnchors[_rng.Next(_treeAnchors.Count)];
            var c = new Vector2I(a.X + _rng.Next(-3, 4), a.Y + _rng.Next(-2, 4));
            placed += TryScatter(c, MushroomTiles, SrcVeg);
        }
        // spiky undergrowth on litter
        for (int i = 0; i < 90; i++)
        {
            var c = new Vector2I(_rng.Next(1, MapW - 1), _rng.Next(1, MapH - 1));
            if (GroundTerrainAt(c) == _tLitter)
                placed += TryScatter(c, SpikyTiles, SrcVeg);
        }
        // reeds + water herbs around the pond rim
        for (int i = 0; i < 16; i++)
        {
            double th = _rng.NextDouble() * Math.Tau;
            double r = 4.6 + _rng.NextDouble() * 1.2;
            var c = new Vector2I((int)(11.5 + Math.Cos(th) * r), (int)(8.2 + Math.Sin(th) * r / 1.35));
            placed += TryScatter(c, i % 2 == 0 ? ReedTilesD : HerbTiles, i % 2 == 0 ? SrcD : SrcVeg);
        }
        // herbs near the herb nodes (readable theming)
        foreach (string id in new[] { "herb_1", "herb_2" })
        {
            Vector2I h = NodeCells[id];
            for (int i = 0; i < 5; i++)
                placed += TryScatter(new Vector2I(h.X + _rng.Next(-3, 4), h.Y + _rng.Next(-2, 3)), HerbTiles, SrcVeg);
        }
        GD.Print($"[ForestPainter] scatter placed {placed} decor singles");
    }

    private int ScatterUniform(Vector2I[] tiles, int src, int attempts)
    {
        int n = 0;
        for (int i = 0; i < attempts; i++)
            n += TryScatter(new Vector2I(_rng.Next(1, MapW - 1), _rng.Next(1, MapH - 1)), tiles, src);
        return n;
    }

    private Vector2I RandInEllipse(double cx, double cy, double rx, double ry)
    {
        double th = _rng.NextDouble() * Math.Tau, r = Math.Sqrt(_rng.NextDouble());
        return new Vector2I((int)(cx + Math.Cos(th) * r * rx), (int)(cy + Math.Sin(th) * r * ry));
    }

    private int TryScatter(Vector2I c, Vector2I[] tiles, int srcId)
    {
        if (c.X < 1 || c.X >= MapW - 1 || c.Y < 1 || c.Y >= MapH - 1) return 0;
        if (_band.Contains(c) || _blocked.Contains(c) || _trail.Contains(c) || _water.Contains(c)) return 0;
        if (_groundDecor.GetCellSourceId(c) != -1 || _overhead.GetCellSourceId(c) != -1) return 0;
        if (_props.GetCellSourceId(c) != -1 || _walls.GetCellSourceId(c) != -1) return 0;
        if (_overheadDecor.GetCellSourceId(c) != -1) return 0; // under a fringe-dome overhang
        if (_overheadAccent.GetCellSourceId(c) != -1) return 0; // under an accent-dome overhang
        int t = GroundTerrainAt(c);
        if (t != GrassTerrain && t != _tLitter && t != _tMoss) return 0;
        foreach (Vector2I m in NodeCells.Values)
            if (Math.Abs(m.X - c.X) <= 1 && Math.Abs(m.Y - c.Y) <= 1) return 0;
        foreach (Vector2I m in RoamerCells.Values)
            if (Math.Abs(m.X - c.X) <= 1 && Math.Abs(m.Y - c.Y) <= 1) return 0;

        Vector2I tile = tiles[_rng.Next(tiles.Length)];
        if (_ts.GetSource(srcId) is not TileSetAtlasSource src || !src.HasTile(tile)) return 0;
        _groundDecor.SetCell(c, srcId, tile);
        return 1;
    }

    private int GroundTerrainAt(Vector2I c) => _ground.GetCellTileData(c)?.Terrain ?? -1;

    // ------------------------------------------------------------------ functional nodes + fx

    private void AddFunctionalNodes(Node2D root)
    {
        AddMarker(root, "PlayerSpawn", CellCenter(32, 32));

        // Exit trigger: same placement/shape the current scene ships (user-tuned offsets kept).
        var area = new Area2D { Name = "ExitTrigger", Position = CellCenter(32, 34), UniqueNameInOwner = true };
        root.AddChild(area);
        area.Owner = root;
        var shape = new CollisionShape2D
        {
            Name = "CollisionShape2D",
            Position = new Vector2(-25f, 51.25f),
            Shape = new RectangleShape2D { Size = new Vector2(102f, 133.5f) }, // unique resource
        };
        area.AddChild(shape);
        shape.Owner = root;

        var forest = Bulwark.Data.Territories.Forest;
        foreach (var node in forest.Nodes)
        {
            if (!NodeCells.TryGetValue(node.NodeId, out Vector2I cell))
                throw new InvalidOperationException($"no position for node '{node.NodeId}'");
            AddMarker(root, $"Node_{node.NodeId}", CellCenter(cell.X, cell.Y));
        }
        foreach (var roamer in forest.Roamers)
        {
            if (!RoamerCells.TryGetValue(roamer.RoamerId, out Vector2I cell))
                throw new InvalidOperationException($"no position for roamer '{roamer.RoamerId}'");
            AddMarker(root, $"Roamer_{roamer.RoamerId}", CellCenter(cell.X, cell.Y));
        }

        var cam = new Camera2D
        {
            Name = "Camera2D",
            Position = CellCenter(MapW / 2, MapH / 2),
            Enabled = false,
        };
        root.AddChild(cam);
        cam.Owner = root;
    }

    private static void AddFx(Node2D root)
    {
        Instance(root, "Hd2dStack", "res://scenes/fx/hd2d_stack.tscn", null);
        Instance(root, "CloudShadows", "res://scenes/fx/cloud_shadows.tscn", new Vector2(1536, 864));
        Instance(root, "FallingLeaves", "res://scenes/fx/falling_leaves.tscn", new Vector2(1536, 720));
    }

    private static void Instance(Node2D root, string name, string path, Vector2? pos)
    {
        var scene = GD.Load<PackedScene>(path) ?? throw new InvalidOperationException($"missing {path}");
        Node inst = scene.Instantiate();
        inst.Name = name;
        root.AddChild(inst);
        inst.Owner = root;
        if (pos.HasValue && inst is Node2D n2)
            n2.Position = pos.Value;
    }

    // ------------------------------------------------------------------ validation

    private void Validate()
    {
        // every marker stands on open, walkable ground
        foreach (var kv in NodeCells) AssertOpen(kv.Value, $"Node_{kv.Key}");
        foreach (var kv in RoamerCells) AssertOpen(kv.Value, $"Roamer_{kv.Key}");
        AssertOpen(new Vector2I(32, 32), "PlayerSpawn");

        // the trail is walkable end to end (tile walls AND baked tree-prefab trunks)
        foreach (Vector2I c in _trail)
        {
            if (_walls.GetCellSourceId(c) != -1)
                throw new InvalidOperationException($"trail cell {c} blocked by Walls");
            if (_prefabTrunks.Contains(c))
                throw new InvalidOperationException($"trail cell {c} blocked by a tree prefab trunk");
        }

        // no ring tile peeks through: every ring cell must be under a FULLY OPAQUE canopy tile
        int exposed = 0;
        foreach (Vector2I c in _walls.GetUsedCells())
        {
            if (_walls.GetCellSourceId(c) != SrcB) continue;
            int over = _overhead.GetCellSourceId(c);
            if (over == -1 || Opacity(over, _overhead.GetCellAtlasCoords(c)) < 0.98f)
            {
                exposed++;
                GD.Print($"[ForestPainter] WARN ring cell exposed at {c}");
            }
        }
        if (exposed > 0)
            throw new InvalidOperationException($"{exposed} perimeter ring cells not covered by opaque canopy");
    }

    private void AssertOpen(Vector2I c, string what)
    {
        if (_walls.GetCellSourceId(c) != -1 || _props.GetCellSourceId(c) != -1)
            throw new InvalidOperationException($"{what} at {c} sits on a solid cell");
        if (_prefabTrunks.Contains(c))
            throw new InvalidOperationException($"{what} at {c} sits on a tree prefab trunk");
        if (_water.Contains(c))
            throw new InvalidOperationException($"{what} at {c} is in the pond");
        if (_band.Contains(c))
            throw new InvalidOperationException($"{what} at {c} is inside the perimeter band");
    }

    // ------------------------------------------------------------------ helpers

    private TileMapLayer MakeLayer(Node2D root, string name, int zIndex, bool ySort)
    {
        var layer = new TileMapLayer
        {
            Name = name,
            TileSet = _ts,
            ZIndex = zIndex,
            YSortEnabled = ySort,
            UniqueNameInOwner = true,
        };
        root.AddChild(layer);
        layer.Owner = root;
        return layer;
    }

    private static void AddMarker(Node2D root, string name, Vector2 pos)
    {
        var m = new Marker2D { Name = name, Position = pos, UniqueNameInOwner = true };
        root.AddChild(m);
        m.Owner = root;
    }

    private static Vector2 CellCenter(int x, int y) => new(x * Cell + Cell / 2f, y * Cell + Cell / 2f);

    private static Godot.Collections.Array<Vector2I> ToArr(IEnumerable<Vector2I> cells)
    {
        var arr = new Godot.Collections.Array<Vector2I>();
        foreach (Vector2I c in cells) arr.Add(c);
        return arr;
    }

    /// <summary>Opaque fraction of one 48px atlas cell, sampled from the source PNG.</summary>
    private float Opacity(int srcId, Vector2I coords)
    {
        if (_opacity.TryGetValue((srcId, coords), out float cached)) return cached;
        if (!_images.TryGetValue(srcId, out Image? img))
        {
            if (_ts.GetSource(srcId) is not TileSetAtlasSource src)
                throw new InvalidOperationException($"missing source {srcId}");
            img = Image.LoadFromFile(ProjectSettings.GlobalizePath(src.Texture.ResourcePath));
            if (img.GetFormat() != Image.Format.Rgba8) img.Convert(Image.Format.Rgba8);
            _images[srcId] = img;
        }
        int n = 0, op = 0;
        for (int y = 0; y < Cell; y += 4)
            for (int x = 0; x < Cell; x += 4)
            {
                n++;
                if (img.GetPixel(coords.X * Cell + x, coords.Y * Cell + y).A > 0.1f) op++;
            }
        float frac = (float)op / n;
        _opacity[(srcId, coords)] = frac;
        return frac;
    }
}
