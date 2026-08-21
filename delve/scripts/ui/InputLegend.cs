using System.Collections.Generic;
using Godot;

namespace Delve.UI;

/// <summary>
/// Compact key/action legend panel (input discoverability chrome, upper-left of a mode's HUD).
/// Passive per CLAUDE.md: renders only the rows fed via <see cref="SetRows"/> — it knows nothing
/// about the input map; the host scene owns which bindings to describe. Fixed five two-column rows
/// placed in the scene (keys column dark, action column muted); unused rows are hidden.
/// </summary>
public partial class InputLegend : PanelContainer
{
    public const int MaxRows = 5;

    private readonly Label[] _keys = new Label[MaxRows];
    private readonly Label[] _actions = new Label[MaxRows];

    public override void _Ready()
    {
        for (int i = 0; i < MaxRows; i++)
        {
            _keys[i] = GetNode<Label>($"%Key{i}");
            _actions[i] = GetNode<Label>($"%Action{i}");
        }
    }

    /// <summary>Render up to <see cref="MaxRows"/> (keys, action) rows; extras are ignored.</summary>
    public void SetRows(IReadOnlyList<(string Keys, string Action)> rows)
    {
        for (int i = 0; i < MaxRows; i++)
        {
            bool has = i < rows.Count;
            _keys[i].Visible = has;
            _actions[i].Visible = has;
            _keys[i].Text = has ? rows[i].Keys : string.Empty;
            _actions[i].Text = has ? rows[i].Action : string.Empty;
        }
    }
}
