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
    private Button _continueButton = null!;
    private Label _rewards = null!;
    private Label _progressText = null!;
    private ProgressBar _progress = null!;
    private Tween? _reveal;
    [Export] public double RevealSeconds { get; set; } = 0.3;
    public event System.Action? Continued;

    private HudRoot? _hud;
    private bool _modalHeld;

    public override void _Ready()
    {
        _resultLabel = GetNode<Label>("%ResultLabel");
        _restartButton = GetNode<Button>("%RestartButton");
        _continueButton = GetNode<Button>("%ContinueButton");
        _rewards = GetNode<Label>("%Rewards");
        _progressText = GetNode<Label>("%ProgressText");
        _progress = GetNode<ProgressBar>("%XpProgress");
        _continueButton.Pressed += () =>
        {
            if (_continueButton.Disabled) return;
            _continueButton.Disabled = true;
            Continued?.Invoke();
        };
        _hud = GetParentOrNull<HudRoot>();
        _restartButton.Pressed += () => GetTree().ReloadCurrentScene();
        // Hidden by default: ReloadCurrentScene only makes sense for a host that owns its own
        // fresh-preset fallback (the standalone dev harness). Any other host must opt in
        // explicitly via SetRestartVisible.
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

    /// <summary>Hide the banner and release the HUD modal it holds.</summary>
    public void HideResult()
    {
        _reveal?.Kill();
        Visible = false;
        if (!_modalHeld) return;
        _modalHeld = false;
        _hud?.PopModal();
    }

    /// <summary>Display the banner with the given headline and headline color.</summary>
    public void ShowResult(string text, Color color)
    {
        _reveal?.Kill();
        GetNode<Control>("%Frame").Modulate = Colors.White;
        _continueButton.Visible = false;
        _rewards.Visible = false;
        _progressText.Visible = false;
        _progress.Visible = false;
        _resultLabel.Text = text;
        _resultLabel.AddThemeColorOverride("font_color", color);
        Visible = true;
        if (!_modalHeld)
        {
            _modalHeld = true;
            _hud?.PushModal();
        }
    }

    public void ShowRewards(string rewards, string progressText, double progress)
    {
        _rewards.Text = rewards;
        _rewards.Visible = true;
        _progressText.Text = progressText;
        _progressText.Visible = progressText.Length > 0;
        _progress.Visible = progressText.Length > 0;
        _progress.Value = progress;
        _continueButton.Visible = true;
        _continueButton.Disabled = false;
        _continueButton.GrabFocus();
        _reveal?.Kill();
        var frame = GetNode<Control>("%Frame");
        frame.Modulate = new Color(Colors.White, 0f);
        _reveal = CreateTween();
        _reveal.TweenProperty(frame, "modulate:a", 1.0, RevealSeconds);
    }
}
