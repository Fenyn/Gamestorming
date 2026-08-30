using Delve.Run;
using Godot;

namespace Delve.UI;

/// <summary>
/// One silhouette per run-map node kind, drawn straight into a CanvasItem so the map buttons and
/// the legend can never disagree. The shape is the placeholder identity of a kind; when real icon
/// art lands, each case here swaps for a texture draw and every caller follows.
/// </summary>
public static class MapNodeShapes
{
    /// <summary>Closed outline for a kind, centred on <paramref name="center"/>. The radius is
    /// scaled per shape so a triangle carries the same visual weight as a circle.</summary>
    public static Vector2[] Outline(NodeKind kind, Vector2 center, float r) => kind switch
    {
        NodeKind.Combat => Polygon(center, r, 32, -Mathf.Pi / 2f),           // circle
        NodeKind.Elite => Polygon(center, r * 1.2f, 4, -Mathf.Pi / 2f),      // diamond
        NodeKind.Event => Polygon(center, r * 1.08f, 6, 0f),                 // hexagon
        NodeKind.Rest => Polygon(center, r * 1.3f, 3, -Mathf.Pi / 2f),       // tent triangle
        NodeKind.Boss => Polygon(center, r * 1.04f, 8, Mathf.Pi / 8f),       // octagon
        NodeKind.Shop => Polygon(center, r * 1.12f, 5, -Mathf.Pi / 2f),      // pentagon
        NodeKind.Treasure => Polygon(center, r * 1.06f, 4, Mathf.Pi / 4f),   // square
        _ => Polygon(center, r, 32, 0f),
    };

    /// <summary>Filled shape with a coloured rim.</summary>
    public static void Draw(
        CanvasItem c, Vector2 center, float r, NodeKind kind, Color face, Color rim, float rimWidth)
    {
        var points = Outline(kind, center, r);
        c.DrawColoredPolygon(points, face);
        DrawRim(c, points, rim, rimWidth);
    }

    /// <summary>Outline only - the pulse halo around a reachable node.</summary>
    public static void DrawRim(CanvasItem c, Vector2[] points, Color rim, float rimWidth)
    {
        var closed = new Vector2[points.Length + 1];
        points.CopyTo(closed, 0);
        closed[^1] = points[0];
        c.DrawPolyline(closed, rim, rimWidth, true);
    }

    private static Vector2[] Polygon(Vector2 center, float r, int sides, float startAngle)
    {
        var points = new Vector2[sides];
        for (int i = 0; i < sides; i++)
        {
            float a = startAngle + Mathf.Tau * i / sides;
            points[i] = center + new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * r;
        }
        return points;
    }
}
