using Godot;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Terrain;

/// <summary>
/// Static grid &lt;-&gt; world math for the 2.5D board. Convention (shared by the procedural
/// battle-map pipeline, PF2e.MapGen → TerrainMeshBuilder): 1 tile = 1 m, grid tile (x, y) occupies world
/// x..x+1 on X and y..y+1 on Z, the floor walk surface is at world y = 0, and grid tile (0,0)'s
/// corner is the world origin. Pure math — holds no state.
///
/// <b>1 tile = 1 m is an invariant here, not a tunable.</b> The mesh builder, the scenery placers
/// and the tile decor all emit vertices at raw tile indices (x, x + 1), so a scale factor in this
/// class would be honoured by half the pipeline only. Rescale a board with a transform on the map
/// root instead.
///
/// Elevation arrives as OVERLOADS taking a <see cref="TerrainHeightMap"/> rather than as a mutable
/// static: the flat signatures below keep their exact meaning ("walk surface at y = 0") for the flat
/// board, and terrain-aware call sites take the height map explicitly. The parameter is deliberately
/// non-nullable — a flat board passes <see cref="TerrainHeightMap.Flat"/>, so both paths run the same
/// code and no call site ever has to invent a null check.
/// </summary>
public static class GridSpace
{
    /// <summary>Center of a grid tile in world space (units stand here).</summary>
    public static Vector3 GridToWorld(PF2eVec p) =>
        new(p.x + 0.5f, 0f, p.y + 0.5f);

    /// <summary>Center of a grid tile, standing on the terrain surface described by <paramref name="height"/>.</summary>
    public static Vector3 GridToWorld(PF2eVec p, TerrainHeightMap height) =>
        new(p.x + 0.5f, height.CenterY(p), p.y + 0.5f);

    /// <summary>Board center in world space, for the orbit camera pivot.</summary>
    public static Vector3 BoardCenter(int width, int height) =>
        new(width * 0.5f, 0f, height * 0.5f);

    /// <summary>
    /// Board center for the orbit camera pivot, raised to the mean walkable height so the camera
    /// orbits the ground the fight happens on rather than the y = 0 plane under a raised map.
    /// </summary>
    public static Vector3 BoardCenter(int width, int height, TerrainHeightMap heightMap) =>
        new(width * 0.5f, heightMap.MeanCenterY, height * 0.5f);

    /// <summary>Floor a world point onto its grid tile (no bounds check).</summary>
    public static PF2eVec WorldToGrid(Vector3 world) =>
        new(Mathf.FloorToInt(world.X), Mathf.FloorToInt(world.Z));

    /// <summary>
    /// Cast a screen ray from <paramref name="camera"/> onto the flat floor plane (y = 0) and
    /// return the grid tile it lands on. False if the ray is parallel/above the plane or the hit
    /// falls outside the [0,width) x [0,height) tile bounds. Flat boards only — boards with terrain
    /// use GridInput3D's physics raycast against the terrain collider instead.
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
