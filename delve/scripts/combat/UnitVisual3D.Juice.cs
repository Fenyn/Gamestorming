using Godot;

namespace Delve.Combat;

/// <summary>Hit, dodge, lunge and death juice. Each animated property has one tween handle (see the
/// TWEEN OWNERSHIP note on <see cref="UnitVisual3D"/>).</summary>
public partial class UnitVisual3D
{
    /// <summary>Seconds into and out of the hit flash, and the shield flash.</summary>
    [Export] public Vector2 HitFlashSeconds { get; set; } = new(0.05f, 0.18f);
    [Export] public Vector2 ShieldFlashSeconds { get; set; } = new(0.1f, 0.25f);

    /// <summary>Metres the hurt shake swings the sprite, and seconds per swing.</summary>
    [Export] public float HurtShakeMetres { get; set; } = 0.05f;
    [Export] public float HurtShakeStepSeconds { get; set; } = 0.05f;

    /// <summary>Metres the dodge leans away, and seconds out and back.</summary>
    [Export] public float DodgeLeanMetres { get; set; } = 0.12f;
    [Export] public Vector2 DodgeLeanSeconds { get; set; } = new(0.07f, 0.11f);

    public void FlashHit() => FlashModulate(Delve.UI.UiColors.BoardFlashHit, HitFlashSeconds.X, HitFlashSeconds.Y);

    public void FlashShield() => FlashModulate(Delve.UI.UiColors.BoardFlashShield, ShieldFlashSeconds.X, ShieldFlashSeconds.Y);

    /// <summary>Tint %Sprite and return it to the look's rest tint, through the single modulate
    /// handle. Dead units are immune, because the <see cref="PlayDeath"/> corpse tint is final.</summary>
    private void FlashModulate(Color tint, float inDuration, float outDuration)
    {
        if (_dead) return;
        _modulateTween?.Kill();
        _sprite.Modulate = _restTint;
        _modulateTween = CreateTween();
        _modulateTween.TweenProperty(_sprite, "modulate", tint * _restTint, inDuration);
        _modulateTween.TweenProperty(_sprite, "modulate", _restTint, outDuration);
    }

    /// <summary>Commit-forward lunge on the token ROOT. <paramref name="distance"/> and the timings
    /// are caller-set, so a hero, whose swing art already carries the strike, can lean a short way over
    /// the length of the wind-up instead of hopping the way an art-less enemy does.</summary>
    public void FlashAttack(float distance = 0.2f, float outDuration = 0.05f, float backDuration = 0.08f)
    {
        // Rest is the position the LAST lunge started from, not wherever the token is now: a second
        // strike in the same turn would otherwise adopt a mid-lunge position as home and creep.
        if (_lungeTween != null && _lungeTween.IsValid())
        {
            _lungeTween.Kill();
            Position = _lungeRest;
        }
        _lungeTween = null;

        var lunge = new Vector3(_facing.X, 0f, _facing.Y);
        if (lunge.LengthSquared() > 0.0001f) lunge = lunge.Normalized() * distance;
        _lungeRest = Position;
        _lungeTween = CreateTween();
        _lungeTween.TweenProperty(this, "position", _lungeRest + lunge, outDuration)
            .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
        _lungeTween.TweenProperty(this, "position", _lungeRest, backDuration)
            .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.InOut);
    }

    /// <summary>Small lateral jitter on %Sprite for a landed hit, layered under
    /// <see cref="FlashHit"/>. Skipped on a kill — <see cref="PlayDeath"/> owns that beat.</summary>
    public void PlayHurtShake()
    {
        if (_dead) return;
        RestartSpriteMove();
        float amp = HurtShakeMetres, step = HurtShakeStepSeconds;
        _spriteMoveTween!.TweenProperty(_sprite, "position", _spriteRest + new Vector3(amp, 0f, 0f), step);
        _spriteMoveTween.TweenProperty(_sprite, "position", _spriteRest + new Vector3(-amp * 0.8f, 0f, 0f), step);
        _spriteMoveTween.TweenProperty(_sprite, "position", _spriteRest, step);
    }

    /// <summary>Duck away from a whiffed attack: %Sprite leans out along the horizontal direction of
    /// <paramref name="awayDir"/> and springs back. World-space rather than sprite-local, so the duck
    /// reads as "away from the attacker" from any camera angle.</summary>
    public void PlayDodgeLean(Vector3 awayDir)
    {
        if (_dead) return;
        var lean = new Vector3(awayDir.X, 0f, awayDir.Z);
        lean = (lean.LengthSquared() > 0.0001f ? lean.Normalized() : Vector3.Right) * DodgeLeanMetres;

        RestartSpriteMove();
        _spriteMoveTween!.TweenProperty(_sprite, "position", _spriteRest + lean, DodgeLeanSeconds.X)
            .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
        _spriteMoveTween.TweenProperty(_sprite, "position", _spriteRest, DodgeLeanSeconds.Y)
            .SetTrans(Tween.TransitionType.Back).SetEase(Tween.EaseType.Out);
    }

    /// <summary>Kill whatever is moving %Sprite, snap back to the configured rest offset, and open a
    /// fresh handle — so a flurry jitters in place instead of stacking offsets.</summary>
    private void RestartSpriteMove()
    {
        _spriteMoveTween?.Kill();
        _sprite.Position = _spriteRest;
        _spriteMoveTween = CreateTween();
    }

    public void PlayDeath()
    {
        _dead = true;
        _hpBar.Visible = false;
        _dying.ProcessMode = ProcessModeEnum.Disabled;
        _dying.Hide();
        _plate.Retire();
        _sprite.Frozen = true;
        // The corpse tint is final, so it takes the modulate handle over from any flash still running
        // (a killing blow FlashHit is always in flight when this lands) and _dead locks out the next.
        _modulateTween?.Kill();
        _spriteMoveTween?.Kill();
        _spriteMoveTween = null;
        _sprite.Position = _spriteRest;

        _modulateTween = CreateTween();
        _modulateTween.TweenProperty(_sprite, "modulate", Delve.UI.UiColors.BoardCorpse, DeathFadeDuration);
        _ring.FadeOut(DeathRingFadeDuration);
        FadeShadow(DeathRingFadeDuration);
        ShowCrystal(false);
        _pick.SetPickable(false);
    }
}
