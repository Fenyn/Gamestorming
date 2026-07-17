using System;
using Godot;

namespace Bulwark.Territory;

/// <summary>
/// A visible roaming enemy on a territory map (scenes/territory/roaming_enemy.tscn): random-walk
/// wander inside a home radius, chase when the player comes into sight, and raise
/// <see cref="PlayerContacted"/> once on contact — the scene turns that into the
/// BeginTerritoryEncounter command. Contact detection is delegated to the scene's
/// <see cref="ContactTrigger"/> Area2D child (idiomatic Godot BodyEntered, shared with the wolf lair)
/// rather than a hand-rolled distance poll; the trigger's shape is the contact range. Movement is
/// MoveAndSlide, so wander and chase are stopped by the same baked world collision that blocks the
/// player (see CozyWorldScene.BuildWorldCollision) — the enemy never slides through walls or water.
/// Placeholder visual: a rat idle sprite, matching the token art combat already uses for enemies
/// (monster sprite pack TBD). Holds no game rules.
/// </summary>
public partial class RoamingEnemy : CharacterBody2D
{
    [Export] public float WanderSpeed { get; set; } = 55f;
    [Export] public float ChaseSpeed { get; set; } = 95f;

    /// <summary>Max distance from the spawn point wander targets are picked in.</summary>
    [Export] public float WanderRadius { get; set; } = 140f;

    /// <summary>Player distance at which the roamer switches to chasing.</summary>
    [Export] public float SightRange { get; set; } = 180f;

    /// <summary>Raised once when the roamer touches the player, with the roamer id.</summary>
    public event Action<string>? PlayerContacted;

    public string RoamerId { get; private set; } = "";

    private Node2D? _player;
    private ContactTrigger? _contact;
    private Label? _aggroLabel;
    private Vector2 _home;
    private Vector2 _wanderTarget;
    private double _retargetIn;
    private bool _triggered;
    private bool _chasing;
    // Cosmetic wander only (never anchors save state), so plain Random matches the fx precedent —
    // DeterministicRng is reserved for the save-critical forage/respawn rolls.
    private readonly Random _random = new();

    public override void _Ready()
    {
        _home = GlobalPosition;
        _wanderTarget = _home;
        _aggroLabel = GetNodeOrNull<Label>("%AggroLabel");

        _contact = GetNodeOrNull<ContactTrigger>("%ContactTrigger");
        if (_contact != null)
            _contact.Contacted += OnContact;
    }

    /// <summary>Injected by the territory scene after instancing. The player reference drives the
    /// sight/chase steering; contact itself flows through the <see cref="ContactTrigger"/> child.</summary>
    public void Setup(string roamerId, Node2D player)
    {
        RoamerId = roamerId;
        _player = player;
    }

    /// <summary>Freeze in place (used while the encounter hand-off toast plays).</summary>
    public void Freeze()
    {
        _triggered = true;
        Velocity = Vector2.Zero;
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
        if (_triggered || _player == null)
            return;

        float playerDistance = GlobalPosition.DistanceTo(_player.GlobalPosition);

        Vector2 target;
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
            if (_retargetIn <= 0.0 || GlobalPosition.DistanceTo(_wanderTarget) < 6f)
                PickWanderTarget();
            target = _wanderTarget;
            speed = WanderSpeed;
        }

        Vector2 to = target - GlobalPosition;
        Velocity = to.Length() < 2f ? Vector2.Zero : to.Normalized() * speed;
        MoveAndSlide();
    }

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
        _wanderTarget = _home + new Vector2(Mathf.Cos((float)angle), Mathf.Sin((float)angle)) * dist;
        _retargetIn = 1.5 + _random.NextDouble() * 2.0;
    }
}
