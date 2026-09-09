using System.Collections.Generic;
using Delve.Run;
using Godot;

namespace Delve.UI;

/// <summary>Small line symbols inside the existing destination silhouettes.</summary>
public static class MapNodeGlyphs
{
    // Coordinates are normalized to a ten-unit half-width. Each array is one stroke.
    private static readonly IReadOnlyDictionary<NodeKind, float[][]> Strokes =
        new Dictionary<NodeKind, float[][]>
        {
            [NodeKind.Combat] = new[]
            {
                new float[] { -8, 8, 8, -8, 8, -3 },
                new float[] { 8, -8, 3, -8 },
                new float[] { -8, 2, -2, 8 },
            },
            [NodeKind.Elite] = new[]
            {
                new float[] { -8, 8, 8, -8, 8, -3 },
                new float[] { 8, 8, -8, -8, -8, -3 },
                new float[] { -8, 2, -2, 8 },
                new float[] { 8, 2, 2, 8 },
            },
            [NodeKind.Event] = new[]
            {
                new float[] { 0, -9, 3, -3, 9, 0, 3, 3, 0, 9, -3, 3, -9, 0, -3, -3, 0, -9 },
            },
            [NodeKind.Rest] = new[]
            {
                new float[] { -8, 7, 0, -5, 8, 7, -8, 7 },
                new float[] { 0, -5, 0, 7 },
            },
            [NodeKind.Meeting] = new[]
            {
                new float[] { -9, 0, -2, 0 },
                new float[] { -5, -4, -2, 0, -5, 4 },
                new float[] { 9, 0, 2, 0 },
                new float[] { 5, -4, 2, 0, 5, 4 },
            },
            [NodeKind.Boss] = new[]
            {
                new float[] { -9, -5, -6, 6, 6, 6, 9, -5, 4, -1, 0, -8, -4, -1, -9, -5 },
                new float[] { -6, 9, 6, 9 },
            },
        };

    public static void Draw(CanvasItem canvas, Vector2 center, NodeKind kind, Color color)
    {
        if (!Strokes.TryGetValue(kind, out var strokes)) return;
        foreach (var stroke in strokes)
        {
            var points = new Vector2[stroke.Length / 2];
            for (int i = 0; i < points.Length; i++)
                points[i] = center + new Vector2(stroke[i * 2], stroke[i * 2 + 1]);
            canvas.DrawPolyline(points, color, 2f, false);
        }
    }
}
