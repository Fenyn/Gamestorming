using Delve.Data;
using Delve.Terrain;
using Godot;

namespace Delve.Combat;

/// <summary>
/// A billboarded pixel-art sprite that animates itself and points itself at a logical facing. It is
/// the drawn body of any 2.5D entity: it knows sheets, frames and directions, and nothing about
/// characters, teams, health or rules.
///
/// Two sheet layouts are supported. A HERO uses a baked Mana Seed page (see <see cref="ManaSeedSheet"/>)
/// with 4 facing rows (S/N/E/W), one static stand frame while idle and a 6-frame walk cycle while
/// moving. An ENEMY uses a folder of side-view idle frames that cycle continuously and flip
/// horizontally to match the facing as the camera sees it.
///
/// The owner sets <see cref="Facing"/> in grid space; this node projects it onto the camera ground
/// axes, so the correct row (hero) or flip (enemy) is drawn from any camera yaw. The camera is
/// resolved from the viewport on demand, so no caller has to hand one over.
///
/// FRAME OWNERSHIP. <see cref="Sprite3D.Texture"/> and <see cref="Sprite3D.Frame"/> belong to the
/// per-frame loop in <see cref="_Process"/>, which a running swing clip outranks until it finishes.
/// <see cref="Frozen"/> stops both, which is how an owner holds a final pose.
/// </summary>
public partial class BillboardSpriteAnimator : Sprite3D
{
    /// <summary>Pixels between the cell bottom edge and the character feet. Measured on the baked
    /// sheets: the 32px body occupies cell rows 12-43, so the feet sit 20px above the bottom.</summary>
    private const int HeroFootMarginPx = 20;

    // --- Sizing (1 tile = 1 m). ---
    private const float HeroPixelSize = 0.05f;     // ~30 px chibi body -> ~1.5 m
    private const float EnemyPixelSize = 0.02f;    // -> ~0.7 m tall rat
    private const float EnemyFrameTime = 1f / 6f;  // enemy idle fps
    private const int EnemyIdleFrames = 8;

    /// <summary>Sprite height in pixels used when the enemy frames fail to load.</summary>
    private const int EnemyFallbackHeightPx = 44;

    /// <summary>How far an enemy sprite sinks into the ground, so it stands on the tile.</summary>
    private const float EnemySink = 0.08f;

    private bool _isHero;
    private Texture2D[] _idleFrames = System.Array.Empty<Texture2D>();

    /// <summary>Hero movement page, restored when a swing clip ends. Null for enemies.</summary>
    private Texture2D? _walkSheet;

    /// <summary>Hero axe-swing page (<see cref="ManaSeedSheet.AxePage"/>), preloaded at configure time
    /// so the first strike of a fight does not hitch on a disk read. Null for enemies.</summary>
    private Texture2D? _swingSheet;

    /// <summary>The hero swing clip in flight (<see cref="PlaySwing"/>), or idle. While it plays it
    /// OUTRANKS the walk and stand frame selection in <see cref="_Process"/>.</summary>
    private readonly SpriteActionPlayer _swing = new();

    private float _animTimer;
    private int _animFrame;
    private bool _moving;
    private Camera3D? _camera;

    /// <summary>
    /// Seconds a caller must wait after <see cref="PlaySwing"/> for the swing STRIKE frame to be on
    /// screen. The presenter holds its AttackRolled gate this long, so the damage spark and number
    /// land on the frame the axe bites rather than before it.
    /// </summary>
    public static float SwingImpactDelay => ManaSeedSheet.Chop.TimeToImpact;

    /// <summary>Read-only handle on the drawn sprite, for callers that must examine it.</summary>
    public Sprite3D Sprite => this;

    /// <summary>Logical facing in grid space (x along world X, y along world Z).</summary>
    public Vector2 Facing { get; set; } = Vector2.Right;

    /// <summary>While true, the frame loop and the swing clip do not write the sprite, so the pose on
    /// screen stays. An owner sets it to hold a final pose, for example a corpse.</summary>
    public bool Frozen { get; set; }

    /// <summary>World height (m) of a configured ENEMY body, from its texture. 0 until
    /// <see cref="ConfigureEnemy"/> runs; heroes size against their own constant instead.
    /// UnitVisual3D floats the HP bar and name off this, so a tall placeholder reads tall.</summary>
    public float BodyHeight { get; private set; }

    /// <summary>Heroes play their walk cycle while true, else the static stand frame.</summary>
    public void SetMoving(bool moving)
    {
        if (_moving == moving) return;
        _moving = moving;
        _animFrame = 0;
        _animTimer = 0f;
    }

    public override void _Ready() => PixelSprite.Configure(this);

    // ------------------------------------------------------------------ Configure

    /// <summary>Set up a Mana Seed hero sheet from its sprite folder. The sprite is lifted so the
    /// character feet stand at the node origin.</summary>
    public void ConfigureHero(string sheetFolder)
    {
        _isHero = true;
        _walkSheet = GD.Load<Texture2D>(ManaSeedSheet.SheetPath(sheetFolder, ManaSeedSheet.WalkPage));
        // The swing page is a plain Texture write away from the walk page (every Mana Seed page
        // shares the 8x8 anatomy and facing-row order), so it only has to be resident.
        _swingSheet = GD.Load<Texture2D>(ManaSeedSheet.SheetPath(sheetFolder, ManaSeedSheet.Chop.Page));
        Texture = _walkSheet;
        Hframes = ManaSeedSheet.Columns;
        Vframes = ManaSeedSheet.Rows;
        PixelSize = HeroPixelSize;
        // Cell center sits (32 - foot margin) px above the feet; lift by that to plant feet at y=0.
        float centerAboveFeet = (ManaSeedSheet.CellPx * 0.5f - HeroFootMarginPx) * HeroPixelSize;
        Position = new Vector3(0f, centerAboveFeet, 0f);
    }

    /// <summary>Set up a side-view enemy from a folder of idle_1 to idle_8 frames.</summary>
    public void ConfigureEnemy(string folder)
    {
        _isHero = false;
        LoadIdleFrames(folder);
        if (_idleFrames.Length > 0) Texture = _idleFrames[0];
        PixelSize = EnemyPixelSize;
        float h = (Texture?.GetHeight() ?? EnemyFallbackHeightPx) * EnemyPixelSize;
        BodyHeight = h;
        Position = new Vector3(0f, h * 0.5f - EnemySink, 0f);
    }

    private void LoadIdleFrames(string folder)
    {
        var frames = new System.Collections.Generic.List<Texture2D>(EnemyIdleFrames);
        for (int i = 1; i <= EnemyIdleFrames; i++)
        {
            var tex = GD.Load<Texture2D>($"{folder}/idle_{i}.png");
            if (tex != null) frames.Add(tex);
        }
        _idleFrames = frames.ToArray();
    }

    // ------------------------------------------------------------------ Per-frame

    public override void _Process(double delta)
    {
        // Standalone (F6) blockout: no sheet configured, so there is nothing to animate.
        if (_walkSheet == null && _idleFrames.Length == 0) return;

        // A hero swing clip outranks walk and stand until it finishes. The frame loop below would
        // otherwise overwrite the clip cell with a stand or walk cell every tick. The presenter paces
        // the world effect off SwingImpactDelay, so nothing has to be read back from the clip here.
        if (_swing.IsPlaying)
        {
            _swing.Tick((float)delta);
            if (_swing.IsPlaying)
            {
                if (!Frozen) Frame = _swing.SheetFrame(FacingRow());
                return;
            }
            // Finished this very tick: hand the sprite back rather than draw one frame of a dead clip
            // (the walk page cells at those indices mean something else entirely).
            EndSwing();
        }

        // Animation clock: heroes only animate while walking; enemies idle-cycle continuously.
        float frameTime = _isHero ? ManaSeedSheet.WalkFrameTime : EnemyFrameTime;
        _animTimer += (float)delta;
        if (_animTimer >= frameTime)
        {
            _animTimer -= frameTime;
            _animFrame = (_animFrame + 1) % AnimFrameCount;
            if (!Frozen) AdvanceAnimFrame();
        }

        if (!Frozen) ApplyFacing();
    }

    /// <summary>Frames in the running cycle: the hero walk cycle, or the loaded enemy idle frames.</summary>
    private int AnimFrameCount => _isHero ? ManaSeedSheet.WalkFrames : Mathf.Max(_idleFrames.Length, 1);

    private void AdvanceAnimFrame()
    {
        // Hero frames are fully resolved in ApplyFacing (stand against walk); nothing to do here.
        if (!_isHero && _idleFrames.Length > 0)
        {
            Texture = _idleFrames[_animFrame];
        }
    }

    /// <summary>The current 3D camera of the viewport, resolved on demand and kept until it goes away.</summary>
    private Camera3D? ResolveCamera()
    {
        if (_camera != null && IsInstanceValid(_camera)) return _camera;
        _camera = GetViewport()?.GetCamera3D();
        return _camera;
    }

    /// <summary>Logical <see cref="Facing"/> resolved against the camera: X = screen right, Y = into
    /// the screen (away from the viewer). The one place the camera-relative projection lives, shared
    /// by the walk and stand frame picker and the swing clip row lookup.</summary>
    private Vector2 ScreenFacing()
    {
        // Camera basis projected onto the ground plane.
        Vector3 right = Vector3.Right, fwd = Vector3.Forward;
        var camera = ResolveCamera();
        if (camera != null)
        {
            var basis = camera.GlobalBasis;
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

    /// <summary>Pick the sprite row (hero) or the flip (enemy) from facing as the camera sees it.</summary>
    public void ApplyFacing()
    {
        if (_isHero)
        {
            int dir = FacingRow();
            Frame = _moving
                ? (ManaSeedSheet.WalkRowOffset + dir) * ManaSeedSheet.Columns + _animFrame
                : dir * ManaSeedSheet.Columns;
        }
        else
        {
            // Enemy art faces screen-right by default; flip when logical facing points screen-left.
            float sx = ScreenFacing().X;
            if (sx < -0.1f) FlipH = true;
            else if (sx > 0.1f) FlipH = false;
        }
    }

    // ------------------------------------------------------------------ Swing clip

    /// <summary>
    /// Start the hero axe-swing clip (<see cref="ManaSeedSheet.Chop"/> on the character
    /// <see cref="ManaSeedSheet.AxePage"/>). No-op for an enemy, for a frozen sprite, and for a hero
    /// whose sheet set failed to load. The caller waits <see cref="SwingImpactDelay"/> for the strike
    /// frame; the follow-through then plays out and hands the sprite back in <see cref="_Process"/>.
    /// </summary>
    /// <returns>True if a clip actually started, so a caller can use a plain lunge instead.</returns>
    public bool PlaySwing()
    {
        if (!_isHero || Frozen || _swingSheet == null) return false;
        Texture = _swingSheet;
        _swing.Play(ManaSeedSheet.Chop);
        Frame = _swing.SheetFrame(FacingRow());
        return true;
    }

    /// <summary>Return the sprite to the movement page once the clip ends. Only Texture and Frame are
    /// ever written here. Every page shares the sheet anatomy, so nothing else has to change.</summary>
    private void EndSwing()
    {
        _swing.Stop();
        if (_walkSheet != null) Texture = _walkSheet;
    }
}
