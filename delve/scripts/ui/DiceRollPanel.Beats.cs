using Godot;

namespace Delve.UI;

/// <summary>The beats as tween chains on one stored tween. The presenter's gate opens when the
/// outcome word has arrived, after the freeze on a critical success; the shrink, hold and fade
/// play on during the next board effect.</summary>
public partial class DiceRollPanel
{
    [Export] public float TumbleStepSeconds { get; set; } = 0.045f;
    [Export] public float CentreTumbleSeconds { get; set; } = 0.40f;
    [Export] public float TrackTumbleSeconds { get; set; } = 0.35f;
    [Export] public float CentreLandSeconds { get; set; } = 0.18f;
    [Export] public float TrackLandSeconds { get; set; } = 0.15f;
    [Export] public float LandPopScale { get; set; } = 1.3f;
    /// <summary>Centre stage: the modifier counts into the total.</summary>
    [Export] public float CountSeconds { get; set; } = 0.25f;
    /// <summary>Degree track: the marker slides from the die face to the total.</summary>
    [Export] public float SlideSeconds { get; set; } = 0.30f;
    [Export] public float WordSeconds { get; set; } = 0.18f;
    /// <summary>The hit-stop a critical success holds before the gate opens.</summary>
    [Export] public float FreezeSeconds { get; set; } = 0.2f;
    [Export] public float ShrinkSeconds { get; set; } = 0.2f;
    [Export] public float ShrinkScale { get; set; } = 0.35f;
    /// <summary>Short beat: face, total and outcome each take one step.</summary>
    [Export] public float ShortStepSeconds { get; set; } = 0.1f;
    /// <summary>How long the settled row stays before fading.</summary>
    [Export] public float HoldSeconds { get; set; } = 1.1f;
    [Export] public float FadeSeconds { get; set; } = 0.2f;

    private int TumbleSteps(float seconds) => Mathf.Max(1, Mathf.RoundToInt(seconds / Mathf.Max(0.01f, TumbleStepSeconds)));

    /// <summary>Seconds from the start of a beat until its gate opens.</summary>
    public float GateSeconds(RollBeat beat)
    {
        if (beat.Pace == RollPace.Settled) return 0;
        if (beat.Pace == RollPace.Short) return ShortStepSeconds * 3;
        bool centre = beat.Stage == RollStage.CentreStage;
        return TumbleSteps(centre ? CentreTumbleSeconds : TrackTumbleSeconds) * TumbleStepSeconds
            + (centre ? CentreLandSeconds : TrackLandSeconds) + (centre ? CountSeconds : SlideSeconds)
            + WordSeconds + (beat.Freeze ? FreezeSeconds : 0);
    }

    private void BuildFull(CombatRoll roll, RollBeat beat)
    {
        var hero = Hero!;
        var tween = _tween!;
        HideRow();
        hero.Begin(roll, beat.Stage, FormatApplied(roll, Icons, AppliedIconSize));
        hero.Place(GetGlobalRect(), HeroGap);
        bool centre = beat.Stage == RollStage.CentreStage;
        float land = centre ? CentreLandSeconds : TrackLandSeconds;
        Tumbling = true;
        for (int i = TumbleSteps(centre ? CentreTumbleSeconds : TrackTumbleSeconds); i > 0; i--)
        {
            tween.TweenCallback(Callable.From(() => TumbleFace(hero.ShowFace)));
            tween.TweenInterval(TumbleStepSeconds);
        }
        tween.TweenCallback(Callable.From(() =>
        {
            Tumbling = false;
            hero.Land();
            hero.Total.Modulate = hero.Total.Modulate with { A = 1 };
            if (centre) hero.Chip.Modulate = hero.Chip.Modulate with { A = 1 };
        }));
        Pop(tween, hero.Face, land);
        tween.TweenMethod(Callable.From<float>(hero.Count), (float)roll.Die, (float)roll.Total, centre ? CountSeconds : SlideSeconds);
        tween.TweenCallback(Callable.From(hero.ShowWord));
        tween.TweenProperty(hero.Word, "modulate:a", 1f, WordSeconds);
        tween.Parallel().TweenProperty(hero.Word, "scale", Vector2.One, WordSeconds)
            .SetTrans(Tween.TransitionType.Back).SetEase(Tween.EaseType.Out);
        if (beat.Freeze) tween.TweenInterval(FreezeSeconds);
        tween.TweenCallback(Callable.From(Arrive));
        tween.TweenMethod(Callable.From<float>(Shrink), 0f, 1f, ShrinkSeconds);
        tween.TweenCallback(Callable.From(hero.Clear));
    }

    /// <summary>The hero shrinks into the row while the row fades in under it.</summary>
    private void Shrink(float t)
    {
        if (Hero is not { } hero) return;
        var row = GetGlobalRect();
        var start = new Vector2(row.GetCenter().X - hero.Size.X / 2, row.Position.Y - HeroGap - hero.Size.Y);
        hero.PivotOffset = hero.Size / 2;
        hero.GlobalPosition = start.Lerp(row.GetCenter() - hero.Size / 2, t);
        hero.Scale = Vector2.One * Mathf.Lerp(1f, ShrinkScale, t);
        hero.Modulate = hero.Modulate with { A = 1 - t };
        SetRowAlpha(t, t);
    }

    private void BuildShort()
    {
        var tween = _tween!;
        SetRowAlpha(1, 1);
        foreach (var node in new CanvasItem[] { _math, _detail, _applied, _outcome, _rowTrack })
            node.Modulate = node.Modulate with { A = 0 };
        Pop(tween, _face, ShortStepSeconds);
        tween.TweenProperty(_math, "modulate:a", 1f, ShortStepSeconds);
        tween.Parallel().TweenProperty(_detail, "modulate:a", 1f, ShortStepSeconds);
        tween.Parallel().TweenProperty(_applied, "modulate:a", 1f, ShortStepSeconds);
        tween.Parallel().TweenProperty(_rowTrack, "modulate:a", 1f, ShortStepSeconds);
        tween.TweenCallback(Callable.From(() =>
        {
            _outcome.PivotOffset = _outcome.Size * 0.5f;
            _outcome.Scale = Vector2.One * 0.7f;
        }));
        tween.TweenProperty(_outcome, "modulate:a", 1f, ShortStepSeconds);
        tween.Parallel().TweenProperty(_outcome, "scale", Vector2.One, ShortStepSeconds)
            .SetTrans(Tween.TransitionType.Back).SetEase(Tween.EaseType.Out);
        tween.TweenCallback(Callable.From(Arrive));
    }

    private void Pop(Tween tween, Control target, float seconds)
    {
        tween.TweenCallback(Callable.From(() => target.PivotOffset = target.Size * 0.5f));
        tween.TweenProperty(target, "scale", Vector2.One * LandPopScale, seconds * 0.5f)
            .SetTrans(Tween.TransitionType.Back).SetEase(Tween.EaseType.Out);
        tween.TweenProperty(target, "scale", Vector2.One, seconds * 0.5f)
            .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
    }

    private void AppendHoldAndFade()
    {
        var tween = _tween!;
        tween.TweenInterval(HoldSeconds);
        tween.TweenProperty(this, "modulate:a", 0f, FadeSeconds);
        tween.TweenCallback(Callable.From(() =>
        {
            _current = null;
            _phase = Phase.Idle;
            Beat = null;
            ResultShowing = false;
            Visible = false;
            _tween = null;
            StartNextRoll();
        }));
    }
}
