using System;
using System.Text;
using Delve.UI;
using Godot;

namespace Delve.Flow;

/// <summary>
/// One titled section of the hero sheet's body: a small display-face heading with its content
/// below it, the way a printed character sheet groups its lists. Two shapes share the component -
/// an INLINE section keeps its entries on one line joined by dim dots (saves, senses), and a LIST
/// section stacks one entry per line (skills, strikes, features), which reads far better than
/// chips wrapping sideways.
///
/// Signals every hoverable outward; the sheet owns tooltip policy.
/// </summary>
public partial class SheetSection : VBoxContainer
{
    /// <summary>An entry line's height, so hover targets stay comfortable.</summary>
    private const int LineHeight = 28;

    public event Action<SheetTip?, Control>? TipTarget;

    private Label _heading = null!;
    private VBoxContainer _items = null!;

    public override void _Ready()
    {
        _heading = GetNode<Label>("%SectionHeading");
        _items = GetNode<VBoxContainer>("%SectionItems");
    }

    /// <summary>The section's ◆ takes the owning character's accent.</summary>
    public void SetAccent(Color accent)
        => GetNode<Label>("%Glyph").AddThemeColorOverride("font_color", accent);

    /// <summary>Read one row of the sheet. Inline keeps the entries on a single dotted line.</summary>
    public void Fill(SheetRow row, bool inline)
    {
        _heading.Text = row.Label;
        Clear(_items);

        if (inline) FillInline(row);
        else FillList(row);
    }

    private void FillInline(SheetRow row)
    {
        var line = new HBoxContainer();
        line.AddThemeConstantOverride("separation", 8);
        _items.AddChild(line);

        foreach (var entry in row.Entries)
        {
            if (line.GetChildCount() > 0) line.AddChild(Item("·", ThemeNames.CardRoleLabel));
            var segment = Item(entry.Label, "");
            line.AddChild(segment);
            Hoverable(segment, entry);
        }
    }

    /// <summary>Most entries a list section prints; the tail collapses into "+N more" whose
    /// hover names everything it hides, so nothing is lost silently.</summary>
    public const int MaxListItems = 8;

    private void FillList(SheetRow row)
    {
        int shown = row.Entries.Count <= MaxListItems ? row.Entries.Count : MaxListItems - 1;
        for (int i = 0; i < shown; i++)
        {
            var item = Item(row.Entries[i].Label, "");
            _items.AddChild(item);
            Hoverable(item, row.Entries[i]);
        }

        if (shown == row.Entries.Count) return;

        var names = new StringBuilder();
        for (int i = shown; i < row.Entries.Count; i++)
        {
            if (names.Length > 0) names.Append('\n');
            names.Append(row.Entries[i].Label);
        }
        var tail = Item($"+{row.Entries.Count - shown} more", ThemeNames.CardRoleLabel);
        _items.AddChild(tail);
        Hoverable(tail, new SheetEntry(
            tail.Text, new SheetTip($"{row.Label} — everything", "", names.ToString())));
    }

    private void Hoverable(Control item, SheetEntry entry)
    {
        if (entry.Tip == null) return;
        item.MouseFilter = MouseFilterEnum.Stop;
        TipTarget?.Invoke(entry.Tip, item);
    }

    private static Label Item(string text, string variation) => new()
    {
        Text = text,
        ThemeTypeVariation = variation,
        CustomMinimumSize = new Vector2(0, LineHeight),
        VerticalAlignment = VerticalAlignment.Center,
        SizeFlagsVertical = SizeFlags.ShrinkBegin,
        SizeFlagsHorizontal = SizeFlags.ShrinkBegin,
    };

    private static void Clear(Node host)
    {
        foreach (var child in host.GetChildren())
        {
            host.RemoveChild(child);
            child.QueueFree();
        }
    }
}
