using Delve.Terrain;
using Godot;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Combat;

public partial class UnitVisual3D
{
    /// <summary>Draw the body at a low supporting surface; the rules anchor remains on Character.
    /// Called at spawn and each completed movement segment, including authoritative reconciliation.</summary>
    public void PlaceOnGround(PF2eVec anchor, TerrainHeightMap height)
    {
        Position = GridSpace.CreatureBodyToWorld(anchor, Character.TileWidth, height);
        _ring.SetSurface(anchor, Character.TileWidth, height,
            GetParent() is Node3D board ? board.GlobalTransform : Transform3D.Identity);
    }
}
