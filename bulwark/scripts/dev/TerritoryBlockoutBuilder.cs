using System;
using System.Collections.Generic;
using Godot;
using Godot.Collections;

namespace Bulwark.Dev;

/// <summary>
/// ONE-SHOT headless painter that assembles the Tier-1 forest blockout in code and saves it as
/// <c>scenes/territory/forest.tscn</c> via PackedScene.Pack (repo convention: never hand-roll
/// tile_map_data bytes). Produces a MINIMAL blocking layout for the user to repaint: a grass
/// clearing with a dirt trail, a colliding tree-line perimeter (B-sheet cells — guaranteed physics;
/// the user repaints with real trees and adds trunk collision in-editor), scattered tree/rock decor,
/// plus the functional nodes: entry spawn, exit trigger back to the outpost, one Marker2D per
/// resource node and roamer spawn (ids sourced from Territories.Forest — the single contract).
///
/// NEVER RE-RUN AFTER THE USER HAS PAINTED THE MAP. The builder refuses to overwrite an existing
/// forest.tscn unless "--force" is passed after "--" on the command line:
///   godot --headless res://scenes/dev/territory_blockout_builder.tscn -- --force
/// </summary>
public partial class TerritoryBlockoutBuilder : Node
{
    private const string TilesetPath = "res://assets/tilesets/outpost_tileset.tres";
    private const string OutPath = "res://scenes/territory/forest.tscn";
    private const string ElderwoodOutPath = "res://scenes/territory/elderwood.tscn";
    private const int Cell = 48;

    // Map extents (tiles): ~2 outpost screens (outpost is 40x30).
    private const int MapW = 64;
    private const int MapH = 36;

    // Terrain ids on terrain set 0 (catalog order, same as OutpostBlockoutBuilder).
    private const int GrassTerrain = 0;
    private const int DirtTerrain = 1;

    // Source ids from TileSetBuilder (see assets/tilesets/README.md).
    private const int SourceB = 11;      // architecture — right-half cells carry opaque collision
    private const int SourceBigTrees = 22; // trees (no physics — decorative in the blockout)
    private const int SourceDecor = 23;  // props

    // Blockout positions per data id (cells). Territories.Forest is the id source of truth;
    // Build() throws if an id defined there has no position here.
    private static readonly System.Collections.Generic.Dictionary<string, Vector2I> NodeCells = new()
    {
        ["rock_1"] = new Vector2I(10, 10),
        ["rock_2"] = new Vector2I(52, 8),
        ["rock_3"] = new Vector2I(44, 26),
        ["herb_1"] = new Vector2I(18, 20),
        ["herb_2"] = new Vector2I(40, 14),
        ["berry_1"] = new Vector2I(8, 26),
        ["berry_2"] = new Vector2I(26, 6),
        ["berry_3"] = new Vector2I(56, 20),
        ["wood_1"] = new Vector2I(14, 14),
        ["wood_2"] = new Vector2I(48, 30),
    };

    private static readonly System.Collections.Generic.Dictionary<string, Vector2I> RoamerCells = new()
    {
        ["gob_1"] = new Vector2I(20, 12),
        ["gob_2"] = new Vector2I(44, 10),
        ["gob_3"] = new Vector2I(32, 18),
        ["gob_4"] = new Vector2I(12, 28),
        ["gob_5"] = new Vector2I(52, 26),
        // The brigands and expedition/wolf-lair sites (added after the forest.tscn was hand-painted)
        // are placed directly in that scene; they are intentionally NOT positioned here, so a
        // never-happen forest rebuild would fail loudly rather than silently drop them.
    };

    // ---- Elderwood blockout positions (the moderate second territory; ids from Territories.Elderwood).
    private static readonly System.Collections.Generic.Dictionary<string, Vector2I> ElderwoodNodeCells = new()
    {
        ["hardwood_1"] = new Vector2I(10, 8),
        ["hardwood_2"] = new Vector2I(54, 10),
        ["coal_1"] = new Vector2I(14, 26),
        ["coal_2"] = new Vector2I(50, 28),
        ["mushroom_1"] = new Vector2I(20, 14),
        ["mushroom_2"] = new Vector2I(44, 16),
        ["forest_root_1"] = new Vector2I(8, 18),
        ["forest_root_2"] = new Vector2I(56, 22),
        ["ward_salt_1"] = new Vector2I(26, 24),
        ["ley_glade_1"] = new Vector2I(38, 8),
    };

    private static readonly System.Collections.Generic.Dictionary<string, Vector2I> ElderwoodRoamerCells = new()
    {
        ["beast_1"] = new Vector2I(16, 10),
        ["beast_2"] = new Vector2I(48, 12),
        ["warden_1"] = new Vector2I(24, 20),
        ["warden_2"] = new Vector2I(40, 22),
        ["spider_1"] = new Vector2I(12, 14),
        ["spider_2"] = new Vector2I(52, 18),
        ["thornback_1"] = new Vector2I(30, 12),
        ["thornback_2"] = new Vector2I(36, 26),
    };

    public override void _Ready()
    {
        try
        {
            var args = OS.GetCmdlineUserArgs();
            bool force = System.Array.IndexOf(args, "--force") >= 0;
            // Which territory to generate: default forest; "-- --territory elderwood" for the Elderwood.
            bool elderwood = ReadTerritoryArg(args) == "elderwood";
            string outPath = elderwood ? ElderwoodOutPath : OutPath;

            // Never-rerun guard: the user hand-paints each territory scene after generation.
            if (Godot.FileAccess.FileExists(outPath) && !force)
            {
                GD.Print($"[TerritoryBlockoutBuilder] REFUSED: {outPath} already exists. " +
                         "It may be hand-painted — never re-run this builder over a painted map. " +
                         "Pass '-- --force' to overwrite anyway.");
                GetTree().Quit(1);
                return;
            }

            Build(elderwood);
            GD.Print("[TerritoryBlockoutBuilder] DONE");
        }
        catch (Exception e)
        {
            GD.PushError($"[TerritoryBlockoutBuilder] FAILED: {e}");
            GD.Print($"[TerritoryBlockoutBuilder] FAILED: {e.Message}\n{e.StackTrace}");
            GetTree().Quit(1);
            return;
        }
        GetTree().Quit();
    }

    /// <summary>Read the "--territory &lt;id&gt;" user arg (default "forest").</summary>
    private static string ReadTerritoryArg(string[] args)
    {
        int i = System.Array.IndexOf(args, "--territory");
        return i >= 0 && i + 1 < args.Length ? args[i + 1] : "forest";
    }

    private void Build(bool elderwood)
    {
        var tileSet = GD.Load<TileSet>(TilesetPath);
        if (tileSet == null) throw new InvalidOperationException("could not load tileset");

        // Per-territory config: the data definition (id source of truth), blockout cell tables, output
        // path, and the TerritoryScene exports that make each scene self-describing. The Elderwood reuses
        // the exact same TerritoryScene adapter (design decision: one generic territory scene) — only its
        // exports differ: its exit points back to the Verdant Fringe, and entry raises elderwood_entered.
        var def = elderwood ? Bulwark.Data.Territories.Elderwood : Bulwark.Data.Territories.Forest;
        var nodeCells = elderwood ? ElderwoodNodeCells : NodeCells;
        var roamerCells = elderwood ? ElderwoodRoamerCells : RoamerCells;
        string outPath = elderwood ? ElderwoodOutPath : OutPath;

        // Instantiate the adapter directly so its script is attached without SetScript() (which
        // would swap the managed wrapper and invalidate our reference).
        var root = elderwood
            ? new Bulwark.Territory.TerritoryScene
            {
                Name = "Elderwood",
                TerritoryId = "elderwood",
                ExitTerritoryId = "verdant_fringe",
                ExitLabel = "To the Verdant Fringe",
                TerritoryEnteredEvent = "elderwood_entered",
            }
            : new Bulwark.Territory.TerritoryScene { Name = "Forest" };

        // --- Tile layers (bottom to top, matching the outpost scene shape) ---
        var ground = MakeLayer(root, "Ground", tileSet, zIndex: 0, ySort: false);
        MakeLayer(root, "GroundDecor", tileSet, zIndex: 0, ySort: false);
        var walls = MakeLayer(root, "Walls", tileSet, zIndex: 0, ySort: true);
        var props = MakeLayer(root, "Props", tileSet, zIndex: 0, ySort: true);
        MakeLayer(root, "Overhead", tileSet, zIndex: 10, ySort: true);

        // --- Ground: grass fill + a dirt trail from the south entry into the interior ---
        var grassCells = new Array<Vector2I>();
        for (int y = 0; y < MapH; y++)
            for (int x = 0; x < MapW; x++)
                grassCells.Add(new Vector2I(x, y));
        ground.SetCellsTerrainConnect(grassCells, 0, GrassTerrain);

        var dirtCells = new Array<Vector2I>();
        for (int y = 12; y <= MapH - 2; y++)
        {
            dirtCells.Add(new Vector2I(31, y));
            dirtCells.Add(new Vector2I(32, y));
        }
        for (int x = 20; x <= 44; x++) // an east-west fork mid-map
            dirtCells.Add(new Vector2I(x, 18));
        ground.SetCellsTerrainConnect(dirtCells, 0, DirtTerrain);

        // --- Walls: colliding perimeter (B-sheet opaque cells) so the map edge blocks.
        // Rough placeholder — the user repaints the tree-line and refines collision in-editor.
        Vector2I wallTile = FirstTile(tileSet, SourceB, new Vector2I(9, 1));
        for (int x = 0; x < MapW; x++)
        {
            walls.SetCell(new Vector2I(x, 0), SourceB, wallTile);
            walls.SetCell(new Vector2I(x, MapH - 1), SourceB, wallTile);
        }
        for (int y = 1; y < MapH - 1; y++)
        {
            walls.SetCell(new Vector2I(0, y), SourceB, wallTile);
            walls.SetCell(new Vector2I(MapW - 1, y), SourceB, wallTile);
        }

        // --- Props: scattered trees (decorative, no physics in the blockout) + rock decor ---
        Vector2I treeTile = FirstTile(tileSet, SourceBigTrees, new Vector2I(1, 2));
        var treeCells = new[]
        {
            new Vector2I(6, 6), new Vector2I(14, 4), new Vector2I(24, 10), new Vector2I(38, 6),
            new Vector2I(50, 4), new Vector2I(58, 10), new Vector2I(6, 18), new Vector2I(24, 24),
            new Vector2I(38, 22), new Vector2I(58, 30), new Vector2I(18, 30), new Vector2I(42, 32),
        };
        foreach (var c in treeCells)
            props.SetCell(c, SourceBigTrees, treeTile);

        Vector2I decorTile = FirstTile(tileSet, SourceDecor, new Vector2I(0, 0));
        props.SetCell(new Vector2I(28, 14), SourceDecor, decorTile);
        props.SetCell(new Vector2I(46, 20), SourceDecor, decorTile);

        // --- Functional nodes ---
        AddMarker(root, "PlayerSpawn", CellCenter(32, 32));
        AddExitTrigger(root, CellCenter(32, 34), new Vector2(4 * Cell, Cell));

        // Node/roamer markers: the territory definition drives the ids so scene and data cannot drift.
        foreach (var node in def.Nodes)
        {
            if (!nodeCells.TryGetValue(node.NodeId, out Vector2I cell))
                throw new InvalidOperationException($"no blockout position for node '{node.NodeId}'");
            AddMarker(root, $"Node_{node.NodeId}", CellCenter(cell.X, cell.Y));
        }
        foreach (var roamer in def.Roamers)
        {
            if (roamer.IsBoss)
                continue; // boss sites are placed by their dedicated lair scene, not as a roamer marker
            if (!roamerCells.TryGetValue(roamer.RoamerId, out Vector2I cell))
                throw new InvalidOperationException($"no blockout position for roamer '{roamer.RoamerId}'");
            AddMarker(root, $"Roamer_{roamer.RoamerId}", CellCenter(cell.X, cell.Y));
        }

        var cam = new Camera2D
        {
            Name = "Camera2D",
            Position = CellCenter(MapW / 2, MapH / 2),
            Enabled = false, // configured but NOT current; the player scene brings its own camera
        };
        root.AddChild(cam);
        cam.Owner = root;

        // --- Pack + save ---
        var packed = new PackedScene();
        Error perr = packed.Pack(root);
        if (perr != Error.Ok) throw new InvalidOperationException($"pack failed: {perr}");
        Error serr = ResourceSaver.Save(packed, outPath);
        if (serr != Error.Ok) throw new InvalidOperationException($"save failed: {serr}");
        GD.Print($"[TerritoryBlockoutBuilder] saved {outPath} " +
                 $"(ground cells={ground.GetUsedCells().Count}, walls={walls.GetUsedCells().Count}, " +
                 $"nodes={def.Nodes.Count}, roamers={def.Roamers.Count})");
    }

    private static TileMapLayer MakeLayer(Node2D root, string name, TileSet ts, int zIndex, bool ySort)
    {
        var layer = new TileMapLayer
        {
            Name = name,
            TileSet = ts,
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

    private static void AddExitTrigger(Node2D root, Vector2 pos, Vector2 size)
    {
        var area = new Area2D { Name = "ExitTrigger", Position = pos, UniqueNameInOwner = true };
        root.AddChild(area);
        area.Owner = root;
        var shape = new CollisionShape2D { Name = "CollisionShape2D" };
        // Unique shape resource for this node (never shared).
        shape.Shape = new RectangleShape2D { Size = size };
        area.AddChild(shape);
        shape.Owner = root;
    }

    private static Vector2 CellCenter(int x, int y) => new(x * Cell + Cell / 2f, y * Cell + Cell / 2f);

    /// <summary>Return <paramref name="preferred"/> if that tile exists in the source, else the source's first tile.</summary>
    private static Vector2I FirstTile(TileSet ts, int sourceId, Vector2I preferred)
    {
        if (ts.GetSource(sourceId) is not TileSetAtlasSource src) return Vector2I.Zero;
        if (src.HasTile(preferred)) return preferred;
        if (src.GetTilesCount() > 0) return src.GetTileId(0);
        return Vector2I.Zero;
    }
}
