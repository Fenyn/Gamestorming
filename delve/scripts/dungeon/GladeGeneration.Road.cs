using System.Collections.Generic;
using PF2e.MapGen;

namespace Delve.Dungeon;

public static partial class GladeGeneration
{
    /// <summary>The entrance's worn road: a full mouth wide from the arrival mouth to the centre, then a
    /// one-tile footpath out to each other mouth. Only open ground changes surface; the land keeps its
    /// shape.</summary>
    private static void LayRoad(MapLayout layout, IReadOnlyList<DoorSide> mouths, DoorSide arrival)
    {
        int n = layout.Width, mid = n / 2;
        foreach (var side in mouths)
        {
            int half = side == arrival ? RoomGeneration.DoorWidth / 2 : 0;
            for (int along = 1; along <= mid; along++)
                for (int across = -half; across <= half; across++)
                {
                    var (x, y) = side switch
                    {
                        DoorSide.North => (mid + across, along),
                        DoorSide.South => (mid + across, n - 1 - along),
                        DoorSide.West => (along, mid + across),
                        _ => (n - 1 - along, mid + across)
                    };
                    if (layout.GetTile(x, y) == TileRole.Ground) layout.SetSurface(x, y, SurfaceType.Dirt);
                }
        }
    }
}
