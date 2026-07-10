using System;
using Godot;
using Godot.Collections;

namespace Bulwark.Dev;

/// <summary>
/// Headless painter that assembles the outpost blockout scene in code and saves it as
/// <c>scenes/outpost/outpost.tscn</c> via PackedScene.Pack (repo convention: never hand-roll
/// tile_map_data bytes). Produces a MINIMAL blocking layout for the user to repaint: a grass ground
/// rectangle, a farmable dirt patch, a sketched wall run with a ruined gap, plus the functional
/// nodes (spawn/farm markers, ruined-building placeholders, gate trigger, non-current camera).
///
/// Run via <c>scenes/dev/outpost_blockout_builder.tscn</c>.
/// </summary>
public partial class OutpostBlockoutBuilder : Node
{
    private const string TilesetPath = "res://assets/tilesets/outpost_tileset.tres";
    private const string OutPath = "res://scenes/outpost/outpost.tscn";
    private const int Cell = 48;

    // Map extents (tiles).
    private const int MapW = 40;
    private const int MapH = 30;

    // Terrain ids (catalog order: A2 grass=0, A2 dirt(farmable)=1, ...). See TileSetBuilder.
    private const int GrassTerrain = 0;
    private const int DirtTerrain = 1;

    // Source ids from TileSetBuilder.
    private const int SourceB = 11;          // restored architecture
    private const int SourceBDestroyed = 31; // ruined architecture
    private const int SourceC = 12;          // decor props
    private const int SourceRoofs = 14;      // overhead roofs

    public override void _Ready()
    {
        try
        {
            Build();
            GD.Print("[OutpostBlockoutBuilder] DONE");
        }
        catch (Exception e)
        {
            GD.PushError($"[OutpostBlockoutBuilder] FAILED: {e}");
            GD.Print($"[OutpostBlockoutBuilder] FAILED: {e.Message}\n{e.StackTrace}");
        }
        GetTree().Quit();
    }

    private void Build()
    {
        var tileSet = GD.Load<TileSet>(TilesetPath);
        if (tileSet == null) throw new InvalidOperationException("could not load tileset");

        // Instantiate the adapter directly so its script is attached without SetScript() (which would
        // swap the managed wrapper and invalidate our reference).
        var root = new Bulwark.Cozy.OutpostScene { Name = "Outpost" };

        // --- Tile layers (bottom to top) ---
        var ground = MakeLayer(root, "Ground", tileSet, zIndex: 0, ySort: false);
        var groundDecor = MakeLayer(root, "GroundDecor", tileSet, zIndex: 0, ySort: false);
        var walls = MakeLayer(root, "Walls", tileSet, zIndex: 0, ySort: true);
        var props = MakeLayer(root, "Props", tileSet, zIndex: 0, ySort: true);
        var overhead = MakeLayer(root, "Overhead", tileSet, zIndex: 10, ySort: true);

        // --- Ground: fill grass, then a farmable dirt patch ---
        var grassCells = new Array<Vector2I>();
        for (int y = 0; y < MapH; y++)
            for (int x = 0; x < MapW; x++)
                grassCells.Add(new Vector2I(x, y));
        ground.SetCellsTerrainConnect(grassCells, 0, GrassTerrain);

        // Dirt farm patch (8x6) toward the east side.
        var farm = new Rect2I(24, 8, 8, 6);
        var dirtCells = new Array<Vector2I>();
        for (int y = farm.Position.Y; y < farm.End.Y; y++)
            for (int x = farm.Position.X; x < farm.End.X; x++)
                dirtCells.Add(new Vector2I(x, y));
        ground.SetCellsTerrainConnect(dirtCells, 0, DirtTerrain);

        // --- Walls: a short restored wall run with a ruined gap (fort footprint sketch) ---
        Vector2I wallTile = FirstTile(tileSet, SourceB, new Vector2I(9, 1));
        Vector2I ruinTile = FirstTile(tileSet, SourceBDestroyed, new Vector2I(9, 1));
        for (int x = 8; x <= 14; x++)
            walls.SetCell(new Vector2I(x, 6), SourceB, wallTile);
        // ruined gap
        walls.SetCell(new Vector2I(11, 6), SourceBDestroyed, ruinTile);
        // two side returns
        walls.SetCell(new Vector2I(8, 7), SourceB, wallTile);
        walls.SetCell(new Vector2I(14, 7), SourceBDestroyed, ruinTile);

        // --- Props: a couple of decorations (demonstrative) ---
        Vector2I propTile = FirstTile(tileSet, SourceC, new Vector2I(0, 0));
        props.SetCell(new Vector2I(6, 10), SourceC, propTile);
        props.SetCell(new Vector2I(18, 20), SourceC, propTile);

        // --- Overhead: a roof tile above the wall (renders over the player) ---
        Vector2I roofTile = FirstTile(tileSet, SourceRoofs, new Vector2I(0, 0));
        overhead.SetCell(new Vector2I(10, 5), SourceRoofs, roofTile);
        overhead.SetCell(new Vector2I(11, 5), SourceRoofs, roofTile);

        // --- Functional nodes ---
        AddMarker(root, "PlayerSpawn", CellCenter(20, 15));
        AddMarker(root, "FarmArea", CellCenter(27, 10)); // center-ish of the dirt patch
        AddMarker(root, "RuinedBuilding_1", CellCenter(11, 6));
        AddMarker(root, "RuinedBuilding_2", CellCenter(8, 7));
        AddMarker(root, "RuinedBuilding_3", CellCenter(14, 7));
        AddMarker(root, "RuinedBuilding_4", CellCenter(20, 4));

        AddGateTrigger(root, CellCenter(20, 29), new Vector2(2 * Cell, Cell));

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
        Error serr = ResourceSaver.Save(packed, OutPath);
        GD.Print($"[OutpostBlockoutBuilder] saved {OutPath} err={serr} " +
                 $"(ground cells={ground.GetUsedCells().Count}, walls={walls.GetUsedCells().Count})");

        // Verify farmable query round-trips through the ground layer's tile data.
        int farmable = 0;
        foreach (Vector2I c in ground.GetUsedCells())
        {
            TileData td = ground.GetCellTileData(c);
            if (td != null && (bool)td.GetCustomData("farmable")) farmable++;
        }
        GD.Print($"[OutpostBlockoutBuilder] farmable ground cells painted = {farmable}");
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

    private static void AddGateTrigger(Node2D root, Vector2 pos, Vector2 size)
    {
        var area = new Area2D { Name = "GateTrigger", Position = pos, UniqueNameInOwner = true };
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
