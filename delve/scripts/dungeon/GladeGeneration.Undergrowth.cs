using System;
using System.Collections.Generic;
using System.Linq;
using Delve.Run;
using PF2e;
using PF2e.MapGen;

namespace Delve.Dungeon;

public static partial class GladeGeneration
{
    /// <summary>The shared forest <see cref="Run.Undergrowth"/> inside the tree ring, with a few
    /// clumps in the open when the glade holds no fight (a fight glade gets its trees from
    /// <see cref="Dress"/>). Nothing grows on the mouths, the lanes along the door axes or the
    /// deployment boxes, so the reach rules still hold; <see cref="Reached"/> checks the result.</summary>
    private static void Undergrowth(MapLayout layout, IReadOnlyList<DoorSide> doors, int half, bool combat, Random rng)
    {
        int mid = layout.Width / 2;
        var zones = ZoneTiles(layout.Width, doors, half).ToHashSet();
        var mouths = MouthTiles(layout.Width, doors).ToArray();
        bool KeepOpen(Vector2Int p) => Math.Abs(p.x - mid) <= 1 || Math.Abs(p.y - mid) <= 1 || zones.Contains(p)
            || mouths.Any(m => Math.Abs(m.x - p.x) + Math.Abs(m.y - p.y) <= MouthClear);
        Run.Undergrowth.Grow(layout, ring: 1, KeepOpen, clumps: !combat, rng);
    }
}
