using Godot;
using PF2e.MapGen;
using Ungilded.Look;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Props;

/// <summary>Streaks across the surface of every mouth where a channel or the sludge leaves the
/// board, drifting along the board's authored flow (<see cref="Ungilded.Terrain.HaloPlan.Flow"/>):
/// out of the downstream mouth, and in from the halo toward the board at the upstream one. A board
/// with no authored flow, or a mouth across it, drifts out of the mouth.</summary>
public static class CulvertFlows
{
    /// <summary>The emitter's box starts this far out from the mouth's board-side edge, metres.</summary>
    private const float StartOut = 0.3f;

    public static void Place(Node3D parent, DressingContext context, PackedScene scene, Color water, Color sludge, float lift)
    {
        var layout = context.Skirt.Layout;
        int m = context.Skirt.Margin;
        var (fx, fy) = context.Skirt.Plan?.Flow ?? default;
        var flowDir = new Vector3(fx, 0, fy);
        foreach (var span in CulvertSpans.Find(context))
        {
            if (scene.Instantiate() is not GpuParticles3D flow) continue;
            var first = span.Tiles[0];
            float a0 = span.AlongX ? first.X : first.Y;
            float a1 = (span.AlongX ? span.Tiles[^1].X : span.Tiles[^1].Y) + 1f;
            float along = (a0 + a1) * 0.5f - m;
            var outward = span.AlongX ? new Vector3(0, 0, span.OutwardSign) : new Vector3(span.OutwardSign, 0, 0);
            bool upstream = flowDir.Dot(outward) < 0f;
            var process = flow.ProcessMaterial as ParticleProcessMaterial;
            // Upstream streaks start one drift length further out, so they end where the downstream ones start.
            float travel = upstream && process != null
                ? (process.InitialVelocityMin + process.InitialVelocityMax) * 0.5f * (float)flow.Lifetime
                : 0f;
            float depth = span.InnerEdge - m + span.OutwardSign * (StartOut + travel);
            float y = context.SkirtHeights.CenterY(new PF2eVec(first.X, first.Y)) + lift;
            var at = span.AlongX ? new Vector3(along, y, depth) : new Vector3(depth, y, along);
            flow.Name = $"CulvertFlow_{first.X}_{first.Y}";
            // The scene emits along local +Z; LookingAt points local -Z at its target.
            flow.Transform = new Transform3D(Basis.LookingAt(upstream ? outward : -outward, Vector3.Up), at);
            if (process != null)
            {
                process.EmissionBoxExtents = new Vector3((a1 - a0) * 0.5f - 0.1f, process.EmissionBoxExtents.Y, process.EmissionBoxExtents.Z);
                process.Color = layout.GetTile(first.X, first.Y) == TileRole.Water ? water : sludge;
            }
            parent.AddChild(flow);
        }
    }
}
