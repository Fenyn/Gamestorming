using Godot;

namespace Ungilded.UI;

/// <summary>The beats as tween chains on one stored tween. A full beat runs in two chains: the d20
/// (tumble, land, count, outcome slam and hold), then, on a hit with rolled damage, the damage dice
/// (tumble, land one by one, count into the total). The presenter's gate opens after the last of
/// them; the shrink, hold and fade play on during the next board effect.</summary>
public partial class DiceRollPanel
{
    [Export] public float TumbleStepSeconds { get; set; } = 0.06f;
    [Export] public float CentreTumbleSeconds { get; set; } = 0.48f;
    [Export] public float TrackTumbleSeconds { get; set; } = 0.48f;
    [Export] public float CentreLandSeconds { get; set; } = 0.24f;
    [Export] public float TrackLandSeconds { get; set; } = 0.24f;
    [Export] public float LandPopScale { get; set; } = 1.35f;
    /// <summary>The landed face shows alone this long before the total and modifier appear.</summary>
    [Export] public float LandRestSeconds { get; set; } = 0.12f;
    /// <summary>Centre stage: the modifier counts into the total.</summary>
    [Export] public float CountSeconds { get; set; } = 0.40f;
    /// <summary>Degree track: the marker slides from the die face to the total.</summary>
    [Export] public float SlideSeconds { get; set; } = 0.45f;
    /// <summary>The outcome word fades in while it shrinks from <see cref="WordSlamScale"/> to its size,
    /// then bounces to <see cref="WordBounceScale"/> and back over <see cref="WordBounceSeconds"/>.</summary>
    [Export] public float WordSeconds { get; set; } = 0.18f;
    [Export] public float WordSlamScale { get; set; } = 2.4f;
    [Export] public float WordBounceSeconds { get; set; } = 0.14f;
    [Export] public float WordBounceScale { get; set; } = 1.15f;
    /// <summary>Every outcome holds still this long before anything else moves.</summary>
    [Export] public float OutcomeHoldSeconds { get; set; } = 0.30f;
    /// <summary>The extra hit-stop a critical success holds after the outcome.</summary>
    [Export] public float FreezeSeconds { get; set; } = 0.2f;
    [Export] public float DamageTumbleSeconds { get; set; } = 0.36f;
    [Export] public float DamageLandSeconds { get; set; } = 0.20f;
    /// <summary>Seconds between one damage die landing and the next.</summary>
    [Export] public float DamageStaggerSeconds { get; set; } = 0.10f;
    /// <summary>The flat modifier and bonuses count the dice sum into the damage total.</summary>
    [Export] public float DamageCountSeconds { get; set; } = 0.30f;
    [Export] public float DamageHoldSeconds { get; set; } = 0.20f;
    [Export] public float ShrinkSeconds { get; set; } = 0.2f;
    [Export] public float ShrinkScale { get; set; } = 0.35f;
    /// <summary>Short beat: face, total and outcome each take one step.</summary>
    [Export] public float ShortStepSeconds { get; set; } = 0.1f;
    /// <summary>How long the settled row stays before fading.</summary>
    [Export] public float HoldSeconds { get; set; } = 1.1f;
    [Export] public float FadeSeconds { get; set; } = 0.2f;

    private int TumbleSteps(float seconds) => Mathf.Max(1, Mathf.RoundToInt(seconds / Mathf.Max(0.01f, TumbleStepSeconds)));

    /// <summary>Seconds from the start of a beat until its gate opens, at the panel's pace.</summary>
    /// <param name="damageDice">Damage dice the full beat rolls after the outcome; 0 for a miss.</param>
    public float GateSeconds(RollBeat beat, int damageDice = 0)
    {
        if (beat.Pace == RollPace.Settled) return 0;
        if (beat.Pace == RollPace.Short) return ShortStepSeconds * 3 * Pace;
        bool centre = beat.Stage == RollStage.CentreStage;
        float seconds = TumbleSteps(centre ? CentreTumbleSeconds : TrackTumbleSeconds) * TumbleStepSeconds
            + (centre ? CentreLandSeconds : TrackLandSeconds) + LandRestSeconds + (centre ? CountSeconds : SlideSeconds)
            + WordSeconds + WordBounceSeconds + OutcomeHoldSeconds + (beat.Freeze ? FreezeSeconds : 0);
        if (damageDice > 0)
            seconds += TumbleSteps(DamageTumbleSeconds) * TumbleStepSeconds + (damageDice - 1) * DamageStaggerSeconds
                + DamageLandSeconds + DamageCountSeconds + DamageHoldSeconds;
        return seconds * Pace;
    }

    private void BuildFull(CombatRoll roll, RollBeat beat, DamageRoll? damage)
    {
        var hero = Hero!;
        var tween = _tween!;
        HideRow();
        hero.Begin(roll, beat.Stage, FormatApplied(roll, Icons, AppliedIconSize));
        if (damage != null) hero.SetDamage(damage);
        hero.Place(GetGlobalRect(), HeroGap);
        bool centre = beat.Stage == RollStage.CentreStage;
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
        }));
        Pop(tween, hero.Face, centre ? CentreLandSeconds : TrackLandSeconds);
        tween.TweenInterval(LandRestSeconds);
        tween.TweenCallback(Callable.From(() =>
        {
            hero.Total.Modulate = hero.Total.Modulate with { A = 1 };
            if (centre) hero.Chip.Modulate = hero.Chip.Modulate with { A = 1 };
        }));
        tween.TweenMethod(Callable.From<float>(hero.Count), (float)roll.Die, (float)roll.Total, centre ? CountSeconds : SlideSeconds);
        tween.TweenCallback(Callable.From(() => hero.ShowWord(WordSlamScale)));
        tween.TweenProperty(hero.Word, "modulate:a", 1f, WordSeconds);
        tween.Parallel().TweenProperty(hero.Word, "scale", Vector2.One, WordSeconds)
            .SetTrans(Tween.TransitionType.Quad).SetEase(Tween.EaseType.In);
        tween.TweenProperty(hero.Word, "scale", Vector2.One * WordBounceScale, WordBounceSeconds * 0.5f)
            .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
        tween.TweenProperty(hero.Word, "scale", Vector2.One, WordBounceSeconds * 0.5f)
            .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.In);
        tween.TweenInterval(OutcomeHoldSeconds + (beat.Freeze ? FreezeSeconds : 0));
        // Damage can reach the panel after this chain was built, so the second chain is built when
        // the outcome hold ends.
        tween.TweenCallback(Callable.From(BuildAfterOutcome));
    }

    private void BuildAfterOutcome()
    {
        _awaitingDamage = false;
        _tween = NewTween();
        if (Hero is { Visible: true, Damage: { } damage } hero) BuildDamage(hero, damage);
        _tween.TweenCallback(Callable.From(Arrive));
        _tween.TweenMethod(Callable.From<float>(Shrink), 0f, 1f, ShrinkSeconds);
        _tween.TweenCallback(Callable.From(() => Hero?.Clear()));
        AppendHoldAndFade();
    }

    private void BuildDamage(DiceHeroView hero, DamageRoll damage)
    {
        var tween = _tween!;
        tween.TweenCallback(Callable.From(hero.ShowDamageRow));
        for (int i = TumbleSteps(DamageTumbleSeconds); i > 0; i--)
        {
            tween.TweenCallback(Callable.From(() => hero.TumbleDamage(_tumble)));
            tween.TweenInterval(TumbleStepSeconds);
        }
        for (int i = 0; i < hero.DamageDice.Count; i++)
        {
            int index = i;
            tween.TweenCallback(Callable.From(() =>
            {
                hero.LandDamageDie(index);
                PopNow(hero.DamageDice[index], DamageLandSeconds);
                hero.TumbleDamage(_tumble);
            }));
            tween.TweenInterval(index < hero.DamageDice.Count - 1 ? DamageStaggerSeconds : DamageLandSeconds);
        }
        tween.TweenCallback(Callable.From(hero.ShowDamageChips));
        tween.TweenMethod(Callable.From<float>(hero.CountDamage), (float)damage.DiceSum, (float)damage.Total, DamageCountSeconds);
        tween.TweenCallback(Callable.From(() =>
        {
            hero.CountDamage(damage.Total);
            PopNow(hero.DamageTotal, DamageHoldSeconds);
        }));
        tween.TweenInterval(DamageHoldSeconds);
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
        foreach (var node in new CanvasItem[] { _math, _detail, _applied, _outcome, _damage, _rowTrack })
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
        tween.Parallel().TweenProperty(_damage, "modulate:a", 1f, ShortStepSeconds);
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

    /// <summary>A pop on its own tween, so the beat chain can move on while it plays.</summary>
    private void PopNow(Control target, float seconds)
    {
        var tween = NewTween();
        Pop(tween, target, seconds);
    }

    private void AppendHoldAndFade()
    {
        var tween = _tween!;
        tween.TweenInterval(HoldSeconds);
        tween.TweenProperty(this, "modulate:a", 0f, FadeSeconds);
        tween.TweenCallback(Callable.From(() =>
        {
            if (_hold == HoldKind.Paused) _hold = HoldKind.Reshown;
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
