using System;
using System.Collections.Generic;
using System.Linq;
using Delve.Combat;
using Godot;

namespace Delve.Village;

/// <summary>
/// A hen on the LimeZu chicken sheet (24 x 4 cells of 16 px): stands, pecks, and potters about
/// within <see cref="Range"/> of where it was placed, along the walkable ground's routes and round
/// the other movers. Side cells face east and flip for west; the walk strip holds side, back, side
/// and front runs of six cells. The stage hands it the walkable ground and the crowd.
/// </summary>
public partial class VillageChicken : Sprite3D, ICrowdMember
{
    public const string Group = "village_chicken";

    [Export] public float Range { get; set; } = 1.2f;
    [Export] public float Speed { get; set; } = 0.5f;
    [Export] public float WalkFrameSeconds { get; set; } = 0.11f;
    [Export] public float PeckFrameSeconds { get; set; } = 0.2f;

    /// <summary>How much room a hen takes among the movers.</summary>
    [Export] public float BodyRoom { get; set; } = 0.15f;

    private const int Columns = 24;
    private const float StuckSeconds = 1f;
    private float _stuck;
    private const int WalkRow = 1, PeckRow = 3;

    private enum Doing { Stand, Peck, Walk }

    private Doing _doing = Doing.Stand;
    private Vector3 _home;
    private readonly Queue<Vector2> _path = new();
    private Vector2 _goal;
    private Vector2 _facing = Vector2.Right;
    private float _timer;
    private float _clock;
    private Random _random = new();
    private Camera3D? _camera;

    public VillageWalkable? Walkable { get; set; }
    public VillageCrowd? Crowd { get; set; }

    /// <summary>Where the hen was placed; it never strays further than <see cref="Range"/> from it.</summary>
    public Vector2 Home => new(_home.X, _home.Z);

    public bool Walking => _doing == Doing.Walk;

    public Vector2 Ground => new(GlobalPosition.X, GlobalPosition.Z);
    public Vector2 Velocity => Walking ? _facing.Normalized() * Speed : Vector2.Zero;
    public float Room => BodyRoom;
    public bool Present => IsVisibleInTree();

    public override void _Ready()
    {
        AddToGroup(Group);
        _home = GlobalPosition;
        _random = new Random((int)(_home.X * 997 + _home.Z * 131));
        _timer = (float)_random.NextDouble() * 2f;
    }

    public override void _Process(double delta)
    {
        if (!IsVisibleInTree()) return;
        Tick((float)delta);
    }

    public void Tick(float delta)
    {
        _clock += delta;
        _timer -= delta;
        if (_doing == Doing.Walk) Walk(delta);
        else if (_timer <= 0) Next();
        Draw();
        SunShadows.Follow(this);
    }

    private void Walk(float delta)
    {
        float step = Speed * delta;
        while (_path.Count > 0)
        {
            var at = Ground;
            var toward = _path.Peek() - at;
            if (_path.Count > 1 && Crowd != null && Crowd.Passable(this, _path.Peek(), _path.ElementAt(1)))
            {
                _path.Dequeue();
                continue;
            }
            if (toward.Length() > step)
            {
                var next = Crowd?.Step(this, _path.Peek(), _goal, Speed, delta) ?? at + toward.Normalized() * step;
                if (next != at) _facing = next - at;
                // Held up by someone: after a while the hen gives up on that spot and does something else.
                _stuck = next.DistanceTo(at) < step / 4 ? _stuck + delta : 0;
                if (_stuck > StuckSeconds)
                {
                    _stuck = 0;
                    _path.Clear();
                    Next();
                    return;
                }
                GlobalPosition = new Vector3(next.X, GlobalPosition.Y, next.Y);
                return;
            }
            _path.Dequeue();
        }
        Next();
    }

    private void Next()
    {
        _clock = 0;
        double roll = _random.NextDouble();
        if (_doing != Doing.Walk && roll < 0.45)
        {
            float angle = (float)_random.NextDouble() * Mathf.Tau, reach = (float)_random.NextDouble() * Range;
            var target = Home + new Vector2(Mathf.Cos(angle), Mathf.Sin(angle)) * reach;
            if (Walkable != null) target = Walkable.Keep(target);
            _goal = target;
            _path.Clear();
            foreach (var point in Walkable?.Route(Ground, target) ?? new[] { target }) _path.Enqueue(point);
            _doing = Doing.Walk;
            return;
        }
        _doing = roll < 0.75 ? Doing.Peck : Doing.Stand;
        _timer = _doing == Doing.Peck ? PeckFrameSeconds * 2 * _random.Next(2, 6) : 1f + (float)_random.NextDouble() * 2f;
    }

    private void Draw()
    {
        _camera ??= GetViewport()?.GetCamera3D();
        var screen = CameraFacing.OnScreen(_facing, _camera);
        bool side = Mathf.Abs(screen.X) >= Mathf.Abs(screen.Y);
        FlipH = side && screen.X < 0;
        // Run order on the walk strip: side, back, side, front.
        int run = side ? 0 : screen.Y > 0 ? 1 : 3;
        Frame = _doing switch
        {
            Doing.Walk => WalkRow * Columns + run * 6 + (int)(_clock / WalkFrameSeconds) % 6,
            Doing.Peck => PeckRow * Columns + run * 2 + (int)(_clock / PeckFrameSeconds) % 2,
            _ => run,
        };
    }
}
