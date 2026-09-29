using System.Collections.Generic;
using Godot;

namespace Delve.Dungeon;

/// <summary>What a room is built from: its tactical layout, the terrain and walls around it, and
/// what closes a doorway. <see cref="DungeonRoomPrefab"/> keeps everything the rooms share (door
/// markers, picking, props, lights). A prefab with no Shell child builds masonry.</summary>
public abstract partial class RoomShell : Node3D
{
    public abstract float HeightScale { get; }

    /// <summary>False where the setting brings its own light, so the room adds no spot pool.</summary>
    public virtual bool LightPool => true;

    public abstract GeneratedRoom Generate(DungeonRoomPrefab room, int seed, int size, IReadOnlyList<DoorSide> doors, bool openLayout);

    public abstract void Build(DungeonRoomPrefab room, IReadOnlyList<DoorSide> doors);

    /// <summary>Dress one open doorway, already placed and turned, and return the leaf that closes
    /// it during a fight.</summary>
    public abstract Node3D BuildDoor(DungeonRoomPrefab room, Node3D door, DoorSide side);

    public virtual void Cutaway(DungeonRoomPrefab room, Camera3D camera) { }
}
