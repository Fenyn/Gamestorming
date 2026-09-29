using Delve.Data;
using Delve.UI;
using Godot;
using PF2e.Core;

namespace Delve.Combat;

/// <summary>
/// 2.5D combat token: the assembly that turns an <see cref="ICharacter"/> into a thing on the board.
/// It draws nothing itself. A <see cref="BillboardSpriteAnimator"/> child is the body, a
/// <see cref="TeamRing"/> child is the ground ring and turn indicator, and a <see cref="WorldHpBar"/>
/// child is the health bar, and a <see cref="UnitPickArea"/> child is the click column a picking ray
/// resolves to this unit's tile. This script adds the name label, maps the character onto those
/// children, and owns the hit, dodge, lunge and death juice. Thin presentation adapter — no rules.
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
    private UnitPickArea _pick = null!;
    private NamePlate3D _plate = null!;
    private string _letter = "";

    public NamePlate3D Plate => _plate;
    public DyingBadge Dying => _dying;
    private DyingBadge _dying = null!;

    private bool _dead;
    private float _hpBarY;
    private Vector2 _facing = Vector2.Right;

    // --- Single-writer tween handles (see the class doc TWEEN OWNERSHIP note). ---
    private Tween? _lungeTween;
    private Vector3 _lungeRest;
    private Tween? _spriteMoveTween;
    private Vector3 _spriteRest;
    private Tween? _modulateTween;

    /// <summary>The sprite's resting modulate: the active look's sprite tint.</summary>
    private Color _restTint = Colors.White;

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
        // A tile-conforming footprint belongs to discrete occupied squares, not the sliding pose.
        _ring.Visible = !moving && !_ringHidden;
    }

    /// <summary>Pop the ring and start its breath while this unit has the turn.</summary>
    private bool _active, _focused;
    public void SetActive(bool active)
    {
        _active = active;
        _ring.SetActive(active);
        ShowCrystal(active);
        RefreshSelection();
    }
    public void SetFocused(bool focused) { _focused = focused; RefreshSelection(); }
    private void RefreshSelection() => _sprite.SetHoverHighlight(_active || _focused,
        _active && _isHero ? UiColors.CharacterAccent(_character.Id) : UiColors.Accent);

    /// <summary>See <see cref="BillboardSpriteAnimator.PlaySwing"/>.</summary>
    public bool PlaySwing() => _sprite.PlaySwing();
    public bool PlayAttack(out float impactDelay) => _sprite.PlayAttack(out impactDelay);
    public PackedScene? AttackEffect => _sprite.AttackEffect;

    // ------------------------------------------------------------------ Spawn and configure

    /// <summary>
    /// Instance one token from unit_token.tscn and configure it for a character. The caller then sets
    /// the position and adds the token to the tree. Heroes pass a null <paramref name="enemyFolder"/>
    /// and resolve their sheet through <see cref="HeroSpriteMap"/>; enemies pass the folder resolved
    /// by <see cref="EnemySpriteMap"/>.
    /// </summary>
    public static UnitVisual3D Spawn(PackedScene scene, ICharacter character, string? enemyFolder = null, string letter = "")
    {
        var visual = scene.Instantiate<UnitVisual3D>();
        visual.Configure(character, enemyFolder, letter);
        return visual;
    }

    /// <summary>Per-unit setup. Call it before the node enters the tree, so <see cref="_Ready"/> has
    /// its data. Prefer <see cref="Spawn"/>, which does both.</summary>
    public void Configure(ICharacter character, string? enemyFolder = null, string letter = "")
    {
        _character = character;
        _letter = letter;
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
        _pick = GetNode<UnitPickArea>("%PickArea");
        _plate = GetNode<NamePlate3D>("%Plate");
        _dying = GetNode<DyingBadge>("%Dying");

        // Standalone (F6) with no Configure() call: leave the raw blockout token visible, do not crash.
        if (_character == null) return;

        // Team identity comes from the palette, so the board ring and the HUD's ally/enemy chips agree.
        _ring.SetTeamColor(_character.TeamId == 1 ? UiColors.Ally : UiColors.Enemy);
        _ring.SetFootprint(_character.TileWidth);
        ConfigureSprite();
        _restTint = Delve.Look.LookScene.ActiveSpriteTint;
        _sprite.Modulate = _restTint;
        ConfigureMarkers();
        // The column reaches the HP bar: the one size cue that already separates a hero from a rat.
        _pick.Configure(_character.TileWidth, _hpBarY);
        _pick.Sprite = _sprite;
        _pick.GridTile = () => _character.GridPosition;
        _hpBar.RestPosition = new Vector3(0f, _hpBarY + BoardPlateLift, 0f);
        _plate.Configure(_character.Name, _letter, UiColors.Enemy, TeamRing.RadiusPerTile * _character.TileWidth);
        _plate.Position = new Vector3(0f, _hpBarY, 0f);
        // Snap at spawn: the bar has no previous value to travel from, and a fight that opens with
        // every bar sliding in from empty reads as damage nobody dealt.
        UpdateHealthBar(instant: true);
        _character.Health.OnHealthChanged += OnLiveHealthChanged;
        _dying.Configure(_character, _hpBar.ScreenWidth, () => _hpBar.Zoom, () => _hpBar.GlobalPosition);
        _dying.Position = new Vector3(0, _hpBarY + BoardPlateLift, 0);
        _sprite.ApplyFacing();
    }

    public override void _ExitTree()
    {
        if (_character?.Health != null) _character.Health.OnHealthChanged -= OnLiveHealthChanged;
    }

    private void OnLiveHealthChanged(int current, int maximum) => UpdateHealthBar();

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

    public void DisablePicking() => _pick.SetPickable(false);
}
