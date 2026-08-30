using System.Collections.Generic;
using Delve.UI;
using Godot;

namespace Delve.Flow;

/// <summary>
/// The trail layer under the map nodes: every edge as a dashed walking-path, coloured by what it
/// means right now. The road already walked burns ember, the choices open from the party's node
/// read bright, everything else recedes to the hairline colour.
/// </summary>
public partial class MapEdgeCanvas : Control
{
    public enum EdgeState
    {
        /// <summary>A road the run can never take again.</summary>
        Dead,
        Dim,
        Open,
        Traveled,
    }

    /// <summary>One trail: node centres plus each end's clearance (half the medallion, so a boss
    /// edge backs off further than a skirmish edge and dashes never poke into a shape).</summary>
    public readonly record struct MapEdge(Vector2 From, Vector2 To, float FromClear, float ToClear, EdgeState State);

    private readonly List<MapEdge> _edges = new();

    public MapEdgeCanvas() => MouseFilter = MouseFilterEnum.Ignore;

    /// <summary>Replace all edges.</summary>
    public void SetEdges(IEnumerable<MapEdge> edges)
    {
        _edges.Clear();
        _edges.AddRange(edges);
        QueueRedraw();
    }

    public override void _Draw()
    {
        foreach (var (from, to, fromClear, toClear, state) in _edges)
        {
            var dir = (to - from).Normalized();
            var a = from + dir * fromClear;
            var b = to - dir * toClear;
            var (color, width) = state switch
            {
                EdgeState.Traveled => (UiColors.Accent, 3f),
                EdgeState.Open => (UiColors.Text with { A = 0.85f }, 2.5f),
                EdgeState.Dead => (UiColors.TextDim with { A = 0.2f }, 2f),
                // Pale bone, not the hairline brown - the fog backdrop swallows dark lines.
                _ => (UiColors.TextDim with { A = 0.5f }, 2f),
            };
            DrawDashedLine(a, b, color, width, 7f, true, true);
        }
    }
}
