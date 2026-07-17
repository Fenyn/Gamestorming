using Bulwark.Data;
using Godot;
using PF2e.Core;

namespace Bulwark.Combat;

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
        UpdateHealthBar();
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
            _sprite.Texture = GD.Load<Texture2D>($"{folder}/p1.png");
            _sprite.Hframes = ManaSeedSheet.Columns;
            _sprite.Vframes = 8;
            _sprite.PixelSize = HeroPixelSize;
            // Cell center sits (32 - foot margin) px above the feet; lift by that to plant feet at y=0.
            float centerAboveFeet = (ManaSeedSheet.CellPx * 0.5f - HeroFootMarginPx) * HeroPixelSize;
            _sprite.Position = new Vector3(0f, centerAboveFeet, 0f);
            _hpBarY = 1.75f;
        }
        else
        {
            LoadRatFrames();
            if (_ratFrames.Length > 0) _sprite.Texture = _ratFrames[0];
            _sprite.PixelSize = RatPixelSize;
            float h = (_sprite.Texture?.GetHeight() ?? 44) * RatPixelSize;
            _sprite.Position = new Vector3(0f, h * 0.5f - 0.08f, 0f);
            _hpBarY = 0.9f;
        }
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

        // Billboard the HP bar to face the camera (full).
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

    /// <summary>Pick the sprite row (hero) or flip (rat) from facing as seen through the camera.</summary>
    private void ApplyFacingFrame()
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

        float sx = facing.Dot(right);      // + = screen right
        float sy = facing.Dot(fwd);        // + = into screen (away from viewer)

        if (_isHero)
        {
            // 4-direction snap on the dominant screen axis: S = toward viewer, N = away,
            // E = screen right, W = screen left (ManaSeedSheet facing rows).
            int dir = Mathf.Abs(sx) >= Mathf.Abs(sy)
                ? (sx >= 0f ? ManaSeedSheet.RowEast : ManaSeedSheet.RowWest)
                : (sy >= 0f ? ManaSeedSheet.RowNorth : ManaSeedSheet.RowSouth);

            _sprite.Frame = _moving
                ? (ManaSeedSheet.WalkRowOffset + dir) * ManaSeedSheet.Columns + _animFrame % ManaSeedSheet.WalkFrames
                : dir * ManaSeedSheet.Columns;
        }
        else
        {
            // Rat art faces screen-right by default; flip when logical facing points screen-left.
            if (sx < -0.1f) _sprite.FlipH = true;
            else if (sx > 0.1f) _sprite.FlipH = false;
        }
    }

    // ------------------------------------------------------------------ Presenter API

    public void SetActive(bool active)
    {
        _active = active;
        _ringMat.AlbedoColor = active
            ? new Color(1f, 0.9f, 0.3f, 0.9f)
            : _teamColor with { A = 0.45f };
        _ring.Scale = active ? new Vector3(1.18f, 1f, 1.18f) : Vector3.One;
    }

    public void UpdateHealthBar()
    {
        if (_character.Health == null) return;
        int cur = _character.Health.CurrentHP;
        int max = _character.Health.MaxHP;
        float ratio = max > 0 ? Mathf.Clamp((float)cur / max, 0f, 1f) : 0f;

        const float w = 0.8f;
        _hpFill.Scale = new Vector3(ratio, 1f, 1f);
        _hpFill.Position = new Vector3(-w * 0.5f + w * ratio * 0.5f, 0f, 0.001f);
        _hpFillMat.AlbedoColor = ratio > 0.6f ? new Color(0.25f, 0.8f, 0.25f)
            : ratio > 0.3f ? new Color(0.9f, 0.8f, 0.15f)
            : new Color(0.9f, 0.25f, 0.25f);
    }

    public void FlashHit()
    {
        var tween = CreateTween();
        tween.TweenProperty(_sprite, "modulate", new Color(1.6f, 0.6f, 0.6f), 0.05f);
        tween.TweenProperty(_sprite, "modulate", Colors.White, 0.18f);
    }

    public void FlashAttack()
    {
        var lunge = new Vector3(Facing.X, 0f, Facing.Y);
        if (lunge.LengthSquared() > 0.0001f) lunge = lunge.Normalized() * 0.2f;
        var origin = Position;
        var tween = CreateTween();
        tween.TweenProperty(this, "position", origin + lunge, 0.05f);
        tween.TweenProperty(this, "position", origin, 0.08f);
    }

    public void FlashShield()
    {
        var tween = CreateTween();
        tween.TweenProperty(_sprite, "modulate", new Color(0.7f, 0.85f, 1.4f), 0.1f);
        tween.TweenProperty(_sprite, "modulate", Colors.White, 0.25f);
    }

    public void PlayDeath()
    {
        _dead = true;
        var tween = CreateTween();
        tween.SetParallel(true);
        tween.TweenProperty(_sprite, "modulate", new Color(0.4f, 0.4f, 0.4f, 0.25f), 0.5f);
        tween.TweenProperty(_ringMat, "albedo_color", _teamColor with { A = 0f }, 0.4f);
    }
}
