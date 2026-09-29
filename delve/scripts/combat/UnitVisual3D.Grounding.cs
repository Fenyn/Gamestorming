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
        // The board's transform is this token's global transform with its own local one taken out.
        var board = IsInsideTree() ? GlobalTransform * Transform.AffineInverse() : Transform3D.Identity;
        _ring.SetSurface(anchor, Character.TileWidth, height, board);
    }
}
