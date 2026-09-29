using System;
using Godot;

namespace Delve.UI;

/// <summary>
/// The single pip renderer: a row of square Panel pips styled by the PipFilled / PipSpent /
/// PipDisabled theme variations. The action bar's action-economy pips (14 px) and the chips'
/// cost pips (8 px) both instance scenes/ui/pip_row.tscn — pip visuals change here and in the
/// three pip styleboxes, nowhere else.
/// </summary>
public partial class PipRow : HBoxContainer
{
    /// <summary>Square pip side length in px (14 on the action bar, 8 on chips).</summary>
    [Export] public Vector2 PipSize { get; set; } = new(14, 14);

    /// <summary>Pip styles for a row on a light surface (the parchment command menu); empty keeps
    /// the default dark-HUD styles.</summary>
    [Export] public StringName FilledVariation { get; set; } = "";
    [Export] public StringName SpentVariation { get; set; } = "";

    private string Filled => FilledVariation.IsEmpty ? ThemeNames.PipFilled : FilledVariation.ToString();
    private string Spent => SpentVariation.IsEmpty ? ThemeNames.PipSpent : SpentVariation.ToString();

    /// <summary>Action-economy readout: <paramref name="max"/> pips, the first
    /// <paramref name="remaining"/> filled, the rest spent. The last <paramref name="previewSpend"/>
    /// filled pips draw hollow: what the hovered move or action would cost.</summary>
    public void SetActionEconomy(int remaining, int max, int previewSpend = 0)
    {
        int keep = Math.Max(0, remaining - previewSpend);
        Rebuild(max, i => i < keep ? Filled : i < remaining ? ThemeNames.PipPreview : Spent);
    }

    /// <summary>Cost readout: <paramref name="count"/> pips, filled when the owning control is
    /// enabled, dimmed otherwise.</summary>
    public void SetCost(int count, bool enabled)
        => Rebuild(count, _ => enabled ? Filled : ThemeNames.PipDisabled);

    /// <summary>Reuse existing pip Panels and add/remove to match the requested count — never
    /// QueueFree-and-readd, which would double the row for a frame on same-frame re-renders.</summary>
    private void Rebuild(int count, Func<int, string> variationFor)
    {
        while (GetChildCount() > count)
        {
            var child = GetChild(GetChildCount() - 1);
            RemoveChild(child);
            child.QueueFree();
        }
        while (GetChildCount() < count)
            AddChild(new Panel
            {
                CustomMinimumSize = PipSize,
                SizeFlagsVertical = SizeFlags.ShrinkCenter,
                MouseFilter = MouseFilterEnum.Ignore,
            });
        for (int i = 0; i < count; i++)
            GetChild<Panel>(i).ThemeTypeVariation = variationFor(i);
    }
}
