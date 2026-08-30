using System;
using Godot;
using PF2e.Grid;

namespace Delve.Terrain;

/// <summary>
/// Vertex-level geometry helpers for the terrain mesh. Every method here works on world-space points
/// only: nothing reads the layout, the theme or the palette. This is where the Unity to Godot winding
/// flip lives, and the only place a triangle enters a <see cref="MeshBuffer"/>.
/// </summary>
public static class TerrainGeometry
{
    /// <summary>Default vertex colour of terrain geometry: white, i.e. full wave on a water surface.</summary>
    internal static readonly Color VertexWhite = new(1f, 1f, 1f, 1f);

    /// <summary>
    /// Two triangles for one tile top, split along the SHORTER diagonal so a non-planar corner set
    /// distorts less. Six vertices rather than four: each triangle carries its own geometrically
    /// correct normal, which is what stops the dark-triangle artifact on slopes whose halves face
    /// different ways. <paramref name="faceDown"/> flips both the normal and the winding, for the
    /// downward-looking quads (bridge undersides, pillar bottom caps).
    ///
    /// The four corners MUST trace the footprint counter-clockwise seen from above, as a tile's
    /// sw → se → ne → nw does. <see cref="ComputeUpNormal"/> forces the stored normal up (then
    /// <paramref name="faceDown"/> negates it) without re-deriving the winding, so a clockwise
    /// footprint gets a normal that contradicts the face it actually emits.
    /// </summary>
    internal static void AddQuad(
        MeshBuffer buffer, MeshBuffer? collision,
        Vector3 sw, Vector3 se, Vector3 ne, Vector3 nw, bool faceDown = false)
    {
        Vector2 uvSW = new(0, 0);
        Vector2 uvSE = new(1, 0);
        Vector2 uvNE = new(1, 1);
        Vector2 uvNW = new(0, 1);

        if (ShouldSplitAlternate(sw, se, ne, nw))
        {
            // SW-NE diagonal.
            AddTriangle(buffer, collision, sw, ne, se, Face(ComputeUpNormal(sw, ne, se), faceDown),
                uvSW, uvNE, uvSE, faceDown);
            AddTriangle(buffer, collision, sw, nw, ne, Face(ComputeUpNormal(sw, nw, ne), faceDown),
                uvSW, uvNW, uvNE, faceDown);
        }
        else
        {
            // SE-NW diagonal.
            AddTriangle(buffer, collision, sw, nw, se, Face(ComputeUpNormal(sw, nw, se), faceDown),
                uvSW, uvNW, uvSE, faceDown);
            AddTriangle(buffer, collision, se, nw, ne, Face(ComputeUpNormal(se, nw, ne), faceDown),
                uvSE, uvNW, uvNE, faceDown);
        }
    }

    /// <summary>
    /// Emit one triangle. <paramref name="a"/>/<paramref name="b"/>/<paramref name="c"/> are in UNITY
    /// front-face order; the 2nd and 3rd indices are swapped so the same face is front-facing in Godot.
    /// This is the single place the winding flip happens for triangle-at-a-time geometry;
    /// <paramref name="faceDown"/> keeps the Unity order instead, which points the face the other
    /// way (its <paramref name="normal"/> arrives already negated).
    /// </summary>
    internal static void AddTriangle(
        MeshBuffer buffer, MeshBuffer? collision,
        Vector3 a, Vector3 b, Vector3 c, Vector3 normal, Vector2 uvA, Vector2 uvB, Vector2 uvC,
        bool faceDown = false) =>
        buffer.AddTriangle(collision, a, b, c, normal, uvA, uvB, uvC, reverse: !faceDown);

    internal static Vector3 Face(Vector3 upNormal, bool faceDown) => faceDown ? -upNormal : upNormal;

    /// <summary>Upward-facing normal for a triangle in winding order, flipped if it points down.</summary>
    internal static Vector3 ComputeUpNormal(Vector3 a, Vector3 b, Vector3 c)
    {
        Vector3 normal = (b - a).Cross(c - a).Normalized();
        if (normal.Y < 0) normal = -normal;
        return normal;
    }

    /// <summary>
    /// True when the quad should split along SW-NE rather than SE-NW: the diagonal with the smaller
    /// height difference. The tile highlights in <c>GridOverlay3D</c> split by the same rule, so a
    /// highlight lies on the face it marks instead of crossing its diagonal.
    /// </summary>
    public static bool ShouldSplitAlternate(Vector3 sw, Vector3 se, Vector3 ne, Vector3 nw) =>
        MathF.Abs(sw.Y - ne.Y) <= MathF.Abs(se.Y - nw.Y);

    /// <summary>Flat quad across a tile footprint at a fixed height — the under-bridge floor or water.</summary>
    internal static void AddFillQuad(
        MeshBuffer buffer, float worldY, Vector3 vSW, Vector3 vSE, Vector3 vNE, Vector3 vNW) =>
        AddQuad(buffer, null,
            new Vector3(vSW.X, worldY, vSW.Z), new Vector3(vSE.X, worldY, vSE.Z),
            new Vector3(vNE.X, worldY, vNE.Z), new Vector3(vNW.X, worldY, vNW.Z));

    /// <summary>
    /// A wall quad with an outward normal and world-unit UVs. Four vertices, two triangles.
    /// Trapezoidal walls where one vertical edge collapses would give a zero-length cross product and
    /// a black face, so the normal falls back to the opposite vertical edge (both point "down", so the
    /// signed direction is unchanged) and finally to up.
    /// </summary>
    internal static void AddWallQuad(
        MeshBuffer buffer, MeshBuffer? collision,
        Vector3 topLeft, Vector3 topRight, Vector3 bottomRight, Vector3 bottomLeft) =>
        AddWallQuad(buffer, collision, topLeft, topRight, bottomRight, bottomLeft, VertexWhite, VertexWhite);

    /// <summary>
    /// <see cref="AddWallQuad(MeshBuffer, MeshBuffer?, Vector3, Vector3, Vector3, Vector3)"/> with
    /// per-row vertex colours, so a water skirt can lock its bottom edge against the wave shader
    /// (alpha 0) while its top edge rides the surface (alpha 1).
    /// </summary>
    internal static void AddWallQuad(
        MeshBuffer buffer, MeshBuffer? collision,
        Vector3 topLeft, Vector3 topRight, Vector3 bottomRight, Vector3 bottomLeft,
        Color topColor, Color bottomColor)
    {
        Vector3 normal = WallNormal(topLeft, topRight, bottomRight, bottomLeft) ?? Vector3.Up;

        // Wall UVs are what terrain_wall.gdshader samples: U runs along the wall anchored to world
        // coordinates (adjacent quads continue each other seamlessly), V is depth below the top lip
        // in metres — V = 0 at the lip, so the transition band of the wall's top tile always sits
        // exactly where wall meets top, regardless of the face's world height.
        bool runsAlongX = MathF.Abs(topRight.X - topLeft.X) >= MathF.Abs(topRight.Z - topLeft.Z);
        float uLeft = runsAlongX ? topLeft.X : topLeft.Z;
        float uRight = runsAlongX ? topRight.X : topRight.Z;
        float heightL = topLeft.Y - bottomLeft.Y;
        float heightR = topRight.Y - bottomRight.Y;

        // Unity wound (0,2,1) and (0,3,2); both are swapped for Godot's front-face convention.
        buffer.AddQuad(collision, topLeft, topRight, bottomRight, bottomLeft, normal,
            new Vector2(uLeft, 0), new Vector2(uRight, 0),
            new Vector2(uRight, heightR), new Vector2(uLeft, heightL),
            topColor, topColor, bottomColor, bottomColor);
    }

    /// <summary>
    /// Outward normal of a wall quad, or null when the quad is degenerate. A trapezoidal wall whose
    /// left vertical edge collapses gives a zero-length cross product, so the normal falls back to
    /// the right vertical edge (both point "down", so the signed direction is unchanged).
    /// </summary>
    internal static Vector3? WallNormal(Vector3 topLeft, Vector3 topRight, Vector3 bottomRight, Vector3 bottomLeft)
    {
        Vector3 edge1 = topRight - topLeft;
        Vector3 normal = (bottomLeft - topLeft).Cross(edge1);
        if (normal.LengthSquared() < 1e-8f)
            normal = (bottomRight - topRight).Cross(edge1);
        return normal.LengthSquared() < 1e-8f ? null : normal.Normalized();
    }

    /// <summary>The outer (tile edge) and inner (inset) corner pairs of one edge band.</summary>
    internal static (Vector3 outerA, Vector3 outerB, Vector3 innerA, Vector3 innerB) InsetEdge(
        CardinalDirection dir, Vector3 vSW, Vector3 vSE, Vector3 vNE, Vector3 vNW, float width) =>
        dir switch
        {
            CardinalDirection.North => (vNW, vNE, vNW.Lerp(vSW, width), vNE.Lerp(vSE, width)),
            CardinalDirection.South => (vSE, vSW, vSE.Lerp(vNE, width), vSW.Lerp(vNW, width)),
            CardinalDirection.East => (vNE, vSE, vNE.Lerp(vNW, width), vSE.Lerp(vSW, width)),
            _ => (vSW, vNW, vSW.Lerp(vSE, width), vNW.Lerp(vNE, width)),
        };

    /// <summary>An up-facing band lifted clear of the surface it overlays. Never joins the collider.</summary>
    internal static void AddLiftedStrip(
        MeshBuffer buffer, Vector3 outerA, Vector3 outerB, Vector3 innerA, Vector3 innerB, float yOffset)
    {
        var up = new Vector3(0, yOffset, 0);
        AddOverlayQuad(buffer, innerA + up, innerB + up, outerB + up, outerA + up, Vector3.Up);
    }

    /// <summary>
    /// Four vertices, two triangles, one shared normal — the flat overlay quad every overlay uses.
    /// Vertices are given in Unity's front-face order and wound for Godot. Overlays never contribute to
    /// the collision mesh: they are decoration lying on faces that are already in it.
    /// </summary>
    internal static void AddOverlayQuad(
        MeshBuffer buffer, Vector3 v0, Vector3 v1, Vector3 v2, Vector3 v3, Vector3 normal) =>
        buffer.AddQuad(null, v0, v1, v2, v3, normal,
            new Vector2(0, 0), new Vector2(1, 0), new Vector2(1, 1), new Vector2(0, 1),
            VertexWhite, VertexWhite, VertexWhite, VertexWhite);

    /// <summary>
    /// Interpolate down the edge from <paramref name="top"/> to <paramref name="bottom"/> to the point
    /// at <paramref name="targetY"/>. A vertical-collapsed edge snaps to the top.
    /// </summary>
    internal static Vector3 InterpolateY(Vector3 top, Vector3 bottom, float targetY)
    {
        float dy = top.Y - bottom.Y;
        if (dy < 0.0001f) return top;
        return top.Lerp(bottom, Math.Clamp((top.Y - targetY) / dy, 0f, 1f));
    }

    /// <summary>Banker's rounding, matching Unity's Mathf.RoundToInt (and TileData.EffectiveHeight).</summary>
    internal static int RoundToInt(float value) => (int)Math.Round((double)value);
}
