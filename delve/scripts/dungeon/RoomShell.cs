using System.Collections.Generic;
using Godot;

namespace Delve.Dungeon;

/// <summary>What a room is built from: its tactical layout, the terrain and walls around it, and
/// what closes a doorway. <see cref="DungeonRoomPrefab"/> keeps everything the rooms share (door
/// markers, picking, props, lights). A prefab with no Shell child builds masonry.</summary>
public abstract partial class RoomShell : Node3D
{
    public abstract float HeightScale { get; }

    /// <summary>Map theme and look key for fights hosted in the room.</summary>
    public abstract string BiomeId { get; }

    /// <summary>False where the setting brings its own light, so the room adds no spot pool.</summary>
    public virtual bool LightPool => true;

    public abstract GeneratedRoom Generate(DungeonRoomPrefab room, int seed, int size, IReadOnlyList<DoorSide> doors, bool openLayout);

    public abstract void Build(DungeonRoomPrefab room, IReadOnlyList<DoorSide> doors);

    /// <summary>Dress one open doorway, already placed and turned, and return the leaf that closes
    /// it during a fight.</summary>
    public abstract Node3D BuildDoor(DungeonRoomPrefab room, Node3D door, DoorSide side);

    public virtual void Cutaway(DungeonRoomPrefab room, Camera3D camera) { }

    /// <summary>Tiles the shell draws outside the room on every side. Packing keeps rooms this far
    /// apart, and a passage starts where the margins end.</summary>
    public virtual int Margin => 0;

    /// <summary>Colour the setting's trees are multiplied by, for passages between its rooms; null keeps them as drawn.</summary>
    public virtual Color? WoodTint => null;

    /// <summary>Fog-of-war brightness for everything the shell drew.</summary>
    public abstract void SetLight(float light);

    /// <summary>World box of the room the party stands in, so trees in front of it fade.</summary>
    public virtual void Focus(Aabb box) { }
}
