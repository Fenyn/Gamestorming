using System.Collections.Generic;
using Godot;

namespace Ungilded.Story;

/// <summary>
/// The arrows a tutorial tip draws over the units it names: the arrow art at a whole-pixel scale,
/// bobbing, in the tint the popup sets. Each arrow points down at its mark from <see cref="Gap"/>
/// pixels above it. It sits on the tip layer over the dim and the HUD, under the box.
/// </summary>
public partial class TipArrows : Control
{
    [Export] public Texture2D Art { get; set; } = null!;

    /// <summary>Screen pixels per art pixel.</summary>
    [Export] public int ArtScale { get; set; } = 3;

    /// <summary>Pixels between the arrow's point and its mark.</summary>
    [Export] public float Gap { get; set; } = 4f;

    /// <summary>Pixels the arrow rises at the top of its bob.</summary>
    [Export] public float BobPixels { get; set; } = 4f;

    /// <summary>Seconds per bob.</summary>
    [Export] public float BobPeriod { get; set; } = 1f;

    public Color Tint { get; set; } = Colors.White;

    private readonly List<Vector2> _marks = new();
    private float _time;

    private Vector2 ArrowSize => Art.GetSize() * ArtScale;

    /// <summary>Draw an arrow over each of <paramref name="marks"/> (canvas pixels); empty draws none.</summary>
    public void SetMarks(IReadOnlyList<Vector2> marks)
    {
        _marks.Clear();
        _marks.AddRange(marks);
        QueueRedraw();
    }

    /// <summary>The rect the arrow over <paramref name="mark"/> covers over its whole bob.</summary>
    public Rect2 ArrowRect(Vector2 mark)
    {
        var size = ArrowSize;
        return new Rect2(mark.X - size.X / 2, mark.Y - Gap - size.Y - BobPixels, size.X, size.Y + BobPixels);
    }

    public override void _Process(double delta)
    {
        if (_marks.Count == 0) return;
        _time += (float)delta;
        QueueRedraw();
    }

    public override void _Draw()
    {
        // Whole pixels, so the art stays on the screen grid as it bobs.
        float bob = Mathf.Round(BobPixels * (0.5f + 0.5f * Mathf.Sin(_time * Mathf.Tau / BobPeriod)));
        var size = ArrowSize;
        foreach (var mark in _marks)
        {
            var position = new Vector2(Mathf.Round(mark.X - size.X / 2), Mathf.Round(mark.Y - Gap - size.Y - bob));
            DrawTextureRect(Art, new Rect2(position, size), false, Tint);
        }
    }
}
