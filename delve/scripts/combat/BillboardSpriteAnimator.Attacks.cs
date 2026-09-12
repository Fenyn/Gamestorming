using Godot;

namespace Delve.Combat;

public partial class BillboardSpriteAnimator
{
    private bool _enemyAttacking;
    public PackedScene? AttackEffect => _enemyDefinition?.AttackEffect;

    /// <summary>Start the configured strike and return the time to its contact frame.</summary>
    public bool PlayAttack(out float impactDelay)
    {
        impactDelay = 0;
        if (Frozen) return false;
        if (_isHero)
        {
            if (!PlaySwing()) return false;
            impactDelay = SwingImpactDelay;
            return true;
        }
        var definition = _enemyDefinition;
        var frames = definition?.Frames;
        if (frames == null || definition == null) return false;
        var name = definition.AttackAnimation;
        if (!frames.HasAnimation(name) || frames.GetAnimationLoop(name)
            || frames.GetAnimationSpeed(name) <= 0 || definition.AttackImpactFrame < 0
            || definition.AttackImpactFrame >= frames.GetFrameCount(name)) return false;
        double delay = 0;
        for (int i = 0; i < definition.AttackImpactFrame; i++) delay += frames.GetFrameDuration(name, i);
        impactDelay = (float)(delay / frames.GetAnimationSpeed(name));
        // A new strike restarts its wind-up, even if the previous recovery is still playing.
        _enemyAttacking = _enemyAnimation.Play(frames, name);
        Texture = _enemyAnimation.Texture;
        return _enemyAttacking;
    }
}
