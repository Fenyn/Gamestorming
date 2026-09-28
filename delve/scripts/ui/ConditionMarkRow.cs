using System.Collections.Generic;
using Delve.Combat;
using Godot;

namespace Delve.UI;

/// <summary>The first few conditions as 1x icons with their values, the rest as "+N". The party chips
/// and the initiative rows share it, so one unit shows the same marks and count on both.</summary>
public static class ConditionMarkRow
{
    public static void Fill(HBoxContainer box, IReadOnlyList<ConditionMarkView> conditions, ConditionIconSet? icons,
        int maxMarks, int iconSize, StringName? textVariation = null)
    {
        foreach (var child in box.GetChildren())
        {
            box.RemoveChild(child);
            child.QueueFree();
        }
        box.Visible = conditions.Count > 0;
        int shown = System.Math.Min(conditions.Count, System.Math.Max(1, maxMarks));
        for (int i = 0; i < shown; i++)
        {
            box.AddChild(new TextureRect
            {
                Texture = icons?.Tile(conditions[i].IconKey),
                CustomMinimumSize = new Vector2(iconSize, iconSize),
                ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
                StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered,
                TextureFilter = CanvasItem.TextureFilterEnum.Nearest,
                SizeFlagsVertical = Control.SizeFlags.ShrinkCenter,
                MouseFilter = Control.MouseFilterEnum.Ignore,
            });
            if (conditions[i].Value > 0) box.AddChild(Text(conditions[i].Value.ToString(), textVariation));
        }
        if (conditions.Count > shown) box.AddChild(Text($"+{conditions.Count - shown}", textVariation));
    }

    /// <summary>The "+N" a row of <paramref name="count"/> conditions prints, or "".</summary>
    public static string Overflow(int count, int maxMarks)
        => count > System.Math.Max(1, maxMarks) ? $"+{count - System.Math.Max(1, maxMarks)}" : "";

    private static Label Text(string text, StringName? variation)
    {
        var label = new Label { Text = text, MouseFilter = Control.MouseFilterEnum.Ignore };
        if (variation != null) label.ThemeTypeVariation = variation;
        return label;
    }
}
