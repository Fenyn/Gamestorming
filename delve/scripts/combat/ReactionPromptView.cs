using System.Collections.Generic;

namespace Delve.Combat;

/// <summary>
/// UI-facing snapshot of a pending reaction prompt. Pure Delve data, built by
/// <see cref="ReactionPromptBuilder"/> from the engine's ReactionPromptContext.
/// </summary>
public sealed record ReactionPromptView
{
    public required string ReactorName { get; init; }

    /// <summary>Engine UniqueId of the reactor, so the HUD can frame its party chip and plate.</summary>
    public int ReactorId { get; init; }

    /// <summary>The reaction's display name ("Shield Block", "Reactive Strike").</summary>
    public required string ReactionName { get; init; }

    /// <summary>Prompt heading, "Shield Block?".</summary>
    public string Title { get; init; } = "";

    /// <summary>Label of the accept button: "Block", "Strike" or "Use".</summary>
    public string AcceptLabel { get; init; } = "Use";

    /// <summary>At most two compact numbers: before→after pairs or labelled values.</summary>
    public IReadOnlyList<FigureView> Figures { get; init; } = System.Array.Empty<FigureView>();

    /// <summary>The consequence as full sentences. Shown on hover, or as the body when there are no figures.</summary>
    public string Description { get; init; } = "";
}
