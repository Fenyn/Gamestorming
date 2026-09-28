using System;
using System.Collections.Generic;
using System.Linq;
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
    private readonly IReadOnlyList<ICharacter> _enemies;
    private bool _disposed;

    /// <summary>An attack title named its target, before the roll line arrives, so the board can
    /// label the target while the roll row shows.</summary>
    internal event Action<ICharacter>? AttackTargetNamed;

    internal CombatLogBridge(CombatLogPanel panel, IReadOnlyList<ICharacter> allies, IReadOnlyList<ICharacter> enemies)
    {
        _panel = panel;
        _enemies = enemies;
        var actors = new List<(string, Color)>();
        foreach (var unit in allies) { _units.Add(unit); actors.Add((unit.Name, UiColors.LogAlly)); }
        foreach (var unit in enemies) { _units.Add(unit); actors.Add((unit.Name, UiColors.LogEnemy)); }
        panel.SetActors(actors);
        panel.SetEnemies(System.Linq.Enumerable.Select(enemies, unit => unit.Name));
        CombatLog.OnLogEntry += OnEntry;
        SpellCastAction.OnSpellResolved += OnSpell;
    }

    private void OnEntry(CombatLogEntry entry)
    {
        if (_disposed || entry.Message is not { } line) return;
        string? message = line;
        RollBreakdown? breakdown = null;
        if (!entry.IsDetail)
        {
            var attacked = Find(CombatLogFormat.AttackTarget(line));
            _subject = attacked ?? Trailing(line);
            _actor = _units.Where(unit => line.StartsWith(unit.Name + " ", StringComparison.Ordinal))
                .OrderByDescending(unit => unit.Name.Length).FirstOrDefault();
            int with = line.LastIndexOf(" with ", StringComparison.Ordinal);
            _strikeName = with < 0 ? null : line[(with + 6)..];
            if (attacked != null && _actor != null && attacked != _actor) AttackTargetNamed?.Invoke(attacked);
        }
        else
        {
            breakdown = Breakdown(line);
            message = CombatLogMasks.Mask(line, _subject, _enemies);
        }
        if (message != null) _panel.AppendEntry(message, (int)entry.Severity, entry.IsDetail, breakdown, EnemyRoller(line));
    }

    /// <summary>The roller's side from its team: the creature the roll line names, else the action's actor.</summary>
    private bool? EnemyRoller(string line)
    {
        if (CombatRoll.Parse(line) is not { } roll) return null;
        var roller = _units.Where(unit => roll.Prefix.StartsWith(unit.Name, StringComparison.Ordinal))
            .OrderByDescending(unit => unit.Name.Length).FirstOrDefault() ?? _actor;
        return roller == null ? null : roller.TeamId != 1;
    }

    /// <summary>The creature the last action title names: an attack's target, or the creature a skill
    /// action title ends with. Its roll and damage lines follow as details.</summary>
    private ICharacter? _subject;

    /// <summary>The creature the last action title starts with, and the strike it names after "with".</summary>
    private ICharacter? _actor;
    private string? _strikeName;

    /// <summary>The named modifiers behind a roll line, read the moment the engine logs it: a Strike's
    /// attack and AC modifiers, or a skill check's skill modifiers and the save DC it met.</summary>
    private RollBreakdown? Breakdown(string message)
    {
        if (_actor == null || _subject == null || CombatRoll.Parse(message) is not { } roll) return null;
        if (roll.IsAttack)
        {
            var (weapon, type) = ModifierBreakdown.StrikeWeapon(_actor, _strikeName);
            return ModifierBreakdown.Attack(_actor, _subject, type, weapon);
        }
        if (!Enum.TryParse<Skill>(roll.Prefix.TrimEnd(':', ' '), out var skill)) return null;
        var saves = Enum.GetValues<SavingThrow>().Where(s => !roll.DcMasked
            && 10 + PF2e.Utilities.StatsCalculator.CalculateSave(_subject, s) == roll.DC).ToList();
        return ModifierBreakdown.Check(_actor, skill, _subject, saves.Count == 1 ? saves[0] : null);
    }

    private ICharacter? Find(string name)
    {
        if (name.Length == 0) return null;
        foreach (var unit in _units)
            if (unit.Name == name) return unit;
        return null;
    }

    private ICharacter? Trailing(string title)
        => _units.Where(unit => title.EndsWith(" " + unit.Name, StringComparison.Ordinal))
            .OrderByDescending(unit => unit.Name.Length).FirstOrDefault();

    internal static bool ArmorClassKnown(ICharacter target) => CombatLogMasks.Known(target, CreatureKnowledgeField.AC);

    internal void Present(BattleEvent evt)
    {
        if (_disposed) return;
        switch (evt.Type)
        {
            case BattleEventType.TurnStarted when evt.Source != null:
                _panel.BeginTurn(evt.Source.Name);
                break;
            case BattleEventType.TurnDelayed when evt.Source != null && evt.Target != null:
                _panel.AppendEntry($"{evt.Source.Name} delays until after {evt.Target.Name}.", 8, false);
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
                _panel.AppendEntry(InFeet(evt), 8, false);
                break;
        }
    }

    private static readonly System.Text.RegularExpressions.Regex EngineStride =
        new(@"^(.+) (Strides|Crawls) to \((\d+), (\d+)\)$");

    /// <summary>The engine's AI stride or crawl names a grid coordinate. The log reads the
    /// straight-line distance from the mover's start tile in feet instead.</summary>
    private static string InFeet(BattleEvent evt)
    {
        var match = EngineStride.Match(evt.Description!);
        if (!match.Success || evt.Source == null) return evt.Description!;
        var destination = new PF2e.Vector2Int(int.Parse(match.Groups[3].Value), int.Parse(match.Groups[4].Value));
        int tiles = PF2e.Utilities.AreaCalculator.GetPF2eDistance(evt.Source.GridPosition, destination);
        return $"{match.Groups[1].Value} {match.Groups[2].Value.ToLowerInvariant()} {tiles * MovementActions.FeetPerTile} ft";
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
