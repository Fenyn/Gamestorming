using System;
using System.Collections.Generic;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Combat;

/// <summary>
/// The standard combat board (the M1 combat slice): grid size plus the party/enemy anchor squares
/// both the F5 combat test and territory encounters deploy on. Party anchors are marching-order
/// slots (Veteran, Elara, Medic, Fenwick); enemy anchors host up to five creatures on the far side.
/// </summary>
public static class CombatBoards
{
    public const int StandardWidth = 14;
    public const int StandardHeight = 12;

    public static readonly PF2eVec[] PartyAnchors =
    {
        new(1, 4), new(2, 5), new(1, 6), new(2, 7),
    };

    public static readonly PF2eVec[] EnemyAnchors =
    {
        new(12, 3), new(12, 5), new(11, 6), new(12, 7), new(11, 9),
    };

    /// <summary>
    /// The first <paramref name="count"/> anchors for a team: <see cref="PartyAnchors"/> for team 1,
    /// <see cref="EnemyAnchors"/> for any other team. A team larger than its anchor table repeats the
    /// last anchor — a duplicate is legal input, because <c>CombatSetup.Normalize</c> spreads the
    /// stack onto the nearest free walkable cells and reports each move.
    /// </summary>
    public static List<PF2eVec> Anchors(int teamId, int count)
    {
        var table = teamId == 1 ? PartyAnchors : EnemyAnchors;
        var result = new List<PF2eVec>(Math.Max(0, count));
        for (int i = 0; i < count; i++)
            result.Add(table.Length == 0 ? default : table[Math.Min(i, table.Length - 1)]);
        return result;
    }
}
