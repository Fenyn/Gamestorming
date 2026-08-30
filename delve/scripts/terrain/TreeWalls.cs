using System.Collections.Generic;
using PF2e.Grid;
using PF2e.MapGen;

namespace Delve.Terrain;

/// <summary>
/// Turns a tree-biome layout's Wall tiles from raised terrain blocks into TREE SPOTS: each tile is
/// flattened to the ground elevation it stands on and its position is returned, so the stage can
/// stand a billboard tree prop there instead of the crate-shaped block the mesh builder would draw.
///
/// This runs on the RENDER layout only (the skirted copy), never on the board the rules engine
/// reads — the original tile keeps its Wall role, so it still blocks movement and sight exactly as
/// before; only what the eye sees changes. Enclosed biomes (vault walls that really are walls)
/// never call this: the gate is <see cref="BackdropThemeDefinition.WallsAreTrees"/>.
/// </summary>
public static class TreeWalls
{
    private const int Units = TileCornerHeights.UnitsPerElevation;

    /// <summary>Flatten every Wall tile of <paramref name="layout"/> to its ground elevation and
    /// return the flattened positions, in the layout's own tile coordinates.</summary>
    public static List<(int X, int Y)> Convert(MapLayout layout)
    {
        var spots = new List<(int X, int Y)>();

        for (int y = 0; y < layout.Height; y++)
        {
            for (int x = 0; x < layout.Width; x++)
            {
                if (layout.GetTile(x, y) != TileRole.Wall) continue;

                layout.SetCornerHeights(x, y, TileCornerHeights.Flat(layout.GetElevation(x, y) * Units));
                layout.SetSlope(x, y, SlopeType.Flat, 0);
                spots.Add((x, y));
            }
        }

        return spots;
    }
}
