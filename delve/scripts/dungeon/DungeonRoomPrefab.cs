using System;
using System.Collections.Generic;
using System.Linq;
using Delve.Data;
using Delve.Terrain;
using Delve.UI;
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

    /// <summary>The glowing threshold tile in each open doorway (scenes/dungeon/door_marker.tscn).</summary>
    [Export] public PackedScene DoorMarkerScene { get; set; } = null!;

    /// <summary>Metres the threshold tile floats above the floor, clear of z-fighting.</summary>
    [Export] public float DoorMarkerLift { get; set; } = 0.04f;
    [Export] public bool UsePurpose { get; set; }
    [Export] public RoomPurpose Purpose { get; set; }
    public RoomPurpose? PurposeOverride { get; set; }
    public StationHistory History { get; set; } = StationHistory.Evacuated;
    [Export] public DungeonPalette? Palette { get; set; }

    public Color PaletteTint(string key) => Palette?.Tint(key) ?? Colors.Magenta;
    [Export] public int FeatureCount { get; set; } = 4;
    [Export(PropertyHint.Range, "-1,2,1")] public int LayoutVariant { get; set; } = -1;
    [Export] public bool HangingBanners { get; set; }
    public GeneratedRoom Generated { get; private set; } = null!;
    public TerrainHeightMap Heights { get; private set; } = null!;
    public int Width => Generated.Layout.Width;
    public Dictionary<DoorSide, Node3D> DoorLeaves { get; } = new();
    private readonly Dictionary<DoorSide, Vector3> _leafRest = new();
    public DoorSide? HoveredDoor { get; private set; }

    /// <summary>What the room is built from. Left unset, the prefab builds masonry.</summary>
    [Export] public RoomShell? Shell { get; set; }
    public int Seed { get; private set; }
    public int Size { get; private set; }
    public bool OpenLayout { get; private set; }
    private readonly List<DungeonProp> _focals = new();
    private readonly List<OmniLight3D> _lamps = new();
    private readonly Dictionary<DoorSide, Area3D> _doorAreas = new();
    private readonly Dictionary<DoorSide, MeshInstance3D> _doorMarkers = new();
    private bool _resolved;
    public void Generate(int seed, IReadOnlyList<DoorSide> doors, int sizeOverride = 0, bool openLayout = false)
    {
        Seed = seed;
        OpenLayout = openLayout;
        Size = sizeOverride > 0 ? sizeOverride : SizeVariants.Length > 0 ? SizeVariants[new Random(Delve.Run.RunRng.StableSeed(seed, 0, "size")).Next(SizeVariants.Length)] : InteriorSize;
        if (Shell == null) AddChild(Shell = new MasonryShell { Name = "Shell" });
        Generated = Shell.Generate(this, seed, Size, doors, openLayout);
        Heights = new TerrainHeightMap(Generated.Layout, Shell.HeightScale);
        Shell.Build(this, doors);
        foreach (var side in doors)
        {
            var door = new Node3D
            {
                Position = DoorPosition(side),
                RotationDegrees = new Vector3(0, side is DoorSide.East or DoorSide.West ? 90 : 0, 0)
            };
            AddChild(door);
            var marker = DoorMarkerScene.Instantiate<MeshInstance3D>();
            marker.Position = new Vector3(0, DoorMarkerLift, 0);
            door.AddChild(marker);
            _doorMarkers[side] = marker;
            var leaf = Shell.BuildDoor(this, door, side);
            DoorLeaves[side] = leaf;
            _leafRest[side] = leaf.Position;
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
            _lamps.AddRange(prop.Lamps);
            if (p.Kind is "shrine" or "cache" or "collapse" or "camp" or "entrance")
                _focals.Add(prop);
        }
        if (Shell.LightPool) AddLightPool();
    }

    public Vector3 DoorPosition(DoorSide side) => side switch
    {
        DoorSide.North => new(Width / 2 + 0.5f, 0, 0.5f),
        DoorSide.South => new(Width / 2 + 0.5f, 0, Width - 0.5f),
        DoorSide.West => new(0.5f, 0, Width / 2 + 0.5f),
        _ => new(Width - 0.5f, 0, Width / 2 + 0.5f)};
    /// <summary>Scale on every lamp in the room once it is cleared. Above 1, so a cleared room reads
    /// as made safe rather than abandoned.</summary>
    [Export] public float ResolvedLightScale { get; set; } = 1.3f;

    [Export] public double ResolvedLightSeconds { get; set; } = 0.6;


    /// <summary>Every lamp's position in room space, for effects that rise from the lamps.</summary>
    public IReadOnlyList<Vector3> LampPositions => _lamps.Select(l => ToLocal(l.GlobalPosition)).ToArray();

    public void SetResolved()
    {
        if (_resolved)
            return;
        _resolved = true;
        foreach (var focal in _focals)
            focal.Resolve();
        if (_lamps.Count == 0) return;
        if (!IsInsideTree())
        {
            foreach (var lamp in _lamps) lamp.LightEnergy *= ResolvedLightScale;
            return;
        }
        var warm = CreateTween().SetParallel(true);
        foreach (var lamp in _lamps)
            warm.TweenProperty(lamp, "light_energy", lamp.LightEnergy * ResolvedLightScale, ResolvedLightSeconds)
                .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
    }

    /// <summary>Time a door shutter takes to sink into the floor or rise back.</summary>
    [Export] public double DoorShutterSeconds { get; set; } = 0.35;

    /// <summary>How far below its closed height an open shutter rests, fully under the floor.</summary>
    [Export] public float DoorShutterDrop { get; set; } = 1.9f;

    private Tween? _doorTween;
    private bool? _doorsOpen;

    /// <summary>Sinks the shutters into the floor, or raises them. Instant snaps without a tween.</summary>
    public void SetDoorsOpen(bool open, bool instant = false)
    {
        if (_doorsOpen == open) return;
        _doorsOpen = open;
        _doorTween?.Kill();
        _doorTween = null;
        foreach (var (side, leaf) in DoorLeaves)
        {
            leaf.Visible = true;
            float target = _leafRest[side].Y - (open ? DoorShutterDrop : 0);
            if (instant || !IsInsideTree())
            {
                leaf.Position = leaf.Position with { Y = target };
                leaf.Visible = !open;
                continue;
            }
            _doorTween ??= CreateTween().SetParallel(true);
            _doorTween.TweenProperty(leaf, "position:y", target, DoorShutterSeconds)
                .SetTrans(Tween.TransitionType.Back).SetEase(open ? Tween.EaseType.In : Tween.EaseType.Out);
        }
        if (open) _doorTween?.Chain().TweenCallback(Callable.From(() =>
        {
            foreach (var leaf in DoorLeaves.Values) leaf.Visible = false;
        }));
    }

    public bool DoorsOpen => _doorsOpen == true;

    public void SetTraversalActive(bool active)
    {
        foreach (var (side, area) in _doorAreas)
        {
            area.CollisionLayer = active ? 4u : 0u;
            _doorMarkers[side].Visible = active;
        }
        SetHoveredDoor(null);
    }

    /// <summary>The hovered threshold reaches further into the room, like a lit path.</summary>
    [Export] public float HoveredDoorDepthScale { get; set; } = 1.7f;

    private const string TintUniform = "tint";

    public void SetHoveredDoor(DoorSide? hovered)
    {
        if (hovered == HoveredDoor && hovered != null) return;
        HoveredDoor = hovered;
        foreach (var (side, marker) in _doorMarkers)
        {
            bool selected = hovered == side;
            marker.Scale = new Vector3(1, 1, selected ? HoveredDoorDepthScale : 1);
            (marker.GetSurfaceOverrideMaterial(0) as ShaderMaterial)?.SetShaderParameter(TintUniform, UiColors.BoardDoor(selected));
        }
    }

    public void Cutaway(Camera3D camera) => Shell?.Cutaway(this, camera);
}
