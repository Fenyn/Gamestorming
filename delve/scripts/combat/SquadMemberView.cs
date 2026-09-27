using System.Collections.Generic;

namespace Delve.Combat;

public enum ReactionMark { None, Ready, Spent }

/// <summary>One condition icon on a party chip. <see cref="IconKey"/> resolves through the condition icon set.</summary>
public sealed record ConditionMarkView(string IconKey, string Label, int Value, string Description);

/// <summary>Party-chip presentation, independent of engine character objects.</summary>
public sealed record SquadMemberView
{
    public int Id { get; init; }
    public string HeroId { get; init; } = "";
    public required string Name { get; init; }
    public int Hp { get; init; }
    public int MaxHp { get; init; }

    /// <summary>Acting now, or answering a reaction prompt: the chip takes the bone frame.</summary>
    public bool Framed { get; init; }
    public bool Focused { get; init; }
    public bool Down { get; init; }
    public ReactionMark Reaction { get; init; }
    public IReadOnlyList<ConditionMarkView> Conditions { get; init; } = System.Array.Empty<ConditionMarkView>();

    /// <summary>AC, gear, spell DC and reaction state as sentences for the chip's hover.</summary>
    public string Tooltip { get; init; } = "";
}
