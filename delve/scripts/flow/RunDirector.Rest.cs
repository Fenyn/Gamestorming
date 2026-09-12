using Delve.Run;
using Godot;
using PF2e.Core;

namespace Delve.Flow;

public partial class RunDirector
{
    // ---------------------------------------------------------------- Rest

    /// <summary>Open the Campsite screen. Public so a spike can drive one it did not walk to.</summary>
    public void OpenRest()
    {
        if (_state == null) return;
        _restPanel.Show(_state);
        SetPhase(RunPhase.Rest);
    }

    /// <summary>Take the night's rest at a Campsite: heal, clear Wounded, roll the day over.</summary>
    public void Rest()
    {
        if (_state == null) return;
        PartyRecovery.LongRest(_state.Party, _state.Clock, wardstone: _state.Wardstone);
        GoToMap();
    }

    /// <summary>Open the ten-minute activity screen from the map.</summary>
    public void OpenShortRest()
    {
        if (_state == null || Phase != RunPhase.Map) return;
        _shortRestResolved = false;
        _shortRestPanel.Show(_state);
        SetPhase(RunPhase.ShortRest);
    }

    /// <summary>Spend one ten-minute block. The panel shows the lines it produced.</summary>
    public void TakeShortRest(ShortRestKind kind, PF2eCharacter? target)
    {
        if (_state == null || Phase != RunPhase.ShortRest || _shortRestResolved) return;
        _shortRestResolved = true;
        int wardBefore = _state.Wardstone.Ward;

        var result = ShortRest.Perform(
            _state.Party, _state.Clock, kind, target, new RecoveryRules(),
            wardstone: _state.Wardstone);
        _shortRestPanel.ShowResult(result, _state, wardBefore);
        EndOnSpentWard();
    }

    /// <summary>
    /// End the run when the ward has gone out (design/core_concept.md, "Wardstone"). Called after
    /// every burn. True when it ended the run, so the caller stops what it was doing.
    /// </summary>
    private bool EndOnSpentWard()
    {
        if (_state == null || !_state.Wardstone.IsSpent || _state.Outcome != RunOutcome.InProgress)
            return false;

        GD.Print("[RunDirector] the ward is out - the run ends.");
        EndRun(RunOutcome.Defeat);
        return true;
    }

    /// <summary>Leave the ten-minute screen and return to the map.</summary>
    public void CloseShortRest() => GoToMap();

}
