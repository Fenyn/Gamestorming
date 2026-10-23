using Godot;

namespace Ungilded.Story;

/// <summary>The caret from a tip box toward its cutout: a filled triangle in the panel border colour.</summary>
public partial class TipPointer : Control
{
    /// <summary>Pixels across the triangle's base, on the box edge.</summary>
    [Export] public float BaseWidth { get; set; } = 30f;

    public Color Fill { get; set; } = Colors.White;

    private Vector2 _base, _tip;
    private bool _shown;

    public void Point(Vector2 basePoint, Vector2 tip)
    {
        _base = basePoint;
        _tip = tip;
        _shown = true;
        QueueRedraw();
    }

    public void Clear()
    {
        _shown = false;
        QueueRedraw();
    }

    public override void _Draw()
    {
        if (!_shown) return;
        var along = (_tip - _base).Normalized();
        var across = new Vector2(-along.Y, along.X) * (BaseWidth / 2);
        DrawColoredPolygon(new[] { _base + across, _tip, _base - across }, Fill);
    }
}
