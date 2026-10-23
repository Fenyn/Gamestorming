using Godot;

namespace Ungilded.Story;

/// <summary>
/// Black bars at the top and bottom of the screen while a cutscene set plays. They ease in and out.
/// The layer sits under the black backdrop, the narration and the dialogue box, and each bar is
/// shorter than the gap under the dialogue box, so neither covers text.
/// </summary>
public partial class Letterbox : CanvasLayer
{
    /// <summary>Bar height at 1080 px, in viewport pixels.</summary>
    [Export] public float BarHeight { get; set; } = 30f;

    [Export] public float EaseSeconds { get; set; } = 0.8f;

    /// <summary>True while the bars are in or easing in.</summary>
    public bool IsShown { get; private set; }

    private Control _top = null!;
    private Control _bottom = null!;
    private Tween? _tween;
    private float _reveal;

    public override void _Ready()
    {
        _top = GetNode<Control>("%Top");
        _bottom = GetNode<Control>("%Bottom");
        Apply();
    }

    public void ShowBars() => Ease(true);

    public void HideBars() => Ease(false);

    /// <summary>The bottom bar's rectangle on screen.</summary>
    public Rect2 BottomRect => _bottom.GetGlobalRect();

    /// <summary>The top bar's rectangle on screen.</summary>
    public Rect2 TopRect => _top.GetGlobalRect();

    /// <summary>0 out, 1 fully in. Tweened by <see cref="ShowBars"/> and <see cref="HideBars"/>.</summary>
    public float Reveal
    {
        get => _reveal;
        set
        {
            _reveal = value;
            Apply();
        }
    }

    private void Ease(bool show)
    {
        if (IsShown == show && _tween == null) return;
        IsShown = show;
        _tween?.Kill();
        var tween = CreateTween().SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.InOut);
        _tween = tween;
        tween.TweenProperty(this, nameof(Reveal), show ? 1f : 0f, EaseSeconds);
        tween.Finished += () =>
        {
            if (_tween == tween) _tween = null;
        };
    }

    private void Apply()
    {
        if (_top == null) return;
        float height = BarHeight * _reveal;
        _top.OffsetBottom = height;
        _bottom.OffsetTop = -height;
        Visible = _reveal > 0f;
    }
}
