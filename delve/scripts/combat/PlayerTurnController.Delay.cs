using System;
using PF2e.Core;

namespace Delve.Combat;

public sealed partial class PlayerTurnController
{
    /// <summary>
    /// Delay this turn. Legal only before any action. The turn order bar offers every anchor the
    /// engine returns, next-round rows included; a click on one settles the return, and the choice
    /// is final.
    /// </summary>
    public void BeginDelay()
    {
        if (!Ready() || DelayReason() != null) return;
        var actor = _current!;

        ClearTransient();
        foreach (var anchor in DelayAnchors?.Invoke(actor) ?? Array.Empty<ICharacter>())
            _delayAnchors[anchor.UniqueId] = anchor;
        if (_delayAnchors.Count == 0) { Cancel(); return; }
        SetMode(PlayerTurnMode.SelectingDelaySlot);
        DelayAnchorsChanged?.Invoke(new System.Collections.Generic.List<int>(_delayAnchors.Keys));
    }

    /// <summary>A turn order chip was clicked while picking the Delay slot.</summary>
    public void DelayAnchorClicked(int combatantId)
    {
        if (_mode != PlayerTurnMode.SelectingDelaySlot || _current == null) return;
        if (!_delayAnchors.TryGetValue(combatantId, out var anchor)) return;
        RequestDelay(_current, anchor);
    }

    /// <summary>Hand the turn to the session as a Delay. The controller is done with it: the
    /// session's turn-ended event releases control, exactly as after End Turn.</summary>
    private void RequestDelay(ICharacter actor, ICharacter after)
    {
        SetBusy(true);
        SetMode(PlayerTurnMode.Idle);
        ClearTransient();
        DelayRequested?.Invoke(actor, after);
    }

    /// <summary>Why the actor cannot Delay now: acted already (the controller's rule), or the
    /// session's reason. Null when allowed.</summary>
    private string? DelayReason()
    {
        if (_current == null) return "No active turn";
        if (_actedThisTurn) return "Delay must be the first thing you do this turn";
        return DelayBlockedReason?.Invoke(_current);
    }
}
