using Godot;
using PF2eVec = PF2e.Vector2Int;

namespace Bulwark.Combat;

/// <summary>
/// Static grid &lt;-&gt; world math for the 2.5D combat board. Convention (matches the Crocotile 3D
/// export spec in assets/maps/README.md): 1 tile = 1 m, grid tile (x, y) occupies world
/// x..x+1 on X and y..y+1 on Z, the floor walk surface is at world y = 0, and grid tile (0,0)'s
/// corner is the world origin. Pure math — holds no state.
/// </summary>
public static class GridSpace
{
    public const float TileSize = 1f;

    /// <summary>Center of a grid tile in world space (units stand here).</summary>
    public static Vector3 GridToWorld(PF2eVec p) =>
        new(p.x * TileSize + TileSize * 0.5f, 0f, p.y * TileSize + TileSize * 0.5f);

    /// <summary>World-space corner (min X, min Z) of a grid tile — used to lay flat overlays.</summary>
    public static Vector3 GridToWorldCorner(PF2eVec p) =>
        new(p.x * TileSize, 0f, p.y * TileSize);

    /// <summary>Board center in world space, for the orbit camera pivot.</summary>
    public static Vector3 BoardCenter(int width, int height) =>
        new(width * TileSize * 0.5f, 0f, height * TileSize * 0.5f);

    /// <summary>Floor a world point onto its grid tile (no bounds check).</summary>
    public static PF2eVec WorldToGrid(Vector3 world) =>
        new(Mathf.FloorToInt(world.X / TileSize), Mathf.FloorToInt(world.Z / TileSize));

    /// <summary>
    /// Cast a screen ray from <paramref name="camera"/> onto the flat floor plane (y = 0) and
    /// return the grid tile it lands on. False if the ray is parallel/above the plane or the hit
    /// falls outside the [0,width) x [0,height) tile bounds. Flat maps only — Crocotile maps with
    /// elevation will need a physics raycast against the floor collider instead.
    /// </summary>
    public static bool TryRayToTile(Camera3D camera, Vector2 screenPos, int width, int height, out PF2eVec tile)
    {
        tile = default;
        if (camera == null) return false;

        Vector3 origin = camera.ProjectRayOrigin(screenPos);
        Vector3 dir = camera.ProjectRayNormal(screenPos);
        if (Mathf.IsZeroApprox(dir.Y)) return false;

        float t = -origin.Y / dir.Y;
        if (t <= 0f) return false;

        Vector3 hit = origin + dir * t;
        var cell = WorldToGrid(hit);
        if (cell.x < 0 || cell.y < 0 || cell.x >= width || cell.y >= height) return false;

        tile = cell;
        return true;
    }
}
