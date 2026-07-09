namespace Bulwark.Combat;

/// <summary>
/// UI-facing snapshot of what the action bar should show for the current ally. Pure Bulwark data.
/// </summary>
public sealed record ActionBarState
{
    public int ActionsRemaining { get; init; }
    public int MaxActions { get; init; } = 3;
    public bool CanMove { get; init; }
    public bool CanStep { get; init; }
    public bool CanStrike { get; init; }
    public bool CanRaiseShield { get; init; }
    public int Map { get; init; }
    public PlayerTurnMode Mode { get; init; }
    public string ActorName { get; init; } = "";
}
