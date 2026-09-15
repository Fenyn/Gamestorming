using System;
using System.Collections.Generic;
using System.Linq;
using Delve.Data;
using Delve.Terrain;
using Godot;
using PF2e.Grid;
using PF2e.MapGen;

namespace Delve.Dungeon;
/// <summary>The prefab owns both its procedural interior and all of its dressing.</summary>
public partial class DungeonRoomPrefab : Node3D
{
    [Export]
    public RoomFamily Family { get; set; }

    [Export]
    public int InteriorSize { get; set; } = 14;

    [Export]
    public int[] SizeVariants { get; set; } = Array.Empty<int>();

    [Export]
    public int MinPillarInset { get; set; } = 3;

    [Export]
    public int MaxPillarInset { get; set; } = 4;

    [Export]
    public int MinCover { get; set; } = 2;

    [Export]
    public int MaxCover { get; set; } = 4;

    [Export]
    public int DebrisCount { get; set; } = 8;

    [Export]
    public PackedScene PropScene { get; set; } = null!;
    [Export] public bool UsePurpose { get; set; }
    [Export] public RoomPurpose Purpose { get; set; }
    public RoomPurpose? PurposeOverride { get; set; }
    public StationHistory History { get; set; } = StationHistory.Evacuated;
    [Export] public DungeonPalette? Palette { get; set; }
    [Export] public int FeatureCount { get; set; } = 4;
    [Export(PropertyHint.Range, "-1,2,1")] public int LayoutVariant { get; set; } = -1;
    [Export] public bool HangingBanners { get; set; }
    public GeneratedRoom Generated { get; private set; } = null!;
    public TerrainHeightMap Heights { get; private set; } = null!;
    public int Width => Generated.Layout.Width;
    public Dictionary<DoorSide, Node3D> DoorLeaves { get; } = new();
    public DoorSide? HoveredDoor { get; private set; }

    private readonly List<(Node3D Wall, DoorSide Side)> _upperWalls = new();
    private readonly List<DungeonProp> _focals = new();
    private readonly Dictionary<DoorSide, Area3D> _doorAreas = new();
    private readonly Dictionary<DoorSide, MeshInstance3D> _doorMarkers = new();
    private readonly Dictionary<DoorSide, Label3D> _doorLabels = new();
    private bool _resolved;
    public void Generate(int seed, IReadOnlyList<DoorSide> doors, int sizeOverride = 0, bool openLayout = false)
    {
        int size = sizeOverride > 0 ? sizeOverride : SizeVariants.Length > 0 ? SizeVariants[new Random(Delve.Run.RunRng.StableSeed(seed, 0, "size")).Next(SizeVariants.Length)] : InteriorSize;
        var profile = new RoomVariation(MinPillarInset, MaxPillarInset, MinCover, MaxCover, DebrisCount, FeatureCount, LayoutVariant);
        Generated = RoomGeneration.Generate(Family, seed, size, doors, openLayout, profile, PurposeOverride ?? (UsePurpose ? Purpose : null), History);
        Heights = new TerrainHeightMap(Generated.Layout, MapThemes.Sewer.HeightScale);
        // The visual copy opens door thresholds; the tactical copy keeps them closed.
        var render = RoomGeneration.Generate(Family, seed, size, doors, openLayout, profile, PurposeOverride ?? (UsePurpose ? Purpose : null), History).Layout;
        foreach (var side in doors)
            foreach (var p in RoomGeneration.Threshold(render.Width, side))
                render.SetTile(p.x, p.y, TileRole.Ground);
        var map = new MapView3D();
        AddChild(map);
        map.Build(render, Palette?.Theme() ?? MapThemes.Sewer);
        var masonry = new DungeonProp { Palette = Palette };
        AddChild(masonry);
        int n = Width;
        foreach (DoorSide side in Enum.GetValues<DoorSide>())
        {
            bool open = doors.Contains(side);
            for (int i = 0; i < n; i++)
            {
                if (open && i >= n / 2 - 1 && i <= n / 2 + 1)
                    continue;
                var at = side switch
                {
                    DoorSide.North => new Vector3(i + 0.5f, 1.3f, 0.5f),
                    DoorSide.South => new(i + 0.5f, 1.3f, n - 0.5f),
                    DoorSide.West => new(0.5f, 1.3f, i + 0.5f),
                    _ => new(n - 0.5f, 1.3f, i + 0.5f)};
                var wall = masonry.Box(at, new(1, 1.6f, 1), new Color("59606d"));
                _upperWalls.Add((wall, side));
                if (HangingBanners && i > 1 && i < n - 2 && (i + (seed & 3)) % 4 == 0)
                {
                    var banner = new MeshInstance3D
                    {
                        Mesh = new BoxMesh { Size = new(0.65f, 1.1f, 0.04f) },
                        MaterialOverride = Palette?.Material(Colors.White, "cloth"),
                        Position = side switch
                        {
                            DoorSide.North => new(0, 0.1f, 0.52f),
                            DoorSide.South => new(0, 0.1f, -0.52f),
                            DoorSide.West => new(0.52f, 0.1f, 0),
                            _ => new(-0.52f, 0.1f, 0)
                        },
                        RotationDegrees = new(0, side is DoorSide.East or DoorSide.West ? 90 : 0, 0)
                    };
                    wall.AddChild(banner); // Cutaway hides the furnishing with its wall.
                }
            }

            if (!open)
                continue;
            var pos = DoorPosition(side);
            var door = new Node3D
            {
                Position = pos,
                RotationDegrees = new Vector3(0, side is DoorSide.East or DoorSide.West ? 90 : 0, 0)
            };
            AddChild(door);
            var frame = new DungeonProp { Palette = Palette };
            door.AddChild(frame);
            frame.Box(new(-1.65f, 1, 0), new(0.3f, 2, 0.6f), new Color("92908a"));
            frame.Box(new(1.65f, 1, 0), new(0.3f, 2, 0.6f), new Color("92908a"));
            frame.Box(new(0, 2.1f, 0), new(3.6f, 0.25f, 0.6f), new Color("92908a"));
            var marker = frame.Box(new(0, 0.035f, 0), new(3, 0.07f, 0.75f), new Color("76b5ad"), true);
            _doorMarkers[side] = marker;
            var label = new Label3D
            {
                Position = new(0, 2.7f, 0), FontSize = 30, PixelSize = 0.008f,
                Billboard = BaseMaterial3D.BillboardModeEnum.Enabled, NoDepthTest = true,
                OutlineSize = 8, Visible = false
            };
            door.AddChild(label);
            _doorLabels[side] = label;
            var leaf = frame.Box(new(0, 0.9f, 0), new(3, 1.8f, 0.18f), new Color("5b4939"), surface: "wood");
            DoorLeaves[side] = leaf;
            var area = new Area3D
            {
                CollisionLayer = 0,
                CollisionMask = 0,
                InputRayPickable = true
            };
            area.SetMeta("door_side", (int)side);
            _doorAreas[side] = area;
            door.AddChild(area);
            area.AddChild(new CollisionShape3D { Position = new(0, 1, 0), Shape = new BoxShape3D { Size = new(3.4f, 2.4f, 0.8f) } });
        }

        foreach (var p in Generated.Props)
        {
            var prop = PropScene.Instantiate<DungeonProp>();
            AddChild(prop);
            prop.Palette = Palette;
            prop.Build(p);
            if (p.Kind is "shrine" or "cache" or "collapse" or "camp" or "entrance")
                _focals.Add(prop);
        }
    }

    public Vector3 DoorPosition(DoorSide side) => side switch
    {
        DoorSide.North => new(Width / 2 + 0.5f, 0, 0.5f),
        DoorSide.South => new(Width / 2 + 0.5f, 0, Width - 0.5f),
        DoorSide.West => new(0.5f, 0, Width / 2 + 0.5f),
        _ => new(Width - 0.5f, 0, Width / 2 + 0.5f)};
    public void SetResolved()
    {
        if (_resolved)
            return;
        _resolved = true;
        foreach (var focal in _focals)
            focal.Resolve();
    }

    public void SetDoorsOpen(bool open)
    {
        foreach (var leaf in DoorLeaves.Values)
            leaf.Visible = !open;
    }

    public void SetTraversalActive(bool active)
    {
        foreach (var (side, area) in _doorAreas)
        {
            area.CollisionLayer = active ? 4u : 0u;
            _doorMarkers[side].Visible = active;
        }
        SetHoveredDoor(null, "");
    }

    public void SetHoveredDoor(DoorSide? hovered, string text)
    {
        HoveredDoor = hovered;
        foreach (var (side, marker) in _doorMarkers)
        {
            bool selected = hovered == side;
            marker.Scale = new Vector3(1, 1, selected ? 1.7f : 1);
            if (marker.MaterialOverride is StandardMaterial3D material)
            {
                material.AlbedoColor = material.Emission = new Color(selected ? "edc881" : "76b5ad");
                material.EmissionEnergyMultiplier = selected ? 1 : 0.25f;
            }
            _doorLabels[side].Visible = selected;
            if (selected) _doorLabels[side].Text = text;
        }
    }

    public void Cutaway(Camera3D camera)
    {
        var relative = camera.GlobalPosition - (GlobalPosition + new Vector3(Width / 2f, 0, Width / 2f));
        foreach (var(wall, side)in _upperWalls)
            wall.Visible = side switch
            {
                DoorSide.North => relative.Z > 0,
                DoorSide.South => relative.Z < 0,
                DoorSide.West => relative.X > 0,
                _ => relative.X < 0
            };
    }
}
