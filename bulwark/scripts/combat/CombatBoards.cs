using PF2eVec = PF2e.Vector2Int;

namespace Bulwark.Combat;

/// <summary>
/// The standard combat board (the M1 combat slice): grid size plus the party/enemy anchor squares
/// both the F5 combat test and territory encounters deploy on. Party anchors are marching-order
/// slots (Veteran, Scout, Medic, Scholar); enemy anchors host up to five creatures on the far side.
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
}
