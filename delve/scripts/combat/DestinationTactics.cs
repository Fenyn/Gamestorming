using System.Collections.Generic;
using System.Linq;
using PF2e.Core;
using PF2e.Data;
using PF2e.Grid;
using PF2e.RuleEvents.Reactions;
using PF2e.Utilities;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Combat;

public sealed record DestinationTactics(IReadOnlyList<ICharacter> Targets, string Caption)
{
    /// <summary>Prospective geometry only. Never move a live unit to ask a preview question.</summary>
    public static DestinationTactics Read(BattleGrid grid, ICharacter actor, PF2eVec tile,
        IReadOnlyList<PF2eVec> path, MoveKind kind, IReadOnlyList<ICharacter> enemies)
    {
        var spatial = new TerrainSpatial(grid);
        bool terrain = TerrainSpatial.HasSpatialFeatures(grid);
        var weapon = WeaponAttackCalculator.ResolveWeapon(actor);
        var targets = enemies.Where(e => e.Health?.IsAlive == true
            && FlankingCalculator.IsWithinReach(tile, actor.TileWidth, e.GridPosition, e.TileWidth, weapon.GetRangeInTiles())
            && (!terrain || spatial.HasLineOfSightFrom(tile, actor, e))).ToArray();
        var words = new List<string>();
        if (!weapon.IsRanged && targets.Any(e => SpatialDelegates.IsFlankedFrom(tile, actor.TileWidth, actor, e))) words.Add("Flank");
        if (targets.Length > 0) words.Add($"{targets.Length} in reach");
        // Cover names its attacker; a single shield must never imply protection from every direction.
        var threat = enemies.Where(e => e.Health?.IsAlive == true)
            .OrderBy(e => System.Math.Abs(tile.x - e.GridPosition.x) + System.Math.Abs(tile.y - e.GridPosition.y)).FirstOrDefault();
        if (threat != null && terrain && spatial.GetTileCover(tile, actor, threat) != CoverLevel.None)
            words.Add($"Cover vs {threat.Name}");
        if (kind != MoveKind.Step && enemies.Any(e => KnownReactionOnPath(e, actor, path))) words.Add("Reaction risk");
        return new(targets, string.Join(" · ", words));
    }

    private static bool KnownReactionOnPath(ICharacter enemy, ICharacter actor, IReadOnlyList<PF2eVec> path)
    {
        if (enemy.Health?.IsAlive != true || !PlayerActionExecutor.IsCreatureFieldKnown(
                enemy.CreatureStats?.CreatureId, CreatureKnowledgeField.All)) return false;
        var reactions = enemy.Features?.ActiveFeatures.OfType<IMovementReaction>();
        return reactions != null && reactions.Any(reaction => path.Take(System.Math.Max(0, path.Count - 1)).Any(tile =>
            FlankingCalculator.IsWithinReach(enemy.GridPosition, enemy.TileWidth, tile, actor.TileWidth, reaction.GetReachTiles(enemy))));
    }
}
