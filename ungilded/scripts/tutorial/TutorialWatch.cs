using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Events;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Tutorial;

/// <summary>
/// One encounter's link from the combat event stream to <see cref="TutorialHooks"/>. The session
/// calls it around every presented <see cref="BattleEvent"/>, at each enemy tile exit and when a
/// player action ends; it turns what it sees into pause-point callbacks and awaits them there, so
/// the encounter loop waits exactly as it waits for the reaction prompt.
///
/// Damage and conditions are found by comparing each combatant with its last snapshot, so HP lost
/// with no event of its own (persistent damage at a turn end) still reports. A strike reports once
/// its damage and death events have played, which is the first event that is not one of them, or
/// the end of the action.
/// </summary>
internal sealed class TutorialWatch
{
    private readonly TutorialHooks _hooks;
    private readonly Func<IEnumerable<ICharacter>> _combatants;
    private readonly Dictionary<ICharacter, int> _hp = new();
    private readonly Dictionary<ICharacter, HashSet<Condition>> _conditions = new();
    private readonly Queue<Func<Task>> _deferred = new();

    private StrikeContext? _lastStrike;
    private StrikeInfo? _pendingStrike;
    private ICharacter? _strideStarting;
    private IReadOnlyList<PF2eVec>? _plannedPath;

    /// <summary>Presentation for a held stride: the scene leans the token toward the next tile.</summary>
    internal Func<ICharacter, PF2eVec, Task>? HoldStride { get; set; }

    internal TutorialWatch(TutorialHooks hooks, Func<IEnumerable<ICharacter>> combatants)
    {
        _hooks = hooks;
        _combatants = combatants;
        Snapshot();
    }

    /// <summary>Take the current HP and conditions as the baseline, with no callbacks.</summary>
    internal void Snapshot()
    {
        foreach (var c in _combatants())
        {
            _hp[c] = c.Health?.CurrentHP ?? 0;
            _conditions[c] = ConditionsOf(c);
        }
    }

    /// <summary>The engine's last resolved strike; matched to the AttackRolled event that follows.</summary>
    internal void NoteStrike(StrikeContext context) => _lastStrike = context;

    /// <summary>The route of the scripted Stride about to start.</summary>
    internal void NotePlannedPath(IReadOnlyList<PF2eVec> path) => _plannedPath = path;

    /// <summary>A callback raised from a synchronous engine site, run at the next pause point.</summary>
    internal void Defer(Func<Task> callback) => _deferred.Enqueue(callback);

    internal async Task BeforeEvent(BattleEvent evt)
    {
        if (_pendingStrike != null && !ContinuesStrike(evt)) await FlushStrike();
        await FlushDeferred();
    }

    internal async Task AfterEvent(BattleEvent evt)
    {
        switch (evt.Type)
        {
            case BattleEventType.AttackRolled:
                if (_pendingStrike != null) await FlushStrike();
                _pendingStrike = StrikeFrom(evt);
                // The engine applied the damage already; it reports after its DamageDealt plays.
                return;
            case BattleEventType.SpellCast:
                return;
            case BattleEventType.MovementStarted when evt.Path == null && evt.Source is { TeamId: not 1 }:
                _strideStarting = evt.Source;
                break;
        }
        await Compare();
    }

    /// <summary>The end of a player action or turn: everything still pending reports now.</summary>
    internal async Task Settle()
    {
        await FlushStrike();
        await FlushDeferred();
        await Compare();
    }

    /// <summary>Movement reaction check for one tile exit. The first exit of an enemy Stride holds
    /// for the BeforeEnemyStride callbacks; the reaction check runs after them.</summary>
    internal async Task BeforeTileExit(BeforeMoveEventArgs args)
    {
        if (!ReferenceEquals(args.Actor, _strideStarting)) return;
        _strideStarting = null;
        var path = _plannedPath ?? new[] { args.FromTile, args.ToTile };
        _plannedPath = null;
        if (!_hooks.HasStrideGates) return;
        if (HoldStride != null) await HoldStride(args.Actor, args.ToTile);
        await _hooks.RaiseEnemyStride(new EnemyStride(args.Actor, args.FromTile, args.ToTile, path));
    }

    private static bool ContinuesStrike(BattleEvent evt) => evt.Type is BattleEventType.DamageDealt
        or BattleEventType.CreatureDied or BattleEventType.CreatureUnconscious or BattleEventType.ShieldBlocked
        or BattleEventType.ConditionApplied or BattleEventType.ConditionValueChanged;

    private StrikeInfo? StrikeFrom(BattleEvent evt)
    {
        var ctx = _lastStrike;
        if (ctx == null || evt.Source == null || evt.Target == null
            || !ReferenceEquals(ctx.Attacker, evt.Source) || !ReferenceEquals(ctx.Defender, evt.Target))
            return null;
        _lastStrike = null;
        return new StrikeInfo(ctx.Attacker, ctx.Defender, ctx.Degree, ctx.D20Roll, ctx.Total, ctx.TargetAC,
            ctx.Hit ? ctx.DamageResult?.TotalDamage ?? 0 : 0,
            ctx.TargetKilled || ctx.Defender.Health?.IsDead == true,
            ctx.SourceAction?.IsReaction == true);
    }

    private async Task FlushStrike()
    {
        if (_pendingStrike is not { } strike) return;
        _pendingStrike = null;
        await Compare();
        await _hooks.RaiseStrike(strike);
    }

    private async Task FlushDeferred()
    {
        while (_deferred.Count > 0) await _deferred.Dequeue()();
    }

    /// <summary>Report HP lost and conditions gained since the last snapshot.</summary>
    private async Task Compare()
    {
        foreach (var c in _combatants().ToArray())
        {
            int hp = c.Health?.CurrentHP ?? 0;
            int before = _hp.TryGetValue(c, out int seen) ? seen : hp;
            _hp[c] = hp;
            if (hp < before) await _hooks.RaiseDamage(c, hp);

            var now = ConditionsOf(c);
            var had = _conditions.TryGetValue(c, out var previous) ? previous : now;
            _conditions[c] = now;
            foreach (var condition in now.Where(x => !had.Contains(x)).ToArray())
                await _hooks.RaiseCondition(c, condition);
        }
    }

    private static HashSet<Condition> ConditionsOf(ICharacter c)
        => c.Conditions?.GetAllConditions().Select(i => i.Definition.Condition).ToHashSet() ?? new HashSet<Condition>();
}
