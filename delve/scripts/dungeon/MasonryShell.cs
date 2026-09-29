using System;
using System.Collections.Generic;
using System.Linq;
using Delve.Data;
using Delve.Terrain;
using Godot;
using PF2e.MapGen;

namespace Delve.Dungeon;

/// <summary>The ward station's stone room: palette-textured floor, masonry walls the camera cuts
/// away, and timber shutters in every doorway.</summary>
public partial class MasonryShell : RoomShell
{
    private readonly List<(Node3D Wall, DoorSide Side)> _upperWalls = new();
    private MapView3D? _map;

    public override void SetLight(float light) => _map?.SetLight(light);

    public override float HeightScale => MapThemes.Sewer.HeightScale;
    public override string BiomeId => MapThemes.Sewer.BiomeId;

    public override GeneratedRoom Generate(DungeonRoomPrefab room, int seed, int size, IReadOnlyList<DoorSide> doors, bool openLayout)
    {
        var profile = new RoomVariation(room.MinPillarInset, room.MaxPillarInset, room.MinCover, room.MaxCover, room.DebrisCount, room.FeatureCount, room.LayoutVariant);
        return RoomGeneration.Generate(room.Family, seed, size, doors, openLayout, profile, room.PurposeOverride ?? (room.UsePurpose ? room.Purpose : null), room.History);
    }

    public override void Build(DungeonRoomPrefab room, IReadOnlyList<DoorSide> doors)
    {
        // The visual copy opens door thresholds; the tactical copy keeps them closed.
        var render = Generate(room, room.Seed, room.Size, doors, room.OpenLayout).Layout;
        foreach (var side in doors)
            foreach (var p in RoomGeneration.Threshold(render.Width, side))
                render.SetTile(p.x, p.y, TileRole.Ground);
        var map = _map = new MapView3D();
        AddChild(map);
        map.Build(render, room.Palette?.Theme() ?? MapThemes.Sewer);
        var masonry = new DungeonProp { Palette = room.Palette };
        AddChild(masonry);
        int n = room.Width, seed = room.Seed;
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
                var wall = masonry.Box(at, new(1, 1.6f, 1), room.PaletteTint("masonry"));
                _upperWalls.Add((wall, side));
                if (room.HangingBanners && i > 1 && i < n - 2 && (i + (seed & 3)) % 4 == 0)
                {
                    var banner = new MeshInstance3D
                    {
                        Mesh = new BoxMesh { Size = new(0.65f, 1.1f, 0.04f) },
                        MaterialOverride = room.Palette?.Material(Colors.White, "cloth"),
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
        }
    }

    public override Node3D BuildDoor(DungeonRoomPrefab room, Node3D door, DoorSide side)
    {
        var frame = new DungeonProp { Palette = room.Palette };
        door.AddChild(frame);
        frame.Box(new(-1.65f, 1, 0), new(0.3f, 2, 0.6f), room.PaletteTint("door_frame"));
        frame.Box(new(1.65f, 1, 0), new(0.3f, 2, 0.6f), room.PaletteTint("door_frame"));
        frame.Box(new(0, 2.1f, 0), new(3.6f, 0.25f, 0.6f), room.PaletteTint("door_frame"));
        return frame.Box(new(0, 0.9f, 0), new(3, 1.8f, 0.18f), room.PaletteTint("door_leaf"), surface: "wood");
    }

    public override void Cutaway(DungeonRoomPrefab room, Camera3D camera)
    {
        int n = room.Width;
        var relative = camera.GlobalPosition - (room.GlobalPosition + new Vector3(n / 2f, 0, n / 2f));
        foreach (var (wall, side) in _upperWalls)
            wall.Visible = side switch
            {
                DoorSide.North => relative.Z > 0,
                DoorSide.South => relative.Z < 0,
                DoorSide.West => relative.X > 0,
                _ => relative.X < 0
            };
    }
}
