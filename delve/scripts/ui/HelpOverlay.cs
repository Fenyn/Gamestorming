using Godot;

namespace Delve.UI;

/// <summary>
/// Centered controls-help card, hidden by default and toggled by <see cref="HudRoot"/> on
/// combat_help (Tab/H). Non-modal: every node ignores the mouse, so the game stays fully playable
/// underneath. Passive per CLAUDE.md — it renders the exported <see cref="Rows"/> and nothing else.
/// Keys render as keycaps, the same chip the action bar uses, and an action's key text comes from
/// the live input map, so a rebind relabels the legend with no scene edit.
/// </summary>
public partial class HelpOverlay : Control
{
    /// <summary>
    /// One legend row per entry, written "keys|caption". <c>keys</c> is a comma-separated list; a
    /// token that names an input action renders that action's current key, and any other token
    /// renders as written (mouse and camera bindings are not actions).
    /// </summary>
    [Export] public string[] Rows { get; set; } = System.Array.Empty<string>();

    private GridContainer _grid = null!;

    public override void _Ready()
    {
        _grid = GetNode<GridContainer>("%Grid");
        Visible = false;
        Build();
    }

    public void Toggle() => Visible = !Visible;

    private void Build()
    {
        foreach (var child in _grid.GetChildren())
            child.QueueFree();

        foreach (string row in Rows)
        {
            int split = row.IndexOf('|');
            if (split < 0)
            {
                GD.PushWarning($"[HelpOverlay] Legend row has no '|' separator: '{row}'");
                continue;
            }

            _grid.AddChild(BuildKeycaps(row[..split]));
            _grid.AddChild(new Label
            {
                Text = row[(split + 1)..],
                MouseFilter = MouseFilterEnum.Ignore,
            });
        }
    }

    /// <summary>One keycap per comma-separated token, in a row.</summary>
    private static HBoxContainer BuildKeycaps(string keys)
    {
        var row = new HBoxContainer { MouseFilter = MouseFilterEnum.Ignore };
        row.AddThemeConstantOverride("separation", 4);

        foreach (string token in keys.Split(','))
        {
            string text = token.Trim();
            if (text.Length == 0) continue;

            var cap = new PanelContainer
            {
                ThemeTypeVariation = ThemeNames.Keycap,
                MouseFilter = MouseFilterEnum.Ignore,
                SizeFlagsVertical = SizeFlags.ShrinkCenter,
            };
            cap.AddChild(new Label
            {
                Text = InputNames.KeyLabelFor(text),
                ThemeTypeVariation = ThemeNames.HintLabel,
                MouseFilter = MouseFilterEnum.Ignore,
            });
            row.AddChild(cap);
        }
        return row;
    }
}
