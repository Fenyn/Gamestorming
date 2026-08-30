using Godot;

namespace Delve.Terrain;

/// <summary>A rectangle of tiles in layout coordinates.</summary>
public readonly record struct TileRect(int X, int Y, int Width, int Height)
{
    /// <summary>True when tile (<paramref name="x"/>, <paramref name="y"/>) is inside the rectangle.</summary>
    public bool Contains(int x, int y) => x >= X && y >= Y && x < X + Width && y < Y + Height;
}

/// <summary>
/// The two things a caller can vary about one terrain build, for the case the mesh is not the board
/// itself: a layout that is a board plus its generated halo (see <see cref="SkirtLayout"/>).
///
/// Both default to "the mesh IS the board", so a caller that passes nothing gets exactly the build
/// it got before this record existed.
/// </summary>
public sealed record TerrainMeshOptions
{
    /// <summary>
    /// World XZ that the layout's tile (0,0) corner sits at. <see cref="MapView3D"/> translates the
    /// built mesh here and the baked ground material samples its atlas from here, so the two can
    /// never disagree. Zero = the layout starts at the world origin.
    /// </summary>
    public Vector2 WorldOrigin { get; init; } = Vector2.Zero;

    /// <summary>
    /// Tiles that get top-surface grid lines, or null for the whole layout. The lattice marks the
    /// PLAYABLE board, so a skirted build passes the board's rectangle inside the enlarged layout;
    /// the closed W/S boundary edges are drawn at the rectangle's own <c>X</c>/<c>Y</c>.
    /// </summary>
    public TileRect? GridLineRect { get; init; }
}
