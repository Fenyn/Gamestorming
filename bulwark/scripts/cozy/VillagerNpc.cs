using System;
using Bulwark.Data;
using Godot;

namespace Bulwark.Cozy;

/// <summary>
/// A single villager NPC in a walkable world scene (the outpost). Each placed villager is its OWN
/// entity — a <see cref="CharacterBody2D"/> that owns its per-instance presentation and behavior —
/// instanced from the shared <c>scenes/cozy/npc.tscn</c> by <see cref="VillagerLoader"/> and
/// configured through <see cref="Setup"/> from villager data (no per-character scene needed; the
/// appearance is data-driven off the <see cref="CharacterProfile.SpriteId"/>).
///
/// Behavior: the NPC idles at its home marker (the spawn position) and periodically wanders to a
/// random point within <see cref="WanderRadius"/> of HOME (never of its current position, so it
/// can't drift away over time), then returns to idling. Wander uses the same Mana Seed 4-direction
/// walk cycle as <see cref="PlayerController"/> when it moves. It is a thin adapter per CLAUDE.md:
/// no game rules live here beyond this presentational wander loop. The talk/gift interaction is
/// resolved by the scene via <see cref="VillagerLoader.NearestVillagerId"/> using this node's world
/// position, so the NPC only needs to expose its <see cref="Id"/> and sit at the right place.
/// </summary>
public partial class VillagerNpc : CharacterBody2D
{
    /// <summary>Mana Seed hero sheets shared with the avatar / combat token (folder = SpriteId).</summary>
    private const string SpriteRoot = "res://assets/sprites/heroes/";
    private const string DefaultSpriteFolder = "veteran";

    // ------------------------------------------------------------------ Wander tunables

    /// <summary>Max distance (px) from HOME a wander target may be picked.</summary>
    [Export] public float WanderRadius { get; set; } = 96f;

    /// <summary>Wander walk speed (px/s) — deliberately slow, well under the player's pace.</summary>
    [Export] public float WanderSpeed { get; set; } = 40f;

    /// <summary>Minimum idle time (s) before picking a new wander target.</summary>
    [Export] public float WanderIdleMinSeconds { get; set; } = 3f;

    /// <summary>Maximum idle time (s) before picking a new wander target.</summary>
    [Export] public float WanderIdleMaxSeconds { get; set; } = 7f;

    /// <summary>Distance (px) to the wander target counted as "arrived".</summary>
    [Export] public float WanderArriveDistance { get; set; } = 4f;

    /// <summary>How long (s) a wander walk may be blocked by a collision before giving up and
    /// returning to idle (an unreachable target must not wedge the NPC against a wall forever).</summary>
    [Export] public float WanderStuckGiveUpSeconds { get; set; } = 1f;

    // ------------------------------------------------------------------ Commute (schedule) tunables

    /// <summary>Walk speed (px/s) while commuting to a new schedule anchor — deliberately brisker than
    /// <see cref="WanderSpeed"/> so the daily move reads as purposeful, not a stroll.</summary>
    [Export] public float CommuteSpeed { get; set; } = 70f;

    /// <summary>How long (s) a commute may make no progress (wedged on geometry) before the NPC warps
    /// straight to its anchor rather than staying stuck forever.</summary>
    [Export] public float CommuteTeleportSeconds { get; set; } = 4f;

    private Sprite2D? _sprite;

    /// <summary>The character/villager id this NPC represents (the dialogue + friendship key).</summary>
    public string Id { get; private set; } = string.Empty;

    // Facing row into the Mana Seed sheet (0=S, 1=N, 2=E, 3=W). Idle NPCs face south (toward camera)
    // until their first wander sets a real facing.
    private int _facingRow = ManaSeedSheet.RowSouth;
    private float _animTimer;
    private int _animFrame;
    private bool _moving;

    // ---- Wander state ----
    private Vector2 _home;
    private Vector2 _walkTarget;
    private bool _walking;
    private bool _wanderEnabled = true;
    private double _idleTimer;
    private double _blockedTimer;
    private Random? _rng;

    // ---- Commute state (walking to a new schedule anchor) ----
    private Vector2 _anchorTarget;
    private bool _commuting;
    private double _commuteStuckTimer;

    /// <summary>
    /// Optional suppression check invoked every physics tick: while it returns true the NPC halts in
    /// place and returns to idle (no new wander target is picked). Wired by <see cref="VillagerLoader"/>
    /// from a host-supplied predicate (dialogue/modal open, a cutscene playing, or this NPC being the
    /// active talk target) — see <see cref="SetWanderSuppression"/>. Null (no host wiring, e.g. an F6/
    /// spike run) means never suppressed.
    /// </summary>
    private Func<bool>? _isSuppressed;

    public override void _Ready()
    {
        _sprite ??= GetNodeOrNull<Sprite2D>("%Sprite");
        ZIndex = 4; // just under the player (z=5), above the z=0 world layers, below Overhead (z=10)
        ApplyStandFrame();
    }

    /// <summary>
    /// Configure this NPC from villager data (called by <see cref="VillagerLoader"/> right after the
    /// instance is added to the tree). Assigns identity, world position (also the wander HOME point),
    /// and appearance. Null-safe: an unknown/absent sprite falls back to the default hero sheet so the
    /// NPC is always visible.
    /// </summary>
    public void Setup(string id, string? spriteId, Vector2 spawnPosition)
    {
        Id = id;
        Name = $"Villager_{id}";
        GlobalPosition = spawnPosition;
        _home = spawnPosition;
        _rng = new Random(id.GetHashCode());
        _idleTimer = NextIdleSeconds();
        ApplySprite(spriteId);
    }

    /// <summary>Wire the wander suppression predicate (see <see cref="_isSuppressed"/>). Pass null to
    /// clear it. Safe to call before or after <see cref="Setup"/>.</summary>
    public void SetWanderSuppression(Func<bool>? isSuppressed) => _isSuppressed = isSuppressed;

    /// <summary>
    /// Pin/unpin wander externally — a director staging this actor (e.g. a cutscene's <c>enter</c>
    /// walk-in) can disable wander so it never fights the staged movement, then re-enable it once the
    /// scene resumes. Disabling immediately halts any in-progress walk and returns the NPC to idle.
    /// </summary>
    public void SetWanderEnabled(bool enabled)
    {
        _wanderEnabled = enabled;
        if (!enabled && _walking)
            StopWalking();
    }

    /// <summary>
    /// Re-anchor this NPC to a new home position (a schedule slot change). The wander center becomes
    /// <paramref name="position"/> immediately; if the NPC is not already there it stops wandering and
    /// COMMUTES (walks) to it at <see cref="CommuteSpeed"/>, then resumes wandering around the new
    /// anchor on arrival. Commuting is paused by the same suppression / <see cref="SetWanderEnabled"/>
    /// gates as wander, so a dialogue or a pin holds the NPC mid-walk. Idempotent when already at the
    /// anchor (the placement-time / save-load case, where the NPC is spawned directly on its anchor).
    /// </summary>
    public void SetAnchor(Vector2 position)
    {
        _home = position; // wander now centers on the new anchor even before the commute finishes
        if (GlobalPosition.DistanceTo(position) <= WanderArriveDistance)
        {
            _commuting = false; // already here — no cross-map walk
            return;
        }

        _anchorTarget = position;
        _commuting = true;
        _commuteStuckTimer = 0;
        _walking = false; // cancel any in-progress wander walk; the commute takes over
    }

    public override void _PhysicsProcess(double delta)
    {
        bool active = _wanderEnabled && !(_isSuppressed?.Invoke() ?? false);
        if (!active)
        {
            // Suppressed / pinned: halt in place but KEEP any commute pending, so it resumes on release.
            if (_walking)
                StopWalking();
            if (_commuting)
            {
                Velocity = Vector2.Zero;
                _moving = false;
            }
            UpdateAnimation(delta);
            return;
        }

        if (_commuting)
            ProcessCommute(delta);
        else if (_walking)
            ProcessWalking(delta);
        else
            ProcessIdle(delta);

        UpdateAnimation(delta);
    }

    // ------------------------------------------------------------------ Wander

    private void ProcessIdle(double delta)
    {
        _idleTimer -= delta;
        if (_idleTimer > 0)
            return;

        _walkTarget = _home + RandomOffsetInRadius();
        _walking = true;
        _blockedTimer = 0;
    }

    private void ProcessWalking(double delta)
    {
        Vector2 toTarget = _walkTarget - GlobalPosition;
        float distance = toTarget.Length();
        if (distance <= WanderArriveDistance)
        {
            StopWalking();
            return;
        }

        Vector2 direction = toTarget / distance;
        Velocity = direction * WanderSpeed;
        MoveAndSlide();
        UpdateFacing(direction);
        _moving = true;

        if (GetSlideCollisionCount() > 0)
        {
            _blockedTimer += delta;
            if (_blockedTimer >= WanderStuckGiveUpSeconds)
            {
                StopWalking(); // unreachable target — give up and idle in place
                return;
            }
        }
        else
        {
            _blockedTimer = 0;
        }
    }

    /// <summary>
    /// Straight-line commute to the schedule anchor at <see cref="CommuteSpeed"/>, reusing the wander
    /// walk animation/facing. On arrival, wander resumes (the anchor is already the wander home). If the
    /// NPC makes no real progress for <see cref="CommuteTeleportSeconds"/> (wedged on geometry), it warps
    /// to the anchor — a prototype-grade Stardew-style off-screen villager teleport.
    /// </summary>
    private void ProcessCommute(double delta)
    {
        Vector2 toTarget = _anchorTarget - GlobalPosition;
        float distance = toTarget.Length();
        if (distance <= WanderArriveDistance)
        {
            _commuting = false;
            StopWalking(); // arrived — resume wandering around the new home (= anchor)
            return;
        }

        Vector2 before = GlobalPosition;
        Vector2 direction = toTarget / distance;
        Velocity = direction * CommuteSpeed;
        MoveAndSlide();
        UpdateFacing(direction);
        _moving = true;

        // No meaningful progress this tick (blocked by a wall/prop) accrues toward the teleport fallback.
        if (GlobalPosition.DistanceTo(before) < 0.5f)
        {
            _commuteStuckTimer += delta;
            if (_commuteStuckTimer >= CommuteTeleportSeconds)
            {
                GlobalPosition = _anchorTarget; // prototype off-screen warp: a stuck commuter never wedges
                _commuting = false;
                StopWalking();
            }
        }
        else
        {
            _commuteStuckTimer = 0;
        }
    }

    /// <summary>Halt in place (whether arrived, given up, disabled, or suppressed) and start a fresh
    /// randomized idle countdown before the next wander target is picked.</summary>
    private void StopWalking()
    {
        _walking = false;
        _moving = false;
        Velocity = Vector2.Zero;
        _blockedTimer = 0;
        _idleTimer = NextIdleSeconds();
    }

    private Vector2 RandomOffsetInRadius()
    {
        var rng = _rng ??= new Random();
        double angle = rng.NextDouble() * (Math.PI * 2);
        double radius = rng.NextDouble() * WanderRadius;
        return new Vector2((float)(Math.Cos(angle) * radius), (float)(Math.Sin(angle) * radius));
    }

    private double NextIdleSeconds()
    {
        var rng = _rng ??= new Random();
        double min = Math.Min(WanderIdleMinSeconds, WanderIdleMaxSeconds);
        double max = Math.Max(WanderIdleMinSeconds, WanderIdleMaxSeconds);
        return min + rng.NextDouble() * (max - min);
    }

    // ------------------------------------------------------------------ Facing / animation

    /// <summary>Same 4-direction facing rule as <see cref="PlayerController"/>: the larger axis wins.</summary>
    private void UpdateFacing(Vector2 v)
    {
        if (Mathf.Abs(v.X) >= Mathf.Abs(v.Y))
            _facingRow = v.X >= 0f ? ManaSeedSheet.RowEast : ManaSeedSheet.RowWest;
        else
            _facingRow = v.Y >= 0f ? ManaSeedSheet.RowSouth : ManaSeedSheet.RowNorth;
    }

    private void UpdateAnimation(double delta)
    {
        if (_sprite == null)
            return;

        if (_moving)
        {
            _animTimer += (float)delta;
            if (_animTimer >= ManaSeedSheet.WalkFrameTime)
            {
                _animTimer -= ManaSeedSheet.WalkFrameTime;
                _animFrame = (_animFrame + 1) % ManaSeedSheet.WalkFrames;
            }
            _sprite.Frame = (ManaSeedSheet.WalkRowOffset + _facingRow) * ManaSeedSheet.Columns + _animFrame;
        }
        else
        {
            _animFrame = 0;
            _animTimer = 0f;
            ApplyStandFrame();
        }
    }

    private void ApplySprite(string? spriteId)
    {
        _sprite ??= GetNodeOrNull<Sprite2D>("%Sprite");
        if (_sprite == null)
            return;

        string folder = string.IsNullOrEmpty(spriteId) ? DefaultSpriteFolder : spriteId;
        string path = $"{SpriteRoot}{folder}/p1.png";
        if (!ResourceLoader.Exists(path))
            path = $"{SpriteRoot}{DefaultSpriteFolder}/p1.png";
        if (ResourceLoader.Exists(path))
            _sprite.Texture = GD.Load<Texture2D>(path);

        ApplyStandFrame();
    }

    private void ApplyStandFrame()
    {
        if (_sprite != null)
            _sprite.Frame = _facingRow * ManaSeedSheet.Columns; // stand frame is column 0 of the facing row
    }
}
