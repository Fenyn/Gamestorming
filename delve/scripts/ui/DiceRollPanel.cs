using Godot;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using System.Text.RegularExpressions;

namespace Delve.UI;

/// <summary>
/// A short visual reveal of each resolved d20; never rolls gameplay dice. Enabled by default.
/// One roll plays as a staged chain on a single stored tween: the
/// face tumbles through random numbers, lands on the rolled value with a pop, then the sum line
/// fades in, then the outcome word pops in, and the whole card holds and fades. Rolls queue;
/// the combat presenter awaits the actual outcome reveal rather than estimating its duration.
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
    [Export] public int SumFontSize { get; set; } = 48;
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
    private TextureRect _outline = null!;
    private Label _context = null!;
    private RichTextLabel _math = null!;
    private Label _outcome = null!;
    private CombatRoll? _roll;
    private Tween? _tween;
    private readonly System.Random _tumble = new();
    private int _lastFace;
    private readonly Queue<(CombatRoll Roll, string Context, TaskCompletionSource Result)> _pending = new();
    private TaskCompletionSource? _result;
    private Task _latestResult = Task.CompletedTask;
    private bool _animationsEnabled = true;

    [Export] public bool AnimationsEnabled
    {
        get => _animationsEnabled;
        set { _animationsEnabled = value; if (!value) ClearRoll(); }
    }

    public bool ResultShowing { get; private set; }

    /// <summary>Wait until every roll announced so far has shown its final outcome.</summary>
    public async Task WaitForResultsAsync(CancellationToken token = default)
    {
        token.ThrowIfCancellationRequested();
        while (true)
        {
            var pending = _latestResult;
            await pending.WaitAsync(token);
            token.ThrowIfCancellationRequested();
            if (pending == _latestResult) return;
        }
    }

    /// <summary>Seconds from <see cref="ShowRoll"/> until the outcome word has fully arrived.</summary>
    public float SettleSeconds =>
        TumbleSeconds + LandPopSeconds + SumDelaySeconds + SumFadeSeconds + OutcomeDelaySeconds + OutcomePopSeconds;

    /// <summary>True while the face is still tumbling (before it lands on the rolled value).</summary>
    public bool Tumbling { get; private set; }

    public override void _Ready()
    {
        _die = GetNode<Label>("%DieValue");
        _face = _die.GetParent<Control>();
        _outline = GetNode<TextureRect>("%Outline");
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
        ResultShowing = false;
        _result?.TrySetResult();
        _result = null;
        while (_pending.TryDequeue(out var pending)) pending.Result.TrySetResult();
        _latestResult = Task.CompletedTask;
        Visible = false;
    }

    public override void _ExitTree() => ClearRoll();

    public void ShowRoll(CombatRoll roll, string context)
    {
        if (!AnimationsEnabled) return;
        var result = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        _latestResult = result.Task;
        _pending.Enqueue((roll, context, result));
        if (_roll == null) StartNextRoll();
    }

    private void StartNextRoll()
    {
        if (!_pending.TryDequeue(out var next)) return;
        var (roll, context, result) = next;
        _result = result;
        ResultShowing = false;
        _roll = roll;
        _context.Text = context;
        _math.Text = "";
        _outcome.Text = "";
        _die.Text = "";
        _die.RemoveThemeColorOverride("font_color");
        _face.PivotOffset = _face.Size * 0.5f;
        _face.Scale = Vector2.One;
        _outline.PivotOffset = _outline.Size * 0.5f;
        _outline.Rotation = 0;
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
        _tween.TweenCallback(Callable.From(() =>
        {
            ResultShowing = true;
            result.TrySetResult();
        }));
        // Hold, fade, hide.
        _tween.TweenInterval(HoldSeconds);
        _tween.TweenProperty(this, "modulate", Colors.Transparent, FadeSeconds);
        _tween.TweenCallback(Callable.From(() =>
        {
            _roll = null;
            _result = null;
            ResultShowing = false;
            Visible = false;
            _tween = null;
            StartNextRoll();
        }));
    }

    private void TumbleFace()
    {
        int face;
        do face = _tumble.Next(1, 21); while (face == _lastFace);
        _lastFace = face;
        _die.Text = face.ToString();
        _outline.RotationDegrees = (face % 5 - 2) * 9;
    }

    private void Land()
    {
        if (_roll == null) return;
        Tumbling = false;
        _outline.Rotation = 0;
        _die.Text = _roll.Die.ToString();
        // A natural 20 or 1 reads in the log's crit colours; every other face keeps the caption tone.
        if (_roll.Die == 20) _die.AddThemeColorOverride("font_color", UiColors.Accent);
        else if (_roll.Die == 1) _die.AddThemeColorOverride("font_color", UiColors.HpLow);
    }

    /// <summary>Total and target share the primary size. The die is secondary, with modifiers below.</summary>
    private void ShowMath()
    {
        if (_roll == null) return;
        string dim = UiColors.TextDim.ToHtml();
        string Detail(string text) => $"[font_size={SumDetailFontSize}][color=#{dim}]{text}[/color][/font_size]";
        string Big(int number, Color colour) =>
            $"[font_size={SumFontSize}][b][color=#{colour.ToHtml()}]{number}[/color][/b][/font_size]";
        _math.Text = $"[center]{Big(_roll.Total, SeverityColor())} {Detail("vs")} {Big(_roll.DC, UiColors.Text)}"
            + $"\n{Detail($"TOTAL / {_roll.Defense}")}"
            + $"\n[font_size={SumDetailFontSize}]{FormatAdjustments(_roll)}[/font_size][/center]";
        _math.PivotOffset = _math.Size * 0.5f;
        _math.Scale = Vector2.One * 0.85f;
    }

    /// <summary>Color signed adjustments supplied by the roll feed. Preserve their names and signs;
    /// never infer a named condition from an unexplained difference in the final total.</summary>
    internal static string FormatAdjustments(CombatRoll roll)
    {
        int reported = 0;
        string text = Regex.Replace(CombatLogFormat.Escape(roll.Modifiers), @"[+-]\d+", match =>
        {
            if (!int.TryParse(match.Value, out int value)) return match.Value;
            reported += value;
            var color = value < 0 ? UiColors.HpLow : UiColors.HpHigh;
            return $"[color=#{color.ToHtml()}]{match.Value}[/color]";
        });
        int remaining = roll.Total - roll.Die - reported;
        if (remaining != 0)
        {
            var color = remaining < 0 ? UiColors.HpLow : UiColors.HpHigh;
            text += $" · Other [color=#{color.ToHtml()}]{remaining:+0;-0;0}[/color]";
        }
        return $"[color=#{UiColors.TextDim.ToHtml()}]Modifiers {text}[/color]";
    }

    /// <summary>Use the UI's action, health, muted, and danger tones for the total and outcome.</summary>
    private Color SeverityColor()
    {
        return _roll?.Degree switch {
            "CriticalSuccess" => UiColors.Accent, "Success" => UiColors.HpHigh,
            "Failure" => UiColors.TextDim, _ => UiColors.HpLow
        };
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
