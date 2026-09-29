using Godot;

namespace Delve.Dungeon;

/// <summary>What joins two open doorways: stone corridor in the station, a trail in the forest.</summary>
public interface IPassage
{
    /// <summary>Build between two doorway centres in world space. <paramref name="from"/> is the
    /// room on the first side, for its palette.</summary>
    void Build(DungeonRoomPrefab from, Vector3 a, Vector3 b);

    void Cutaway(Camera3D camera);

    /// <summary>Fog-of-war brightness, between the tiers of the two rooms it joins.</summary>
    void SetLight(float light);

    /// <summary>World box of the room the party stands in, so trees in front of it fade.</summary>
    void Focus(Aabb box);
}
