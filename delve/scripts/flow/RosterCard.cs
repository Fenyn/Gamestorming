using System;
using Delve.Run;
using Delve.UI;
using Godot;

namespace Delve.Flow;

/// <summary>
/// How one roster card reads: whether it is the starting character, and the gate that greys it out.
/// A null <see cref="DisabledReason"/> means the card takes clicks; a non-null one is rendered as
/// the <c>Unavailable: reason</c> tooltip the guidelines require (section 7).
/// </summary>
public sealed record RosterCardState(bool Chosen, string? DisabledReason = null, bool Locked = false);

/// <summary>
/// One compact roster entry: portrait thumb, name, role, and the caption that names the starting
/// character. Passive - it renders what <see cref="Setup"/> and <see cref="SetState"/> hand it and
/// signals clicks and hovers outward. The featured sheet does the talking; this only has to be
/// scannable in a column of five.
/// </summary>
public partial class RosterCard : Button
{
    private TextureRect _sprite = null!;
    private Panel _lockScrim = null!;
    private Label _name = null!;
    private Label _role = null!;
    private Label _caption = null!;

    private string _id = "";
    private Color _accent;

    /// <summary>Catalog id of the clicked card.</summary>
    public event Action<string>? Clicked;

    /// <summary>Catalog id under the pointer, or null when it left.</summary>
    public event Action<string?>? Hovered;

    /// <summary>Catalog id this card carries.</summary>
    public string Id => _id;

    public override void _Ready()
    {
        _sprite = GetNode<TextureRect>("%Sprite");
        _lockScrim = GetNode<Panel>("%LockScrim");
        _name = GetNode<Label>("%NameLabel");
        _role = GetNode<Label>("%RoleLabel");
        _caption = GetNode<Label>("%CaptionLabel");

        Pressed += () => Clicked?.Invoke(_id);
        // A disabled Button still reports the pointer, so a locked entry's sheet is readable even
        // though the card refuses the pick.
        MouseEntered += () => Hovered?.Invoke(_id);
        MouseExited += () => Hovered?.Invoke(null);
    }

    /// <summary>Fill the card from one roster entry. Safe to call again for a second run.</summary>
    public void Setup(CharacterDef def, Texture2D? portrait)
    {
        _id = def.Id;
        _accent = UiColors.CharacterAccent(def.Id);
        _name.Text = def.DisplayName;
        _role.Text = def.Role;
        _sprite.Texture = portrait;
        SetState(new RosterCardState(false));
    }

    /// <summary>Repaint the chosen state, the disabled gate and the caption.</summary>
    public void SetState(RosterCardState state)
    {
        ThemeTypeVariation = state.Chosen
            ? ThemeNames.RosterCardSelected
            : state.DisabledReason != null ? ThemeNames.RosterCardLocked : ThemeNames.RosterCard;

        // A roster card is a character-owned surface: its chosen border and caption wear the
        // character's own colour (design/ui_guidelines.md section 4.1).
        if (state.Chosen
            && GetThemeStylebox("normal", ThemeNames.RosterCardSelected).Duplicate() is StyleBoxFlat sel)
        {
            sel.BorderColor = _accent;
            AddThemeStyleboxOverride("normal", sel);
            AddThemeStyleboxOverride("hover", sel);
        }
        else
        {
            RemoveThemeStyleboxOverride("normal");
            RemoveThemeStyleboxOverride("hover");
        }
        _caption.AddThemeColorOverride("font_color", _accent);

        Disabled = state.DisabledReason != null;
        TooltipText = state.DisabledReason == null ? "" : $"Unavailable: {state.DisabledReason}";
        _lockScrim.Visible = state.Locked;

        // A Button's disabled font color reaches its own text, and the card has none - every word
        // on it is a child Label. Take them down to the palette's disabled ink together, so a card
        // that takes no clicks reads as one (design/ui_guidelines.md section 4.3).
        _name.AddThemeColorOverride("font_color", Disabled ? UiColors.TextDisabled : UiColors.Text);
        _role.AddThemeColorOverride("font_color", Disabled ? UiColors.TextDisabled : UiColors.TextDim);

        _caption.Text = state.Chosen ? "STARTING CHARACTER" : "";
    }
}
