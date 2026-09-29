using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using PF2e;
using PF2e.Core;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Combat;

public sealed partial class PlayerTurnController
{
    /// <summary>
    /// Stride (or Crawl) one leg at a time to the plan's leg ends. The lifecycle checks sit BETWEEN
    /// legs, in the controller rather than the executor: a Reactive Strike can drop the mover on leg
    /// one, the turn can be handed to the AI, or the encounter can be torn down while a leg animates,
    /// and none of those may start the next leg. A condition gained mid-walk (tripped prone, grabbed)
    /// ends the chain before an illegal Stride; the executor refuses one as well. A leg that ends
    /// short ends the chain too, since the next leg's route assumed the planned tile.
    /// </summary>
    private async Task<bool> WalkLegs(ICharacter actor, IReadOnlyList<PF2eVec> legs, MoveKind kind)
    {
        bool moved = false;
        foreach (var leg in legs)
        {
            if (CancellationToken.IsCancellationRequested || !ReferenceEquals(_current, actor)) break;
            if (!CanAct(actor) || (actor.Actions?.TotalActionsRemaining ?? 0) <= 0) break;
            if (kind == MoveKind.Stride && _exec.MoveRestriction(actor) != null) break;

            bool walked = kind == MoveKind.Crawl
                ? await _exec.ExecuteCrawl(actor, leg)
                : await _exec.ExecuteStride(actor, leg);
            if (!walked) break;
            moved = true;
            if (actor.GridPosition != leg) break;
        }
        return moved;
    }

    /// <summary>
    /// Run one action to completion, then republish the bar. <c>async void</c> because it is called
    /// from UI event handlers, so the resumption after the await must prove the controller is still
    /// on the SAME turn: the encounter can end, the scene can reset, or the next turn can begin while
    /// the action animates. A changed <see cref="_current"/> or a cancelled encounter means the state
    /// this continuation would publish belongs to a turn that is over — drop it.
    /// </summary>
    private async void RunAction(Func<Task<bool>> action)
    {
        if (_busy || _current == null) return;
        var actor = _current;
        SetBusy(true);
        SetMode(PlayerTurnMode.Idle);
        ClearTransient();
        PublishState();

        try
        {
            if (await action()) _actedThisTurn = true;
        }
        catch (OperationCanceledException)
        {
            // Encounter cancelled mid-action (scene exit / reset). Nothing left to publish.
            return;
        }
        catch (Exception e)
        {
            Log.Error($"[PlayerTurnController] action failed: {e.Message}");
        }

        if (CancellationToken.IsCancellationRequested || !ReferenceEquals(_current, actor))
            return;

        SetBusy(false);
        ActionCompleted?.Invoke();

        int remaining = _current?.Actions?.TotalActionsRemaining ?? 0;
        PublishState();

        if (remaining <= 0 || !CanAct(actor))
            EndTurnRequested?.Invoke();
    }
}
