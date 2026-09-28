using Godot;

namespace Delve.UI;

/// <summary>
/// End-of-encounter overlay: a dimmed full-screen modal with the result title, the party figures
/// that changed, one row per changed hero and the notes. Passive: the host hands it a
/// <see cref="Delve.Flow.CombatResultsView"/>. Pushes <see cref="HudRoot"/>'s modal state on show.
/// </summary>
public partial class VictoryBanner : Control
{
    [Export] public PackedScene? FigureScene { get; set; }
    [Export] public PackedScene? RowScene { get; set; }
    [Export] public double RevealSeconds { get; set; } = 0.3;

    private Label _resultLabel = null!;
    private Button _restartButton = null!;
    private Button _continueButton = null!;
    private HBoxContainer _figures = null!;
    private VBoxContainer _members = null!;
    private Label _notes = null!;
    private ProgressBar _progress = null!;
    private Tween? _reveal;
    public event System.Action? Continued;

    private HudRoot? _hud;
    private bool _modalHeld;

    public override void _Ready()
    {
        _resultLabel = GetNode<Label>("%ResultLabel");
        _restartButton = GetNode<Button>("%RestartButton");
        _continueButton = GetNode<Button>("%ContinueButton");
        _figures = GetNode<HBoxContainer>("%Figures");
        _members = GetNode<VBoxContainer>("%Members");
        _notes = GetNode<Label>("%Notes");
        _progress = GetNode<ProgressBar>("%XpProgress");
        _continueButton.Pressed += () =>
        {
            if (_continueButton.Disabled) return;
            _continueButton.Disabled = true;
            Continued?.Invoke();
        };
        _hud = GetParentOrNull<HudRoot>();
        _restartButton.Pressed += () => GetTree().ReloadCurrentScene();
        // Only a host that owns its own fresh-preset fallback opts in through SetRestartVisible.
        _restartButton.Visible = false;
        Visible = false;
        Resized += FitFrame;
        FitFrame();
        WirePartyDetails();
    }

    private void FitFrame()
    {
        var frame = GetNode<Control>("%Frame");
        frame.CustomMinimumSize = new Vector2(Mathf.Min(720, Mathf.Max(240, Size.X - 64)), 0);
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
        GetNode<Delve.Flow.CharacterDetailsOverlay>("%ResultDetails").Close();
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
        FitFrame();
        RenderRows(new Delve.Flow.CombatResultsView());
        _resultLabel.Text = text.TrimEnd('!');
        _resultLabel.AddThemeColorOverride("font_color", color);
        Visible = true;
        if (!_modalHeld)
        {
            _modalHeld = true;
            _hud?.PushModal();
        }
    }

    public void ShowRewards(Delve.Flow.CombatResultsView view)
    {
        RenderRows(view);
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
