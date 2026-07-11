namespace Bulwark.Combat;

/// <summary>
/// UI-facing snapshot of a pending reaction prompt ("Use Shield Block?"). Pure Bulwark data —
/// deliberately carries no PF2e engine types so it can be consumed by passive Control scripts.
/// Built by <see cref="CombatSession"/> from the engine's ReactionPromptContext.
/// </summary>
public sealed record ReactionPromptView
{
    /// <summary>The ally who would spend their reaction.</summary>
    public required string ReactorName { get; init; }

    /// <summary>Sprite/portrait lookup key for the reactor (hero sheet name).</summary>
    public string PortraitKey { get; init; } = "";

    /// <summary>The reaction's display name (e.g. "Shield Block", "Reactive Strike").</summary>
    public required string ReactionName { get; init; }

    /// <summary>Consequence text (e.g. "Absorb 5 of 12 incoming damage — shield takes the rest.").</summary>
    public string Description { get; init; } = "";
}
