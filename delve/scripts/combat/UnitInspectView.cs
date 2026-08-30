using System.Collections.Generic;

namespace Delve.Combat;

/// <summary>
/// UI-facing snapshot of one combatant for hover inspection: name, team, HP, AC, and active
/// conditions as short display labels (e.g. "Frightened 2", "Prone", "Shield Raised"). Pure
/// Delve data — deliberately carries no PF2e engine types so a passive Control can render it.
///
/// <see cref="AcText"/> and <see cref="HpText"/> are the LINES to draw, already masked for
/// bestiary knowledge by <c>PlayerActionExecutor.GetUnitInspect</c>: an enemy species whose AC /
/// MaxHP the party has not recalled yet reads "AC ?" / "?/?". The raw <see cref="Ac"/>,
/// <see cref="Hp"/> and <see cref="MaxHp"/> numbers stay on the record for the HP BAR (its fill
/// ratio is board-visible information and is never hidden) and for the active-ally action bar,
/// which is always ungated.
/// </summary>
public sealed record UnitInspectView
{
    public required string Name { get; init; }
    public int TeamId { get; init; }

    /// <summary>True for a party member (<see cref="TeamId"/> 1). Allies are never knowledge-gated.</summary>
    public bool IsAlly { get; init; }

    public int Hp { get; init; }
    public int MaxHp { get; init; }
    public int Ac { get; init; }
    public IReadOnlyList<string> Conditions { get; init; } = System.Array.Empty<string>();

    /// <summary>The AC line to draw: "AC 15", or "AC ?" while that species' AC is unrevealed.</summary>
    public required string AcText { get; init; }

    /// <summary>The HP fraction to draw: "4/10", or "?/?" while that species' MaxHP is unrevealed.</summary>
    public required string HpText { get; init; }
}
