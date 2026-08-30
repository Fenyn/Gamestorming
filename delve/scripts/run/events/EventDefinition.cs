using System.Collections.Generic;
using PF2e.Data;

namespace Delve.Run.Events;

/// <summary>What an event outcome does. Data only - no delegates, so events move to data files later.</summary>
public enum EventEffectKind
{
    Nothing,

    /// <summary>Heal the acting member for <c>Value</c> percent of its maximum HP.</summary>
    HealFraction,

    /// <summary>Damage the acting member for <c>Value</c>, floored at 1 HP.</summary>
    Damage,

    /// <summary>Raise (or, negative, lower) the acting member's Wounded value by <c>Value</c>.</summary>
    WoundedDelta,

    /// <summary>Add <c>Value</c> to the run's gold.</summary>
    GoldDelta,
}

/// <summary>One data-only effect of an outcome.</summary>
public sealed record EventEffect(EventEffectKind Kind, int Value = 0);

/// <summary>What one degree of success does, plus the line to show for it.</summary>
public sealed record EventOutcome(string Text, IReadOnlyList<EventEffect> Effects)
{
    /// <summary>An outcome that only prints.</summary>
    public static EventOutcome Nothing(string text) =>
        new(text, new List<EventEffect> { new(EventEffectKind.Nothing) });
}

/// <summary>The skill check an option rolls, if it rolls one.</summary>
public sealed record EventCheck(Skill Skill, int Dc, bool AllowPickActor);

/// <summary>One choice on an event, with its outcome per degree of success.</summary>
public sealed record EventOption
{
    public required string Label { get; init; }

    /// <summary>Null for an option that resolves straight to <see cref="Success"/>.</summary>
    public EventCheck? Check { get; init; }

    public required EventOutcome Success { get; init; }

    /// <summary>Falls back to <see cref="Success"/> when unset.</summary>
    public EventOutcome? CriticalSuccess { get; init; }

    /// <summary>Falls back to <see cref="Success"/> when unset.</summary>
    public EventOutcome? Failure { get; init; }

    /// <summary>Falls back to <see cref="Failure"/>, then to <see cref="Success"/>, when unset.</summary>
    public EventOutcome? CriticalFailure { get; init; }
}

/// <summary>A text encounter: what the party sees and what it may do about it.</summary>
public sealed record EventDefinition
{
    public required string Id { get; init; }
    public required string Title { get; init; }
    public required string Body { get; init; }
    public required IReadOnlyList<EventOption> Options { get; init; }
}
