using Delve.Data;
using Godot;
using PF2e.Core;

namespace Delve.Combat;

/// <summary>
/// 2.5D combat token: a billboarded 2D sprite standing on a grid square in the 3D board. Heroes use
/// a baked Mana Seed "page 1" sheet (see <see cref="HeroSpriteMap"/>): 4 facings (S/N/E/W), a single
/// static stand frame while idle and a 6-frame walk cycle while moving, with camera-relative facing
/// selection; enemies use a side-view sheet (currently only rats — see <see cref="EnemySpriteMap"/>)
/// that cycles idle frames and flips horizontally to match its logical facing as seen by the camera.
/// Carries a Label3D name, a billboarded HP bar and a team-colored ground ring that doubles as the
/// current-turn indicator.
///
/// The static node subtree (sprite, ring, HP bar, name) is authored in scenes/combat/unit_token.tscn;
/// this script only fetches those nodes in _Ready and applies the per-unit runtime configuration
/// (sprite texture/frames/size, team-tinted materials, bar/name height) set through <see cref="Configure"/>.
/// Thin presentation adapter — no rules.
///
/// TWEEN OWNERSHIP. Several bits of juice animate the same properties, so each property has exactly
/// ONE stored tween handle that every effect writing it kills (and snaps back to rest) before
/// starting — the <see cref="Delve.Territory.ResourceNodeView.PlayHitReaction"/> pattern:
///  • ROOT position — <see cref="_lungeTween"/> (<see cref="FlashAttack"/>). Also written by
///    GodotPresenter3D.AnimateSegment's movement tween, which is why the lunge restores
///    <see cref="_lungeRest"/> rather than assuming the current position is rest.
///  • %Sprite local position — <see cref="_spriteMoveTween"/> (<see cref="PlayHurtShake"/>,
///    <see cref="PlayDodgeLean"/>), around the rest offset captured in <see cref="ConfigureSprite"/>.
///  • %Sprite modulate — <see cref="_modulateTween"/> (<see cref="FlashHit"/>,
///    <see cref="FlashShield"/>, <see cref="PlayDeath"/>). A hit landing during a shield flash used
///    to leave the loser's end-colour painted on; now the newcomer resets to white first, and
///    <see cref="PlayDeath"/> additionally latches <see cref="_dead"/> so nothing can overwrite the
///    corpse tint afterwards.
///  • %Ring scale/colour — <see cref="_ringTween"/> (pop-in) plus <see cref="_ringPulseTween"/>
///    (the looping active-turn pulse it hands off to); <see cref="SetActive"/> kills both.
///  • %HpFill scale/position/colour — <see cref="_hpTween"/>.
/// %Sprite's Frame/Texture stay owned by the per-frame animation loop in <see cref="_Process"/>,
/// which a running <see cref="_swing"/> clip outranks exactly like the cozy avatar's tool swing.
/// </summary>
public partial class UnitVisual3D : Node3D
{
    // Hero sheet anatomy comes from ManaSeedSheet (shared with the cozy avatar renderer).
    /// <summary>Pixels between the cell's bottom edge and the character's feet. Measured on the
    /// baked sheets: the 32px body occupies cell rows 12-43, so the feet sit 20px above the bottom.</summary>
    private const int HeroFootMarginPx = 20;

    // --- Sizing (1 tile = 1 m). ---
    private const float HeroPixelSize = 0.05f;    // ~30 px chibi body -> ~1.5 m
    private const float RatPixelSize = 0.02f;     // -> ~0.7 m tall rat
    private const float AnimFrameTime = 1f / 6f;  // rat idle fps

    /// <summary>A hero's <see cref="HpBarHeight"/> — also the reference silhouette every unit-sized
    /// effect is scaled against (see the presenter's death-poof sizing).</summary>
    public const float HeroHpBarY = 1.75f;

    /// <summary>A rat's <see cref="HpBarHeight"/>.</summary>
    private const float RatHpBarY = 0.9f;

    private ICharacter _character = null!;
    private bool _isHero;
    private Color _teamColor;
    private Camera3D? _camera;

    private Sprite3D _sprite = null!;
    private Texture2D[] _ratFrames = System.Array.Empty<Texture2D>();
    private MeshInstance3D _ring = null!;
    private StandardMaterial3D _ringMat = null!;
    private Node3D _hpBar = null!;
    private MeshInstance3D _hpBarBg = null!;
    private MeshInstance3D _hpFill = null!;
    private StandardMaterial3D _hpFillMat = null!;
    private Label3D _name = null!;

    private float _animTimer;
    private int _animFrame;
    private bool _active;
    private bool _dead;
    private float _hpBarY;

    // --- Single-writer tween handles (see the class doc's TWEEN OWNERSHIP note). ---
    private Tween? _lungeTween;
    private Vector3 _lungeRest;
    private Tween? _spriteMoveTween;
    private Vector3 _spriteRest;
    private Tween? _modulateTween;
    private Tween? _hpTween;
    private Tween? _ringTween;
    private Tween? _ringPulseTween;

    /// <summary>The hero swing clip in flight (<see cref="PlaySwing"/>), or idle. While it plays it
    /// OUTRANKS the walk/stand frame selection in <see cref="_Process"/> — the same rule bulwark's
    /// cozy avatar tool swing follows (PlayerController).</summary>
    private readonly SpriteActionPlayer _swing = new();

    /// <summary>Hero movement page, restored when a swing clip ends. Null for enemies.</summary>
    private Texture2D? _walkSheet;

    /// <summary>Hero axe-swing page (<see cref="ManaSeedSheet.AxePage"/>), preloaded at configure time
    /// so the first strike of a fight does not hitch on a disk read. Null for enemies.</summary>
    private Texture2D? _swingSheet;

    /// <summary>
    /// Seconds a caller must wait after <see cref="PlaySwing"/> for the swing's STRIKE frame to be on
    /// screen — the presenter holds its AttackRolled gate this long so the damage spark and number
    /// land on the frame the axe bites rather than before it.
    /// </summary>
    public static float SwingImpactDelay => ManaSeedSheet.Chop.TimeToImpact;

    /// <summary>Height (m) above this unit's feet at which its HP bar floats — the one size cue that
    /// distinguishes a ~1.6 m hero from a ~0.7 m rat, so effects that must be placed against the
    /// unit's silhouette (impact sparks, damage popups, death poofs) scale off it.</summary>
    public float HpBarHeight => _hpBarY;

    /// <summary>Logical facing in grid space (x along world X, y along world Z). Set by the presenter.</summary>
    public Vector2 Facing { get; set; } = Vector2.Right;

    private bool _moving;

    /// <summary>Heroes play their walk cycle while true, else the static stand frame. Set by the presenter.</summary>
    public void SetMoving(bool moving)
    {
        if (_moving == moving) return;
        _moving = moving;
        _animFrame = 0;
        _animTimer = 0f;
    }

    public ICharacter Character => _character;

    /// <summary>
    /// Per-unit setup for a token instanced from unit_token.tscn. Must be called before the node
    /// enters the tree (before _Ready) so the runtime configuration has its data. Heroes pass a null
    /// <paramref name="enemyFolder"/> and resolve their sheet via <see cref="HeroSpriteMap"/>; enemies
    /// pass the folder resolved by <see cref="EnemySpriteMap"/>.
    /// </summary>
    public void Configure(ICharacter character, string? enemyFolder = null)
    {
        _character = character;
        _isHero = character.CreatureStats == null;
        _teamColor = character.TeamId == 1
            ? new Color(0.35f, 0.6f, 0.95f)
            : new Color(0.85f, 0.4f, 0.35f);
        // Heroes start facing the enemy side; team 1 (left) looks +X, team 2 (right) looks -X.
        Facing = character.TeamId == 1 ? Vector2.Right : Vector2.Left;
        _enemyFolder = enemyFolder;
    }

    private string? _enemyFolder;

    public void SetCamera(Camera3D camera) => _camera = camera;

    public override void _Ready()
    {
        // The static node subtree lives in unit_token.tscn; grab it, then apply per-unit runtime state.
        _sprite = GetNode<Sprite3D>("%Sprite");
        _ring = GetNode<MeshInstance3D>("%Ring");
        _hpBar = GetNode<Node3D>("%HpBar");
        _hpBarBg = GetNode<MeshInstance3D>("%HpBarBg");
        _hpFill = GetNode<MeshInstance3D>("%HpFill");
        _name = GetNode<Label3D>("%Name");

        // Standalone (F6) with no Configure() call: leave the raw blockout token visible, don't crash.
        if (_character == null) return;

        BuildMaterials();
        ConfigureSprite();
        ConfigureHpBar();
        ConfigureName();
        // Snap at spawn: the bar has no previous value to travel from, and a fight that opens with
        // every bar sliding in from empty reads as damage nobody dealt.
        UpdateHealthBar(instant: true);
        ApplyFacingFrame();
    }

    // ------------------------------------------------------------------ Configure (runtime)

    // Team-tinted, per-instance materials stay in code (SetActive, the health-bar color, and the death
    // tween all mutate them), assigned as overrides on the scene's meshes so the shared scene
    // sub-resources never diverge across tokens.
    private void BuildMaterials()
    {
        _ringMat = new StandardMaterial3D
        {
            ShadingMode = BaseMaterial3D.ShadingModeEnum.Unshaded,
            Transparency = BaseMaterial3D.TransparencyEnum.Alpha,
            AlbedoColor = _teamColor with { A = 0.45f },
        };
        _ring.MaterialOverride = _ringMat;

        _hpBarBg.MaterialOverride = BarMaterial(new Color(0.08f, 0.08f, 0.1f, 0.9f));
        _hpFillMat = BarMaterial(new Color(0.25f, 0.8f, 0.25f));
        _hpFill.MaterialOverride = _hpFillMat;
    }

    private void ConfigureSprite()
    {
        if (_isHero)
        {
            string folder = HeroSpriteMap.FolderFor(_character.Id);
            _walkSheet = GD.Load<Texture2D>($"{folder}/{ManaSeedSheet.WalkPage}.png");
            // The swing page is a plain Texture write away from the walk page (every Mana Seed page
            // shares the 8x8 anatomy and facing-row order), so it only has to be resident.
            _swingSheet = GD.Load<Texture2D>($"{folder}/{ManaSeedSheet.Chop.Page}.png");
            _sprite.Texture = _walkSheet;
            _sprite.Hframes = ManaSeedSheet.Columns;
            _sprite.Vframes = 8;
            _sprite.PixelSize = HeroPixelSize;
            // Cell center sits (32 - foot margin) px above the feet; lift by that to plant feet at y=0.
            float centerAboveFeet = (ManaSeedSheet.CellPx * 0.5f - HeroFootMarginPx) * HeroPixelSize;
            _sprite.Position = new Vector3(0f, centerAboveFeet, 0f);
            _hpBarY = HeroHpBarY;
        }
        else
        {
            LoadRatFrames();
            if (_ratFrames.Length > 0) _sprite.Texture = _ratFrames[0];
            _sprite.PixelSize = RatPixelSize;
            float h = (_sprite.Texture?.GetHeight() ?? 44) * RatPixelSize;
            _sprite.Position = new Vector3(0f, h * 0.5f - 0.08f, 0f);
            _hpBarY = RatHpBarY;
        }

        // Rest pose for every %Sprite-position effect (hurt shake, dodge lean) to snap back to.
        _spriteRest = _sprite.Position;
    }

    private void LoadRatFrames()
    {
        string folder = _enemyFolder ?? EnemySpriteMap.DefaultFolder;
        var frames = new System.Collections.Generic.List<Texture2D>(8);
        for (int i = 1; i <= 8; i++)
        {
            var tex = GD.Load<Texture2D>($"{folder}/idle_{i}.png");
            if (tex != null) frames.Add(tex);
        }
        _ratFrames = frames.ToArray();
    }

    private void ConfigureHpBar() => _hpBar.Position = new Vector3(0f, _hpBarY, 0f);

    private void ConfigureName()
    {
        _name.Text = _character.Name;
        _name.Position = new Vector3(0f, _hpBarY + 0.22f, 0f);
    }

    private static StandardMaterial3D BarMaterial(Color color) => new()
    {
        ShadingMode = BaseMaterial3D.ShadingModeEnum.Unshaded,
        Transparency = BaseMaterial3D.TransparencyEnum.Alpha,
        AlbedoColor = color,
        CullMode = BaseMaterial3D.CullModeEnum.Disabled,
        NoDepthTest = true,
    };

    // ------------------------------------------------------------------ Per-frame

    public override void _Process(double delta)
    {
        // Standalone (F6) blockout: no unit configured, so there is nothing to animate.
        if (_character == null) return;

        // A hero swing clip outranks walk and stand until it finishes — the frame loop below would
        // otherwise overwrite the clip's cell with a stand/walk cell every tick. Its impact edge is
        // not consumed here: the presenter paces the world effect off SwingImpactDelay so the number
        // and the spark are gated in the event stream rather than fired from a render callback.
        if (_swing.IsPlaying)
        {
            _swing.Tick((float)delta);
            if (_swing.IsPlaying)
            {
                if (!_dead) _sprite.Frame = _swing.SheetFrame(FacingRow());
                BillboardHpBar();
                return;
            }
            // Finished this very tick: hand the sprite back rather than draw one frame of a dead clip
            // (the walk page's cells at those indices mean something else entirely).
            EndSwing();
        }

        // Animation clock: heroes only animate while walking; rats idle-cycle continuously.
        float frameTime = _isHero ? ManaSeedSheet.WalkFrameTime : AnimFrameTime;
        _animTimer += (float)delta;
        if (_animTimer >= frameTime)
        {
            _animTimer -= frameTime;
            // 24 is divisible by both the hero-walk (6) and rat (8) frame counts.
            _animFrame = (_animFrame + 1) % 24;
            if (!_dead) AdvanceAnimFrame();
        }

        if (!_dead) ApplyFacingFrame();

        BillboardHpBar();
    }

    /// <summary>Billboard the HP bar to face the camera (full).</summary>
    private void BillboardHpBar()
    {
        if (_camera != null && IsInstanceValid(_camera))
            _hpBar.GlobalBasis = _camera.GlobalBasis;
    }

    private void AdvanceAnimFrame()
    {
        // Hero frames are fully resolved in ApplyFacingFrame (stand vs walk); nothing to do here.
        if (!_isHero && _ratFrames.Length > 0)
        {
            _sprite.Texture = _ratFrames[_animFrame % _ratFrames.Length];
        }
    }

    /// <summary>Logical <see cref="Facing"/> resolved against the camera: X = screen right, Y = into
    /// the screen (away from the viewer). The one place the camera-relative projection lives, shared
    /// by the walk/stand frame picker and the swing clip's row lookup.</summary>
    private Vector2 ScreenFacing()
    {
        // Camera basis projected onto the ground plane.
        Vector3 right = Vector3.Right, fwd = Vector3.Forward;
        if (_camera != null && IsInstanceValid(_camera))
        {
            var basis = _camera.GlobalBasis;
            fwd = -basis.Z; fwd.Y = 0f; fwd = fwd.LengthSquared() > 0.0001f ? fwd.Normalized() : Vector3.Forward;
            right = basis.X; right.Y = 0f; right = right.LengthSquared() > 0.0001f ? right.Normalized() : Vector3.Right;
        }

        Vector3 facing = new Vector3(Facing.X, 0f, Facing.Y);
        if (facing.LengthSquared() < 0.0001f) facing = Vector3.Right;
        facing = facing.Normalized();

        return new Vector2(facing.Dot(right), facing.Dot(fwd));
    }

    /// <summary>4-direction snap on the dominant screen axis: S = toward viewer, N = away, E = screen
    /// right, W = screen left (<see cref="ManaSeedSheet"/> facing rows).</summary>
    private int FacingRow()
    {
        Vector2 s = ScreenFacing();
        return Mathf.Abs(s.X) >= Mathf.Abs(s.Y)
            ? (s.X >= 0f ? ManaSeedSheet.RowEast : ManaSeedSheet.RowWest)
            : (s.Y >= 0f ? ManaSeedSheet.RowNorth : ManaSeedSheet.RowSouth);
    }

    /// <summary>Pick the sprite row (hero) or flip (rat) from facing as seen through the camera.</summary>
    private void ApplyFacingFrame()
    {
        if (_isHero)
        {
            int dir = FacingRow();
            _sprite.Frame = _moving
                ? (ManaSeedSheet.WalkRowOffset + dir) * ManaSeedSheet.Columns + _animFrame % ManaSeedSheet.WalkFrames
                : dir * ManaSeedSheet.Columns;
        }
        else
        {
            // Rat art faces screen-right by default; flip when logical facing points screen-left.
            float sx = ScreenFacing().X;
            if (sx < -0.1f) _sprite.FlipH = true;
            else if (sx > 0.1f) _sprite.FlipH = false;
        }
    }

    // ------------------------------------------------------------------ Presenter API

    // Active-turn ring: pops past its resting size, settles, then breathes. RingPop overshoots
    // RingActive so the turn handover reads as a beat rather than a state change.
    private static readonly Vector3 RingActive = new(1.18f, 1f, 1.18f);
    private static readonly Vector3 RingPop = new(1.34f, 1f, 1.34f);
    private static readonly Vector3 RingPulse = new(1.26f, 1f, 1.26f);

    public void SetActive(bool active)
    {
        _active = active;
        _ringMat.AlbedoColor = active
            ? new Color(1f, 0.9f, 0.3f, 0.9f)
            : _teamColor with { A = 0.45f };

        // One writer at a time for %Ring's scale: kill whichever of the two is live, snap to rest.
        _ringTween?.Kill();
        _ringTween = null;
        _ringPulseTween?.Kill();
        _ringPulseTween = null;

        if (!active)
        {
            _ring.Scale = Vector3.One;
            return;
        }

        _ring.Scale = Vector3.One;
        _ringTween = CreateTween();
        _ringTween.TweenProperty(_ring, "scale", RingPop, 0.11f)
            .SetTrans(Tween.TransitionType.Back).SetEase(Tween.EaseType.Out);
        _ringTween.TweenProperty(_ring, "scale", RingActive, 0.09f)
            .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
        // Hands off to the looping breath. Killing _ringTween cancels this callback, so a deactivate
        // mid-pop can never start a pulse on a unit whose turn has already passed.
        _ringTween.TweenCallback(Callable.From(StartRingPulse));
    }

    /// <summary>The active unit's gentle continuous breath, started by <see cref="SetActive"/>'s pop
    /// and killed by its deactivate. Its own handle so the pop tween is never killed from inside its
    /// own finished-callback.</summary>
    private void StartRingPulse()
    {
        if (!_active) return;
        _ringPulseTween?.Kill();
        _ringPulseTween = CreateTween();
        _ringPulseTween.SetLoops();
        _ringPulseTween.TweenProperty(_ring, "scale", RingPulse, 0.65f)
            .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.InOut);
        _ringPulseTween.TweenProperty(_ring, "scale", RingActive, 0.65f)
            .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.InOut);
    }

    /// <summary>Bar width in metres (the %HpFill quad's authored size), the span the fill scales across.</summary>
    private const float HpBarWidth = 0.8f;

    /// <summary>How long the bar takes to travel to a new HP value. Short enough to finish inside the
    /// hit's own beat, long enough that the drop reads as a drop rather than a jump cut.</summary>
    private const float HpTweenDuration = 0.2f;

    /// <param name="instant">Snap instead of travelling — used at spawn, where there is no previous
    /// value to animate from.</param>
    public void UpdateHealthBar(bool instant = false)
    {
        if (_character.Health == null) return;
        int cur = _character.Health.CurrentHP;
        int max = _character.Health.MaxHP;
        float ratio = max > 0 ? Mathf.Clamp((float)cur / max, 0f, 1f) : 0f;

        // Never scale a mesh through a literal zero axis (renderer det==0 on a singular transform) —
        // an emptied bar rests one thousandth wide, which is invisible at any gameplay distance.
        var scale = new Vector3(Mathf.Max(ratio, 0.001f), 1f, 1f);
        var position = new Vector3(-HpBarWidth * 0.5f + HpBarWidth * ratio * 0.5f, 0f, 0.001f);
        Color color = ratio > 0.6f ? new Color(0.25f, 0.8f, 0.25f)
            : ratio > 0.3f ? new Color(0.9f, 0.8f, 0.15f)
            : new Color(0.9f, 0.25f, 0.25f);

        _hpTween?.Kill();
        _hpTween = null;

        if (instant)
        {
            _hpFill.Scale = scale;
            _hpFill.Position = position;
            _hpFillMat.AlbedoColor = color;
            return;
        }

        _hpTween = CreateTween();
        _hpTween.SetParallel(true);
        _hpTween.TweenProperty(_hpFill, "scale", scale, HpTweenDuration)
            .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
        _hpTween.TweenProperty(_hpFill, "position", position, HpTweenDuration)
            .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
        _hpTween.TweenProperty(_hpFillMat, "albedo_color", color, HpTweenDuration);
    }

    public void FlashHit() => FlashModulate(new Color(1.6f, 0.6f, 0.6f), 0.05f, 0.18f);

    public void FlashShield() => FlashModulate(new Color(0.7f, 0.85f, 1.4f), 0.1f, 0.25f);

    /// <summary>Tint %Sprite and return it to white, through the single modulate handle. A flash
    /// arriving on top of another kills it and resets to white first, so overlapping effects can no
    /// longer strand a half-faded tint. Dead units are immune — <see cref="PlayDeath"/>'s corpse tint
    /// is final.</summary>
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
    /// are caller-set so a hero, whose swing art already carries the strike, can lean a short way over
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

        var lunge = new Vector3(Facing.X, 0f, Facing.Y);
        if (lunge.LengthSquared() > 0.0001f) lunge = lunge.Normalized() * distance;
        _lungeRest = Position;
        _lungeTween = CreateTween();
        _lungeTween.TweenProperty(this, "position", _lungeRest + lunge, outDuration)
            .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
        _lungeTween.TweenProperty(this, "position", _lungeRest, backDuration)
            .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.InOut);
    }

    /// <summary>
    /// Start the hero axe-swing clip (<see cref="ManaSeedSheet.Chop"/> on the character's own
    /// <see cref="ManaSeedSheet.AxePage"/>). No-op for enemies (rats have no swing art), for a dead
    /// unit, and for a hero whose sheet set failed to load. The caller waits
    /// <see cref="SwingImpactDelay"/> for the strike frame; the follow-through then plays out on its
    /// own and hands the sprite back to walk/stand in <see cref="_Process"/>.
    /// </summary>
    /// <returns>True if a clip actually started, so a caller can fall back to the plain lunge.</returns>
    public bool PlaySwing()
    {
        if (!_isHero || _dead || _swingSheet == null) return false;
        _sprite.Texture = _swingSheet;
        _swing.Play(ManaSeedSheet.Chop);
        _sprite.Frame = _swing.SheetFrame(FacingRow());
        return true;
    }

    /// <summary>Return the sprite to the movement page once the clip ends. Only Texture and Frame are
    /// ever written here — every page shares the sheet anatomy, so nothing else has to change.</summary>
    private void EndSwing()
    {
        _swing.Stop();
        if (_walkSheet != null) _sprite.Texture = _walkSheet;
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

    /// <summary>Duck away from a whiffed attack: %Sprite leans out along <paramref name="awayDir"/>'s
    /// horizontal direction and springs back. World-space rather than sprite-local so the duck reads
    /// as "away from the attacker" from any camera angle.</summary>
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
        // The corpse tint is final, so it takes the modulate handle over from any flash still running
        // (a killing blow's FlashHit is always in flight when this lands) and _dead locks out the next.
        _modulateTween?.Kill();
        _spriteMoveTween?.Kill();
        _spriteMoveTween = null;
        _sprite.Position = _spriteRest;

        _modulateTween = CreateTween();
        _modulateTween.SetParallel(true);
        _modulateTween.TweenProperty(_sprite, "modulate", new Color(0.4f, 0.4f, 0.4f, 0.25f), 0.5f);
        _modulateTween.TweenProperty(_ringMat, "albedo_color", _teamColor with { A = 0f }, 0.4f);
    }
}
