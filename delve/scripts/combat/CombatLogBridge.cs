using System;
using System.Collections.Generic;
using Delve.UI;
using Godot;
using PF2e.Actions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Events;

namespace Delve.Combat;

/// <summary>Encounter-owned subscriptions; supplements engine text with presentation outcomes.</summary>
internal sealed class CombatLogBridge : IDisposable
{
    private readonly CombatLogPanel _panel;
    private readonly HashSet<ICharacter> _units = new();
    private bool _disposed;

    internal CombatLogBridge(CombatLogPanel panel, IReadOnlyList<ICharacter> allies, IReadOnlyList<ICharacter> enemies)
    {
        _panel = panel;
        var actors = new List<(string, Color)>();
        foreach (var unit in allies) { _units.Add(unit); actors.Add((unit.Name, UiColors.LogAlly)); }
        foreach (var unit in enemies) { _units.Add(unit); actors.Add((unit.Name, UiColors.LogEnemy)); }
        panel.SetActors(actors);
        CombatLog.OnLogEntry += OnEntry;
        SpellCastAction.OnSpellResolved += OnSpell;
    }

    private void OnEntry(CombatLogEntry entry)
    {
        if (!_disposed) _panel.AppendEntry(entry.Message, (int)entry.Severity, entry.IsDetail);
    }

    internal void Present(BattleEvent evt)
    {
        if (_disposed) return;
        switch (evt.Type)
        {
            case BattleEventType.TurnStarted when evt.Source != null:
                _panel.BeginTurn(evt.Source.Name);
                break;
            case BattleEventType.DamageDealt when evt.Target != null && evt.IntValue is int damage:
                string type = evt.DamageType is { } damageType ? $" {damageType.ToString().ToLowerInvariant()}" : "";
                _panel.AppendEntry($"{evt.Target.Name} takes {damage}{type} damage.", 0, true);
                break;
            case BattleEventType.Healed when evt.Target != null && evt.IntValue is int healing:
                _panel.AppendEntry($"{evt.Target.Name} regains {healing} HP.", 5, true);
                break;
            case BattleEventType.CreatureDied when evt.Source != null:
                _panel.AppendEntry($"{evt.Source.Name} dies.", 0, true);
                break;
            case BattleEventType.MovementStarted when evt.Path == null && !string.IsNullOrWhiteSpace(evt.Description):
                _panel.AppendEntry(evt.Description, 8, false);
                break;
        }
    }

    private void OnSpell(SpellCompletionEvent evt)
    {
        if (_disposed || !_units.Contains(evt.Caster) || evt.Context is not { IsPreview: false } ctx
            || ctx.TargetResults == null) return;
        bool save = ctx.Spell.DefenseType is SpellDefenseType.BasicSave or SpellDefenseType.Save;
        bool attack = ctx.Spell.DefenseType == SpellDefenseType.SpellAttack;
        if (!save && !attack) return;
        foreach (var target in ctx.TargetResults)
        {
            if (target.Target == null || target.HealingApplied > 0) continue;
            // Spell results store degree from the target's perspective. Per-target roll totals
            // are not retained by the engine, so report the resolved degree without inventing dice.
            string result = target.Degree switch {
                DegreeOfSuccess.CriticalSuccess => save ? "critically saves" : "is critically missed",
                DegreeOfSuccess.Success => save ? "saves" : "is missed",
                DegreeOfSuccess.Failure => save ? "fails the save" : "is hit",
                _ => save ? "critically fails the save" : "is critically hit",
            };
            if (target.ConcealmentMiss) result = "is missed due to concealment";
            int severity = target.Degree >= DegreeOfSuccess.Success ? 1 : 4;
            _panel.AppendEntry($"{target.Target.Name} {result}{(save ? $" ({ctx.Spell.SaveType})" : "")}.", severity, true);
        }
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        CombatLog.OnLogEntry -= OnEntry;
        SpellCastAction.OnSpellResolved -= OnSpell;
    }
}
