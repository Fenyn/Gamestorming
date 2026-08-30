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

        if (_content == null) return;
        // Content is a Container, so it republishes its own minimum size when a label grows. This
        // Button is not a Container and must forward that upward itself.
        _content.MinimumSizeChanged += FitToContent;
        FitToContent();
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
