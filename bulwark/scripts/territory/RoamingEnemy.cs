using System;
using Godot;

namespace Bulwark.Territory;

/// <summary>
/// A visible roaming enemy on a territory map (scenes/territory/roaming_enemy.tscn): random-walk
/// wander inside a home radius on the XZ ground plane, chase when the player comes into sight, and
/// raise <see cref="PlayerContacted"/> once on contact — the scene turns that into the
/// BeginTerritoryEncounter command. Contact detection is delegated to the scene's
/// <see cref="ContactTrigger"/> Area3D child (idiomatic Godot BodyEntered, shared with the wolf
/// lair) rather than a hand-rolled distance poll; the trigger's shape is the contact range. Movement
/// is MoveAndSlide, so wander and chase are stopped by the same AUTHORED world collision that blocks
/// the player (the scene's %Ground body and the resource-node bodies) — the enemy never slides
/// through walls or water.
///
/// GRID: one cell is ONE METRE, so every tunable below is in metres / metres-per-second. Placeholder
/// visual: a billboarded rat idle sprite (assets/sprites/enemies/rat_v1 — the same 8-frame side-view
/// sheet the 3D combat token uses; monster art pack TBD). Holds no game rules.
/// </summary>
public partial class RoamingEnemy : CharacterBody3D
{
    /// <summary>Frames of the rat idle loop (idle_1..idle_8.png), shared with the combat token.</summary>
    private const string SpriteFolder = "res://assets/sprites/enemies/rat_v1";

    private const int IdleFrames = 8;

    /// <summary>Seconds per idle frame (matches Bulwark.Combat.UnitVisual3D's rat cadence).</summary>
    private const float AnimFrameTime = 1f / 6f;

    [Export] public float WanderSpeed { get; set; } = 1.1f;
    [Export] public float ChaseSpeed { get; set; } = 2f;

    /// <summary>Max distance (m) from the spawn point wander targets are picked in.</summary>
    [Export] public float WanderRadius { get; set; } = 3f;

    /// <summary>Player distance (m) at which the roamer switches to chasing.</summary>
    [Export] public float SightRange { get; set; } = 3.8f;

    /// <summary>Raised once when the roamer touches the player, with the roamer id.</summary>
    public event Action<string>? PlayerContacted;

    public string RoamerId { get; private set; } = "";

    private Node3D? _player;
    private ContactTrigger? _contact;
    private Sprite3D? _sprite;
    private Label3D? _aggroLabel;
    private Texture2D[] _frames = Array.Empty<Texture2D>();
    private Vector3 _home;
    private Vector3 _wanderTarget;
    private double _retargetIn;
    private float _animTimer;
    private int _animFrame;
    private bool _triggered;
    private bool _chasing;
    // Cosmetic wander only (never anchors save state), so plain Random matches the fx precedent —
    // DeterministicRng is reserved for the save-critical forage/respawn rolls.
    private readonly Random _random = new();

    public override void _Ready()
    {
        _home = GlobalPosition;
        _wanderTarget = _home;
        _aggroLabel = GetNodeOrNull<Label3D>("%AggroLabel");
        _sprite = GetNodeOrNull<Sprite3D>("%Sprite");
        LoadFrames();

        _contact = GetNodeOrNull<ContactTrigger>("%ContactTrigger");
        if (_contact != null)
            _contact.Contacted += OnContact;
    }

    /// <summary>Injected by the territory scene after instancing. The player reference drives the
    /// sight/chase steering; contact itself flows through the <see cref="ContactTrigger"/> child.</summary>
    public void Setup(string roamerId, Node3D player)
    {
        RoamerId = roamerId;
        _player = player;
    }

    /// <summary>Freeze in place (used while the encounter hand-off toast plays).</summary>
    public void Freeze()
    {
        _triggered = true;
        Velocity = Vector3.Zero;
        _contact?.Disarm();
    }

    /// <summary>The contact trigger fired: latch, halt, and hand the encounter to the scene once.</summary>
    private void OnContact()
    {
        if (_triggered)
            return;
        Freeze();
        PlayerContacted?.Invoke(RoamerId);
    }

    public override void _PhysicsProcess(double delta)
    {
        Animate((float)delta);

        if (_triggered || _player == null || !IsInstanceValid(_player))
            return;

        float playerDistance = Flat(GlobalPosition).DistanceTo(Flat(_player.GlobalPosition));

        Vector3 target;
        float speed;
        if (playerDistance <= SightRange)
        {
            SetChasing(true);
            target = _player.GlobalPosition;
            speed = ChaseSpeed;
        }
        else
        {
            SetChasing(false);
            _retargetIn -= delta;
            if (_retargetIn <= 0.0 || Flat(GlobalPosition).DistanceTo(Flat(_wanderTarget)) < 0.15f)
                PickWanderTarget();
            target = _wanderTarget;
            speed = WanderSpeed;
        }

        Vector3 to = Flat(target) - Flat(GlobalPosition);
        Vector3 step = to.Length() < 0.05f ? Vector3.Zero : to.Normalized() * speed;
        // A small constant sink keeps the body seated on the authored floor collider (the avatar's rule).
        Velocity = new Vector3(step.X, -1f, step.Z);
        MoveAndSlide();
    }

    /// <summary>XZ-plane projection: wander/chase steering ignores height entirely.</summary>
    private static Vector3 Flat(Vector3 v) => new(v.X, 0f, v.Z);

    /// <summary>Render-only aggro indicator: the "!" label shows while chasing, hides on wander.</summary>
    private void SetChasing(bool chasing)
    {
        if (_chasing == chasing)
            return;
        _chasing = chasing;
        if (_aggroLabel != null)
            _aggroLabel.Visible = chasing;
    }

    private void PickWanderTarget()
    {
        double angle = _random.NextDouble() * Math.Tau;
        float dist = (float)_random.NextDouble() * WanderRadius;
        _wanderTarget = _home + new Vector3(Mathf.Cos((float)angle), 0f, Mathf.Sin((float)angle)) * dist;
        _retargetIn = 1.5 + _random.NextDouble() * 2.0;
    }

    private void LoadFrames()
    {
        if (_sprite == null)
            return;
        var frames = new System.Collections.Generic.List<Texture2D>(IdleFrames);
        for (int i = 1; i <= IdleFrames; i++)
        {
            var tex = GD.Load<Texture2D>($"{SpriteFolder}/idle_{i}.png");
            if (tex != null)
                frames.Add(tex);
        }
        _frames = frames.ToArray();
        if (_frames.Length > 0)
            _sprite.Texture = _frames[0];
    }

    private void Animate(float delta)
    {
        if (_sprite == null || _frames.Length == 0)
            return;
        _animTimer += delta;
        if (_animTimer < AnimFrameTime)
            return;
        _animTimer -= AnimFrameTime;
        _animFrame = (_animFrame + 1) % _frames.Length;
        _sprite.Texture = _frames[_animFrame];
    }
}
