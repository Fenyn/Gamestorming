using Godot;
using Godot.Collections;

namespace Ungilded.Story;

/// <summary>
/// The art behind a narration page: stacked <see cref="DriftLayer"/>s fitted to this control's size.
/// <see cref="Play"/> moves each layer by its drift over <see cref="DriftSeconds"/>, easing out, so near
/// layers pass far ones. A resize refits the layers at the current drift.
/// </summary>
public partial class CrawlScenery : Control
{
    [Export] public Array<DriftLayer> Layers { get; set; } = new();

    [Export] public float DriftSeconds { get; set; } = 24f;

    private float _progress;

    /// <summary>Fraction of the drift travelled, 0 to 1.</summary>
    public float Progress
    {
        get => _progress;
        set
        {
            _progress = value;
            foreach (var layer in Layers)
                layer.Position = layer.Rest + layer.Drift * _progress;
        }
    }

    public override void _Ready()
    {
        Fit();
        Resized += Fit;
    }

    public void Play()
    {
        var tween = CreateTween().SetIgnoreTimeScale()
            .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
        tween.TweenProperty(this, nameof(Progress), 1f, DriftSeconds).From(0f);
    }

    private void Fit()
    {
        foreach (var layer in Layers)
            layer.Fit(Size);
        Progress = _progress;
    }
}
