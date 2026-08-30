using Delve.Data;
using Godot;
using PF2e.Grid;
using PF2e.MapGen;

namespace Delve.Terrain;

/// <summary>
/// Everything one terrain build shares: the layout and theme it reads, the derived grids it computed
/// once, and the two sinks geometry goes into. <see cref="TerrainMeshBuilder.Build"/> makes one of
/// these and hands it to every pass, so no pass re-derives a grid another pass already has.
/// </summary>
internal sealed class TerrainBuildContext
{
    internal required MapLayout Layout { get; init; }

    internal required MapThemeDefinition Theme { get; init; }

    /// <summary>World Y per corner-height unit — <see cref="MapThemeDefinition.HeightScale"/>.</summary>
    internal required float HeightScale { get; init; }

    internal required int Width { get; init; }

    internal required int Height { get; init; }

    /// <summary>
    /// The one surface grid every surface decision reads: the ground texture bake, the top faces and
    /// the cliff faces. A bank-dirt shore then gets an earth lip and a grass-topped cover block a grass
    /// overhang, because nothing is looking at a second opinion.
    /// </summary>
    internal required SurfaceType[] EffectiveSurfaces { get; init; }

    internal required SurfacePalette Palette { get; init; }

    /// <summary>The single-surface collision buffer: tops, cliff walls and void floors.</summary>
    internal required MeshBuffer Collision { get; init; }

    /// <summary>Where the passes log the cliff faces they emit, for a spike. Null in a normal build.</summary>
    internal TerrainDebugFaces? Debug { get; init; }

    /// <summary>Tiles that get top-surface grid lines. Resolved from
    /// <see cref="TerrainMeshOptions.GridLineRect"/> to the whole layout when the caller named none,
    /// so the passes never carry a null case.</summary>
    internal required TileRect GridLines { get; init; }

    /// <summary>Effective surface of one tile.</summary>
    internal SurfaceType SurfaceAt(int x, int y) => EffectiveSurfaces[y * Width + x];

    /// <summary>
    /// The four world corners of a tile top. Tile (x, y) occupies world x..x+1 on X and y..y+1 on Z
    /// (GridSpace convention): SW = (x, y), SE = (x+1, y), NW = (x, y+1), NE = (x+1, y+1).
    /// </summary>
    internal (Vector3 SW, Vector3 SE, Vector3 NE, Vector3 NW) CornerWorld(
        int x, int y, TileCornerHeights corners) =>
        (new Vector3(x, corners.SW * HeightScale, y),
         new Vector3(x + 1, corners.SE * HeightScale, y),
         new Vector3(x + 1, corners.NE * HeightScale, y + 1),
         new Vector3(x, corners.NW * HeightScale, y + 1));
}
