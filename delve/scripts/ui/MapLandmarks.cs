using Delve.Run;
using Godot;

namespace Delve.UI;

/// <summary>Small environmental silhouettes around readable destination seals.</summary>
public static class MapLandmarks
{
    public static void Draw(Control canvas, Vector2 center, NodeKind kind, Color stone, Color shadow, Color light)
    {
        void Stroke(Vector2 a, Vector2 b, Color color, float width = 2) =>
            canvas.DrawLine(center + a, center + b, color, width, true);
        void Stone(float x, float y, float height)
        {
            var p = center + new Vector2(x, y);
            canvas.DrawColoredPolygon(new[] { p + new Vector2(-5, 0), p + new Vector2(-4, -height),
                p + new Vector2(3, -height - 3), p + new Vector2(7, -2) }, stone);
            canvas.DrawLine(p + new Vector2(-2, -height + 4), p + new Vector2(-1, -3), light with { A = 0.25f }, 1);
        }
        switch (kind)
        {
            case NodeKind.Boss:
                Stone(-43, 22, 28); Stone(42, 18, 35); Stone(-25, 43, 15); Stone(22, 46, 22);
                Stroke(new(-43, 28), new(-24, 39), stone); Stroke(new(24, 41), new(44, 24), stone);
                break;
            case NodeKind.Rest:
                Stroke(new(-29, 26), new(-14, 42), stone, 3);
                Stroke(new(-28, 41), new(-14, 27), stone, 3);
                canvas.DrawCircle(center + new Vector2(-22, 33), 6, light with { A = 0.7f });
                canvas.DrawCircle(center + new Vector2(-22, 33), 2, UiColors.Text);
                break;
            case NodeKind.Elite:
                canvas.DrawArc(center + new Vector2(22, 28), 16, Mathf.Pi, Mathf.Tau, 12, stone, 8, true);
                canvas.DrawCircle(center + new Vector2(22, 27), 11, shadow);
                break;
            case NodeKind.Event:
                Stone(-27, 28, 16); Stone(26, 31, 22);
                Stroke(new(-10, 35), new(0, 44), stone, 1); Stroke(new(0, 44), new(10, 35), stone, 1);
                break;
            default:
                Stroke(new(24, 19), new(24, 42), stone, 3);
                Stroke(new(17, 26), new(31, 26), stone, 2);
                Stone(28, 44, 6);
                break;
        }
    }
}
