using System;
using System.Collections.Generic;
using System.Linq;
using PF2e.Core;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Tutorial.Encounters;

/// <summary>The board queries the scripts place gold tiles and scripted moves with.</summary>
internal sealed partial class EncounterStage
{
    /// <summary>Free orthogonal neighbours of <paramref name="target"/> the actor reaches with one Stride.</summary>
    public List<PF2eVec> FreeNeighbours(ICharacter actor, ICharacter target)
    {
        var reachable = Session.PlayerActions.GetReachableTiles(actor);
        var p = target.GridPosition;
        return new[] { new PF2eVec(p.x + 1, p.y), new PF2eVec(p.x - 1, p.y), new PF2eVec(p.x, p.y + 1), new PF2eVec(p.x, p.y - 1) }
            .Where(reachable.Contains).ToList();
    }

    /// <summary>The tile on the far side of <paramref name="target"/> from <paramref name="ally"/>:
    /// standing there flanks it.</summary>
    public static PF2eVec Opposite(ICharacter target, ICharacter ally)
        => new(2 * target.GridPosition.x - ally.GridPosition.x, 2 * target.GridPosition.y - ally.GridPosition.y);

    /// <summary>A free tile next to <paramref name="target"/> that <paramref name="mover"/> reaches in
    /// one Stride, nearest the mover first; <paramref name="prefer"/> wins when it qualifies.</summary>
    public PF2eVec? ApproachTile(ICharacter mover, ICharacter target, PF2eVec? prefer = null)
    {
        var exec = Session.PlayerActions;
        var tiles = exec.GetReachableTiles(mover)
            .Where(t => Math.Max(Math.Abs(t.x - target.GridPosition.x), Math.Abs(t.y - target.GridPosition.y)) == 1)
            .ToList();
        if (prefer is { } wanted && tiles.Contains(wanted)) return wanted;
        return tiles.OrderBy(t => exec.GetPathTo(mover, t)?.Count ?? int.MaxValue)
            .ThenBy(t => t.x).ThenBy(t => t.y).Cast<PF2eVec?>().FirstOrDefault();
    }

    public static bool Adjacent(ICharacter a, ICharacter b)
        => Math.Max(Math.Abs(a.GridPosition.x - b.GridPosition.x), Math.Abs(a.GridPosition.y - b.GridPosition.y)) == 1;
}
