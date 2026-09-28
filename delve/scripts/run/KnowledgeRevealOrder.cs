using System.Collections.Generic;
using PF2e.Data;

namespace Delve.Run;

/// <summary>One journal field: the stat-block field and its short label ("AC", "Weak").</summary>
public sealed record KnowledgeFieldRow(CreatureKnowledgeField Field, string Label);

/// <summary>The journal's tunables: the fixed order Recall Knowledge reveals a species' fields in,
/// and how many fields each degree of success reveals. The name is always known.</summary>
public static class KnowledgeRevealOrder
{
    public static readonly IReadOnlyList<KnowledgeFieldRow> Fields = new KnowledgeFieldRow[]
    {
        new(CreatureKnowledgeField.AC, "AC"),
        new(CreatureKnowledgeField.Weaknesses, "Weak"),
        new(CreatureKnowledgeField.MaxHP, "HP"),
        new(CreatureKnowledgeField.Resistances, "Resist"),
        new(CreatureKnowledgeField.Immunities, "Immune"),
        new(CreatureKnowledgeField.FortSave, "Fort"),
        new(CreatureKnowledgeField.RefSave, "Ref"),
        new(CreatureKnowledgeField.WillSave, "Will"),
        new(CreatureKnowledgeField.Speeds, "Speed"),
        new(CreatureKnowledgeField.Strikes, "Strikes"),
        new(CreatureKnowledgeField.Traits, "Traits"),
    };

    public static int RevealCount(DegreeOfSuccess degree) => degree switch
    {
        DegreeOfSuccess.CriticalSuccess => 2,
        DegreeOfSuccess.Success => 1,
        _ => 0,
    };

    public static string LabelFor(CreatureKnowledgeField field)
    {
        foreach (var row in Fields)
            if (row.Field == field) return row.Label;
        return field.ToString();
    }
}
