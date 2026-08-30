using System;
using System.Collections.Generic;
using PF2e.Core;
using PF2e.Grid;
using PF2e.Utilities;

namespace Delve.Combat;

/// <summary>
/// Registry scans shared by the strike, spell and skill executors, plus the one action-economy
/// reason string they all print. Read-only: nothing here changes battle state.
/// </summary>
internal static class CombatantQuery
{
    /// <summary>
    /// Living combatants on the wanted side that satisfy <paramref name="inRange"/>. The single
    /// registry scan behind strike targets and spell targets — each caller brings its own range test
    /// (weapon reach uses FlankingCalculator, spell range uses the PF2e diagonal distance). Allies
    /// include the source itself. Yields nothing when no registry is wired.
    /// </summary>
    internal static IEnumerable<ICharacter> ScanCombatants(
        ICharacter source, bool enemies, Func<ICharacter, bool> inRange)
    {
        var registry = CombatantRegistry.Instance;
        if (registry == null) yield break;

        foreach (var other in registry.All)
        {
            if (other.Health == null || other.Health.IsDead) continue;
            if ((other.TeamId == source.TeamId) == enemies) continue;
            if (inRange(other)) yield return other;
        }
    }

    /// <summary>Living combatants on the wanted side within <paramref name="rangeTiles"/>.</summary>
    internal static IEnumerable<ICharacter> TargetsInRange(
        ICharacter caster, int rangeTiles, bool enemies)
        => ScanCombatants(caster, enemies, other => AreaCalculator.GetPF2eDistance(
            caster.GridPosition, caster.TileWidth, other.GridPosition, other.TileWidth) <= rangeTiles);

    /// <summary>True when at least one living combatant on the wanted side is in range.</summary>
    internal static bool AnyTargetInRange(ICharacter actor, int rangeTiles, bool enemies)
    {
        foreach (var _ in TargetsInRange(actor, rangeTiles, enemies))
            return true;
        return false;
    }

    /// <summary>"Needs 2 actions (1 left)" — the shared action-economy unavailability reason.</summary>
    internal static string NeedsActionsReason(int cost, int remaining)
        => $"Needs {cost} action{(cost == 1 ? "" : "s")} ({remaining} left)";
}
