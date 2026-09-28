using System.Collections.Generic;
using System.Linq;
using Delve.Run;
using PF2e.Core;
using PF2e.Data;

namespace Delve.Combat;

/// <summary>One species group in the combat journal: "Goblin Warrior", "A, B", "Known 3 of 11".</summary>
public sealed record JournalGroupView(string Name, string Letters, string KnownText, IReadOnlyList<JournalFact> Facts);

/// <summary>Builds the combat journal from the creatures in the current fight, masked by the same
/// reveal check the inspect card and the forecast use.</summary>
internal static class CombatJournalRows
{
    internal static IReadOnlyList<JournalGroupView> Build(IEnumerable<ICharacter> enemies, EnemyLetters letters)
    {
        var groups = new List<JournalGroupView>();
        foreach (var group in enemies.Where(c => c.CreatureStats != null).GroupBy(letters.BaseNameFor))
        {
            var first = group.First();
            var stats = first.CreatureStats!;
            string? id = stats.CreatureId;
            var facts = CreatureFacts.Facts(stats.SourceDefinition, stats.Data,
                field => UnitInspectFactory.IsCreatureFieldKnown(id, field));
            string marks = string.Join(", ", group.Select(letters.LetterFor).Where(l => l.Length > 0));
            groups.Add(new JournalGroupView(group.Key, marks, CreatureFacts.KnownText(facts), facts));
        }
        return groups;
    }

    /// <summary>The log line for fields just learned: "Journal: Goblin Warrior  AC 16".</summary>
    internal static string LearnedLine(ICharacter target, string name, IEnumerable<CreatureKnowledgeField> fields)
    {
        var stats = target.CreatureStats!;
        var pairs = fields.Select(f => CreatureFacts.Pair(f, stats.SourceDefinition, stats.Data, true));
        return $"Journal: {name}  {string.Join("  ", pairs)}";
    }
}
