using System;
using System.Collections.Generic;
using Delve.Data;
using Godot;

namespace Delve.Village;

/// <summary>
/// A pick called to the line-up: hurries from the fixed entry point offscreen along the trail to its
/// slot, then waits there with small fidgets (a glance about, a stretch now and then), never a held
/// frame. <see cref="Leave"/> sends it back the way it came, and <see cref="Gone"/> reports it offscreen.
/// </summary>
public sealed class MarchRoutine : IResidentDriver
{
    private const float RunSpeed = 4.2f;
    private const float StretchChance = 0.15f;
    private const float BodyRoom = 0.3f;

    private List<Vector2> _path;
    private readonly VillageCrowd? _crowd;
    private readonly Vector2 _slotFacing;
    private readonly Random _random;
    private int _next;
    private bool _leaving;
    private float _timer;
    private float _glance;

    public Vector2 Position { get; private set; }
    public Vector2 Facing { get; private set; }
    public ResidentPose Pose { get; private set; }
    public ManaSeedClip? Clip { get; private set; }
    public int Cycle { get; private set; }

    public Vector2 Ground => Position;
    public Vector2 Velocity => Pose == ResidentPose.Run ? Facing * RunSpeed : Vector2.Zero;
    public float Room => BodyRoom;
    public bool Present => !Gone;

    /// <summary>Standing in its slot.</summary>
    public bool Arrived => !_leaving && Pose != ResidentPose.Run;

    /// <summary>Walked back out of the frame.</summary>
    public bool Gone { get; private set; }

    /// <param name="path">From the entry point to the slot, inclusive.</param>
    /// <param name="walkIn">False puts it straight in the slot, as when the camp opens with picks already made.</param>
    /// <param name="crowd">The other movers to veer round on the way; null runs through them.</param>
    public MarchRoutine(IReadOnlyList<Vector2> path, Vector2 slotFacing, int seed, bool walkIn, VillageCrowd? crowd = null)
    {
        _path = new List<Vector2>(path);
        _crowd = crowd;
        _slotFacing = slotFacing;
        _random = new Random(seed);
        if (walkIn)
        {
            Position = _path[0];
            _next = 1;
            Pose = ResidentPose.Run;
            Facing = (_path[1] - _path[0]).Normalized();
        }
        else
        {
            Position = _path[^1];
            Wait();
        }
    }

    /// <summary>Turn round and go back out along the path.</summary>
    public void Leave()
    {
        if (_leaving) return;
        _leaving = true;
        var back = new List<Vector2> { Position };
        for (int i = Math.Min(_next, _path.Count) - 1; i >= 0; i--)
            if (_path[i].DistanceTo(Position) > 0.01f) back.Add(_path[i]);
        _path = back;
        _next = 1;
        Clip = null;
        Pose = ResidentPose.Run;
        if (_path.Count < 2) Gone = true;
    }

    public void Tick(float delta)
    {
        if (Gone) return;
        if (Pose == ResidentPose.Run)
        {
            var target = _path[_next];
            var toward = target - Position;
            float step = RunSpeed * delta;
            if (_next < _path.Count - 1 && _crowd != null && _crowd.Passable(this, target, _path[_next + 1]))
            {
                _next++;
                return;
            }
            if (toward.Length() > step)
            {
                var straight = Position + toward.Normalized() * step;
                var next = _crowd?.Step(this, target, _path[^1], RunSpeed, delta) ?? straight;
                // A pick is called to the line-up: held up, it squeezes past along its lane rather than wait.
                if (next.DistanceTo(Position) < step / 4) next = straight;
                Facing = (next - Position).Normalized();
                Position = next;
                return;
            }
            // A bend on the way is passed where the runner is, so a veer round someone is kept.
            if (++_next < _path.Count) return;
            Position = target;
            if (_leaving) Gone = true;
            else Wait();
            return;
        }
        _timer -= delta;
        if (Pose == ResidentPose.Work)
        {
            if (_timer <= 0) Wait();
            return;
        }
        _glance -= delta;
        if (_glance > 0) return;
        if (_random.NextDouble() < StretchChance)
        {
            Clip = ManaSeedSheet.Work(ManaSeedSheet.HoePage, WorkMotion.Lift);
            Pose = ResidentPose.Work;
            Facing = _slotFacing;
            _timer = Clip.Duration;
            Cycle++;
            return;
        }
        double roll = _random.NextDouble();
        Facing = roll < 0.6 ? _slotFacing : roll < 0.8 ? new Vector2(-_slotFacing.Y, _slotFacing.X) : new Vector2(_slotFacing.Y, -_slotFacing.X);
        _glance = 1.5f + (float)_random.NextDouble() * 2.5f;
    }

    private void Wait()
    {
        Clip = null;
        Pose = ResidentPose.Stand;
        Facing = _slotFacing;
        _glance = 1.5f + (float)_random.NextDouble() * 2.5f;
    }
}
