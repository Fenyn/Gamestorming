using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Utilities;
using Ungilded.Combat;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Tutorial;

/// <summary>
/// Runs a <see cref="ScriptedTurn"/> for an enemy through <see cref="PlayerActionExecutor"/>, whose
/// Stride and Strike mirror AITurnExecutor's move and strike: the same events reach the presenter,
/// so a scripted rat walks, provokes and bites exactly like an AI one.
/// </summary>
internal static class ScriptedTurnRunner
{
    /// <param name="planned">Told each Stride's route before it starts, for the stride gate.</param>
    internal static async Task Run(ScriptedTurn turn, ICharacter actor, PlayerActionExecutor exec,
        Action<IReadOnlyList<PF2eVec>> planned, CancellationToken token)
    {
        foreach (var step in turn.Steps)
        {
            token.ThrowIfCancellationRequested();
            if (!CanAct(actor) || step is EndTurnStep) return;

            switch (step)
            {
                case StrideToStep stride:
                    await Stride(actor, exec, stride.Tile, stride.Provokes, planned);
                    break;
                case StrideAwayStep away:
                    if (FarthestFrom(actor, exec, away.From, away.MaxTiles) is { } tile)
                        await Stride(actor, exec, tile, away.Provokes, planned);
                    break;
                case StrikeStep strike:
                    await exec.Strikes.ExecuteCreatureStrike(actor, strike.Target);
                    break;
            }
        }
    }

    private static async Task Stride(ICharacter actor, PlayerActionExecutor exec, PF2eVec tile, bool provokes,
        Action<IReadOnlyList<PF2eVec>> planned)
    {
        if (exec.GetPathTo(actor, tile) is not { Count: >= 2 } path) return;
        planned(path);
        await exec.ExecuteStride(actor, tile, provokes);
    }

    /// <summary>The reachable tile farthest from <paramref name="from"/> whose route is at most
    /// <paramref name="maxTiles"/> long. Ties go to the shorter route, then the lower x and y.</summary>
    private static PF2eVec? FarthestFrom(ICharacter actor, PlayerActionExecutor exec, ICharacter from, int maxTiles)
    {
        PF2eVec? best = null;
        int bestDistance = -1, bestLength = 0;
        foreach (var tile in exec.GetReachableTiles(actor))
        {
            if (exec.GetPathTo(actor, tile) is not { } path || path.Count - 1 > maxTiles) continue;
            int distance = AreaCalculator.GetPF2eDistance(tile, actor.TileWidth, from.GridPosition, from.TileWidth);
            int length = path.Count;
            bool better = best is not { } current || distance > bestDistance
                || distance == bestDistance && (length < bestLength
                    || length == bestLength && (tile.x < current.x || tile.x == current.x && tile.y < current.y));
            if (!better) continue;
            best = tile;
            bestDistance = distance;
            bestLength = length;
        }
        return best;
    }

    private static bool CanAct(ICharacter actor) => actor.Health?.IsAlive == true
        && actor.Conditions?.HasCondition(Condition.Unconscious) != true
        && (actor.Actions?.TotalActionsRemaining ?? 0) > 0;
}
