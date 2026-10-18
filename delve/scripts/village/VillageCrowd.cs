using System;
using System.Collections.Generic;
using Godot;

namespace Delve.Village;

/// <summary>Anything that walks the village ground and takes up room on it: a resident, a pick, a hen.</summary>
public interface ICrowdMember
{
    /// <summary>Where it stands, in grid space (x along world X, y along world Z).</summary>
    Vector2 Ground { get; }

    /// <summary>Where it is heading and how fast, in grid units a second; zero while it stands.</summary>
    Vector2 Velocity { get; }

    /// <summary>How much room it takes, as a radius.</summary>
    float Room { get; }

    /// <summary>False while it is not in the village (a hen whose yard is not built).</summary>
    bool Present { get; }
}

/// <summary>
/// Small avoidance for the village's movers. A walker looks a moment ahead: anyone (standing or
/// walking) who would come within arm's length on the current headings makes it veer to the side away
/// from that meeting point, harder the sooner and closer the meeting, keeping right when they meet
/// head-on. The veer is pulled back onto the walkable ground. Walkers only veer, never stop or turn
/// back, so every walk still arrives, and nobody veers on the last stretch into its own spot.
/// </summary>
public sealed class VillageCrowd
{
    /// <summary>Space kept between two movers' rooms.</summary>
    private const float Gap = 0.2f;

    /// <summary>How hard a full-strength veer turns away, against the way ahead.</summary>
    private const float MaxVeer = 1.2f;

    /// <summary>How far ahead, in seconds, a walker sees a meeting coming.</summary>
    private const float Horizon = 1.5f;

    private readonly List<ICrowdMember> _members = new();

    /// <summary>Puts a stepped-to point back on the walkable ground; null leaves it where it is.</summary>
    public Func<Vector2, Vector2>? Keep { get; set; }

    public IReadOnlyList<ICrowdMember> Members => _members;

    public void Join(ICrowdMember member)
    {
        if (!_members.Contains(member)) _members.Add(member);
    }

    public void Leave(ICrowdMember member) => _members.Remove(member);

    /// <summary>
    /// Whether someone else stands within arm's length of a point. A walker passes a corner of its
    /// route that someone stands on instead of walking into them to reach it.
    /// </summary>
    public bool Crowded(Vector2 point, ICrowdMember self)
    {
        foreach (var other in _members)
            if (other != self && other.Present && other.Ground.DistanceTo(point) < self.Room + other.Room + Gap)
                return true;
        return false;
    }

    /// <summary>Whether a walker can pass the corner of its route at <paramref name="corner"/> and head
    /// straight for <paramref name="beyond"/>: someone stands at the corner and the short cut stays on the ground.</summary>
    public bool Passable(ICrowdMember self, Vector2 corner, Vector2 beyond) =>
        Crowded(corner, self) && (Clear?.Invoke(self.Ground, beyond) ?? true);

    /// <summary>Whether the straight line between two ground points stays on the walkable ground; null: always.</summary>
    public Func<Vector2, Vector2, bool>? Clear { get; set; }

    /// <summary>
    /// One step of a walk at <paramref name="speed"/> from where <paramref name="self"/> stands toward
    /// <paramref name="waypoint"/>, veering round anyone in the way. <paramref name="goal"/> is where the
    /// whole walk ends.
    /// </summary>
    public Vector2 Step(ICrowdMember self, Vector2 waypoint, Vector2 goal, float speed, float delta)
    {
        var from = self.Ground;
        var ahead = (waypoint - from).Normalized();
        float distance = speed * delta;
        if (from.DistanceTo(goal) <= self.Room * 2 + Gap) return from + ahead * distance;
        var right = new Vector2(-ahead.Y, ahead.X);
        var mine = ahead * speed;
        var veer = Vector2.Zero;
        float pace = 1;
        foreach (var other in _members)
        {
            if (other == self || !other.Present) continue;
            var offset = other.Ground - from;
            var closing = other.Velocity - mine;
            float space = self.Room + other.Room + Gap;
            float apart = offset.Length();
            if (apart > space + speed * Horizon) continue;
            if (apart < space && apart > Mathf.Epsilon)
            {
                // Already too close: step apart sideways, and fall back behind someone just ahead.
                float beside = right.Dot(offset);
                veer -= right * (Mathf.Abs(beside) < Gap / 4 ? -1 : Mathf.Sign(beside)) * (space - apart) / space;
                if (offset.Dot(ahead) > 0) pace = Mathf.Min(pace, apart / space);
            }
            float rate = closing.LengthSquared();
            float when = rate < Mathf.Epsilon ? 0 : Mathf.Clamp(-offset.Dot(closing) / rate, 0, Horizon);
            // Already apart and drawing away (or someone behind): nothing to avoid.
            if (when <= 0 && offset.Dot(ahead) <= 0) continue;
            var meeting = offset + closing * when;
            float miss = meeting.Length();
            if (miss >= space) continue;
            float across = right.Dot(meeting);
            // Veer to the side away from the meeting point; dead ahead, keep right.
            float sign = Mathf.Abs(across) < Gap / 4 ? 1 : -Mathf.Sign(across);
            veer += right * sign * (1 - when / Horizon) * (space - miss) / space;
        }
        veer = veer.LimitLength(MaxVeer);
        float length = distance * pace;
        var next = from + (ahead + veer).Normalized() * length;
        var kept = Keep?.Invoke(next) ?? next;
        float moved = kept.DistanceTo(from);
        // Pulled a long way back onto the mesh: the walker is stepping off a seat, so it goes straight on.
        if (moved > length * 2) return from + ahead * length;
        if (moved >= length / 4) return kept;
        // Pinned against the mesh edge: straight on if that stays on the ground, else slide along the edge.
        // A walker pinned for long re-plans its route (see the routines); it never leaves the ground.
        var straight = from + ahead * length;
        return Keep?.Invoke(straight) ?? straight;
    }
}
