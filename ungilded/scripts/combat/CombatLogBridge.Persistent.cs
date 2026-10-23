using System;
using System.Collections.Generic;
using PF2e.CharacterComponents;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Events;

namespace Ungilded.Combat;

/// <summary>
/// Persistent damage in the log, which the engine applies and ticks with no log line or battle
/// event of its own. Three rows of labels and values:
///   gained  (CONDITION)  "The Friend  Persistent bleed 1d4"
///   tick                 "The Friend  Bleed 2  HP 15 → 13"
///   ended   (RECOVERED)  "The Friend  Recovery 16 vs 15  Bleed ends"
/// The gain sits under the action that caused it; the tick and the recovery come at the creature's
/// turn end, on rows of their own.
/// </summary>
internal sealed partial class CombatLogBridge
{
    private const string Gap = "  ";
    private const string PersistentLabelPrefix = "Persistent ";

    private readonly List<Action> _persistentUnsubscribers = new();
    private readonly Dictionary<ICharacter, int> _shownHp = new();

    private void WatchPersistentDamage(ICharacter unit)
    {
        if (unit.Health is { } health)
        {
            _shownHp[unit] = health.CurrentHP;
            Action<int, int> changed = (current, _) => _shownHp[unit] = current;
            Action<DamageEvent> damaged = e => OnDamageTaken(unit, e);
            health.OnHealthChanged += changed;
            health.OnDamageTaken += damaged;
            _persistentUnsubscribers.Add(() => { health.OnHealthChanged -= changed; health.OnDamageTaken -= damaged; });
        }
        if (unit.Conditions is { } conditions)
        {
            Action<ConditionInstance> applied = c => OnConditionApplied(unit, c);
            Action<PersistentDamageRecoveryEvent> recovery = e => OnRecovery(unit, e);
            conditions.OnConditionApplied += applied;
            conditions.OnPersistentDamageRecovery += recovery;
            _persistentUnsubscribers.Add(() =>
            {
                conditions.OnConditionApplied -= applied;
                conditions.OnPersistentDamageRecovery -= recovery;
            });
        }
    }

    private void StopWatchingPersistentDamage()
    {
        foreach (var unsubscribe in _persistentUnsubscribers) unsubscribe();
        _persistentUnsubscribers.Clear();
        _shownHp.Clear();
    }

    private void OnConditionApplied(ICharacter unit, ConditionInstance condition)
    {
        if (_disposed || condition.Definition.Condition != Condition.PersistentDamage
            || condition.PersistentDamage is not { } data) return;
        _panel.AppendEntry($"{unit.Name}{Gap}Persistent {Lower(data.DamageType)} {data.DamageDice}",
            (int)CombatLogSeverity.ConditionApplied, true);
    }

    /// <summary>A tick is the damage instance the condition tracker labels "Persistent ...". It
    /// fires before the HP change event, so the tracked HP is still the HP before the tick.</summary>
    private void OnDamageTaken(ICharacter unit, DamageEvent damage)
    {
        if (_disposed || damage.Result.DamageLabel?.StartsWith(PersistentLabelPrefix, StringComparison.Ordinal) != true) return;
        int after = unit.Health.CurrentHP;
        int before = _shownHp.TryGetValue(unit, out int hp) ? hp : after + damage.Result.TotalDamage;
        _panel.AppendEntry($"{unit.Name}{Gap}{Title(damage.Result.DamageType)} {damage.Result.TotalDamage}{Gap}HP {before} → {after}",
            (int)CombatLogSeverity.Info, false);
    }

    private void OnRecovery(ICharacter unit, PersistentDamageRecoveryEvent recovery)
    {
        if (_disposed || !recovery.Recovered) return;
        _panel.AppendEntry($"{unit.Name}{Gap}Recovery {recovery.FlatCheckRoll} vs {recovery.DC}{Gap}{Title(recovery.DamageType)} ends",
            (int)CombatLogSeverity.ConditionRemoved, false);
    }

    private static string Lower(PF2e.Data.DamageType type) => type.ToString().ToLowerInvariant();

    private static string Title(PF2e.Data.DamageType type) => type.ToString();
}
