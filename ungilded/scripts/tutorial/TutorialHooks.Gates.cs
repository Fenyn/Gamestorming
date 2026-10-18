using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Data;

namespace Ungilded.Tutorial;

/// <summary>
/// Pause points. Each registration is a callback the combat loop awaits before it continues, the
/// same way it awaits the reaction prompt: the board, the AI and the player's next order all wait
/// on the returned Task. A callback that must not pause combat returns a completed Task and runs
/// its own work in the background. Every registration returns a handle; disposing it removes the
/// callback.
/// </summary>
public sealed partial class TutorialHooks
{
    private readonly List<Func<EnemyStride, Task>> _beforeEnemyStride = new();
    private readonly List<Func<ICharacter, Task>> _turnStarted = new();
    private readonly List<Func<StrikeInfo, Task>> _afterStrike = new();
    private readonly List<Func<ICharacter, int, Task>> _damageTaken = new();
    private readonly List<Func<ICharacter, Condition, Task>> _conditionGained = new();
    private readonly List<Func<ICharacter, CreatureKnowledgeField, Task>> _knowledgeRevealed = new();
    private readonly List<Func<BattleResult, Task>> _encounterFinished = new();
    private readonly List<Func<Task>> _partyWiped = new();
    private readonly List<HpThreshold> _thresholds = new();

    private sealed class HpThreshold
    {
        public required ICharacter Unit;
        public required float Fraction;
        public required Func<Task> Callback;
        public bool Fired;
    }

    /// <summary>An enemy is about to leave its first tile of a Stride, scripted or AI. The token
    /// leans toward the next tile and holds; a Reactive Strike prompt comes after the callback.</summary>
    public IDisposable BeforeEnemyStride(Func<EnemyStride, Task> callback) => Add(_beforeEnemyStride, callback);

    /// <summary>A turn began: before the player gets the menu, before the AI plans, before an auto-pass.</summary>
    public IDisposable OnTurnStarted(Func<ICharacter, Task> callback) => Add(_turnStarted, callback);

    /// <summary>A Strike resolved and its damage and death have played.</summary>
    public IDisposable AfterStrikeResolved(Func<StrikeInfo, Task> callback) => Add(_afterStrike, callback);

    /// <summary>A combatant lost HP; the second argument is its HP now.</summary>
    public IDisposable OnDamageTaken(Func<ICharacter, int, Task> callback) => Add(_damageTaken, callback);

    /// <summary>A combatant gained a condition it did not have.</summary>
    public IDisposable OnConditionGained(Func<ICharacter, Condition, Task> callback) => Add(_conditionGained, callback);

    /// <summary>Recall Knowledge revealed a field; the creature is the one that was studied.</summary>
    public IDisposable OnKnowledgeRevealed(Func<ICharacter, CreatureKnowledgeField, Task> callback)
        => Add(_knowledgeRevealed, callback);

    /// <summary>The encounter result is known, before the result banner shows.</summary>
    public IDisposable OnEncounterFinished(Func<BattleResult, Task> callback) => Add(_encounterFinished, callback);

    /// <summary>Every party member is down. Runs before <see cref="OnEncounterFinished"/>. The session
    /// then stops; restart the fight after this returns, not inside it.</summary>
    public IDisposable OnPartyWiped(Func<Task> callback) => Add(_partyWiped, callback);

    /// <summary>Fires once, the first time the character's HP drops to or below
    /// floor(MaxHP x <paramref name="fraction"/>).</summary>
    public IDisposable OnHpBelow(ICharacter character, float fraction, Func<Task> callback)
    {
        var threshold = new HpThreshold { Unit = character, Fraction = fraction, Callback = callback };
        _thresholds.Add(threshold);
        return new Registration(() => _thresholds.Remove(threshold));
    }

    /// <summary>Arm every HP threshold again, for a restarted fight.</summary>
    public void RearmHpThresholds()
    {
        foreach (var threshold in _thresholds) threshold.Fired = false;
    }

    /// <summary>Drop every pause-point callback and HP threshold.</summary>
    public void ClearCallbacks()
    {
        _beforeEnemyStride.Clear();
        _turnStarted.Clear();
        _afterStrike.Clear();
        _damageTaken.Clear();
        _conditionGained.Clear();
        _knowledgeRevealed.Clear();
        _encounterFinished.Clear();
        _partyWiped.Clear();
        _thresholds.Clear();
    }

    internal bool HasStrideGates => _beforeEnemyStride.Count > 0;

    internal Task RaiseEnemyStride(EnemyStride stride) => Run(_beforeEnemyStride, c => c(stride));
    internal Task RaiseTurnStarted(ICharacter unit) => Run(_turnStarted, c => c(unit));
    internal Task RaiseStrike(StrikeInfo strike) => Run(_afterStrike, c => c(strike));
    internal Task RaiseCondition(ICharacter unit, Condition condition) => Run(_conditionGained, c => c(unit, condition));
    internal Task RaiseKnowledge(ICharacter creature, CreatureKnowledgeField field) => Run(_knowledgeRevealed, c => c(creature, field));
    internal Task RaiseFinished(BattleResult result) => Run(_encounterFinished, c => c(result));
    internal Task RaisePartyWiped() => Run(_partyWiped, c => c());

    /// <summary>Damage callbacks, then any HP threshold the new HP crossed for the first time.</summary>
    internal async Task RaiseDamage(ICharacter unit, int hp)
    {
        await Run(_damageTaken, c => c(unit, hp));
        foreach (var threshold in _thresholds.ToArray())
        {
            if (threshold.Fired || !ReferenceEquals(threshold.Unit, unit) || unit.Health == null) continue;
            int limit = (int)MathF.Floor(unit.Health.MaxHP * threshold.Fraction);
            if (hp > limit) continue;
            threshold.Fired = true;
            await threshold.Callback();
        }
    }

    /// <summary>Await each callback in registration order. A snapshot, so a callback may register
    /// or dispose others.</summary>
    private static async Task Run<T>(List<T> callbacks, Func<T, Task> invoke)
    {
        if (callbacks.Count == 0) return;
        foreach (var callback in callbacks.ToArray())
            await invoke(callback);
    }

    private static IDisposable Add<T>(List<T> list, T callback)
    {
        list.Add(callback);
        return new Registration(() => list.Remove(callback));
    }

    private sealed class Registration : IDisposable
    {
        private Action? _remove;
        public Registration(Action remove) => _remove = remove;
        public void Dispose() { _remove?.Invoke(); _remove = null; }
    }
}
