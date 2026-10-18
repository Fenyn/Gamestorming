using System.Collections.Generic;
using System.Linq;
using Delve.Data;
using Delve.Run;
using Delve.Village;
using Godot;

namespace Delve.Dev;

/// <summary>
/// The ground under the residents at one tier: every spot stands clear of the town's pieces and can
/// be walked to from the hearth, every work spot faces the prop its use names within arm's reach, and
/// the line-up lanes stay on the walkable ground.
/// </summary>
public partial class VillageLifeSpike
{
    /// <summary>How often (in simulation ticks) a walking resident is tested against the walkable ground.</summary>
    private const int OffMeshSampling = 5;

    /// <summary>A spot off the walkable mesh by more than this is inside a piece, not beside one.</summary>
    private const float SpotSlack = 0.6f;

    /// <summary>A seat is on its log, so further from the walkable ground than a standing spot.</summary>
    private const float SeatSlack = 1.1f;

    /// <summary>How far past a spot's own distance from the mesh its step onto the mesh may wander.</summary>
    private const float StepSlack = 0.15f;

    /// <summary>The walkable mesh follows a slope only to within a cell or so; a point this close is on it.</summary>
    private const float OnMesh = 0.15f;

    /// <summary>Furthest a work spot may stand from the edge of its prop.</summary>
    private const float Reach = 0.75f;

    /// <summary>Hens wander, so the feed spot only needs one nearby.</summary>
    private const float HensReach = 2.5f;

    /// <summary>The props each spot use works at, by node name prefix in town.tscn.</summary>
    private static readonly Dictionary<string, string[]> Tools = new()
    {
        [VillageActivities.Block] = new[] { "stump" },
        [VillageActivities.Pile] = new[] { "woodpile" },
        [VillageActivities.Anvil] = new[] { "anvil" },
        [VillageActivities.Bench] = new[] { "grindstone", "tool_rack" },
        [VillageActivities.Bed] = new[] { "crop_bed" },
        [VillageActivities.Pot] = new[] { "tripod" },
        [VillageActivities.Goods] = new[] { "crate", "barrel", "cart", "sacks", "basket" },
        [VillageActivities.Hens] = new[] { "chicken" },
        [VillageActivities.Dummy] = new[] { "dummy" },
    };

    private void CheckGround(VillageStage stage, TownTier tier)
    {
        var walkable = stage.Walkable;
        var spots = stage.Residents.Spots.GetChildren().OfType<ResidentSpot>().Where(s => s.Builds((int)tier)).ToList();
        var hub = stage.StopFor(stage.HomeStop)!.GlobalPosition;
        var buried = spots.Where(s => walkable.OffMesh(s.Place.At) > (s.Seated ? SeatSlack : SpotSlack))
            .Select(s => $"{s.Name}({walkable.OffMesh(s.Place.At):0.00})").ToList();
        Check($"{tier}: every spot stands clear of the town's pieces [{string.Join(", ", buried)}]", buried.Count == 0);
        var cut = spots.Where(s => !Reachable(walkable, new Vector2(hub.X, hub.Z), s.Place.At, s.Seated ? SeatSlack : SpotSlack))
            .Select(s => s.Name.ToString()).ToList();
        Check($"{tier}: every spot can be walked to from the hearth [{string.Join(", ", cut)}]", cut.Count == 0);

        var pieces = Pieces(walkable.Obstacles, (int)tier).ToList();
        var unreached = spots.Where(s => s.Use != "" && !FacesTool(s, pieces)).Select(s => $"{s.Name}:{s.Use}").ToList();
        Check($"{tier}: every work spot faces its prop within reach [{string.Join(", ", unreached)}]", unreached.Count == 0);

        var lanes = Enumerable.Range(0, stage.Lineup.Slots.Length)
            .Select(slot => (slot, off: Samples(stage.Lineup.LaneFor(slot)).Where(p => walkable.OffMesh(p) > OnMesh).ToList()))
            .Where(lane => lane.off.Count > 0)
            .Select(lane => $"slot {lane.slot + 1} from ({lane.off[0].X:0.0},{lane.off[0].Y:0.0}) to ({lane.off[^1].X:0.0},{lane.off[^1].Y:0.0})").ToList();
        Check($"{tier}: the line-up lanes stay on the walkable ground [{string.Join(", ", lanes)}]", lanes.Count == 0);
    }

    /// <summary>A walking resident off the mesh, and not just on the short step between one of its own
    /// spots (a seat on a log, a place at a bench) and the walkable ground beside it.</summary>
    private static bool Astray(VillageWalkable walkable, ResidentRoutine routine) =>
        walkable.OffMesh(routine.Position) > OnMesh
        && routine.Spots.All(s => s.At.DistanceTo(routine.Position) > walkable.OffMesh(s.At) + StepSlack);

    private static bool Reachable(VillageWalkable walkable, Vector2 from, Vector2 to, float slack)
    {
        var map = walkable.GetNavigationMap();
        var path = NavigationServer3D.MapGetPath(map, Lift(walkable, from), Lift(walkable, to), true);
        return path.Length > 0 && new Vector2(path[^1].X, path[^1].Z).DistanceTo(to) <= slack;
    }

    private static Vector3 Lift(VillageWalkable walkable, Vector2 at)
    {
        var point = new Vector3(at.X, 0, at.Y);
        return point with { Y = walkable.Ground.HeightAt(point) };
    }

    /// <summary>A prop of the spot's use whose footprint is within reach, roughly ahead of the spot's facing.</summary>
    private static bool FacesTool(ResidentSpot spot, List<(string Name, Rect2 Footprint)> pieces)
    {
        if (!Tools.TryGetValue(spot.Use, out var prefixes)) return false;
        float reach = spot.Use == VillageActivities.Hens ? HensReach : Reach;
        var at = spot.Place.At;
        var facing = spot.Facing.Normalized();
        return pieces.Any(p => prefixes.Any(prefix => p.Name.StartsWith(prefix))
            && Distance(p.Footprint, at) <= reach
            && (p.Footprint.HasPoint(at) || facing.Dot((p.Footprint.GetCenter() - at).Normalized()) >= 0.5f));
    }

    private static float Distance(Rect2 rect, Vector2 at)
    {
        var nearest = new Vector2(Mathf.Clamp(at.X, rect.Position.X, rect.End.X), Mathf.Clamp(at.Y, rect.Position.Y, rect.End.Y));
        return nearest.DistanceTo(at);
    }

    /// <summary>Every piece built at the tier, with its ground footprint (meshes' bounds, or a billboard's frame).</summary>
    private static IEnumerable<(string Name, Rect2 Footprint)> Pieces(IEnumerable<Node> roots, int tier)
    {
        foreach (var root in roots)
            foreach (var child in root.GetChildren())
            {
                if (child is TierGate gate)
                {
                    if (!gate.Builds(tier)) continue;
                    foreach (var piece in Pieces(new[] { gate }, tier)) yield return piece;
                }
                else if (child is Node3D node)
                {
                    if (Footprint(node) is { } footprint) yield return (node.Name, footprint);
                    foreach (var piece in Pieces(new[] { node }, tier)) yield return piece;
                }
            }
    }

    private static Rect2? Footprint(Node3D node)
    {
        if (node is Sprite3D sprite && sprite.Texture != null)
        {
            float half = sprite.Texture.GetWidth() / (float)Mathf.Max(1, sprite.Hframes) * sprite.PixelSize / 2f;
            return new Rect2(sprite.GlobalPosition.X - half, sprite.GlobalPosition.Z - half, half * 2, half * 2);
        }
        Rect2? merged = null;
        var stack = new Stack<Node>(new[] { node });
        while (stack.Count > 0)
        {
            var next = stack.Pop();
            if (next is MeshInstance3D { Mesh: not null } mesh)
            {
                var box = mesh.GlobalTransform * mesh.GetAabb();
                var rect = new Rect2(box.Position.X, box.Position.Z, box.Size.X, box.Size.Z);
                merged = merged is { } so ? so.Merge(rect) : rect;
            }
            foreach (var child in next.GetChildren()) stack.Push(child);
        }
        return merged;
    }

    /// <summary>Points every quarter metre along a path.</summary>
    private static IEnumerable<Vector2> Samples(IReadOnlyList<Vector2> path)
    {
        for (int i = 1; i < path.Count; i++)
        {
            float length = path[i - 1].DistanceTo(path[i]);
            for (float d = 0; d < length; d += 0.25f) yield return path[i - 1].Lerp(path[i], d / length);
        }
        if (path.Count > 0) yield return path[^1];
    }
}
