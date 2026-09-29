using System;
using System.Collections.Generic;
using System.Linq;
using Delve.Data;
using Delve.Terrain;
using Godot;
using PF2e.MapGen;

namespace Delve.Dungeon;

/// <summary>A forest glade: a generated forest board inside a ring of trees, a rim of woodland
/// around it, and a dirt trail leaving each mouth. Brambles close the mouths during a fight.</summary>
public partial class GladeShell : RoomShell
{
    /// <summary>Tree scenes for the glade's own tree tiles (ring and interior), with weights.</summary>
    [Export] public PackedScene[] BoardTreeScenes { get; set; } = Array.Empty<PackedScene>();
    [Export] public float[] BoardTreeWeights { get; set; } = Array.Empty<float>();

    /// <summary>Tree scenes for the woodland rim outside the ring, with weights and the nearest rim
    /// ring each may stand on.</summary>
    [Export] public PackedScene[] RimTreeScenes { get; set; } = Array.Empty<PackedScene>();
    [Export] public float[] RimTreeWeights { get; set; } = Array.Empty<float>();
    [Export] public float[] RimTreeMinRings { get; set; } = Array.Empty<float>();

    /// <summary>Tiles of woodland drawn outside the tree ring. Two neighbouring glades placed
    /// 2 x RimDepth apart meet with no gap.</summary>
    [Export] public int RimDepth { get; set; } = 3;

    /// <summary>Chance a rim tile holds a tree, on the first rim ring and on the outermost.</summary>
    [Export(PropertyHint.Range, "0,1,0.05")] public float RimTreeChanceNear { get; set; } = 0.5f;
    [Export(PropertyHint.Range, "0,1,0.05")] public float RimTreeChanceFar { get; set; } = 0.85f;

    /// <summary>Rim tiles either side of a trail kept clear of trees.</summary>
    [Export] public int TrailShoulder { get; set; } = 1;

    /// <summary>Bramble that closes a mouth during a fight; one stands on each threshold tile.</summary>
    [Export] public PackedScene? GateScene { get; set; }

    private const int TreeSalt = 0x61AD;
    private TreeFader? _fader;

    public override float HeightScale => MapThemes.Forest.HeightScale;
    public override bool LightPool => false;

    public override GeneratedRoom Generate(DungeonRoomPrefab room, int seed, int size, IReadOnlyList<DoorSide> doors, bool openLayout)
        => GladeGeneration.Generate(seed, size, doors);

    public override void Build(DungeonRoomPrefab room, IReadOnlyList<DoorSide> doors)
    {
        var glade = room.Generated.Layout;
        int n = glade.Width, r = RimDepth, m = n + 2 * r;
        var render = new MapLayout { Seed = glade.Seed, Name = glade.Name + "_rim", BorderWidth = r + 1 };
        render.Initialize(m, m);
        var trail = new HashSet<(int X, int Y)>();
        for (int y = 0; y < m; y++)
            for (int x = 0; x < m; x++)
            {
                if (x >= r && y >= r && x < r + n && y < r + n)
                    GladeGeneration.CopyTile(glade, render, x - r, y - r, x, y, 0);
                else
                    GladeGeneration.SetFlat(render, x, y, TileRole.Ground, SurfaceType.Grass, 0);
            }
        foreach (var side in doors)
            foreach (var p in RoomGeneration.Threshold(n, side))
                for (int step = 0; step <= r; step++)
                {
                    var (x, y) = side switch
                    {
                        DoorSide.North => (p.x + r, p.y + r - step),
                        DoorSide.South => (p.x + r, p.y + r + step),
                        DoorSide.West => (p.x + r - step, p.y + r),
                        _ => (p.x + r + step, p.y + r)
                    };
                    GladeGeneration.SetFlat(render, x, y, TileRole.Ground, SurfaceType.Dirt, 0);
                    trail.Add((x, y));
                }

        var rimTrees = RimSpots(render, n, trail);
        var wallTrees = TreeWalls.Convert(render);
        var heights = new TerrainHeightMap(render, HeightScale);
        var map = new MapView3D();
        room.AddChild(map);
        map.Build(render, MapThemes.Forest, new TerrainMeshOptions
        {
            WorldOrigin = new Vector2(-r, -r),
            GridLineRect = new TileRect(r + 1, r + 1, n - 2, n - 2),
        });
        _fader = new TreeFader { Name = "TreeFader" };
        AddChild(_fader);
        var trees = TreeScatter.Build(new SkirtResult(render, r, rimTrees), heights, HeightScale, _fader,
            new TreeMix(RimTreeScenes, RimTreeWeights, RimTreeMinRings),
            new TreeMix(BoardTreeScenes, BoardTreeWeights, Array.Empty<float>()),
            wallTrees);
        if (trees != null) room.AddChild(trees);
    }

    /// <summary>Rim tiles that hold a tree: denser with distance from the ring, never on a trail or
    /// its shoulders.</summary>
    private List<(int X, int Y)> RimSpots(MapLayout render, int n, HashSet<(int X, int Y)> trail)
    {
        int r = RimDepth, m = render.Width;
        var spots = new List<(int X, int Y)>();
        for (int y = 0; y < m; y++)
            for (int x = 0; x < m; x++)
            {
                int ring = Math.Max(Math.Max(r - x, x - (r + n - 1)), Math.Max(r - y, y - (r + n - 1)));
                if (ring <= 0) continue;
                bool shoulder = false;
                for (int d = -TrailShoulder; d <= TrailShoulder && !shoulder; d++)
                    shoulder = trail.Contains((x + d, y)) || trail.Contains((x, y + d));
                if (shoulder) continue;
                float chance = Mathf.Lerp(RimTreeChanceNear, RimTreeChanceFar, r <= 1 ? 1f : (ring - 1f) / (r - 1f));
                if (MapHash.Hash01(x, y, render.Seed + TreeSalt) < chance) spots.Add((x, y));
            }
        return spots;
    }

    public override Node3D BuildDoor(DungeonRoomPrefab room, Node3D door, DoorSide side)
    {
        var gate = new Node3D { Name = "Gate" };
        door.AddChild(gate);
        if (GateScene == null) return gate;
        for (int i = -1; i <= 1; i++)
        {
            var bramble = GateScene.Instantiate<Node3D>();
            bramble.Position = new Vector3(i, 0, 0);
            gate.AddChild(bramble);
        }
        return gate;
    }

    public override void _Notification(int what)
    {
        if (what == NotificationVisibilityChanged && _fader != null)
            _fader.SetProcess(IsVisibleInTree());
    }
}
