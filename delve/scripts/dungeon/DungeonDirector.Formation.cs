using System.Collections.Generic;
using Delve.Terrain;
using PF2e.MapGen;
using Godot;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Dungeon;

/// <summary>Where the party stands in a room: a short row a few steps inside the door it came
/// through, spread across the screen with every other hero a step back, so no hero hides another and
/// the room opens ahead of the party instead of the party blocking its middle.</summary>
public partial class DungeonDirector
{
    /// <summary>Tiles past the door's first inside tile that the row stands.</summary>
    [Export] public int PartyStandInset { get; set; } = 2;

    /// <summary>The order heroes fill the row: the leader in the middle, then outward on alternate sides.</summary>
    private static readonly int[] RowSlots = { 0, -1, 1, -2, 2, -3, 3 };

    /// <summary>The tile each of <paramref name="count"/> heroes stands on after coming in through
    /// <paramref name="entry"/>; with no entry, the same row across the room's middle.</summary>
    private PF2eVec[] PartySpots(DungeonRoomPrefab view, DoorSide? entry, int count)
    {
        var layout = view.Generated.Layout;
        int n = view.Width;
        var anchor = entry switch
        {
            DoorSide.North => RoomGeneration.Inside(n, DoorSide.North) + new PF2eVec(0, PartyStandInset),
            DoorSide.South => RoomGeneration.Inside(n, DoorSide.South) + new PF2eVec(0, -PartyStandInset),
            DoorSide.West => RoomGeneration.Inside(n, DoorSide.West) + new PF2eVec(PartyStandInset, 0),
            DoorSide.East => RoomGeneration.Inside(n, DoorSide.East) + new PF2eVec(-PartyStandInset, 0),
            _ => new PF2eVec(n / 2, n / 2),
        };
        // The screen's horizontal and its depth, snapped to grid steps: at the crawl's 45° yaw a row
        // runs along a tile diagonal, which reads as a straight line across the screen.
        var basis = _camera.Camera.GlobalBasis;
        var across = GridStep(basis.X);
        var back = GridStep(-basis.Z);
        var taken = new HashSet<PF2eVec>();
        var spots = new PF2eVec[count];
        for (int i = 0; i < count; i++)
        {
            int slot = RowSlots[i % RowSlots.Length];
            int depth = (slot & 1) + i / RowSlots.Length * 2;
            var wanted = new PF2eVec(anchor.x + across.x * slot + back.x * depth, anchor.y + across.y * slot + back.y * depth);
            spots[i] = NearestOpen(layout, wanted, taken);
            taken.Add(spots[i]);
        }
        return spots;
    }

    /// <summary>A ground direction as a one-tile grid step: each axis that carries a real share of it.</summary>
    private static PF2eVec GridStep(Vector3 direction)
    {
        var flat = new Vector2(direction.X, direction.Z).Normalized();
        static int Step(float c) => Mathf.Abs(c) > 0.38f ? System.Math.Sign(c) : 0;
        return new PF2eVec(Step(flat.X), Step(flat.Y));
    }

    /// <summary>The walkable tile closest to <paramref name="wanted"/> that no hero has taken.</summary>
    private static PF2eVec NearestOpen(MapLayout layout, PF2eVec wanted, HashSet<PF2eVec> taken)
    {
        for (int radius = 0; radius < layout.Width; radius++)
            for (int dy = -radius; dy <= radius; dy++)
                for (int dx = -radius; dx <= radius; dx++)
                {
                    if (System.Math.Max(System.Math.Abs(dx), System.Math.Abs(dy)) != radius) continue;
                    var tile = new PF2eVec(wanted.x + dx, wanted.y + dy);
                    if (layout.IsInBounds(tile.x, tile.y) && layout.IsWalkable(tile.x, tile.y) && !taken.Contains(tile)) return tile;
                }
        return wanted;
    }
}
