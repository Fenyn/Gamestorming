using System.Collections.Generic;
using System.Linq;
using Delve.Village;
using Godot;

namespace Delve.Dev;

/// <summary>
/// The village's small avoidance: a walker passes someone standing on its line, two walkers meeting
/// head-on pass each other, and in the simulated village no walker ever overlaps another mover.
/// </summary>
public partial class VillageLifeSpike
{
    /// <summary>Two movers this much of their rooms apart overlap on screen.</summary>
    private const float Overlap = 0.6f;

    private sealed class Mover : ICrowdMember
    {
        public Vector2 Ground { get; set; }
        public Vector2 Velocity { get; set; }
        public float Room => 0.3f;
        public bool Present => true;
    }

    private void CheckCrowd()
    {
        var crowd = new VillageCrowd();
        var stander = new Mover { Ground = Vector2.Zero };
        var walker = new Mover { Ground = new Vector2(-3, 0) };
        crowd.Join(stander);
        crowd.Join(walker);
        float closest = Walk(crowd, walker, new Vector2(3, 0), out bool arrived);
        Check($"crowd: a walker veers round someone standing on its line (closest {closest:0.00}, arrived {arrived})",
            arrived && closest >= (stander.Room + walker.Room) * Overlap);

        crowd.Leave(stander);
        var oncoming = new Mover { Ground = new Vector2(3, 0.02f) };
        crowd.Join(oncoming);
        walker.Ground = new Vector2(-3, 0);
        float nearest = float.MaxValue;
        bool both = false;
        for (int tick = 0; tick < 600 && !both; tick++)
        {
            bool a = Advance(crowd, walker, new Vector2(3, 0));
            bool b = Advance(crowd, oncoming, new Vector2(-3, 0));
            nearest = Mathf.Min(nearest, walker.Ground.DistanceTo(oncoming.Ground));
            both = a && b;
        }
        Check($"crowd: two walkers meeting head-on pass each other (closest {nearest:0.00}, both arrived {both})",
            both && nearest >= (walker.Room + oncoming.Room) * Overlap);
    }

    private float Walk(VillageCrowd crowd, Mover walker, Vector2 goal, out bool arrived)
    {
        float closest = float.MaxValue;
        arrived = false;
        for (int tick = 0; tick < 600 && !arrived; tick++)
        {
            arrived = Advance(crowd, walker, goal);
            closest = Mathf.Min(closest, crowd.Members.Where(m => m != walker).Min(m => m.Ground.DistanceTo(walker.Ground)));
        }
        return closest;
    }

    /// <summary>One step at walking pace; true once at the goal.</summary>
    private bool Advance(VillageCrowd crowd, Mover walker, Vector2 goal)
    {
        const float speed = 1.2f;
        if (walker.Ground.DistanceTo(goal) <= speed * Step)
        {
            walker.Ground = goal;
            walker.Velocity = Vector2.Zero;
            return true;
        }
        var next = crowd.Step(walker, goal, goal, speed, Step);
        walker.Velocity = (next - walker.Ground) / Step;
        walker.Ground = next;
        return false;
    }

    /// <summary>Pairs where a walking mover overlaps another mover.</summary>
    private static IEnumerable<string> Bumps(IReadOnlyList<ResidentFigure> figures, IReadOnlyList<VillageChicken> hens)
    {
        var movers = figures.Select(f => (Name: f.Id, Member: (ICrowdMember)f.Routine!, Walking: f.Routine!.Pose == ResidentPose.Walk))
            .Concat(hens.Select(h => (Name: h.Name.ToString(), Member: (ICrowdMember)h, Walking: h.Walking))).ToList();
        for (int i = 0; i < movers.Count; i++)
            for (int j = i + 1; j < movers.Count; j++)
            {
                var (a, b) = (movers[i], movers[j]);
                if (!a.Walking && !b.Walking) continue;
                float apart = a.Member.Ground.DistanceTo(b.Member.Ground);
                if (apart < (a.Member.Room + b.Member.Room) * Overlap) yield return $"{a.Name}/{b.Name}";
            }
    }

    /// <summary>A walking hen off the walkable mesh beyond the step from its home, or too far from home.</summary>
    private static bool HenAstray(VillageWalkable walkable, VillageChicken hen) =>
        hen.Ground.DistanceTo(hen.Home) > hen.Range + StepSlack
        || (walkable.OffMesh(hen.Ground) > OnMesh && hen.Ground.DistanceTo(hen.Home) > walkable.OffMesh(hen.Home) + StepSlack);
}
