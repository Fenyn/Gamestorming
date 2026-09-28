using Godot;

namespace Delve.UI;

/// <summary>The degree track: four zones around the DC with ticks at DC and DC+10, a marker at a
/// value and the landed zone lit. Thin mode draws only a bar under the settled row's content.</summary>
public partial class DegreeTrack : Control
{
    /// <summary>Points of the scale shown beyond each critical line.</summary>
    [Export] public int SpanBeyondCritLines { get; set; } = 6;
    [Export] public float BarHeight { get; set; } = 16;
    [Export] public float CaptionHeight { get; set; } = 24;
    [Export] public float LabelGap { get; set; } = 24;
    [Export] public float MarkerSize { get; set; } = 10;
    [Export] public float DimAlpha { get; set; } = 0.4f;
    [Export] public int OutlineSize { get; set; } = 6;
    [Export] public bool Thin { get; set; }
    /// <summary>Thin mode: where the bar starts. It runs under the row content, in the panel's
    /// bottom margin, so the row keeps its height.</summary>
    [Export] public float ThinLeft { get; set; }

    private int _dc;
    private bool _attack = true;
    private bool _enemyRoll;
    private float _marker = float.NaN;
    private int _lit = -1;

    public int Dc => _dc;

    public void Configure(int dc, bool attack, bool enemyRoll)
    {
        _dc = dc;
        _attack = attack;
        _enemyRoll = enemyRoll;
        _marker = float.NaN;
        _lit = -1;
        QueueRedraw();
    }

    /// <summary>The value the marker points at; NaN hides it.</summary>
    public float MarkerValue
    {
        get => _marker;
        set { _marker = value; QueueRedraw(); }
    }

    /// <summary>The lit zone (<see cref="DegreeZones"/>), or -1 while the roll is still moving.</summary>
    public int LitZone
    {
        get => _lit;
        set { _lit = value; QueueRedraw(); }
    }

    public Color ZoneColor(int zone) => RollTone.For(zone, _enemyRoll);

    private float Low => _dc - 10 - SpanBeyondCritLines;
    private float High => _dc + 10 + SpanBeyondCritLines;

    /// <summary>Horizontal position of a value inside the bar, clamped to its ends.</summary>
    public float XFor(float value, float left, float width)
        => left + Mathf.Clamp((value - Low) / (High - Low), 0, 1) * width;

    public override void _Draw()
    {
        float left = Thin ? ThinLeft : 0;
        float width = Size.X - left;
        float top = Thin ? Size.Y : CaptionHeight;
        DrawZones(left, width, top);
        if (!float.IsNaN(_marker)) DrawMarker(XFor(_marker, left, width), top);
        if (Thin) return;
        float[] bounds = Bounds(left, width);
        foreach (float x in new[] { bounds[2], bounds[3] })
            DrawRect(new Rect2(x - 1, top - 4, 2, BarHeight + 8), UiColors.Line);
        float caption = CaptionHeight - 6;
        Text($"{(_attack ? "AC" : "DC")} {_dc}", bounds[2], caption, false, UiColors.Text);
        Text($"{_dc + 10}", bounds[3], caption, false, UiColors.Text);
        float labels = top + BarHeight + LabelGap;
        for (int zone = 0; zone < 4; zone++)
            Text(DegreeZones.Label(zone, _attack), (bounds[zone] + bounds[zone + 1]) / 2, labels,
                zone == _lit, zone == _lit ? ZoneColor(zone) : UiColors.TextDim);
    }

    /// <summary>Zone edges. Integer totals sit half a point inside their zone, so a total equal to the
    /// DC lands just right of the DC tick.</summary>
    private float[] Bounds(float left, float width)
        => new[] { left, XFor(_dc - 9.5f, left, width), XFor(_dc - 0.5f, left, width), XFor(_dc + 9.5f, left, width), left + width };

    private void DrawZones(float left, float width, float top)
    {
        float[] bounds = Bounds(left, width);
        for (int zone = 0; zone < 4; zone++)
        {
            var color = ZoneColor(zone);
            if (zone != _lit) color.A *= DimAlpha;
            DrawRect(new Rect2(bounds[zone], top, bounds[zone + 1] - bounds[zone], BarHeight), color);
        }
    }

    private void DrawMarker(float x, float top)
    {
        if (Thin)
        {
            DrawRect(new Rect2(x - 1, top, 2, BarHeight), UiColors.Text);
            return;
        }
        DrawRect(new Rect2(x - 1, top - 2, 2, BarHeight + 4), UiColors.Text);
        DrawColoredPolygon(new[] { new Vector2(x - MarkerSize / 2, top - MarkerSize), new Vector2(x + MarkerSize / 2, top - MarkerSize),
            new Vector2(x, top) }, UiColors.Text);
    }

    private void Text(string text, float centerX, float baseline, bool bold, Color color)
    {
        var font = GetThemeFont("font", bold ? "EmphasisLabel" : "HintLabel");
        int size = GetThemeFontSize("font_size", "HintLabel");
        float width = font.GetStringSize(text, HorizontalAlignment.Left, -1, size).X;
        var position = new Vector2(Mathf.Clamp(centerX - width / 2, 0, Mathf.Max(0, Size.X - width)), baseline);
        DrawStringOutline(font, position, text, HorizontalAlignment.Left, -1, size, OutlineSize, UiColors.Ink);
        DrawString(font, position, text, HorizontalAlignment.Left, -1, size, color);
    }
}
