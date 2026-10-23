using System.Collections.Generic;
using System.Linq;
using Godot;
using PF2e.MapGen;
using Ungilded.Content;
using Ungilded.Data;
using Ungilded.Look;
using Ungilded.Terrain;

namespace Ungilded.Props;

/// <summary>The shape of a culvert arch: where its curve springs from the side walls and how high
/// its crown rises, both in metres above the run's floor, and how many halo rings it roofs.</summary>
public readonly record struct ArchShape(float Spring, float Crown, int Depth, int SegmentsPerTile);

/// <summary>
/// A vaulted culvert over each mouth where a channel or the sludge leaves the board through a gap
/// in the wall (the <see cref="SewerBoard.CulvertMark"/> tiles of an authored halo, walled at both
/// ends of the gap). The masonry fills the wall line from the wall top down to an elliptical
/// soffit, so the run passes under an arch into the dark. Built from the terrain's own wall
/// material, so it takes the halo shading. The jambs (the walls on both sides of the mouth, across
/// the arch's depth) stand at full height whenever the camera is on the board side of the mouth,
/// and the arch hides whenever any jamb is cut, so it never meets a stub.
/// </summary>
public static class CulvertArches
{
    public static void Place(Node3D parent, DressingContext context, ArchShape shape)
    {
        var layout = context.Skirt.Layout;
        int m = context.Skirt.Margin;
        var arches = new List<(MeshInstance3D Arch, List<(int X, int Y)> Jambs)>();
        var standing = new Dictionary<(int X, int Y), int>();
        foreach (var span in CulvertSpans.Find(context))
        {
            var (before, after) = span.Flanks();
            if (layout.GetTile(before.X, before.Y) != TileRole.Wall || layout.GetTile(after.X, after.Y) != TileRole.Wall) continue;

            float hs = context.HeightScale;
            float floor = context.SkirtHeights.CenterY(new PF2e.Vector2Int(span.Tiles[0].X, span.Tiles[0].Y));
            float top = layout.GetCornerHeights(before.X, before.Y).MaxHeight * hs;
            var arch = new MeshInstance3D
            {
                Name = $"CulvertArch_{span.Tiles[0].X}_{span.Tiles[0].Y}",
                Mesh = Build(span, floor, top, shape),
                Position = new Vector3(-m, 0f, -m),
            };
            parent.AddChild(arch);
            var jambs = span.Jambs(shape.Depth)
                .Where(t => layout.IsInBounds(t.X, t.Y) && layout.GetTile(t.X, t.Y) == TileRole.Wall).ToList();
            int inward = span.InwardQuadrants();
            foreach (var jamb in jambs) standing[jamb] = standing.GetValueOrDefault(jamb) | inward;
            arches.Add((arch, jambs));
        }
        if (context.Cutaway is not { } cutaway) return;
        if (standing.Count > 0) cutaway.KeepStanding(standing);
        foreach (var (arch, jambs) in arches) cutaway.Track(arch, jambs);
    }

    private static ArrayMesh Build(CulvertSpan span, float floor, float top, ArchShape shape)
    {
        var buffer = new MeshBuffer();
        bool alongX = span.AlongX;
        float a0 = alongX ? span.Tiles[0].X : span.Tiles[0].Y;
        float a1 = (alongX ? span.Tiles[^1].X : span.Tiles[^1].Y) + 1f;
        // The inner face sits on the board side of the first halo ring; the outer face a few rings out.
        float inner = span.InnerEdge;
        float outer = inner + span.OutwardSign * shape.Depth;
        float mid = (a0 + a1) * 0.5f, half = (a1 - a0) * 0.5f;
        float Soffit(float a)
        {
            float k = (a - mid) / half;
            return floor + shape.Spring + (shape.Crown - shape.Spring) * Mathf.Sqrt(Mathf.Max(0f, 1f - k * k));
        }
        Vector3 At(float a, float y, float d) => alongX ? new Vector3(a, y, d) : new Vector3(d, y, a);

        int segments = Mathf.Max(2, Mathf.RoundToInt((a1 - a0) * shape.SegmentsPerTile));
        float dMin = Mathf.Min(inner, outer), dMax = Mathf.Max(inner, outer);
        for (int i = 0; i < segments; i++)
        {
            float ua = a0 + (a1 - a0) * i / segments, ub = a0 + (a1 - a0) * (i + 1) / segments;
            float ha = Soffit(ua), hb = Soffit(ub);
            foreach (var (d, sign) in new[] { (inner, -span.OutwardSign), (outer, span.OutwardSign) })
                AddFace(buffer, At(ua, top, d), At(ub, top, d), At(ua, ha, d), At(ub, hb, d), alongX, sign);
            TerrainGeometry.AddQuad(buffer, null, At(ua, ha, dMin), Corner(alongX, At(ub, hb, dMin), At(ua, ha, dMax)),
                At(ub, hb, dMax), Corner(alongX, At(ua, ha, dMax), At(ub, hb, dMin)), faceDown: true);
        }
        TerrainGeometry.AddQuad(buffer, null, At(a0, top, dMin), Corner(alongX, At(a1, top, dMin), At(a0, top, dMax)),
            At(a1, top, dMax), Corner(alongX, At(a0, top, dMax), At(a1, top, dMin)));
        return buffer.ToArrayMesh("culvert_arch", MapMaterials.Wall(MapThemes.Sewer, SurfaceType.Stone));
    }

    /// <summary>The south-east or north-west corner of a footprint whose axes are swapped when the
    /// span runs along z, so the quad stays wound south-west, south-east, north-east, north-west.</summary>
    private static Vector3 Corner(bool alongX, Vector3 whenAlongX, Vector3 whenAlongZ) => alongX ? whenAlongX : whenAlongZ;

    /// <summary>One wall face facing <paramref name="sign"/> along the depth axis, its points
    /// ordered left to right as the face looks out.</summary>
    private static void AddFace(MeshBuffer buffer, Vector3 topA, Vector3 topB, Vector3 bottomA, Vector3 bottomB, bool alongX, int sign)
    {
        var normal = alongX ? new Vector3(0, 0, sign) : new Vector3(sign, 0, 0);
        var tangent = new Vector3(normal.Z, 0f, -normal.X);
        bool aLeft = (topB - topA).Dot(tangent) > 0f;
        if (aLeft) TerrainGeometry.AddWallQuad(buffer, null, topA, topB, bottomB, bottomA);
        else TerrainGeometry.AddWallQuad(buffer, null, topB, topA, bottomA, bottomB);
    }
}
