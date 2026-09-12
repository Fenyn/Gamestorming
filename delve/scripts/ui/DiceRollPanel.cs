using Godot;

namespace Delve.UI;

/// <summary>
/// A short visual reveal of the latest resolved d20; never rolls gameplay dice. Always on; an
/// options menu can gate it later. One roll plays as a staged chain on a single stored tween: the
/// face tumbles through random numbers, lands on the rolled value with a pop, then the sum line
/// fades in, then the outcome word pops in, and the whole card holds and fades. A new roll kills
/// the chain and restarts it, so two quick strikes never leave stale pieces of the first on screen.
/// The tumble uses its own display-only random source, so it can never touch combat RNG.
/// </summary>
public partial class DiceRollPanel : PanelContainer
{
    /// <summary>How long the face cycles random numbers before landing.</summary>
    [Export] public float TumbleSeconds { get; set; } = 0.35f;
    /// <summary>Seconds between random faces during the tumble.</summary>
    [Export] public float TumbleStepSeconds { get; set; } = 0.045f;
    /// <summary>Landing pop: the face swells and settles over this time.</summary>
    [Export] public float LandPopSeconds { get; set; } = 0.18f;
    [Export] public float LandPopScale { get; set; } = 1.3f;
    /// <summary>Pause after landing before the sum line appears.</summary>
    [Export] public float SumDelaySeconds { get; set; } = 0.15f;
    [Export] public float SumFadeSeconds { get; set; } = 0.15f;
    /// <summary>Font size of the two numbers that decide the roll: the total and the target it meets.</summary>
    [Export] public int SumFontSize { get; set; } = 36;
    /// <summary>Font size of the arithmetic around them ("19+10 =", "vs AC").</summary>
    [Export] public int SumDetailFontSize { get; set; } = 18;
    /// <summary>Pause after the sum before the outcome word pops in.</summary>
    [Export] public float OutcomeDelaySeconds { get; set; } = 0.2f;
    [Export] public float OutcomePopSeconds { get; set; } = 0.18f;
    /// <summary>How long the finished card stays before fading.</summary>
    [Export] public float HoldSeconds { get; set; } = 1.1f;
    [Export] public float FadeSeconds { get; set; } = 0.2f;

    private Label _die = null!;
    private Control _face = null!;
    private Label _context = null!;
    private RichTextLabel _math = null!;
    private Label _outcome = null!;
    private CombatRoll? _roll;
    private Tween? _tween;
    private readonly System.Random _tumble = new();
    private int _lastFace;

    /// <summary>Seconds from <see cref="ShowRoll"/> until the outcome word has fully arrived.</summary>
    public float SettleSeconds =>
        TumbleSeconds + LandPopSeconds + SumDelaySeconds + SumFadeSeconds + OutcomeDelaySeconds + OutcomePopSeconds;

    /// <summary>True while the face is still tumbling (before it lands on the rolled value).</summary>
    public bool Tumbling { get; private set; }

    public override void _Ready()
    {
        _die = GetNode<Label>("%DieValue");
        _face = _die.GetParent<Control>();
        _context = GetNode<Label>("%RollContext");
        _math = GetNode<RichTextLabel>("%RollMath");
        _outcome = GetNode<Label>("%RollOutcome");
        ClearRoll();
    }

    public void ClearRoll()
    {
        _tween?.Kill();
        _tween = null;
        _roll = null;
        Tumbling = false;
        Visible = false;
    }

    public void ShowRoll(CombatRoll roll, string context)
    {
        ClearRoll();
        _roll = roll;
        _context.Text = context;
        _math.Text = "";
        _outcome.Text = "";
        _die.Text = "";
        _die.RemoveThemeColorOverride("font_color");
        _face.PivotOffset = _face.Size * 0.5f;
        _face.Scale = Vector2.One;
        _math.Modulate = Colors.Transparent;
        _math.PivotOffset = _math.Size * 0.5f;
        _math.Scale = Vector2.One;
        _outcome.Modulate = Colors.Transparent;
        _outcome.PivotOffset = _outcome.Size * 0.5f;
        _outcome.Scale = Vector2.One;
        Modulate = Colors.White;
        Visible = true;
        Tumbling = true;

        int steps = Mathf.Max(1, Mathf.RoundToInt(TumbleSeconds / Mathf.Max(0.01f, TumbleStepSeconds)));
        _tween = CreateTween();
        // Tumble: one random face per step, never the same face twice in a row.
        for (int i = 0; i < steps; i++)
        {
            _tween.TweenCallback(Callable.From(TumbleFace));
            _tween.TweenInterval(TumbleStepSeconds);
        }
        // Land: the rolled value, with a swell that settles back.
        _tween.TweenCallback(Callable.From(Land));
        _tween.TweenProperty(_face, "scale", Vector2.One * LandPopScale, LandPopSeconds * 0.5f)
            .SetTrans(Tween.TransitionType.Back).SetEase(Tween.EaseType.Out);
        _tween.TweenProperty(_face, "scale", Vector2.One, LandPopSeconds * 0.5f)
            .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
        // Sum: the arithmetic line fades in with a small swell on the two numbers that matter.
        _tween.TweenInterval(SumDelaySeconds);
        _tween.TweenCallback(Callable.From(ShowMath));
        _tween.TweenProperty(_math, "modulate", Colors.White, SumFadeSeconds);
        _tween.Parallel().TweenProperty(_math, "scale", Vector2.One, SumFadeSeconds)
            .SetTrans(Tween.TransitionType.Back).SetEase(Tween.EaseType.Out);
        // Outcome: the word pops in, coloured by severity.
        _tween.TweenInterval(OutcomeDelaySeconds);
        _tween.TweenCallback(Callable.From(ShowOutcome));
        _tween.TweenProperty(_outcome, "modulate", Colors.White, OutcomePopSeconds);
        _tween.Parallel().TweenProperty(_outcome, "scale", Vector2.One, OutcomePopSeconds)
            .SetTrans(Tween.TransitionType.Back).SetEase(Tween.EaseType.Out);
        // Hold, fade, hide.
        _tween.TweenInterval(HoldSeconds);
        _tween.TweenProperty(this, "modulate", Colors.Transparent, FadeSeconds);
        _tween.TweenCallback(Callable.From(ClearRoll));
    }

    private void TumbleFace()
    {
        int face;
        do face = _tumble.Next(1, 21); while (face == _lastFace);
        _lastFace = face;
        _die.Text = face.ToString();
    }

    private void Land()
    {
        if (_roll == null) return;
        Tumbling = false;
        _die.Text = _roll.Die.ToString();
        // A natural 20 or 1 reads in the log's crit colours; every other face keeps the caption tone.
        if (_roll.Die == 20) _die.AddThemeColorOverride("font_color", UiColors.LogSeverity[2]);
        else if (_roll.Die == 1) _die.AddThemeColorOverride("font_color", UiColors.LogSeverity[4]);
    }

    /// <summary>"19+10 = 29 vs AC 17" with the total and the target large, the arithmetic around
    /// them small and dim. The total takes the roll's severity colour (the log's crit/hit/miss/fumble
    /// tones) so the result reads as good or bad at a glance; the target stays neutral bright.</summary>
    private void ShowMath()
    {
        if (_roll == null) return;
        string dim = UiColors.TextDim.ToHtml();
        string Detail(string text) => $"[font_size={SumDetailFontSize}][color=#{dim}]{text}[/color][/font_size]";
        string Big(int number, Color colour) =>
            $"[font_size={SumFontSize}][b][color=#{colour.ToHtml()}]{number}[/color][/b][/font_size]";
        _math.Text = $"[center]{Detail($"{_roll.Die}{_roll.Modifiers} =")} {Big(_roll.Total, SeverityColor())}"
            + $" {Detail($"vs {_roll.Defense}")} {Big(_roll.DC, UiColors.Text)}[/center]";
        _math.PivotOffset = _math.Size * 0.5f;
        _math.Scale = Vector2.One * 0.85f;
    }

    /// <summary>The log's severity tone for this roll's degree: crit hit gold, hit green, miss grey,
    /// critical miss red (indices into <see cref="UiColors.LogSeverity"/>).</summary>
    private Color SeverityColor()
    {
        int severity = _roll?.Degree switch { "CriticalSuccess" => 2, "Success" => 1, "Failure" => 3, _ => 4 };
        return UiColors.LogSeverity[severity];
    }

    private void ShowOutcome()
    {
        if (_roll == null) return;
        _outcome.Text = _roll.Outcome;
        _outcome.AddThemeColorOverride("font_color", SeverityColor());
        _outcome.PivotOffset = _outcome.Size * 0.5f;
        _outcome.Scale = Vector2.One * 0.7f;
    }
}
