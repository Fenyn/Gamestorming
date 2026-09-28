using System.Collections.Generic;
using Delve.Combat;
using Godot;

namespace Delve.UI;

/// <summary>
/// The creature journal for the current fight, toggled by <see cref="HudRoot"/> on combat_journal
/// or by the rail's Journal button. One group per species with its letters, a "Known 3 of 11"
/// line and the fields as pairs. Non-modal like the log history: the board stays playable and the
/// panel stays open through enemy turns.
/// </summary>
public partial class CombatJournalPanel : PanelContainer
{
    [Export] public PackedScene? FactsScene { get; set; }
    [Export] public float MaxScrollHeight { get; set; } = 640;

    private VBoxContainer _groups = null!;
    private ScrollContainer _scroll = null!;
    private Label _empty = null!;
    private int _settle;

    public IReadOnlyList<JournalGroupView> Groups { get; private set; } = new List<JournalGroupView>();

    public override void _Ready()
    {
        _groups = GetNode<VBoxContainer>("%JournalGroups");
        _scroll = GetNode<ScrollContainer>("%JournalScroll");
        _empty = GetNode<Label>("%JournalEmpty");
        GetNode<Label>("%JournalKey").Text = InputNames.KeyLabelFor(InputNames.Journal);
        Visible = false;
    }

    public void Toggle()
    {
        Visible = !Visible;
        _settle = 2;
    }

    public void Render(IReadOnlyList<JournalGroupView> groups)
    {
        Groups = groups;
        foreach (var child in _groups.GetChildren())
        {
            _groups.RemoveChild(child);
            child.QueueFree();
        }
        foreach (var group in groups)
        {
            var box = new VBoxContainer { MouseFilter = MouseFilterEnum.Ignore };
            box.AddThemeConstantOverride("separation", 4);
            string title = group.Letters.Length > 0 ? $"{group.Name}  {group.Letters}" : group.Name;
            box.AddChild(new Label { Text = title, ThemeTypeVariation = ThemeNames.RowLabel, MouseFilter = MouseFilterEnum.Ignore });
            box.AddChild(new Label { Text = group.KnownText, ThemeTypeVariation = ThemeNames.HintLabel, MouseFilter = MouseFilterEnum.Ignore });
            if (FactsScene?.Instantiate<JournalFactsGrid>() is { } grid)
            {
                box.AddChild(grid);
                grid.Render(group.Facts);
            }
            _groups.AddChild(box);
        }
        _empty.Visible = groups.Count == 0;
        _settle = 2;
    }

    public override void _Process(double delta)
    {
        if (_settle <= 0) return;
        _settle--;
        _scroll.CustomMinimumSize = new Vector2(0, Mathf.Min(_groups.GetCombinedMinimumSize().Y, MaxScrollHeight));
    }
}
