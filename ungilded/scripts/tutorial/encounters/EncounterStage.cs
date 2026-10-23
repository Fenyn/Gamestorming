using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Godot;
using PF2e.Core;
using PF2e.Data;
using Ungilded.Combat;
using Ungilded.Content;
using Ungilded.Story;
using DialogueSequence = Ungilded.Story.DialogueSequence;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Tutorial.Encounters;

/// <summary>The in-fight dialogue sequences (assets/story).</summary>
internal sealed record PrologueLines(
    DialogueSequence? FriendStrike,
    DialogueSequence? HalfHp,
    DialogueSequence? QuarterHp,
    DialogueSequence? Victory,
    DialogueSequence? Closing);

/// <summary>The d20 and damage dice a forced roll queues.</summary>
internal readonly record struct ForcedRoll(int D20, params int[] Dice);

/// <summary>A turn held at its start until the script releases it.</summary>
internal sealed class TurnGate
{
    public required ICharacter Unit { get; init; }
    public required int Round { get; init; }
    public TaskCompletionSource Released { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);
    public bool Taken { get; set; }
}

/// <summary>
/// Everything one encounter script works with: the fight, the hooks, the story popup and box, the
/// two heroes and the enemies by anchor. It holds each turn at its start while
/// <see cref="HoldTurns"/> is on, so a script reads the fight one turn at a time, and it offers the
/// waits a script needs (an action spent, a turn over, the result). Every wait ends early when the
/// encounter ends or the stage is cancelled.
/// </summary>
internal sealed partial class EncounterStage
{
    private readonly Node _host;
    private readonly CancellationTokenSource _cts = new();
    private readonly List<TurnGate> _gates = new();
    private TaskCompletionSource<BattleResult> _result = new(TaskCreationOptions.RunContinuationsAsynchronously);

    public EncounterStage(Node host) => _host = host;

    public required int Index { get; init; }
    public required int Attempt { get; init; }
    public required CombatScene Scene { get; init; }
    public required TutorialHooks Hooks { get; init; }
    public required TutorialPopup Popup { get; init; }
    public required DialogueBox Dialogue { get; init; }
    public required PrologueBattle Battle { get; init; }
    public required ICharacter Player { get; init; }
    public required ICharacter Friend { get; init; }
    public required IReadOnlyList<ICharacter> Enemies { get; init; }
    public required PrologueLines Lines { get; init; }

    /// <summary>Plain text of every popup shown, in order.</summary>
    public required List<string> PopupLog { get; init; }

    /// <summary>Hold every turn at its start until <see cref="Release"/>. Off lets turns run.</summary>
    public bool HoldTurns { get; set; } = true;

    public CombatSession Session => Scene.Session ?? throw new OperationCanceledException("The encounter is gone.");
    public CancellationToken Token => _cts.Token;
    public bool Finished => _result.Task.IsCompleted;
    public bool HasHeldTurn => _gates.Count > 0;
    public Task<BattleResult> Result => _result.Task;
    public bool Won => _result.Task.IsCompleted && _result.Task.Result == BattleResult.Team1Wins;

    /// <summary>The enemy on this anchor, in <see cref="PrologueBattle.Enemies"/> order.</summary>
    public ICharacter Enemy(string anchor)
    {
        for (int i = 0; i < Battle.Enemies.Count; i++)
            if (Battle.Enemies[i].Anchor == anchor) return Enemies[i];
        throw new KeyNotFoundException($"[EncounterStage] {Battle.Id} has no enemy on '{anchor}'.");
    }

    // ---------------------------------------------------------------- Hooks the runner wires

    internal async Task OnTurnStarted(ICharacter unit)
    {
        if (!HoldTurns || _cts.IsCancellationRequested) return;
        var gate = new TurnGate { Unit = unit, Round = Scene.Session?.RoundNumber ?? 0 };
        _gates.Add(gate);
        await gate.Released.Task;
    }

    internal void NoteResult(BattleResult result) => _result.TrySetResult(result);

    /// <summary>Stop every wait and open every held turn, for a teardown.</summary>
    internal void Cancel()
    {
        _cts.Cancel();
        CloseSteps();
        foreach (var gate in _gates) gate.Released.TrySetResult();
        _gates.Clear();
    }

    // ---------------------------------------------------------------- Turns

    /// <summary>The next held turn, or null once the encounter ended.</summary>
    public async Task<TurnGate?> NextTurn()
    {
        while (true)
        {
            var gate = _gates.FirstOrDefault(g => !g.Taken);
            if (gate != null)
            {
                gate.Taken = true;
                return gate;
            }
            if (Finished) return null;
            await NextFrame();
        }
    }

    public void Release(TurnGate gate)
    {
        _gates.Remove(gate);
        gate.Released.TrySetResult();
    }

    /// <summary>Stop holding turns and open every held one.</summary>
    public void LetTurnsRun()
    {
        HoldTurns = false;
        foreach (var gate in _gates) gate.Released.TrySetResult();
        _gates.Clear();
    }

    /// <summary>True once the actor has spent <paramref name="count"/> more actions and the action
    /// has finished playing; false when the turn or the encounter ended first.</summary>
    public async Task<bool> WaitActions(ICharacter actor, int count = 1)
    {
        int start = actor.Actions?.TotalActionsRemaining ?? 0;
        while (true)
        {
            if (Finished || Scene.Session == null) return false;
            var controller = Scene.Controller;
            int now = actor.Actions?.TotalActionsRemaining ?? 0;
            if (now <= start - count && controller is { Busy: false }) return true;
            if (!ReferenceEquals(Scene.Session.CurrentActor, actor)) return false;
            await NextFrame();
        }
    }

    /// <summary>Wait until the actor's turn is over or the encounter ended.</summary>
    public async Task WaitTurnEnd(ICharacter actor)
    {
        while (!Finished && Scene.Session != null && ReferenceEquals(Scene.Session.CurrentActor, actor))
            await NextFrame();
    }

    public Task<BattleResult> WaitResult() => _result.Task.WaitAsync(_cts.Token);

    // ---------------------------------------------------------------- Story

    public Task Say(DialogueSequence? sequence)
        => sequence == null ? Task.CompletedTask : Dialogue.Play(sequence).WaitAsync(_cts.Token);

    // ---------------------------------------------------------------- Restrictions

    public void Allow(params string[] commands) => Hooks.RestrictCommands(commands);

    /// <summary>Lift the command, move and target restrictions.</summary>
    public void Unlock()
    {
        Hooks.ClearCommandRestriction();
        Hooks.ClearMoveRestriction();
        Scene.TargetFilter = null;
    }

    public void MoveTo(IEnumerable<PF2eVec> tiles, string wrongTile) => Hooks.RestrictMoveTo(tiles, wrongTile);

    /// <summary>Gold tiles that suggest a move and restrict nothing.</summary>
    public void HintMoveTo(IEnumerable<PF2eVec> tiles) => Hooks.HintMoveTo(tiles);

    public void ClearMove() => Hooks.ClearMoveRestriction();

    /// <summary>Only <paramref name="target"/> may be struck, studied or bombed.</summary>
    public void TargetOnly(ICharacter target) => Scene.TargetFilter = c => ReferenceEquals(c, target);

    public void AnyTarget() => Scene.TargetFilter = null;

    // ---------------------------------------------------------------- Dice

    /// <summary>Empty both dice queues, then queue these d20s and damage dice.</summary>
    public void Force(int[] d20s, params int[] dice)
    {
        Hooks.ClearForcedDice();
        Hooks.ForceNextD20(d20s);
        if (dice.Length > 0) Hooks.ForceNextDice(dice);
    }

    public void Force(int d20, params int[] dice) => Force(new[] { d20 }, dice);

    private Func<int>? _commitD20;
    private int[] _commitDice = Array.Empty<int>();
    private Func<PlayerOrder, ForcedRoll?>? _orderRule;

    /// <summary>Force the roll of the player's next committed order: the d20 is worked out and
    /// queued when the order starts (or the reaction prompt is accepted), so it reads the live MAP,
    /// flanking and range of the order the player actually gave.</summary>
    public void ForceOnCommit(Func<int> d20, params int[] dice)
    {
        _commitD20 = d20;
        _commitDice = dice;
    }

    /// <summary>Force the roll of every committed order <paramref name="rule"/> answers, read from
    /// the order's kind and target as it is committed; null lets the order roll live. The rule
    /// stays until it is replaced or cleared with null. A pending <see cref="ForceOnCommit"/> wins.</summary>
    public void ForceByOrder(Func<PlayerOrder, ForcedRoll?>? rule) => _orderRule = rule;

    /// <summary>The scene's <c>BeforePlayerCommand</c>: queue what <see cref="ForceOnCommit"/> left,
    /// or what the order rule gives for this order.</summary>
    internal void OnCommit(PlayerOrder order)
    {
        if (_commitD20 == null && _commitDice.Length == 0)
        {
            if (_orderRule?.Invoke(order) is { } roll) Force(roll.D20, roll.Dice);
            return;
        }
        var d20 = _commitD20;
        var dice = _commitDice;
        _commitD20 = null;
        _commitDice = Array.Empty<int>();
        Hooks.ClearForcedDice();
        int[] d20s = d20 == null ? Array.Empty<int>() : new[] { d20() };
        Force(d20s, dice);
    }

    // ---------------------------------------------------------------- Turn end

    /// <summary>True ends a hero's turn at 0 actions; false keeps it open for the script.</summary>
    public bool AutoEndTurn
    {
        get => Scene.AutoEndTurn;
        set => Scene.AutoEndTurn = value;
    }

    /// <summary>End the actor's turn as End Turn does, with no tip, once its last action has
    /// played, and wait until the turn is over.</summary>
    public async Task EndTurn(ICharacter actor)
    {
        if (!await WaitUntil(actor, () => Scene.Controller is { Busy: false })) return;
        Scene.Controller?.EndTurn();
        await WaitTurnEnd(actor);
    }

    // ---------------------------------------------------------------- Time

    public async Task NextFrame()
    {
        _cts.Token.ThrowIfCancellationRequested();
        await _host.ToSignal(_host.GetTree(), SceneTree.SignalName.ProcessFrame);
        _cts.Token.ThrowIfCancellationRequested();
    }

    public async Task Delay(double seconds)
    {
        _cts.Token.ThrowIfCancellationRequested();
        await _host.ToSignal(_host.GetTree().CreateTimer(seconds), SceneTreeTimer.SignalName.Timeout);
        _cts.Token.ThrowIfCancellationRequested();
    }

    /// <summary>The degree a forced roll should land, named for the scripts.</summary>
    public static DegreeOfSuccess Hit => DegreeOfSuccess.Success;
    public static DegreeOfSuccess Miss => DegreeOfSuccess.Failure;
    public static DegreeOfSuccess Crit => DegreeOfSuccess.CriticalSuccess;
    public static DegreeOfSuccess Fumble => DegreeOfSuccess.CriticalFailure;
}
