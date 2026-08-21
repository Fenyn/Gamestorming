using Delve.Combat.Map;
using Godot;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Combat;

/// <summary>
/// Static grid &lt;-&gt; world math for the 2.5D combat board. Convention (shared by the procedural
/// battle-map pipeline, PF2e.MapGen → TerrainMeshBuilder): 1 tile = 1 m, grid tile (x, y) occupies world
/// x..x+1 on X and y..y+1 on Z, the floor walk surface is at world y = 0, and grid tile (0,0)'s
/// corner is the world origin. Pure math — holds no state.
///
/// Elevation arrives as OVERLOADS taking a <see cref="TerrainHeightMap"/> rather than as a mutable
/// static: the flat signatures below keep their exact meaning ("walk surface at y = 0") for the flat
/// board, and terrain-aware call sites take the height map explicitly. The parameter is deliberately
/// non-nullable — a flat board passes <see cref="TerrainHeightMap.Flat"/>, so both paths run the same
/// code and no call site ever has to invent a null check.
/// </summary>
public static class GridSpace
{
    public const float TileSize = 1f;

    /// <summary>Center of a grid tile in world space (units stand here).</summary>
    public static Vector3 GridToWorld(PF2eVec p) =>
        new(p.x * TileSize + TileSize * 0.5f, 0f, p.y * TileSize + TileSize * 0.5f);

    /// <summary>Center of a grid tile, standing on the terrain surface described by <paramref name="height"/>.</summary>
    public static Vector3 GridToWorld(PF2eVec p, TerrainHeightMap height) =>
        new(p.x * TileSize + TileSize * 0.5f, height.CenterY(p), p.y * TileSize + TileSize * 0.5f);

    /// <summary>World-space corner (min X, min Z) of a grid tile — used to lay flat overlays.</summary>
    public static Vector3 GridToWorldCorner(PF2eVec p) =>
        new(p.x * TileSize, 0f, p.y * TileSize);

    /// <summary>
    /// World-space corner (min X, min Z) of a grid tile, lifted to the tile's CENTRE height. The tile
    /// corner's own elevation is deliberately not used: an overlay anchored here is positioned by its
    /// centre and carries per-corner offsets in its own mesh.
    /// </summary>
    public static Vector3 GridToWorldCorner(PF2eVec p, TerrainHeightMap height) =>
        new(p.x * TileSize, height.CenterY(p), p.y * TileSize);

    /// <summary>Board center in world space, for the orbit camera pivot.</summary>
    public static Vector3 BoardCenter(int width, int height) =>
        new(width * TileSize * 0.5f, 0f, height * TileSize * 0.5f);

    /// <summary>
    /// Board center for the orbit camera pivot, raised to the mean walkable height so the camera
    /// orbits the ground the fight happens on rather than the y = 0 plane under a raised map.
    /// </summary>
    public static Vector3 BoardCenter(int width, int height, TerrainHeightMap heightMap) =>
        new(width * TileSize * 0.5f, heightMap.MeanCenterY, height * TileSize * 0.5f);

    /// <summary>Floor a world point onto its grid tile (no bounds check).</summary>
    public static PF2eVec WorldToGrid(Vector3 world) =>
        new(Mathf.FloorToInt(world.X / TileSize), Mathf.FloorToInt(world.Z / TileSize));

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
