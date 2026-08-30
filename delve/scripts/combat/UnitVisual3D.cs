using Delve.Data;
using Godot;
using PF2e.Core;

namespace Delve.Combat;

/// <summary>
/// 2.5D combat token: the assembly that turns an <see cref="ICharacter"/> into a thing on the board.
/// It draws nothing itself. A <see cref="BillboardSpriteAnimator"/> child is the body, a
/// <see cref="TeamRing"/> child is the ground ring and turn indicator, and a <see cref="WorldHpBar"/>
/// child is the health bar. This script adds the name label, maps the character onto those children,
/// and owns the hit, dodge, lunge and death juice. Thin presentation adapter — no rules.
///
/// The node subtree is authored in scenes/combat/unit_token.tscn. Use <see cref="Spawn"/>, which
/// configures the token before it enters the tree, as <see cref="_Ready"/> requires.
///
/// TWEEN OWNERSHIP. Several bits of juice animate the same property, so each property has exactly ONE
/// stored tween handle. Every effect that writes a property kills that handle, and snaps the property
/// back to rest, before it starts. ROOT position is <see cref="_lungeTween"/>, which GodotPresenter3D
/// also writes, so the lunge restores <see cref="_lungeRest"/> rather than the current position.
/// %Sprite local position is <see cref="_spriteMoveTween"/>, around the rest offset captured in
/// <see cref="ConfigureSprite"/>. %Sprite modulate is <see cref="_modulateTween"/>: a newcomer resets
/// to white first, so overlapping flashes cannot strand a tint, and <see cref="PlayDeath"/> latches
/// <see cref="_dead"/> so nothing overwrites the corpse tint. The children own the rest.
/// </summary>
public partial class UnitVisual3D : Node3D
{
    /// <summary>A hero <see cref="HpBarHeight"/> — also the reference silhouette every unit-sized
    /// effect is scaled against (see the presenter death-poof sizing).</summary>
    public const float HeroHpBarY = 1.75f;

    /// <summary>Clearance (m) between an enemy body top and its HP bar. With the 0.9 m rat this
    /// lands the bar where the old fixed constant put it.</summary>
    private const float EnemyHpBarLift = 0.05f;

    /// <summary>Enemy <see cref="HpBarHeight"/> when the sprite reports no body height.</summary>
    private const float EnemyHpBarFallbackY = 0.9f;

    /// <summary>Height (m) of the name label above the HP bar.</summary>
    private const float NameLift = 0.22f;

    /// <summary>Ring colour of team 1, the player side.</summary>
    [Export] public Color Team1Color { get; set; } = new(0.35f, 0.6f, 0.95f);

    /// <summary>Ring colour of team 2, the enemy side.</summary>
    [Export] public Color Team2Color { get; set; } = new(0.85f, 0.4f, 0.35f);

    /// <summary>How long the corpse tint takes.</summary>
    [Export] public float DeathFadeDuration { get; set; } = 0.5f;

    /// <summary>How long the ring takes to fade away on death.</summary>
    [Export] public float DeathRingFadeDuration { get; set; } = 0.4f;

    private ICharacter _character = null!;
    private string? _enemyFolder;
    private bool _isHero;

    private BillboardSpriteAnimator _sprite = null!;
    private TeamRing _ring = null!;
    private WorldHpBar _hpBar = null!;
    private Label3D _name = null!;

    private bool _dead;
    private float _hpBarY;
    private Vector2 _facing = Vector2.Right;

    // --- Single-writer tween handles (see the class doc TWEEN OWNERSHIP note). ---
    private Tween? _lungeTween;
    private Vector3 _lungeRest;
    private Tween? _spriteMoveTween;
    private Vector3 _spriteRest;
    private Tween? _modulateTween;

    /// <summary>See <see cref="BillboardSpriteAnimator.SwingImpactDelay"/>.</summary>
    public static float SwingImpactDelay => BillboardSpriteAnimator.SwingImpactDelay;

    /// <summary>Height (m) above this unit feet at which its HP bar floats — the one size cue that
    /// separates a ~1.6 m hero from a ~0.7 m rat, so effects placed against the unit silhouette
    /// (impact sparks, damage popups, death poofs) scale off it.</summary>
    public float HpBarHeight => _hpBarY;

    public ICharacter Character => _character;

    /// <summary>Logical facing in grid space (x along world X, y along world Z). Set by the presenter.</summary>
    public Vector2 Facing
    {
        get => _facing;
        set
        {
            _facing = value;
            if (_sprite != null) _sprite.Facing = value;
        }
    }

    /// <summary>Heroes play their walk cycle while true, else the static stand frame.</summary>
    public void SetMoving(bool moving)
    {
        if (_sprite == null) return;
        _sprite.SetMoving(moving);
    }

    /// <summary>Pop the ring and start its breath while this unit has the turn.</summary>
    public void SetActive(bool active) => _ring.SetActive(active);

    /// <summary>See <see cref="BillboardSpriteAnimator.PlaySwing"/>.</summary>
    public bool PlaySwing() => _sprite.PlaySwing();

    // ------------------------------------------------------------------ Spawn and configure

    /// <summary>
    /// Instance one token from unit_token.tscn and configure it for a character. The caller then sets
    /// the position and adds the token to the tree. Heroes pass a null <paramref name="enemyFolder"/>
    /// and resolve their sheet through <see cref="HeroSpriteMap"/>; enemies pass the folder resolved
    /// by <see cref="EnemySpriteMap"/>.
    /// </summary>
    public static UnitVisual3D Spawn(PackedScene scene, ICharacter character, string? enemyFolder = null)
    {
        var visual = scene.Instantiate<UnitVisual3D>();
        visual.Configure(character, enemyFolder);
        return visual;
    }

    /// <summary>Per-unit setup. Call it before the node enters the tree, so <see cref="_Ready"/> has
    /// its data. Prefer <see cref="Spawn"/>, which does both.</summary>
    public void Configure(ICharacter character, string? enemyFolder = null)
    {
        _character = character;
        _isHero = character.CreatureStats == null;
        // Heroes start facing the enemy side; team 1 (left) looks +X, team 2 (right) looks -X.
        Facing = character.TeamId == 1 ? Vector2.Right : Vector2.Left;
        _enemyFolder = enemyFolder;
    }

    public override void _Ready()
    {
        _sprite = GetNode<BillboardSpriteAnimator>("%Sprite");
        _ring = GetNode<TeamRing>("%Ring");
        _hpBar = GetNode<WorldHpBar>("%HpBar");
        _name = GetNode<Label3D>("%Name");

        // Standalone (F6) with no Configure() call: leave the raw blockout token visible, do not crash.
        if (_character == null) return;

        _ring.SetTeamColor(_character.TeamId == 1 ? Team1Color : Team2Color);
        ConfigureSprite();
        _hpBar.Position = new Vector3(0f, _hpBarY, 0f);
        _name.Text = _character.Name;
        _name.Position = new Vector3(0f, _hpBarY + NameLift, 0f);
        // Snap at spawn: the bar has no previous value to travel from, and a fight that opens with
        // every bar sliding in from empty reads as damage nobody dealt.
        UpdateHealthBar(instant: true);
        _sprite.ApplyFacing();
    }

    private void ConfigureSprite()
    {
        _sprite.Facing = _facing;
        if (_isHero)
        {
            _sprite.ConfigureHero(HeroSpriteMap.FolderFor(_character.Id));
            _hpBarY = HeroHpBarY;
        }
        else
        {
            _sprite.ConfigureEnemy(_enemyFolder ?? EnemySpriteMap.DefaultFolder);
            // Bar height follows the body, so a Large placeholder's bar sits above its head.
            _hpBarY = _sprite.BodyHeight > 0f
                ? _sprite.BodyHeight + EnemyHpBarLift
                : EnemyHpBarFallbackY;
        }

        // Rest pose for every %Sprite-position effect (hurt shake, dodge lean) to snap back to.
        _spriteRest = _sprite.Position;
    }

    // ------------------------------------------------------------------ Presenter API

    /// <param name="instant">Snap instead of travelling — used at spawn, where there is no previous
    /// value to animate from.</param>
    public void UpdateHealthBar(bool instant = false)
    {
        if (_character.Health == null) return;
        int max = _character.Health.MaxHP;
        _hpBar.SetRatio(max > 0 ? (float)_character.Health.CurrentHP / max : 0f, instant);
    }

    public void FlashHit() => FlashModulate(new Color(1.6f, 0.6f, 0.6f), 0.05f, 0.18f);

    public void FlashShield() => FlashModulate(new Color(0.7f, 0.85f, 1.4f), 0.1f, 0.25f);

    /// <summary>Tint %Sprite and return it to white, through the single modulate handle. Dead units
    /// are immune, because the <see cref="PlayDeath"/> corpse tint is final.</summary>
    private void FlashModulate(Color tint, float inDuration, float outDuration)
    {
        if (_dead) return;
        _modulateTween?.Kill();
        _sprite.Modulate = Colors.White;
        _modulateTween = CreateTween();
        _modulateTween.TweenProperty(_sprite, "modulate", tint, inDuration);
        _modulateTween.TweenProperty(_sprite, "modulate", Colors.White, outDuration);
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
        const float amp = 0.05f;
        _spriteMoveTween!.TweenProperty(_sprite, "position", _spriteRest + new Vector3(amp, 0f, 0f), 0.05f);
        _spriteMoveTween.TweenProperty(_sprite, "position", _spriteRest + new Vector3(-amp * 0.8f, 0f, 0f), 0.05f);
        _spriteMoveTween.TweenProperty(_sprite, "position", _spriteRest, 0.05f);
    }

    /// <summary>Duck away from a whiffed attack: %Sprite leans out along the horizontal direction of
    /// <paramref name="awayDir"/> and springs back. World-space rather than sprite-local, so the duck
    /// reads as "away from the attacker" from any camera angle.</summary>
    public void PlayDodgeLean(Vector3 awayDir)
    {
        if (_dead) return;
        var lean = new Vector3(awayDir.X, 0f, awayDir.Z);
        lean = lean.LengthSquared() > 0.0001f ? lean.Normalized() * 0.12f : new Vector3(0.12f, 0f, 0f);

        RestartSpriteMove();
        _spriteMoveTween!.TweenProperty(_sprite, "position", _spriteRest + lean, 0.07f)
            .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
        _spriteMoveTween.TweenProperty(_sprite, "position", _spriteRest, 0.11f)
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
        _sprite.Frozen = true;
        // The corpse tint is final, so it takes the modulate handle over from any flash still running
        // (a killing blow FlashHit is always in flight when this lands) and _dead locks out the next.
        _modulateTween?.Kill();
        _spriteMoveTween?.Kill();
        _spriteMoveTween = null;
        _sprite.Position = _spriteRest;

        _modulateTween = CreateTween();
        _modulateTween.TweenProperty(_sprite, "modulate", new Color(0.4f, 0.4f, 0.4f, 0.25f), DeathFadeDuration);
        _ring.FadeOut(DeathRingFadeDuration);
    }
}
