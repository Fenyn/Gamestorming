using System;
using System.Collections.Generic;
using System.Linq;
using Delve.Data;
using Godot;

namespace Delve.Village;

/// <summary>
/// Runs one resident's activity loop over the spots it owns. It only decides: where the resident is,
/// which way it faces, and which pose or clip shows. <see cref="ResidentFigure"/> draws the result.
/// A work step runs only at a spot of its use, so the resident first walks there; every walk follows
/// the route it is given round the town's pieces. Each routine starts part-way through a random step
/// and rolls every range from its own seed.
/// </summary>
public sealed class ResidentRoutine : IResidentDriver
{
    private const float WalkSpeed = 1.2f;
    private const float Arrived = 0.05f;
    private const float BodyRoom = 0.3f;

    /// <summary>How long a walker held up by the crowd waits before re-planning; twice this and it squeezes past.</summary>
    private const float StallSeconds = 1f;

    private readonly VillageActivity _activity;
    private readonly IReadOnlyList<SpotPlace> _spots;
    private readonly Func<Vector2, Vector2, IReadOnlyList<Vector2>> _route;
    private readonly VillageCrowd? _crowd;
    private readonly Random _random;
    private readonly bool _canSit;
    private readonly float _riseSeconds;

    private int _step = -1;
    private int _spot;
    private float _timer;
    private int _repeats;
    private float _glance;
    private float _stretchStand;
    private readonly Queue<Vector2> _path = new();

    /// <summary>True while walking to reach the current step's spot: the step starts on arrival.</summary>
    private bool _stepWaits;

    private float _stalled;
    private bool _replanned;

    public Vector2 Position { get; private set; }
    public Vector2 Facing { get; private set; }
    public ResidentPose Pose { get; private set; } = ResidentPose.Stand;
    public ManaSeedClip? Clip { get; private set; }
    public int Cycle { get; private set; }

    public Vector2 Ground => Position;
    public Vector2 Velocity => Pose == ResidentPose.Walk ? Facing * WalkSpeed : Vector2.Zero;
    public float Room => BodyRoom;
    public bool Present => true;

    /// <summary>How many times the routine moved on to a new step.</summary>
    public int Changes { get; private set; }

    public IReadOnlyList<SpotPlace> Spots => _spots;

    /// <summary>The spot the resident is at, or walking to.</summary>
    public SpotPlace Spot => _spots[_spot];

    /// <summary>The use the current work step needs; empty while not working.</summary>
    public string WorkAt { get; private set; } = "";

    /// <param name="route">The walk between two ground points, ending at the second; null walks straight.</param>
    /// <param name="crowd">The other movers to veer round while walking; null walks through them.</param>
    /// <param name="canSit">False when the figure has no seated art; seated spots are then stood at.</param>
    /// <param name="riseSeconds">How long the figure's rise (and settle) takes.</param>
    public ResidentRoutine(VillageActivity activity, IReadOnlyList<SpotPlace> spots, int seed, bool canSit, float riseSeconds,
        Func<Vector2, Vector2, IReadOnlyList<Vector2>>? route = null, VillageCrowd? crowd = null)
    {
        _activity = activity;
        _spots = spots;
        _route = route ?? ((_, to) => new[] { to });
        _crowd = crowd;
        _random = new Random(seed);
        _canSit = canSit;
        _riseSeconds = riseSeconds;
        _step = _random.Next(activity.Steps.Count) - 1;
        var first = activity.Steps[(_step + 1) % activity.Steps.Count];
        _spot = SpotFor(first.At) ?? _random.Next(spots.Count);
        Position = spots[_spot].At;
        Facing = spots[_spot].Facing;
        Advance();
        // Organic phase: arrive part-way through the first step.
        _timer *= (float)_random.NextDouble();
        if (Pose == ResidentPose.Work) _repeats = 1 + _random.Next(Math.Max(1, _repeats));
        Changes = 0;
    }

    public void Tick(float delta)
    {
        switch (Pose)
        {
            case ResidentPose.Walk:
                Walk(delta);
                break;
            case ResidentPose.Work:
                _timer -= delta;
                if (_timer > 0) break;
                if (--_repeats > 0)
                {
                    _timer += Clip!.Duration;
                    Cycle++;
                }
                else Advance();
                break;
            case ResidentPose.Rise:
                _timer -= delta;
                if (_timer > 0) break;
                Pose = ResidentPose.Stand;
                _timer = _stretchStand;
                _glance = Range(1f, 2.5f);
                break;
            case ResidentPose.Settle:
                _timer -= delta;
                if (_timer <= 0) Advance();
                break;
            case ResidentPose.Stand:
                _timer -= delta;
                _glance -= delta;
                if (_glance <= 0) Glance();
                if (_timer > 0) break;
                if (_stretchStand > 0)
                {
                    _stretchStand = 0;
                    Pose = ResidentPose.Settle;
                    Facing = _spots[_spot].Facing;
                    _timer = _riseSeconds;
                }
                else Advance();
                break;
            default:
                _timer -= delta;
                if (_timer <= 0) Advance();
                break;
        }
    }

    private void Walk(float delta)
    {
        float step = WalkSpeed * delta;
        while (_path.Count > 0)
        {
            var toward = _path.Peek() - Position;
            if (_path.Count > 1 && _crowd != null && _crowd.Passable(this, _path.Peek(), _path.ElementAt(1)))
            {
                _path.Dequeue();
                continue;
            }
            if (toward.Length() > Math.Max(step, Arrived))
            {
                // Held up by the crowd: re-plan from here after a while, and after longer still squeeze past
                // along the route as far as its next corner.
                bool squeeze = _stalled > StallSeconds * 2;
                var next = _crowd == null || squeeze ? Position + toward.Normalized() * step
                    : _crowd.Step(this, _path.Peek(), _spots[_spot].At, WalkSpeed, delta);
                if (!squeeze) _stalled = next.DistanceTo(Position) < step / 4 ? _stalled + delta : 0;
                if (_stalled > StallSeconds && !_replanned) Replan();
                if (next != Position) Facing = (next - Position).Normalized();
                Position = next;
                return;
            }
            // A corner on the way is passed where the walker is, so a veer round someone is kept.
            _path.Dequeue();
            _stalled = 0;
            _replanned = false;
        }
        Position = _spots[_spot].At;
        Facing = _spots[_spot].Facing;
        bool waits = _stepWaits;
        _stepWaits = false;
        if (!waits || !Start(_activity.Steps[_step])) Advance();
    }

    private void Advance()
    {
        Changes++;
        Clip = null;
        WorkAt = "";
        var steps = _activity.Steps;
        for (int tries = 0; tries < steps.Count * 2; tries++)
        {
            _step = (_step + 1) % steps.Count;
            var step = steps[_step];
            if (step.Chance < 1f && _random.NextDouble() > step.Chance) continue;
            if (step.At != "" && _spots[_spot].Use != step.At)
            {
                if (SpotFor(step.At) is not { } there) continue;
                _stepWaits = true;
                WalkTo(there);
                return;
            }
            if (Start(step)) return;
        }
        Pose = _canSit && _spots[_spot].Seated ? ResidentPose.Sit : ResidentPose.Stand;
        _timer = Range(2f, 4f);
        _glance = Range(1.5f, 4f);
    }

    /// <summary>Starts a step at the current spot; false when it cannot run here.</summary>
    private bool Start(ActivityStep step)
    {
        bool seated = _canSit && _spots[_spot].Seated;
        switch (step.Kind)
        {
            case StepKind.Walk when _spots.Count > 1:
                WalkTo((_spot + 1 + _random.Next(_spots.Count - 1)) % _spots.Count);
                return true;
            case StepKind.Work:
                Clip = ManaSeedSheet.Work(_activity.Page, step.Motion);
                Pose = ResidentPose.Work;
                WorkAt = step.At;
                Facing = _spots[_spot].Facing;
                _repeats = _random.Next(step.MinRepeats, step.MaxRepeats + 1);
                _timer = Clip.Duration;
                Cycle++;
                return true;
            case StepKind.Idle or StepKind.Sit:
                Pose = seated ? ResidentPose.Sit : ResidentPose.Stand;
                _timer = Range(step.MinSeconds, step.MaxSeconds);
                _glance = Range(1.5f, 4f);
                return true;
            case StepKind.Stretch when seated:
                Pose = ResidentPose.Rise;
                Facing = _spots[_spot].Facing;
                _timer = _riseSeconds;
                _stretchStand = Range(step.MinSeconds, step.MaxSeconds);
                return true;
        }
        return false;
    }

    private void WalkTo(int spot)
    {
        _spot = spot;
        _replanned = false;
        _stalled = 0;
        Replan();
        _replanned = false;
        Pose = ResidentPose.Walk;
    }

    /// <summary>The route from where the resident stands to its spot.</summary>
    private void Replan()
    {
        _path.Clear();
        foreach (var point in _route(Position, _spots[_spot].At)) _path.Enqueue(point);
        _replanned = true;
    }

    /// <summary>An owned spot of a use: the current one if it fits, else a random one of that use.</summary>
    private int? SpotFor(string use)
    {
        if (use == "") return null;
        if (_spots[_spot].Use == use) return _spot;
        var fits = Enumerable.Range(0, _spots.Count).Where(i => _spots[i].Use == use).ToList();
        return fits.Count == 0 ? null : fits[_random.Next(fits.Count)];
    }

    /// <summary>Look along the spot's facing most of the time, otherwise to one side.</summary>
    private void Glance()
    {
        var home = _spots[_spot].Facing;
        double roll = _random.NextDouble();
        Facing = roll < 0.6 ? home : roll < 0.8 ? new Vector2(-home.Y, home.X) : new Vector2(home.Y, -home.X);
        _glance = Range(1.5f, 4f);
    }

    private float Range(float min, float max) => min + (float)_random.NextDouble() * (max - min);
}
