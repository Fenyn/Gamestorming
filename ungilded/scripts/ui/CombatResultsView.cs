using System.Collections.Generic;
using Ungilded.Combat;
using PF2e.Core;

namespace Ungilded.UI;

/// <summary>One hero's changed figures on the results screen.</summary>
public sealed record ResultMemberRow(PF2eCharacter Member, IReadOnlyList<FigureView> Figures);

/// <summary>What the results screen shows after a fight. A host fills it; an empty view shows the
/// headline only.</summary>
public sealed record CombatResultsView
{
    public IReadOnlyList<FigureView> Figures { get; init; } = System.Array.Empty<FigureView>();
    public IReadOnlyList<ResultMemberRow> Members { get; init; } = System.Array.Empty<ResultMemberRow>();
    public IReadOnlyList<string> Notes { get; init; } = System.Array.Empty<string>();

    /// <summary>Progress bar fill from 0 to 1; null hides the bar.</summary>
    public double? Progress { get; init; }
}
