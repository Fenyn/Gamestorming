using Godot;

namespace Delve.UI;

/// <summary>
/// The controls legend: one row per entry, keys as keycaps beside a caption. Shared by the combat
/// help overlay and the pause menu. A key token that names an input action renders that action's
/// current key, so a rebind relabels the legend with no scene edit.
/// </summary>
public partial class KeyLegend : GridContainer
{
    /// <summary>One row per entry, written "keys|caption". <c>keys</c> is a comma-separated list; a
    /// token that is not an input action (mouse and camera bindings) renders as written.</summary>
    [Export] public string[] Rows { get; set; } = System.Array.Empty<string>();

    public override void _Ready() => Build();

    private void Build()
    {
        foreach (var child in GetChildren())
            child.QueueFree();

        foreach (string row in Rows)
        {
            int split = row.IndexOf('|');
            if (split < 0)
            {
                GD.PushWarning($"[KeyLegend] Legend row has no '|' separator: '{row}'");
                continue;
            }

            AddChild(BuildKeycaps(row[..split]));
            AddChild(new Label
            {
                Text = row[(split + 1)..],
                MouseFilter = MouseFilterEnum.Ignore,
            });
        }
    }

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
