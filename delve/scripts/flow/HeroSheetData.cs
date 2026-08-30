using System;
using System.Collections.Generic;
using System.Text;

namespace Delve.Flow;

/// <summary>
/// What one hovered element of the sheet explains about itself: a title, an optional qualifier
/// under it, and the paragraph. Assembled with the sheet so the spike can assert on the same
/// words the tooltip prints, and so no explanation can drift from the build it describes.
/// </summary>
/// <summary>One labelled line in a tip card's meta band: "Trigger — an ally drops to 0 HP".</summary>
public sealed record SheetMetaRow(string Label, string Text);

/// <summary>
/// How much time the explained thing costs. <see cref="Actions"/> is 1-3 for action-pip costs and
/// 0 for a reaction or free action, which render as words.
/// </summary>
public sealed record SheetActionCost(int Actions, string? Word = null)
{
    public static readonly SheetActionCost Reaction = new(0, "reaction");
    public static readonly SheetActionCost Free = new(0, "free");
    public static SheetActionCost Of(int actions) => new(actions);
}

/// <summary>
/// The standardized tooltip card. Every hoverable on the hero sheet fills the slots it has and the
/// renderer prints them in one fixed order, so a feat, a spell and a strike all read from familiar
/// places: title + cost, trait chips + tag, meta rows (Trigger/Frequency/Range/...), rules text,
/// then a dim numeric footer (breakdown / heighten note). Only Title is required.
/// </summary>
public sealed record SheetTip(
    string Title,
    string Subtitle,
    string Body,
    SheetActionCost? Cost = null,
    IReadOnlyList<string>? Traits = null,
    string? Tag = null,
    IReadOnlyList<SheetMetaRow>? Meta = null,
    string? Footer = null);

/// <summary>
/// One hoverable fragment of an overview row: the words it prints and what it explains. A text
/// row prints its entries as a "·"-joined line; a chip row prints one chip each.
/// </summary>
public sealed record SheetEntry(string Label, SheetTip? Tip = null);

/// <summary>One of the six ability boxes: the three-letter code, the signed modifier the box
/// prints large, the raw score under it, and whether this is the class's key ability.</summary>
public sealed record SheetAbility(string Code, string Modifier, string Score, bool IsKey, SheetTip? Tip = null);

/// <summary>
/// One of the four numbers the header band shouts - HP, AC, the key ability and the character's
/// signature number. Nothing else on the sheet is allowed this weight.
/// </summary>
public sealed record SheetHeadline(string Label, string Value, SheetTip? Tip = null);

/// <summary>How an overview row prints its entries.</summary>
public enum SheetRowStyle
{
    /// <summary>One line of words, entries separated by "·".</summary>
    Text,

    /// <summary>A wrapping run of chips.</summary>
    Chips,
}

/// <summary>
/// One line of the overview: a label on the left and its entries on the right. <see cref="Line"/>
/// is exactly what the row reads as, so a spike can assert the sheet stays a single line of plain
/// words per label.
/// </summary>
public sealed record SheetRow(string Label, IReadOnlyList<SheetEntry> Entries, SheetRowStyle Style)
{
    /// <summary>The row as one string - what the reader sees, joined.</summary>
    public string Line
    {
        get
        {
            var line = new StringBuilder();
            foreach (var entry in Entries)
            {
                if (line.Length > 0) line.Append(" · ");
                line.Append(entry.Label);
            }
            return line.ToString();
        }
    }
}

/// <summary>
/// Everything the hero-select sheet prints about one character, read off the PF2eCharacter the
/// preset builds and already formatted: an identity, four headline numbers, six ability boxes and
/// a short stack of overview rows. Depth lives in the <see cref="SheetTip"/> on each element, not
/// on the page. Godot-free, so <c>hero_select_spike</c> asserts on the sheet's content without
/// standing the UI up. A row the character has nothing for is simply absent.
/// </summary>
public sealed record HeroSheetData(
    string Name,
    string Subtitle,
    int HitPoints,
    int ArmorClass,
    IReadOnlyList<SheetHeadline> Headlines,
    IReadOnlyList<SheetAbility> Abilities,
    IReadOnlyList<SheetRow> Rows)
{
    /// <summary>The sheet for a character that could not be built - no data pack loaded. Keeps the
    /// name so the frame still says who is featured.</summary>
    public static HeroSheetData Unknown(string name) => new(
        name, "sheet unavailable", 0, 0,
        Array.Empty<SheetHeadline>(), Array.Empty<SheetAbility>(), Array.Empty<SheetRow>());

    /// <summary>The row under that label, or null when the character has none.</summary>
    public SheetRow? Row(string label)
    {
        foreach (var row in Rows)
        {
            if (row.Label == label) return row;
        }
        return null;
    }

    /// <summary>Every entry the overview prints, in reading order.</summary>
    public IEnumerable<SheetEntry> Entries()
    {
        foreach (var row in Rows)
        {
            foreach (var entry in row.Entries) yield return entry;
        }
    }

    /// <summary>Every tip the sheet carries, so a spike can assert that nothing hovers blank.</summary>
    public IEnumerable<SheetTip> Tips()
    {
        foreach (var headline in Headlines)
        {
            if (headline.Tip != null) yield return headline.Tip;
        }
        foreach (var ability in Abilities)
        {
            if (ability.Tip != null) yield return ability.Tip;
        }
        foreach (var entry in Entries())
        {
            if (entry.Tip != null) yield return entry.Tip;
        }
    }
}
