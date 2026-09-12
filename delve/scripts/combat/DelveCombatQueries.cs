using PF2e.AI;
using PF2e.Core;
using PF2e.Utilities;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Combat;

/// <summary>
/// The spatial questions the planner cannot answer on its own: would standing here flank, and how
/// much would walking here cost in free swings. Both go through the same code the rules use when the
/// move actually happens, so the AI fears what it will meet and takes flanks that count.
/// </summary>
public sealed class DelveCombatQueries : ICombatQueries
{
    /// <summary>
    /// Whether the actor standing on <paramref name="actorPos"/> would flank
    /// <paramref name="target"/>. Both sides of a flank have to be in melee reach, and this is asked
    /// about tiles the actor is nowhere near, so its own reach is checked here — the engine's
    /// <see cref="PF2e.Utilities.OffGuardHelper.IsFlankingAttacker"/> can skip that test because it
    /// only ever runs while an attack is already landing.
    /// </summary>
    public bool WouldFlankFrom(PF2eVec actorPos, int actorWidth, ICharacter target, ICharacter actor)
    {
        if (target == null || actor == null) return false;

        if (!MeleeThreatHelper.TryGetMeleeThreatReach(actor, out int reach)) return false;
        if (!FlankingCalculator.IsWithinReach(
            actorPos, actorWidth, target.GridPosition, target.TileWidth, reach))
            return false;

        return SpatialDelegates.IsFlankedFrom(actorPos, actorWidth, actor, target);
    }

    /// <summary>
    /// What a tile is worth avoiding because of the reactive strikes that cover it. Each threat
    /// whose reach touches the tile counts once, scaled by how much this actor minds being hit for
    /// free. Sized against the tile scores it competes with in
    /// <c>AIMovementPlanner.ScoreTile</c>, where reaching a target is worth 10.
    /// </summary>
    public float ScoreReactiveStrikeDanger(PF2eVec pos, int tileWidth,
        System.Collections.Generic.List<ReactiveStrikeThreat> threats, float fear)
    {
        if (threats == null || threats.Count == 0) return 0f;

        float danger = 0f;
        foreach (var threat in threats)
        {
            if (threat?.Creature == null) continue;
            if (threat.Creature.Health != null && threat.Creature.Health.IsDead) continue;

            if (FlankingCalculator.IsWithinReach(
                threat.Position, threat.TileWidth, pos, tileWidth, threat.ReachTiles))
                danger += ThreatWeight * fear;
        }
        return danger;
    }

    /// <summary>Score one free swing is worth dodging at full fear. Below the 10 that reaching a
    /// target pays, so a threatened tile is a cost rather than a wall.</summary>
    private const float ThreatWeight = 6f;
}
