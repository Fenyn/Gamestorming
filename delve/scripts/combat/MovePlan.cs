using System.Collections.Generic;
using PF2e.Grid;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Combat;

/// <summary>How a smart move reaches a tile: a careful Step (adjacent, no reactions) or Strides.</summary>
public enum MoveKind { Step, Stride }

/// <summary>One reachable tile of a <see cref="MovePlan"/>: the actions it costs and the move kind.</summary>
public readonly record struct MoveOption(int Actions, MoveKind Kind);

/// <summary>The hovered band tile's cost readout for the action bar (engine-free on purpose).</summary>
public sealed record MoveHoverView(int Actions, MoveKind Kind);

/// <summary>
/// The banded movement of one actor at one moment: every tile it can end a smart move on, the
/// action cost, and the per-band path maps the hover preview and the leg list are rebuilt from.
/// Band k's map is seeded from every standable band-(k-1) tile, so a band-k tile is exactly one
/// Stride from some band-(k-1) tile and the executor's per-leg re-path always finds it. Plain C#;
/// built by <see cref="MovementPlanner"/>, read by the controller.
/// </summary>
public sealed class MovePlan
{
    private readonly PF2eVec _origin;
    private readonly IReadOnlyList<Dictionary<PF2eVec, PathEntry>> _bands;

    /// <summary>Every tile a smart move can end on, keyed by tile.</summary>
    public IReadOnlyDictionary<PF2eVec, MoveOption> Options { get; }

    public static readonly MovePlan Empty = new(default, System.Array.Empty<Dictionary<PF2eVec, PathEntry>>(),
        new Dictionary<PF2eVec, MoveOption>());

    internal MovePlan(PF2eVec origin, IReadOnlyList<Dictionary<PF2eVec, PathEntry>> bands,
        IReadOnlyDictionary<PF2eVec, MoveOption> options)
    {
        _origin = origin;
        _bands = bands;
        Options = options;
    }

    /// <summary>How many Stride bands were built (0 when the actor cannot move).</summary>
    public int BandCount => _bands.Count;

    /// <summary>
    /// The tile-by-tile route (origin first) to <paramref name="dest"/> and the tile each leg ends
    /// on, one per action. A Step is a two-tile route with one leg. Null when the tile is not an
    /// option.
    /// </summary>
    public List<PF2eVec>? PathTo(PF2eVec dest, out List<PF2eVec> legEnds)
    {
        legEnds = new List<PF2eVec>();
        if (!Options.TryGetValue(dest, out var option)) return null;

        if (option.Kind == MoveKind.Step)
        {
            legEnds.Add(dest);
            return new List<PF2eVec> { _origin, dest };
        }

        // Walk the chain outward-in: each band's parent chain ends on the seed it grew from, which
        // is the previous band's leg end. Segments are stitched origin-first afterwards.
        var segments = new List<List<PF2eVec>>();
        var cursor = dest;
        for (int band = option.Actions; band >= 1; band--)
        {
            var segment = Pathfinder.ReconstructPath(_bands[band - 1], cursor);
            if (segment.Count == 0) return null;
            legEnds.Add(cursor);
            segments.Add(segment);
            cursor = segment[0];
        }
        legEnds.Reverse();

        var path = new List<PF2eVec>();
        for (int i = segments.Count - 1; i >= 0; i--)
        {
            var segment = segments[i];
            for (int j = path.Count == 0 ? 0 : 1; j < segment.Count; j++)
                path.Add(segment[j]);
        }
        return path;
    }
}
