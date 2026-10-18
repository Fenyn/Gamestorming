using System.Collections.Generic;
using System.Linq;
using Godot;

namespace Delve.UI;

/// <summary>One row of a <see cref="RuledRows"/> list: a caption ("Success", "Raven"), the text, and
/// an optional status at the right edge ("Done", "3 of 3").</summary>
public readonly record struct RuledRow(string Caption, string Text, string Status = "");

/// <summary>
/// Captioned rows with a thin rule between each, so every entry reads as its own band: an event's
/// degrees of success, the campaign's progress at an expedition's end. Captions share one width so
/// every text starts on one edge; statuses sit at the right edge.
/// </summary>
public partial class RuledRows : VBoxContainer
{
    [Export] public float CaptionWidth { get; set; } = 200;

    /// <summary>Gap between the caption, the text and the status.</summary>
    [Export] public int Gap { get; set; } = 16;

    [Export] public StringName CaptionVariation { get; set; } = ThemeNames.EventCaption;
    [Export] public StringName TextVariation { get; set; } = ThemeNames.EventBody;
    [Export] public StringName StatusVariation { get; set; } = ThemeNames.EventCaption;

    private readonly List<RuledRow> _rows = new();

    public IReadOnlyList<RuledRow> Rows => _rows;

    /// <summary>The rows as "Caption: Text (Status)", one per line, for spikes.</summary>
    public string Text => string.Join("\n", _rows.Select(r => (r.Caption.Length > 0 ? r.Caption + ": " : "") + r.Text + (r.Status.Length > 0 ? $" ({r.Status})" : "")));

    /// <summary>Rules drawn between the rows.</summary>
    public int Rules => GetChildren().OfType<Panel>().Count();

    public void Render(IEnumerable<RuledRow> rows)
    {
        foreach (var child in GetChildren())
        {
            RemoveChild(child);
            child.QueueFree();
        }
        _rows.Clear();
        _rows.AddRange(rows);
        foreach (var row in _rows)
        {
            if (GetChildCount() > 0) AddChild(Rule());
            var line = new HBoxContainer { MouseFilter = MouseFilterEnum.Ignore };
            line.AddThemeConstantOverride("separation", Gap);
            if (row.Caption.Length > 0)
                line.AddChild(new Label { Text = row.Caption, ThemeTypeVariation = CaptionVariation, CustomMinimumSize = new Vector2(CaptionWidth, 0) });
            line.AddChild(new Label
            {
                Text = row.Text,
                ThemeTypeVariation = TextVariation,
                AutowrapMode = TextServer.AutowrapMode.WordSmart,
                SizeFlagsHorizontal = SizeFlags.ExpandFill,
            });
            if (row.Status.Length > 0)
                line.AddChild(new Label { Text = row.Status, ThemeTypeVariation = StatusVariation, HorizontalAlignment = HorizontalAlignment.Right });
            AddChild(line);
        }
        Visible = _rows.Count > 0;
    }

    /// <summary>The thin rule set between two rows; shared by every list that bands its rows.</summary>
    public static Panel Rule() => new()
    {
        ThemeTypeVariation = ThemeNames.RuleLine,
        CustomMinimumSize = new Vector2(0, 1),
        MouseFilter = MouseFilterEnum.Ignore,
    };
}
