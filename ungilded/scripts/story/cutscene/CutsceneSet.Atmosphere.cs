using Godot;
using Ungilded.Props;

namespace Ungilded.Story.Cutscene;

/// <summary>The set's air: dust motes in each torch's light and the colour grade a
/// <see cref="GradeCue"/> blends.</summary>
public partial class CutsceneSet
{
    /// <summary>Dust drifting in a torch's light, added to each torch the look's dressing placed.</summary>
    [Export] public PackedScene? MoteScene { get; set; }

    /// <summary>Torches on this set that carry motes.</summary>
    public int MoteTorches { get; private set; }

    /// <summary>The tint the grade is at or blending to. White is neutral.</summary>
    public Color GradeTint { get; private set; } = Colors.White;

    private Node2D _grade = null!;
    private Tween? _gradeTween;

    /// <summary>Motes at every torch, on a freshly built stage.</summary>
    private void DressAir()
    {
        MoteTorches = 0;
        if (MoteScene == null || Stage.Look?.Dressing is not SewerDressing sewer) return;
        foreach (var torch in sewer.Torches) torch.AddChild(MoteScene.Instantiate());
        MoteTorches = sewer.Torches.Count;
    }

    /// <summary>Blend the grade from where it is to <paramref name="tint"/> over
    /// <paramref name="seconds"/>. The overlay hides once it is back at white.</summary>
    public void BlendGrade(Color tint, float seconds)
    {
        _gradeTween?.Kill();
        GradeTint = tint;
        _grade.Visible = true;
        var tween = CreateTween();
        _gradeTween = tween;
        tween.TweenProperty(_grade, "modulate", tint, Mathf.Max(seconds, 0f));
        if (tint == Colors.White) tween.TweenCallback(Callable.From(() => _grade.Visible = false));
    }
}
