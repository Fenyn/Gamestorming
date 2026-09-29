using Godot;

namespace Delve.UI;

/// <summary>
/// One action-bar caption button: the action name at body size next to a keycap holding the key
/// that triggers it. The keycap text comes from the input map at _Ready, so a rebound action
/// relabels itself and no scene stores a key name.
///
/// It is also the sizing seam for any Button whose content is non-container children. Godot derives
/// a Button's minimum size from its own text and icon only, so this script measures the Content row
/// plus the normal stylebox margins and publishes the result as the button's minimum size, then
/// re-measures whenever the row changes (the Strike button gains a MAP suffix mid-turn).
/// action_chip.tscn carries the same script for that reason and leaves the caption exports empty.
/// </summary>
public partial class CaptionButton : Button
{
    /// <summary>Caption text written into Content/ActionLabel. Empty keeps the authored text.</summary>
    [Export] public string ActionText { get; set; } = "";

    /// <summary>Input action whose first key fills the keycap. Empty keeps the authored text.</summary>
    [Export] public StringName InputAction { get; set; } = "";

    /// <summary>Menu row layout: the caption sits left and the keycap right, across the whole
    /// button, instead of both centred.</summary>
    [Export] public bool FillRow { get; set; }

    /// <summary>Keycap style; empty keeps the authored one.</summary>
    [Export] public StringName KeycapVariation { get; set; } = "";

    /// <summary>Inset of a <see cref="FillRow"/> caption from the button's edges, pixels.</summary>
    [Export] public float RowInset { get; set; } = 14f;

    /// <summary>Caption and keycap label styles for this button's surface (the parchment menus
    /// use dark ink). Empty keeps the labels as authored.</summary>
    [Export] public StringName LabelVariation { get; set; } = "";
    [Export] public StringName DisabledLabelVariation { get; set; } = "";
    [Export] public StringName KeyVariation { get; set; } = "";

    /// <summary>Enable or grey the button and restyle its labels to match; a Label child does not
    /// follow its Button's disabled colour on its own.</summary>
    public void SetEnabled(bool enabled)
    {
        Disabled = !enabled;
        ApplyLabelStyles();
    }

    private void ApplyLabelStyles()
    {
        if (ActionLabel != null && !LabelVariation.IsEmpty)
            ActionLabel.ThemeTypeVariation = Disabled && !DisabledLabelVariation.IsEmpty ? DisabledLabelVariation : LabelVariation;
        if (KeyLabel != null && !KeyVariation.IsEmpty) KeyLabel.ThemeTypeVariation = KeyVariation;
    }

    private Control? _content;
    private float _authoredMinHeight;

    /// <summary>The caption's action label, or null on a button with no caption row.</summary>
    public Label? ActionLabel { get; private set; }

    /// <summary>The keycap's key label, or null on a button with no keycap.</summary>
    public Label? KeyLabel { get; private set; }

    public override void _Ready()
    {
        _authoredMinHeight = CustomMinimumSize.Y;
        _content = GetNodeOrNull<Control>("Content");
        ActionLabel = GetNodeOrNull<Label>("Content/ActionLabel");
        KeyLabel = GetNodeOrNull<Label>("Content/Keycap/KeyLabel");

        if (ActionLabel != null && !string.IsNullOrEmpty(ActionText))
            ActionLabel.Text = ActionText;
        if (KeyLabel != null && !InputAction.IsEmpty)
            KeyLabel.Text = InputNames.KeyLabelFor(InputAction);

        ApplyLabelStyles();
        if (_content == null) return;
        if (!KeycapVariation.IsEmpty && GetNodeOrNull<Control>("Content/Keycap") is { } keycap)
            keycap.ThemeTypeVariation = KeycapVariation;
        if (FillRow)
        {
            _content.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
            _content.OffsetLeft = RowInset;
            _content.OffsetRight = -RowInset;
            if (ActionLabel != null) ActionLabel.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        }
        // Content is a Container, so it republishes its own minimum size when a label grows. This
        // Button is not a Container and must forward that upward itself.
        _content.MinimumSizeChanged += FitToContent;
        FitToContent();
    }

    /// <summary>Show or hide the keycap, for a menu drawn too small for it to stay legible.</summary>
    public void SetKeycapShown(bool shown)
    {
        if (GetNodeOrNull<Control>("Content/Keycap") is { } keycap) keycap.Visible = shown;
    }

    public void SetActionText(string text)
    {
        ActionText = text;
        if (ActionLabel != null) ActionLabel.Text = text;
    }

    /// <summary>Size the button to its Content row plus the normal stylebox margins, never below
    /// the height the scene authored.</summary>
    private void FitToContent()
    {
        if (_content == null) return;
        Vector2 size = _content.GetCombinedMinimumSize() + GetThemeStylebox("normal").GetMinimumSize();
        CustomMinimumSize = new Vector2(size.X, Mathf.Max(size.Y, _authoredMinHeight));
    }
}
