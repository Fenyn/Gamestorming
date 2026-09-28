using System;
using System.Collections.Generic;
using System.Linq;
using PF2e.Conditions;
using PF2e.Core;

namespace Delve.Combat;

/// <summary>A unit's conditions as icon marks for the rail, the party chips and the hover card, most
/// urgent first, so a short row still shows what stops a unit acting or moving.</summary>
public static class ConditionMarks
{
    private static readonly Condition[] Priority =
    {
        Condition.Dying, Condition.Wounded, Condition.Doomed, Condition.Unconscious, Condition.Paralyzed, Condition.Restrained,
        Condition.Grabbed, Condition.Immobilized, Condition.Stunned, Condition.Prone,
    };

    public static ConditionMarkView[] For(ICharacter character)
        => character.Conditions?.GetAllConditions()
            .GroupBy(c => (c.Definition.Condition, c.PersistentDamage?.DamageType))
            .Select(g => g.OrderByDescending(c => c.Value).First())
            .OrderBy(c => Rank(c.Definition.Condition))
            .ThenBy(c => Name(c.Definition))
            .Select(c => new ConditionMarkView(IconKey(c), Label(character, c),
                c.Definition.HasValue ? c.Value : 0, c.Definition.Description ?? ""))
            .ToArray() ?? Array.Empty<ConditionMarkView>();

    /// <summary>"Off-Guard" reads "Off-guard", the case the rest of the UI uses.</summary>
    public static string Name(ConditionDefinition definition)
    {
        var name = definition.DisplayName.ToCharArray();
        for (int i = 1; i < name.Length; i++)
            if (name[i - 1] == '-') name[i] = char.ToLowerInvariant(name[i]);
        return new string(name);
    }

    /// <summary>The name with the effective value the engine applies: "Frightened 1".</summary>
    public static string Label(ICharacter owner, ConditionInstance instance)
    {
        if (instance.PersistentDamage != null) return instance.DisplayLabel;
        var definition = instance.Definition;
        int value = owner.Conditions?.GetConditionValue(definition) ?? instance.Value;
        return definition.HasValue && value > 0 ? $"{Name(definition)} {value}" : Name(definition);
    }

    public static string IconKey(ConditionInstance instance)
        => instance.PersistentDamage?.DamageType.ToString() ?? instance.Definition.Condition.ToString();

    private static int Rank(Condition condition)
    {
        int index = Array.IndexOf(Priority, condition);
        return index < 0 ? Priority.Length : index;
    }

    public static IEnumerable<string> Labels(ICharacter character) => For(character).Select(m => m.Label);
}
