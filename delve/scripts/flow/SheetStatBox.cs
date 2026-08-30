using Delve.UI;
using Godot;

namespace Delve.Flow;

/// <summary>How loud one boxed number on the sheet is allowed to be.</summary>
public enum SheetEmphasis
{
    /// <summary>A number the reader looks up: 22 px body ink.</summary>
    Normal,

    /// <summary>One of the four the reader must find at a glance: 26 px accent.</summary>
    Headline,

    /// <summary>The one box the build is built around - the key ability. Body ink inside an
    /// accent-bordered box: the border is the emphasis, so the number does not have to shout
    /// twice.</summary>
    Key,
}

/// <summary>
/// One boxed number on the hero sheet: a small caption over a large value over a small detail.
/// The ability boxes and the headline row are both instances of it, so a number changes weight in
/// one place. A headline box carries the band's 16 px caption; a rail box is the smaller sibling
/// and drops to the 14 px caption floor on both its lines. Passive - it renders what
/// <see cref="Fill"/> hands it; the sheet owns the hover.
/// </summary>
public partial class SheetStatBox : PanelContainer
{
    private Label _caption = null!;
    private Label _value = null!;
    private Label _detail = null!;

    public override void _Ready()
    {
        _caption = GetNode<Label>("%Caption");
        _value = GetNode<Label>("%Value");
        _detail = GetNode<Label>("%Detail");
    }

    /// <summary>Read one number. An empty <paramref name="detail"/> collapses its row.</summary>
    public void Fill(string caption, string value, string detail, SheetEmphasis emphasis)
    {
        _caption.Text = caption;
        _value.Text = value;
        _detail.Text = detail;
        _detail.Visible = detail.Length > 0;

        bool headline = emphasis == SheetEmphasis.Headline;
        ThemeTypeVariation = emphasis == SheetEmphasis.Key ? ThemeNames.SheetBoxKey
            : headline ? ThemeNames.SheetBoxHeadline
            : ThemeNames.HudInset;
        _value.ThemeTypeVariation = headline ? ThemeNames.SheetKeyValue : ThemeNames.SheetValue;
        _emphasis = emphasis;

        string caps = headline ? ThemeNames.SheetCaption : ThemeNames.SheetCaptionSmall;
        _caption.ThemeTypeVariation = caps;
        _detail.ThemeTypeVariation = caps;
    }

    private SheetEmphasis _emphasis;

    /// <summary>
    /// Colour the box for the character who owns the page: headline boxes take the accent on
    /// their top strip and value, the key box on its border. Neutral rail boxes are untouched.
    /// Character-card surfaces are the one place instance colour overrides are sanctioned
    /// (design/ui_guidelines.md section 4.1) - the colour still comes from the palette.
    /// </summary>
    public void SetAccent(Color accent)
    {
        if (_emphasis == SheetEmphasis.Normal) return;

        _value.AddThemeColorOverride("font_color", accent);
        string variation = _emphasis == SheetEmphasis.Key
            ? ThemeNames.SheetBoxKey : ThemeNames.SheetBoxHeadline;
        if (GetThemeStylebox("panel", variation).Duplicate() is StyleBoxFlat styled)
        {
            styled.BorderColor = accent;
            AddThemeStyleboxOverride("panel", styled);
        }
    }
}
