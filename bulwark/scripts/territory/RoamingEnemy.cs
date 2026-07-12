using System;
using Godot;

namespace Bulwark.Territory;

/// <summary>
/// A visible roaming enemy on a territory map (scenes/territory/roaming_enemy.tscn): random-walk
/// wander inside a home radius, chase when the player comes into sight, and raise
/// <see cref="PlayerContacted"/> once on contact — the scene turns that into the
/// BeginTerritoryEncounter command. Placeholder visual: a rat idle sprite, matching the token art
/// combat already uses for enemies (monster sprite pack TBD). Holds no game rules.
/// </summary>
public partial class RoamingEnemy : CharacterBody2D
{
    [Export] public float WanderSpeed { get; set; } = 55f;
    [Export] public float ChaseSpeed { get; set; } = 95f;

    /// <summary>Max distance from the spawn point wander targets are picked in.</summary>
    [Export] public float WanderRadius { get; set; } = 140f;

    /// <summary>Player distance at which the roamer switches to chasing.</summary>
    [Export] public float SightRange { get; set; } = 180f;

    /// <summary>Player distance that counts as contact (triggers the encounter).</summary>
    [Export] public float ContactRange { get; set; } = 30f;

    /// <summary>Raised once when the roamer touches the player, with the roamer id.</summary>
    public event Action<string>? PlayerContacted;

    public string RoamerId { get; private set; } = "";

    private Node2D? _player;
    private Label? _aggroLabel;
    private Vector2 _home;
    private Vector2 _wanderTarget;
    private double _retargetIn;
    private bool _triggered;
    private bool _chasing;
    private readonly Random _random = new();

    public override void _Ready()
    {
        _home = GlobalPosition;
        _wanderTarget = _home;
        _aggroLabel = GetNodeOrNull<Label>("%AggroLabel");
    }

    /// <summary>Injected by the territory scene after instancing.</summary>
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
    }

    public override void _PhysicsProcess(double delta)
    {
        if (_triggered || _player == null)
            return;

        float playerDistance = GlobalPosition.DistanceTo(_player.GlobalPosition);
        if (playerDistance <= ContactRange)
        {
            Freeze();
            PlayerContacted?.Invoke(RoamerId);
            return;
        }

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
