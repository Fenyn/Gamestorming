using System.Threading.Tasks;
using Godot;

namespace Ungilded.Story;

/// <summary>
/// Full-screen black backdrop for story beats. <see cref="FadeIn"/> brings the black up over the
/// screen; <see cref="FadeOut"/> takes it away and shows what is behind it. Fades ignore the time
/// scale. While any black shows, the overlay blocks mouse input to the board. A new fade or
/// <see cref="SetOpaque"/> completes the task of the fade it replaces.
/// </summary>
public partial class FadeOverlay : CanvasLayer
{
    /// <summary>Start fully black.</summary>
    [Export] public bool StartOpaque { get; set; } = true;

    private ColorRect _black = null!;
    private Tween? _tween;
    private TaskCompletionSource? _pending;

    /// <summary>True while the black is fully up.</summary>
    public bool IsOpaque => _black.Modulate.A >= 1f;

    /// <summary>True while no black shows.</summary>
    public bool IsClear => _black.Modulate.A <= 0f;

    public override void _Ready()
    {
        _black = GetNode<ColorRect>("%Black");
        SetOpaque(StartOpaque);
    }

    /// <summary>Snap to fully black (true) or fully clear (false).</summary>
    public void SetOpaque(bool opaque)
    {
        Cancel();
        Apply(opaque ? 1f : 0f);
    }

    /// <summary>Bring the black up over <paramref name="seconds"/>.</summary>
    public Task FadeIn(float seconds) => FadeTo(1f, seconds);

    /// <summary>Take the black away over <paramref name="seconds"/>.</summary>
    public Task FadeOut(float seconds) => FadeTo(0f, seconds);

    private Task FadeTo(float alpha, float seconds)
    {
        Cancel();
        if (seconds <= 0f || Mathf.IsEqualApprox(_black.Modulate.A, alpha))
        {
            Apply(alpha);
            return Task.CompletedTask;
        }

        _black.Visible = true;
        _black.MouseFilter = Control.MouseFilterEnum.Stop;
        var done = new TaskCompletionSource();
        var tween = CreateTween().SetIgnoreTimeScale();
        _tween = tween;
        _pending = done;
        tween.TweenProperty(_black, "modulate:a", alpha, seconds);
        tween.Finished += () =>
        {
            if (_tween != tween) return;
            _tween = null;
            _pending = null;
            Apply(alpha);
            done.TrySetResult();
        };
        return done.Task;
    }

    private void Cancel()
    {
        _tween?.Kill();
        _tween = null;
        _pending?.TrySetResult();
        _pending = null;
    }

    private void Apply(float alpha)
    {
        _black.Modulate = _black.Modulate with { A = alpha };
        _black.Visible = alpha > 0f;
        _black.MouseFilter = alpha > 0f ? Control.MouseFilterEnum.Stop : Control.MouseFilterEnum.Ignore;
    }
}
