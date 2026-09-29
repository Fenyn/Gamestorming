using System;
using System.Collections.Generic;
using Delve.Data;
using Delve.Terrain;
using Godot;
using PF2e.MapGen;

namespace Delve.Dungeon;

/// <summary>A dirt trail through woodland between two glades' rims. Each glade already draws its own
/// trail out through its margin (<see cref="RoomShell.Margin"/>), so this only fills the stretch
/// left between the margins.</summary>
public partial class TrailPassage : Node3D, IPassage
{
    [Export] public PackedScene[] TreeScenes { get; set; } = Array.Empty<PackedScene>();
    [Export] public float[] TreeWeights { get; set; } = Array.Empty<float>();

    /// <summary>Woodland tiles either side of the three-wide trail.</summary>
    [Export] public int Verge { get; set; } = 3;

    /// <summary>Tiles beside the trail kept clear of trees.</summary>
    [Export] public int Shoulder { get; set; } = 2;

    [Export(PropertyHint.Range, "0,1,0.05")] public float TreeChance { get; set; } = 0.7f;

    private const int TreeSalt = 0x7A11;

    public void Build(DungeonRoomPrefab from, Vector3 a, Vector3 b)
    {
        int margin = from.Shell?.Margin ?? 0;
        bool horizontal = Mathf.Abs(a.X - b.X) > Mathf.Abs(a.Z - b.Z);
        int start = Mathf.FloorToInt(Mathf.Min(horizontal ? a.X : a.Z, horizontal ? b.X : b.Z)) + margin + 1;
        int end = Mathf.FloorToInt(Mathf.Max(horizontal ? a.X : a.Z, horizontal ? b.X : b.Z)) - margin - 1;
        int length = end - start + 1;
        if (length <= 0) return;
        int centre = Mathf.FloorToInt(horizontal ? a.Z : a.X), side = Verge + 1, span = 2 * side + 1;
        var layout = new MapLayout { Seed = start * 7919 + centre, Name = "trail", BorderWidth = 0 };
        layout.Initialize(horizontal ? length : span, horizontal ? span : length);
        var trees = new List<(int X, int Y)>();
        for (int along = 0; along < length; along++)
            for (int across = 0; across < span; across++)
            {
                int x = horizontal ? along : across, y = horizontal ? across : along;
                int offset = Math.Abs(across - side);
                GladeGeneration.SetFlat(layout, x, y, TileRole.Ground, offset <= 1 ? SurfaceType.Dirt : SurfaceType.Grass, 0);
                if (offset > 1 + Shoulder && MapHash.Hash01(x, y, layout.Seed + TreeSalt) < TreeChance) trees.Add((x, y));
            }
        var origin = horizontal ? new Vector2(start, centre - side) : new Vector2(centre - side, start);
        var map = _map = new MapView3D();
        AddChild(map);
        map.Build(layout, MapThemes.Forest, new TerrainMeshOptions { WorldOrigin = origin });
        var fader = _fader = new TreeFader { Name = "TreeFader" };
        AddChild(fader);
        var heights = new TerrainHeightMap(layout, MapThemes.Forest.HeightScale);
        var scatter = TreeScatter.Build(new SkirtResult(layout, 0, trees), heights, MapThemes.Forest.HeightScale, fader,
            new TreeMix(TreeScenes, TreeWeights, Array.Empty<float>()), new TreeMix(Array.Empty<PackedScene>(), Array.Empty<float>(), Array.Empty<float>()),
            new List<(int X, int Y)>());
        if (scatter == null) return;
        if (from.Shell?.WoodTint is { } tint)
            foreach (var tree in fader.Trees) tree.Tint *= tint;
        scatter.Position = new Vector3(origin.X, 0, origin.Y);
        AddChild(scatter);
    }

    private MapView3D? _map;
    private TreeFader? _fader;

    public void SetLight(float light)
    {
        _map?.SetLight(light);
        if (_fader == null) return;
        foreach (var tree in _fader.Trees) tree.SetLight(light);
    }

    public void Focus(Aabb box) => _fader?.Retarget(box);

    public void Cutaway(Camera3D camera) { }
}
