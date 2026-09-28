using System.Collections.Generic;

namespace Delve.Combat;

/// <summary>One labelled modifier: "MAP -5", "Off-guard (Prone) +2", "Frightened 1 -1".
/// <see cref="IconKey"/> names the condition that causes it, empty when no condition does.</summary>
public sealed record ModifierChip(string Label, int Value, string IconKey = "")
{
    public string Text => $"{Label} {Value:+0;-0}";

    public ModifierChip Negated => this with { Value = -Value };
}

/// <summary>The modifiers that applied to one roll, read from the engine's modifier stacks after PF2e
/// stacking. <see cref="Roll"/> sums into the roller's total; <see cref="Defense"/> sums into the AC or
/// DC it meets.</summary>
public sealed record RollBreakdown(IReadOnlyList<ModifierChip> Roll, IReadOnlyList<ModifierChip> Defense)
{
    public static readonly RollBreakdown None = new(System.Array.Empty<ModifierChip>(), System.Array.Empty<ModifierChip>());

    public bool IsEmpty => Roll.Count == 0 && Defense.Count == 0;
}
