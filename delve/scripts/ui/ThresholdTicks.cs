using System;
using System.Collections.Generic;
using Godot;

namespace Delve.UI;

/// <summary>Vertical marks over a bar at fixed fractions of its length, such as the Wardstone's danger
/// thresholds. Place it as a full-rect child of the bar.</summary>
public partial class ThresholdTicks : Control
{
    [Export] public float TickWidth { get; set; } = 2;

    private IReadOnlyList<float> _fractions = Array.Empty<float>();

    public void SetFractions(IReadOnlyList<float> fractions)
    {
        _fractions = fractions;
        QueueRedraw();
    }

    public override void _Draw()
    {
        foreach (float f in _fractions)
        {
            float x = Mathf.Round(Size.X * f - TickWidth / 2);
            DrawRect(new Rect2(x, 0, TickWidth, Size.Y), UiColors.Ink);
        }
    }
}
