using System.Collections.Generic;
using Godot;

namespace Ungilded.Story;

/// <summary>Which side of the cutout a tip box sits on.</summary>
public enum TipSide { Left, Right, Above, Below }

/// <summary>Where a tip box and its pointer go.</summary>
/// <param name="PointerBase">The midpoint of the pointer's base, on the box edge that faces the cutout.</param>
/// <param name="PointerTip">The pointer's tip, toward the cutout centre.</param>
public readonly record struct TipLayout(Vector2 BoxPosition, TipSide Side, Vector2 PointerBase, Vector2 PointerTip);

/// <summary>The screen a tip box is placed on and the search that places it.</summary>
/// <param name="Step">Pixels between the positions tried along each side and away from it.</param>
/// <param name="MaxPush">How many steps past the gap a box may move away from the cutout.</param>
/// <param name="OverlapWeight">Cost of one square pixel over a HUD panel, against one pixel of
/// distance from the aim point.</param>
/// <param name="Panels">HUD panels the box should stay off.</param>
public sealed record TipSpace(Rect2 Screen, float Gap, float Margin, float Step, int MaxPush, float OverlapWeight,
    IReadOnlyList<Rect2> Panels);

/// <summary>
/// Places a tip box beside a cutout. Every position along each side of the cutout, the gap away
/// from it or a few steps further, is tried; a position that covers the cutout or leaves the
/// screen is out. The rest are scored by the area they cover of the HUD panels, then by their
/// distance from the aim point, so the box takes the nearest spot that covers no panel, or the
/// least panel when every spot covers one. The pointer leaves the edge that faces the cutout.
/// </summary>
public static class TipPlacement
{
    /// <param name="cutout">The cutout's bounds; the box sits beside them.</param>
    /// <param name="keepOff">Rects the box must not cover besides the cutout: the panels the
    /// focused part sits in, and context targets.</param>
    /// <param name="aim">The point the pointer aims at: the cutout centre.</param>
    public static TipLayout Place(TipSpace space, Rect2 cutout, IReadOnlyList<Rect2> keepOff, Vector2 aim, Vector2 box,
        float pointerLength, float pointerInset)
    {
        var inner = space.Screen.Grow(-space.Margin);
        Rect2? best = null;
        var bestSide = TipSide.Right;
        float bestCost = float.PositiveInfinity;
        foreach (var side in new[] { TipSide.Right, TipSide.Left, TipSide.Above, TipSide.Below })
            for (int push = 0; push <= space.MaxPush; push++)
            {
                float away = space.Gap + push * space.Step;
                bool horizontal = side is TipSide.Above or TipSide.Below;
                float fixedAxis = side switch
                {
                    TipSide.Right => cutout.End.X + away,
                    TipSide.Left => cutout.Position.X - away - box.X,
                    TipSide.Below => cutout.End.Y + away,
                    _ => cutout.Position.Y - away - box.Y,
                };
                float from = horizontal ? inner.Position.X : inner.Position.Y;
                float to = horizontal ? inner.End.X - box.X : inner.End.Y - box.Y;
                float centred = horizontal ? aim.X - box.X / 2 : aim.Y - box.Y / 2;
                foreach (float along in Positions(from, to, centred, space.Step))
                {
                    var rect = new Rect2(horizontal ? new Vector2(along, fixedAxis) : new Vector2(fixedAxis, along), box);
                    if (!inner.Encloses(rect) || rect.Intersects(cutout) || Covers(rect, keepOff)) continue;
                    float cost = Overlap(rect, space.Panels) * space.OverlapWeight + (rect.GetCenter() - aim).Length();
                    if (cost >= bestCost) continue;
                    bestCost = cost;
                    best = rect;
                    bestSide = side;
                }
            }
        // No spot clears the cutout: below it, clamped on screen.
        var placed = best ?? new Rect2(new Vector2(
            Mathf.Clamp(aim.X - box.X / 2, inner.Position.X, Mathf.Max(inner.Position.X, inner.End.X - box.X)),
            Mathf.Clamp(cutout.End.Y + space.Gap, inner.Position.Y, Mathf.Max(inner.Position.Y, inner.End.Y - box.Y))), box);
        var position = placed.Position.Round();
        var (pointerBase, pointerTip) = Pointer(new Rect2(position, box), bestSide, aim, pointerLength, pointerInset);
        return new TipLayout(position, bestSide, pointerBase, pointerTip);
    }

    /// <summary>A centred box: the screen's middle across, and the height nearest
    /// <paramref name="preferredTop"/> that covers the least of the HUD panels.</summary>
    public static Vector2 PlaceCentred(TipSpace space, Vector2 box, float preferredTop)
    {
        var inner = space.Screen.Grow(-space.Margin);
        float x = Mathf.Round(space.Screen.GetCenter().X - box.X / 2);
        float bestY = preferredTop;
        float bestCost = float.PositiveInfinity;
        foreach (float y in Positions(inner.Position.Y, inner.End.Y - box.Y, preferredTop, space.Step))
        {
            float cost = Overlap(new Rect2(x, y, box), space.Panels) * space.OverlapWeight + Mathf.Abs(y - preferredTop);
            if (cost >= bestCost) continue;
            bestCost = cost;
            bestY = y;
        }
        return new Vector2(x, Mathf.Round(bestY));
    }

    /// <summary>True when <paramref name="rect"/> touches any of <paramref name="rects"/>.</summary>
    public static bool Covers(Rect2 rect, IReadOnlyList<Rect2> rects)
    {
        foreach (var other in rects)
            if (rect.Intersects(other)) return true;
        return false;
    }

    /// <summary>The square pixels of <paramref name="rect"/> that lie over the panels.</summary>
    public static float Overlap(Rect2 rect, IReadOnlyList<Rect2> panels)
    {
        float area = 0;
        foreach (var panel in panels)
            if (rect.Intersects(panel)) area += rect.Intersection(panel).Area;
        return area;
    }

    /// <summary>The pointer from the box edge that faces <paramref name="side"/>'s cutout toward <paramref name="aim"/>.</summary>
    public static (Vector2 Base, Vector2 Tip) Pointer(Rect2 rect, TipSide side, Vector2 aim, float pointerLength, float pointerInset)
    {
        var pointerBase = side switch
        {
            TipSide.Right => new Vector2(rect.Position.X, ClampInset(aim.Y, rect.Position.Y, rect.End.Y, pointerInset)),
            TipSide.Left => new Vector2(rect.End.X, ClampInset(aim.Y, rect.Position.Y, rect.End.Y, pointerInset)),
            TipSide.Below => new Vector2(ClampInset(aim.X, rect.Position.X, rect.End.X, pointerInset), rect.Position.Y),
            _ => new Vector2(ClampInset(aim.X, rect.Position.X, rect.End.X, pointerInset), rect.End.Y),
        };
        var toward = (aim - pointerBase).Normalized();
        return (pointerBase, pointerBase + toward * pointerLength);
    }

    /// <summary>The preferred position (clamped into the range), then every step across the range.</summary>
    private static IEnumerable<float> Positions(float from, float to, float preferred, float step)
    {
        if (to < from) yield break;
        yield return Mathf.Clamp(preferred, from, to);
        for (float p = from; p <= to; p += step) yield return p;
        yield return to;
    }

    private static float ClampInset(float value, float from, float to, float inset)
        => Mathf.Clamp(value, from + inset, Mathf.Max(from + inset, to - inset));
}
