using System.Collections.Generic;
using PF2e.Classes;
using PF2e.Data;

namespace Delve.Data;

/// <summary>
/// Declarative definition of a "variant combo": a base class overlaid with a subclass plus a
/// scripted level-up path (which feats are taken at which levels). Data-driven per CLAUDE.md —
/// adding a new preset build touches data only.
///
/// <see cref="ScriptedChoices"/> maps character level → the choices replayed by
/// <c>LevelUpApplicator.ApplyLevelUp</c>. For the M0 spike the only scripted decision is the
/// Free Archetype dedication feat, keyed by <c>LevelUpChoices.FreeArchetypeFeatId</c>.
/// </summary>
public sealed class VariantComboDefinition
{
    public required string Id { get; init; }
    public required string DisplayName { get; init; }
    public required string Description { get; init; }

    /// <summary>Subclass overlay merged onto the base class via ClassDefinition.ResolveSubclass.</summary>
    public required SubclassDefinition Subclass { get; init; }

    /// <summary>Scripted level-up choices, keyed by the character level they apply at.</summary>
    public Dictionary<int, LevelUpChoices> ScriptedChoices { get; init; } = new();

    /// <summary>
    /// Flatten the scripted choices for every level up to and including <paramref name="toLevel"/>,
    /// ordered by level — the shape LevelUpApplicator.ApplyLevelUp expects.
    /// </summary>
    public List<LevelUpChoices> ChoicesUpTo(int toLevel)
    {
        var result = new List<LevelUpChoices>();
        for (int level = 2; level <= toLevel; level++)
        {
            if (ScriptedChoices.TryGetValue(level, out var choices))
                result.Add(choices);
        }
        return result;
    }
}
