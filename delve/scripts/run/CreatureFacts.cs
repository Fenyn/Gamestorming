using System;
using System.Collections.Generic;
using System.Linq;
using PF2e.CharacterComponents;
using PF2e.Core;
using PF2e.Data;

namespace Delve.Run;

/// <summary>One journal field as printed: "AC 16" when known, "AC ?" when not.</summary>
public sealed record JournalFact(string Text, bool Known);

/// <summary>Journal fields as concise labelled values ("AC 16", "Fort +7", "Weak fire 5"), "?" when
/// unknown. Reads a stat block and its definition, so it serves live combatants and the outpost.</summary>
public static class CreatureFacts
{
    public const string Unknown = "?";

    public static string Pair(CreatureKnowledgeField field, EnemyDefinition? def, CreatureStatBlockData stats, bool known)
        => $"{KnowledgeRevealOrder.LabelFor(field)} {(known ? Value(field, def, stats) : Unknown)}";

    /// <summary>Every journal field in reveal order.</summary>
    public static IReadOnlyList<JournalFact> Facts(EnemyDefinition? def, CreatureStatBlockData stats, Func<CreatureKnowledgeField, bool> known)
        => KnowledgeRevealOrder.Fields.Select(row =>
        {
            bool isKnown = known(row.Field);
            return new JournalFact(Pair(row.Field, def, stats, isKnown), isKnown);
        }).ToArray();

    public static string KnownText(IReadOnlyList<JournalFact> facts) => $"Known {facts.Count(f => f.Known)} of {facts.Count}";

    public static string Value(CreatureKnowledgeField field, EnemyDefinition? def, CreatureStatBlockData stats) => field switch
    {
        CreatureKnowledgeField.AC => stats.AC.ToString(),
        CreatureKnowledgeField.MaxHP => stats.MaxHP.ToString(),
        CreatureKnowledgeField.FortSave => Signed(stats.FortSave),
        CreatureKnowledgeField.RefSave => Signed(stats.RefSave),
        CreatureKnowledgeField.WillSave => Signed(stats.WillSave),
        CreatureKnowledgeField.Speeds => Speeds(stats),
        CreatureKnowledgeField.Weaknesses => Affinities(def?.Weaknesses),
        CreatureKnowledgeField.Resistances => Affinities(def?.Resistances),
        CreatureKnowledgeField.Immunities => Immunities(def),
        CreatureKnowledgeField.Strikes => List((stats.Strikes ?? Array.Empty<CreatureStrike>())
            .Select(s => $"{s.StrikeName} {Signed(s.AttackBonus)}")),
        CreatureKnowledgeField.Traits => List((def?.CreatureTraits?.Traits ?? Enumerable.Empty<TraitDefinition>())
            .Where(t => t != null && t.Category != TraitCategory.Rarity).Select(t => t.DisplayName)),
        _ => "",
    };

    private static string Signed(int value) => value.ToString("+0;-0;0");

    private static string Speeds(CreatureStatBlockData stats)
    {
        var parts = new List<string> { $"{stats.SpeedInFeet} ft" };
        if (stats.ClimbSpeedFeet > 0) parts.Add($"climb {stats.ClimbSpeedFeet} ft");
        if (stats.SwimSpeedFeet > 0) parts.Add($"swim {stats.SwimSpeedFeet} ft");
        if (stats.FlySpeedFeet > 0) parts.Add($"fly {stats.FlySpeedFeet} ft");
        if (stats.BurrowSpeedFeet > 0) parts.Add($"burrow {stats.BurrowSpeedFeet} ft");
        return string.Join(", ", parts);
    }

    private static string Affinities(IEnumerable<DamageAffinity>? entries)
        => List((entries ?? Enumerable.Empty<DamageAffinity>()).Select(a => $"{Lower(a.Type)} {a.Value}"));

    private static string Immunities(EnemyDefinition? def)
    {
        if (def == null) return "none";
        var names = (def.DamageImmunities ?? Array.Empty<DamageType>()).Select(Lower)
            .Concat((def.ConditionImmunities ?? Array.Empty<PF2e.Conditions.ConditionDefinition>())
                .Where(c => c != null).Select(c => c.DisplayName.ToLowerInvariant()))
            .Concat((def.AfflictionTagImmunities ?? Array.Empty<AfflictionTag>())
                .Where(t => t != AfflictionTag.None).Select(t => t.ToString().ToLowerInvariant()));
        return List(names.Distinct());
    }

    private static string Lower(DamageType type) => type.ToString().ToLowerInvariant();

    private static string List(IEnumerable<string> items)
    {
        string text = string.Join(", ", items.Where(s => !string.IsNullOrWhiteSpace(s)));
        return text.Length == 0 ? "none" : text;
    }
}
