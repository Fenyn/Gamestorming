using System.Collections.Generic;
using Delve.UI;
using Godot;

namespace Delve.Flow;

/// <summary>
/// The featured half of hero select, laid out as an overview rather than a printed sheet: a header
/// band of portrait, name and the four numbers that matter, then a body band of a narrow ability
/// rail under the plinth and one quiet line per subject beside it - saves, senses, skills, strikes,
/// defences, spells, features. Nothing is boxed, nothing is headed and nothing scrolls; the sheet
/// fits at 1080p for every character on the roster, and everything the overview leaves out is one
/// hover away.
///
/// Passive. Everything on it comes from the <see cref="HeroSheetData"/> read off the character the
/// preset builds, so the sheet cannot say anything the build does not - explanations included. The
/// sheet owns tooltip policy: its parts announce what explains itself, and this is the only place
/// that decides how a hover behaves.
/// </summary>
public partial class HeroSheet : PanelContainer
{
    /// <summary>The boxed number used by the headline row and the ability rail. Assigned in
    /// hero_sheet.tscn.</summary>
    [Export] public PackedScene? StatBoxScene { get; set; }

    /// <summary>One titled body section. Assigned in hero_sheet.tscn.</summary>
    [Export] public PackedScene? SectionScene { get; set; }

    /// <summary>The hover panel every element explains itself through. Assigned in
    /// hero_sheet.tscn.</summary>
    [Export] public PackedScene? TooltipScene { get; set; }

    private readonly Dictionary<string, (SheetTip Tip, Control Target)> _tips = new();

    private TextureRect _portrait = null!;
    private ColorRect _accentRule = null!;
    private ColorRect _portraitStrip = null!;
    private Label _name = null!;
    private Label _subtitle = null!;
    private HBoxContainer _headlines = null!;
    private GridContainer _abilities = null!;
    private VBoxContainer _columnA = null!;
    private VBoxContainer _columnB = null!;
    private CanvasLayer _tipLayer = null!;
    private SheetTooltip? _tooltip;

    public override void _Ready()
    {
        _portrait = GetNode<TextureRect>("%Portrait");
        _accentRule = GetNode<ColorRect>("%AccentSegment");
        _portraitStrip = GetNode<ColorRect>("%PortraitStrip");
        _name = GetNode<Label>("%HeroName");
        _subtitle = GetNode<Label>("%HeroSubtitle");
        _headlines = GetNode<HBoxContainer>("%HeadlineRow");
        _abilities = GetNode<GridContainer>("%AbilityGrid");
        _columnA = GetNode<VBoxContainer>("%ColumnA");
        _columnB = GetNode<VBoxContainer>("%ColumnB");
        _tipLayer = GetNode<CanvasLayer>("%TipLayer");

        if (TooltipScene == null) return;
        _tooltip = TooltipScene.Instantiate<SheetTooltip>();
        _tipLayer.AddChild(_tooltip);
    }

    private Color _accent;

    /// <summary>
    /// Read one character's sheet. The page is a character-owned surface: every accent role on it
    /// - name rule, portrait strip, headline strips and values, the key ability's border, the
    /// section diamonds, the tooltip's labels - takes the character's own palette colour, while
    /// neutral greys and the panel chrome stay on the game palette
    /// (design/ui_guidelines.md section 4.1).
    /// </summary>
    public void Show(HeroSheetData data, Texture2D? portrait, Color accent)
    {
        _tooltip?.Request(null, null);
        _tooltip?.SetAccent(accent);
        _tips.Clear();

        _accent = accent;
        _accentRule.Color = accent;
        _portraitStrip.Color = accent;
        _portrait.Texture = portrait;
        _name.Text = data.Name;
        _subtitle.Text = data.Subtitle;

        RenderBoxes(data.Headlines, data.Abilities);
        RenderRows(data.Rows);
    }

    /// <summary>
    /// Put one tooltip on screen with no pointer involved, addressed by its title. The rendered
    /// shot uses it; nothing in the game does.
    /// </summary>
    public bool ShowTipForTesting(string title)
    {
        if (_tooltip == null) return false;
        if (!_tips.TryGetValue(title, out var found)) return false;
        if (!IsInstanceValid(found.Target)) return false;

        _tooltip.ShowNow(found.Tip, found.Target);
        return true;
    }

    /// <summary>Put an arbitrary card on screen. The rendered shot proves the full template.</summary>
    public bool ShowCardForTesting(SheetTip tip)
    {
        if (_tooltip == null) return false;
        _tooltip.ShowNow(tip, null);
        return true;
    }

    // ---------------------------------------------------------------- Hover

    /// <summary>Make one control explain itself, and remember it so a shot can summon its tip.</summary>
    private void Register(SheetTip? tip, Control target)
    {
        if (tip == null) return;

        target.MouseFilter = MouseFilterEnum.Stop;
        target.MouseEntered += () => _tooltip?.Request(tip, target);
        target.MouseExited += () => _tooltip?.Request(null, null);
        _tips[tip.Title] = (tip, target);
    }

    // ---------------------------------------------------------------- Bands

    /// <summary>
    /// The two boxed bands. The headline boxes share one width so four numbers read as one row;
    /// the ability boxes fill a two-column rail the width of the plinth, and the class's key
    /// ability is the only bordered box on the page.
    ///
    /// The rail reads down each column rather than across the row, so the builder's flat order
    /// (STR DEX CON INT WIS CHA) is dealt into the grid as PF2e splits it: the three physical
    /// abilities on the left, the three mental ones on the right.
    /// </summary>
    private void RenderBoxes(
        IReadOnlyList<SheetHeadline> headlines, IReadOnlyList<SheetAbility> abilities)
    {
        Clear(_headlines);
        Clear(_abilities);

        foreach (var headline in headlines)
        {
            Box(_headlines, headline.Label, headline.Value, "", SheetEmphasis.Headline, headline.Tip);
        }

        int rows = (abilities.Count + 1) / 2;
        for (int row = 0; row < rows; row++)
        {
            Ability(abilities, row);
            Ability(abilities, row + rows);
        }
    }

    private void Ability(IReadOnlyList<SheetAbility> abilities, int index)
    {
        if (index >= abilities.Count) return;

        var ability = abilities[index];
        Box(_abilities, ability.Code, ability.Modifier, ability.Score,
            ability.IsKey ? SheetEmphasis.Key : SheetEmphasis.Normal, ability.Tip);
    }

    private void Box(
        Control row, string caption, string value, string detail,
        SheetEmphasis emphasis, SheetTip? tip)
    {
        if (StatBoxScene == null) return;

        var box = StatBoxScene.Instantiate<SheetStatBox>();
        box.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        row.AddChild(box);
        box.Fill(caption, value, detail, emphasis);
        box.SetAccent(_accent);
        Register(tip, box);
    }

    /// <summary>
    /// The body's two columns of titled sections, split the way a printed sheet splits: the
    /// fight-facing numbers (saves, senses, strikes, defences) on the left, the lists that grow
    /// with the character (skills, spells, features) on the right. Saves and senses stay on one
    /// dotted line; everything else lists one entry per line.
    /// </summary>
    private void RenderRows(IReadOnlyList<SheetRow> rows)
    {
        Clear(_columnA);
        Clear(_columnB);
        if (SectionScene == null) return;

        foreach (var row in rows)
        {
            bool listColumn = row.Label is HeroSheetBuilder.SkillsRow
                or HeroSheetBuilder.SpellsRow or HeroSheetBuilder.FeaturesRow;
            bool inline = row.Label is HeroSheetBuilder.SavesRow or HeroSheetBuilder.SensesRow;

            var section = SectionScene.Instantiate<SheetSection>();
            section.TipTarget += Register;
            (listColumn ? _columnB : _columnA).AddChild(section);
            section.Fill(row, inline);
            section.SetAccent(_accent);
        }
    }

    private static void Clear(Node row)
    {
        foreach (var child in row.GetChildren())
        {
            row.RemoveChild(child);
            child.QueueFree();
        }
    }
}
