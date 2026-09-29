using System;
using System.Collections.Generic;
using System.Linq;
using Delve.Data;
using Delve.Props;
using Delve.Terrain;
using Godot;
using PF2e.MapGen;

namespace Delve.Dungeon;

/// <summary>A forest glade: a generated forest board inside a ring of trees, a rim of woodland
/// around it, and a dirt trail leaving each mouth. Brambles close the mouths during a fight.</summary>
public partial class GladeShell : RoomShell
{
    /// <summary>Floor whose glade recipes this shell builds (<see cref="GladeRecipes.For"/>).</summary>
    [Export] public string FloorId { get; set; } = "grassland";

    /// <summary>Tiles from the glade centre to the middle of each deployment box.</summary>
    [Export] public int ZoneHalf { get; set; } = RoomGeneration.ZoneHalf;

    /// <summary>Tree scenes for the ring and the clumps inside the glade, with weights. Narrow
    /// sprites, so a trunk does not hide the tiles around it.</summary>
    [Export] public PackedScene[] BoardTreeScenes { get; set; } = Array.Empty<PackedScene>();
    [Export] public float[] BoardTreeWeights { get; set; } = Array.Empty<float>();

    /// <summary>Tree scenes for the woodland rim outside the ring, with weights and the nearest rim
    /// ring each may stand on.</summary>
    [Export] public PackedScene[] RimTreeScenes { get; set; } = Array.Empty<PackedScene>();
    [Export] public float[] RimTreeWeights { get; set; } = Array.Empty<float>();
    [Export] public float[] RimTreeMinRings { get; set; } = Array.Empty<float>();

    /// <summary>Broad trees that stand on a 2x2 block inside a fight glade, like a Large creature,
    /// with weights.</summary>
    [Export] public PackedScene[] BigTreeScenes { get; set; } = Array.Empty<PackedScene>();
    [Export] public float[] BigTreeWeights { get; set; } = Array.Empty<float>();

    /// <summary>Colour every tree of this floor is multiplied by.</summary>
    [Export] public Color TreeTint { get; set; } = Colors.White;

    /// <summary>Tiles of woodland drawn outside the tree ring.</summary>
    [Export] public int RimDepth { get; set; } = 3;

    /// <summary>Chance a rim tile holds a tree, on the first rim ring and on the ones beyond. The
    /// outermost ring is always full, so the drawn forest has no bare edge.</summary>
    [Export(PropertyHint.Range, "0,1,0.05")] public float RimTreeChanceNear { get; set; } = 0.25f;
    [Export(PropertyHint.Range, "0,1,0.05")] public float RimTreeChanceFar { get; set; } = 0.8f;

    /// <summary>Rim tiles either side of a trail kept clear of trees.</summary>
    [Export] public int TrailShoulder { get; set; } = 2;

    /// <summary>Bramble that closes a mouth during a fight, <see cref="GateBrambles"/> across it.</summary>
    [Export] public PackedScene? GateScene { get; set; }
    [Export] public int GateBrambles { get; set; } = 4;
    [Export] public Color GateTint { get; set; } = new(0.62f, 0.42f, 0.40f);

    private const int TreeSalt = 0x61AD;

    /// <summary>Interior from which a glade uses <see cref="WideZoneHalf"/>: front rows 8 tiles apart.</summary>
    private const int WideGlade = 18, WideZoneHalf = 5;
    private TreeFader _fader = null!;
    private MapView3D? _map;
    private readonly List<TreeProp> _gates = new();

    public override float HeightScale => MapThemes.Forest.HeightScale;
    public override string BiomeId => MapThemes.Forest.BiomeId;
    public override bool LightPool => false;
    public override int Margin => RimDepth;
    public override Color? WoodTint => TreeTint;

    public override GeneratedRoom Generate(DungeonRoomPrefab room, int seed, int size, IReadOnlyList<DoorSide> doors, bool openLayout)
    {
        var recipe = GladeRecipes.For(FloorId, room.PurposeOverride ?? room.Purpose);
        // A big guardian glade opens the start gap too, so its landmarks sit between the sides.
        int half = recipe.Size >= WideGlade ? Math.Max(ZoneHalf, WideZoneHalf) : ZoneHalf;
        return GladeGeneration.Generate(seed, recipe.Size > 0 ? recipe.Size : size, doors, new GladeShape(recipe, room.Combat, half));
    }

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
        var landmarks = GladeGeneration.LandmarkTiles(room.Generated.Props).Select(t => (t.X + r, t.Y + r)).ToHashSet();
        var wallTrees = TreeWalls.Convert(render).Where(t => !landmarks.Contains(t)).ToList();
        var heights = new TerrainHeightMap(render, HeightScale);
        _map = new MapView3D();
        AddChild(_map);
        _map.Build(render, MapThemes.Forest, new TerrainMeshOptions
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
        if (trees != null) AddChild(trees);
        PlantBigTrees(room);
        foreach (var tree in _fader.Trees) tree.Tint *= TreeTint;
    }

    /// <summary>One broad tree centred on each 2x2 block the glade reserved for it.</summary>
    private void PlantBigTrees(DungeonRoomPrefab room)
    {
        if (BigTreeScenes.Length == 0) return;
        var grove = new Node3D { Name = "BigTrees" };
        foreach (var prop in room.Generated.Props.Where(p => p.Kind == GladeGeneration.BigTree))
        {
            var corner = new PF2e.Vector2Int((int)prop.X - 1, (int)prop.Y - 1);
            int pick = Pick(BigTreeScenes.Length, BigTreeWeights, MapHash.Hash01(corner.x, corner.y, room.Generated.Layout.Seed + TreeSalt));
            if (BigTreeScenes[pick].Instantiate() is not TreeProp tree) continue;
            tree.Position = new Vector3(prop.X, GridSpace.GridToWorld(corner, room.Heights).Y, prop.Y);
            grove.AddChild(tree);
            _fader.Track(tree);
        }
        AddChild(grove);
    }

    private static int Pick(int count, float[] weights, float roll)
    {
        float Weight(int i) => i < weights.Length ? Mathf.Max(0f, weights[i]) : 1f;
        float target = roll * Enumerable.Range(0, count).Sum(Weight);
        for (int i = 0; i < count; i++)
            if ((target -= Weight(i)) <= 0f) return i;
        return count - 1;
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
                float chance = ring == r ? 1f : Mathf.Lerp(RimTreeChanceNear, RimTreeChanceFar, r <= 2 ? 1f : (ring - 1f) / (r - 2f));
                if (MapHash.Hash01(x, y, render.Seed + TreeSalt) < chance) spots.Add((x, y));
            }
        return spots;
    }

    public override Node3D BuildDoor(DungeonRoomPrefab room, Node3D door, DoorSide side)
    {
        var gate = new Node3D { Name = "Gate" };
        door.AddChild(gate);
        if (GateScene == null) return gate;
        for (int i = 0; i < GateBrambles; i++)
        {
            var bramble = GateScene.Instantiate<Node3D>();
            bramble.Position = new Vector3(i - (GateBrambles - 1) / 2f, 0, 0);
            if (bramble is TreeProp prop)
            {
                prop.Tint *= GateTint;
                _gates.Add(prop);
            }
            gate.AddChild(bramble);
        }
        return gate;
    }

    public override void SetLight(float light)
    {
        _map?.SetLight(light);
        foreach (var tree in _fader.Trees) tree.SetLight(light);
        foreach (var bramble in _gates) bramble.SetLight(light);
    }

    public override void Focus(Aabb box) => _fader.Retarget(box);

    public override void _Notification(int what)
    {
        if (what == NotificationVisibilityChanged && _fader != null)
            _fader.SetProcess(IsVisibleInTree());
    }
}
