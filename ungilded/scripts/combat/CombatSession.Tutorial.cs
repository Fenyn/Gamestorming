using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using PF2e.Core;
using PF2e.Data;
using PF2e.Events;
using Ungilded.Tutorial;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Combat;

/// <summary>
/// The session side of <see cref="TutorialHooks"/>: turn-start gates, auto-passed and scripted
/// turns, the end gates, and the <see cref="TutorialWatch"/> that sits on the event stream. Every
/// gate is awaited inside the loop, as the reaction prompt is, so combat holds until it returns.
/// With no hooks every call here is a no-op.
/// </summary>
public sealed partial class CombatSession
{
    private ICreatureKnowledgeProvider? _knowledge;
    private TutorialWatch? _watch;

    /// <summary>The tutorial hooks this encounter runs under, or null for normal combat.</summary>
    public TutorialHooks? Tutorial { get; private set; }

    /// <summary>A line the log shows with no roll behind it (an auto-passed turn).</summary>
    public event Action<ICharacter, string>? NarrationLogged;

    /// <summary>Presentation for a held enemy stride, set by the scene: lean the token toward the
    /// next tile. Awaited before the BeforeEnemyStride callbacks.</summary>
    public Func<ICharacter, PF2eVec, Task>? StrideHoldPresenter
    {
        get => _strideHold;
        set
        {
            _strideHold = value;
            if (_watch != null) _watch.HoldStride = value;
        }
    }

    private Func<ICharacter, PF2eVec, Task>? _strideHold;

    private IEnumerable<ICharacter> AllCombatants() => _team1.Concat(_team2);

    private void StartTutorialWatch()
    {
        if (Tutorial == null) return;
        _watch = new TutorialWatch(Tutorial, AllCombatants) { HoldStride = _strideHold };
    }

    /// <summary>Report everything the last player action left pending (strike, damage, reveals).
    /// The controller awaits it before the menu opens again.</summary>
    public Task SettleTutorialAsync() => _watch?.Settle() ?? Task.CompletedTask;

    /// <summary>Run a tutorial callback at the next pause point. For callers on a synchronous
    /// engine path, such as the Recall Knowledge result.</summary>
    public void DeferTutorial(Func<Task> callback) => _watch?.Defer(callback);

    private Task TutorialMovementGate(BeforeMoveEventArgs args)
        => _watch?.BeforeTileExit(args) ?? Task.CompletedTask;

    private async Task TutorialTurnStarted(ICharacter current, CancellationToken cancellationToken)
    {
        if (Tutorial == null) return;
        await Tutorial.RaiseTurnStarted(current);
        cancellationToken.ThrowIfCancellationRequested();
    }

    private Task RunScriptedTurn(ICharacter actor, ScriptedTurn script, CancellationToken cancellationToken)
        => ScriptedTurnRunner.Run(script, actor, PlayerActions, path => _watch?.NotePlannedPath(path), cancellationToken);

    /// <summary>The end gates: what is still pending, then the wipe, then the result. A director
    /// that restarted the fight inside a callback cancelled this session; it stops without a result.</summary>
    private async Task TutorialEncounterEnded(BattleResult result, CancellationToken cancellationToken)
    {
        if (Tutorial == null || _watch == null) return;
        await _watch.Settle();
        if (result is BattleResult.Team2Wins or BattleResult.Draw)
            await Tutorial.RaisePartyWiped();
        cancellationToken.ThrowIfCancellationRequested();
        await Tutorial.RaiseFinished(result);
        cancellationToken.ThrowIfCancellationRequested();
    }
}
