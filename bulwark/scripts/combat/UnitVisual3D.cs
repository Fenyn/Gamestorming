using Godot;
using PF2e.Core;

namespace Bulwark.Combat;

/// <summary>
/// 2.5D combat token: a billboarded 2D sprite standing on a grid square in the 3D board. Heroes use
/// a baked Mana Seed "page 1" sheet (see <see cref="HeroSpriteMap"/>): 4 facings (S/N/E/W), a single
/// static stand frame while idle and a 6-frame walk cycle while moving, with camera-relative facing
/// selection; enemies use a side-view rat that cycles idle frames and flips horizontally to match
/// its logical facing as seen by the camera. Carries a Label3D name, a billboarded HP bar and a
/// team-colored ground ring that doubles as the current-turn indicator.
/// Thin presentation adapter — no rules.
/// </summary>
public partial class UnitVisual3D : Node3D
{
    // --- Mana Seed page-1 layout: 512x512, 8x8 grid of 64x64 cells. Rows 0-3 = stand S/N/E/W
    // (column 0); rows 4-7 = walk S/N/E/W (columns 0-5, ~135 ms/frame per the pack's guide). ---
    private const int HeroSheetColumns = 8;
    private const int HeroCellPx = 64;
    private const int HeroWalkFrames = 6;
    private const int HeroWalkRowOffset = 4;
    /// <summary>Pixels between the cell's bottom edge and the character's feet. Measured on the
    /// baked sheets: the 32px body occupies cell rows 12-43, so the feet sit 20px above the bottom.</summary>
    private const int HeroFootMarginPx = 20;
    private const float HeroWalkFrameTime = 0.135f;

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

    public static UnitVisual3D Create(ICharacter character, string? ratFolder = null)
    {
        bool isHero = character.CreatureStats == null;
        return new UnitVisual3D
        {
            _character = character,
            _isHero = isHero,
            _teamColor = character.TeamId == 1
                ? new Color(0.35f, 0.6f, 0.95f)
                : new Color(0.85f, 0.4f, 0.35f),
            // Heroes start facing the enemy side; team 1 (left) looks +X, team 2 (right) looks -X.
            Facing = character.TeamId == 1 ? Vector2.Right : Vector2.Left,
            _ratFolder = ratFolder,
        };
    }

    private string? _ratFolder;

    public void SetCamera(Camera3D camera) => _camera = camera;

    public override void _Ready()
    {
        BuildSprite();
        BuildRing();
        BuildHpBar();
        BuildName();
        UpdateHealthBar();
        ApplyFacingFrame();
    }

    // ------------------------------------------------------------------ Build

    private void BuildSprite()
    {
        _sprite = new Sprite3D
        {
            Shaded = false,
            Billboard = BaseMaterial3D.BillboardModeEnum.FixedY,
            TextureFilter = BaseMaterial3D.TextureFilterEnum.Nearest,
            AlphaCut = SpriteBase3D.AlphaCutMode.Discard,
            AlphaScissorThreshold = 0.5f,
        };

        if (_isHero)
        {
            string folder = HeroSpriteMap.FolderFor(_character.Id);
            _sprite.Texture = GD.Load<Texture2D>($"{folder}/p1.png");
            _sprite.Hframes = HeroSheetColumns;
            _sprite.Vframes = 8;
            _sprite.PixelSize = HeroPixelSize;
            // Cell center sits (32 - foot margin) px above the feet; lift by that to plant feet at y=0.
            float centerAboveFeet = (HeroCellPx * 0.5f - HeroFootMarginPx) * HeroPixelSize;
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
        AddChild(_sprite);
    }

    private void LoadRatFrames()
    {
        string folder = _ratFolder ?? "res://assets/sprites/enemies/rat_v1";
        var frames = new System.Collections.Generic.List<Texture2D>(8);
        for (int i = 1; i <= 8; i++)
        {
            var tex = GD.Load<Texture2D>($"{folder}/idle_{i}.png");
            if (tex != null) frames.Add(tex);
        }
        _ratFrames = frames.ToArray();
    }

    private void BuildRing()
    {
        _ring = new MeshInstance3D
        {
            Mesh = new CylinderMesh { TopRadius = 0.42f, BottomRadius = 0.42f, Height = 0.02f, RadialSegments = 24 },
            Position = new Vector3(0f, 0.02f, 0f),
            CastShadow = GeometryInstance3D.ShadowCastingSetting.Off,
        };
        _ringMat = new StandardMaterial3D
        {
            ShadingMode = BaseMaterial3D.ShadingModeEnum.Unshaded,
            Transparency = BaseMaterial3D.TransparencyEnum.Alpha,
            AlbedoColor = _teamColor with { A = 0.45f },
        };
        _ring.MaterialOverride = _ringMat;
        AddChild(_ring);
    }

    private void BuildHpBar()
    {
        _hpBar = new Node3D { Position = new Vector3(0f, _hpBarY, 0f) };
        AddChild(_hpBar);

        const float w = 0.8f, h = 0.09f;
        var bg = new MeshInstance3D
        {
            Mesh = new QuadMesh { Size = new Vector2(w + 0.04f, h + 0.04f) },
            MaterialOverride = BarMaterial(new Color(0.08f, 0.08f, 0.1f, 0.9f)),
            CastShadow = GeometryInstance3D.ShadowCastingSetting.Off,
        };
        _hpBar.AddChild(bg);

        _hpFillMat = BarMaterial(new Color(0.25f, 0.8f, 0.25f));
        _hpFill = new MeshInstance3D
        {
            Mesh = new QuadMesh { Size = new Vector2(w, h) },
            MaterialOverride = _hpFillMat,
            Position = new Vector3(0f, 0f, 0.001f),
            CastShadow = GeometryInstance3D.ShadowCastingSetting.Off,
        };
        _hpBar.AddChild(_hpFill);
    }

    private void BuildName()
    {
        _name = new Label3D
        {
            Text = _character.Name,
            Billboard = BaseMaterial3D.BillboardModeEnum.Enabled,
            FontSize = 48,
            PixelSize = 0.005f,
            Position = new Vector3(0f, _hpBarY + 0.22f, 0f),
            Modulate = Colors.White,
            OutlineSize = 8,
            OutlineModulate = Colors.Black,
            NoDepthTest = true,
        };
        AddChild(_name);
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
        // Animation clock: heroes only animate while walking; rats idle-cycle continuously.
        float frameTime = _isHero ? HeroWalkFrameTime : AnimFrameTime;
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
            // 4-direction snap on the dominant screen axis. Sheet rows: 0=S (toward viewer),
            // 1=N (away), 2=E (screen right), 3=W (screen left).
            int dir = Mathf.Abs(sx) >= Mathf.Abs(sy)
                ? (sx >= 0f ? 2 : 3)
                : (sy >= 0f ? 1 : 0);

            _sprite.Frame = _moving
                ? (HeroWalkRowOffset + dir) * HeroSheetColumns + _animFrame % HeroWalkFrames
                : dir * HeroSheetColumns;
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
