using Godot;

namespace Delve.UI;

/// <summary>
/// End-of-encounter overlay: a dimmed full-screen modal with a result headline and a Restart
/// button that reloads the current scene. Passive — <c>CombatScene</c> calls <see cref="ShowResult"/>
/// with a pre-formatted string + color; this holds no game rules and no engine types. Pushes
/// <see cref="HudRoot"/>'s modal state on show (combat is over; nothing underneath needs input).
/// </summary>
public partial class VictoryBanner : Control
{
    private Label _resultLabel = null!;
    private Button _restartButton = null!;

    private HudRoot? _hud;
    private bool _modalHeld;

    public override void _Ready()
    {
        _resultLabel = GetNode<Label>("%ResultLabel");
        _restartButton = GetNode<Button>("%RestartButton");
        _hud = GetParentOrNull<HudRoot>();
        _restartButton.Pressed += () => GetTree().ReloadCurrentScene();
        // Hidden by default: ReloadCurrentScene only makes sense for a host that owns its own
        // fresh-preset fallback (the standalone dev harness). In the real flow (EncounterScene)
        // the pending encounter is already consumed and a reload lands on its warning fallback,
        // so that host must opt in explicitly via SetRestartVisible.
        _restartButton.Visible = false;
        Visible = false;
    }

    public override void _ExitTree()
    {
        if (!_modalHeld) return;
        _modalHeld = false;
        _hud?.PopModal();
    }

    /// <summary>Show/hide the Restart button. Opt-in — see the field's remarks above.</summary>
    public void SetRestartVisible(bool visible) => _restartButton.Visible = visible;

    /// <summary>Display the banner with the given headline and headline color.</summary>
    public void ShowResult(string text, Color color)
    {
        _resultLabel.Text = text;
        _resultLabel.AddThemeColorOverride("font_color", color);
        Visible = true;
        if (!_modalHeld)
        {
            _modalHeld = true;
            _hud?.PushModal();
        }
    }
}
