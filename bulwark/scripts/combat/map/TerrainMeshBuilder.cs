using System;
using System.Collections.Generic;
using Bulwark.Data;
using Godot;
using PF2e.Grid;
using PF2e.MapGen;

namespace Bulwark.Combat.Map;

/// <summary>
/// Turns a generated <see cref="MapLayout"/> into the two meshes a battle map needs: a multi-surface
/// visual <see cref="ArrayMesh"/> with its materials baked on, and a single-surface collision
/// <see cref="ArrayMesh"/> for the trimesh picker. Static and pure — no scene, no state, no RNG.
///
/// Ported from the Unity Tactics <c>TileMeshBuilder</c>, with five deliberate differences:
///
/// 1. <b>Winding is flipped on every triangle.</b> A triangle (a, b, c) is front-facing in Unity when
///    <c>Cross(b-a, c-a)</c> points at the viewer, and in Godot when it points AWAY (Godot's
///    right-handed space inverts the relationship). Emitting the Unity vertex order with the 2nd and
///    3rd indices swapped keeps the same face pointing outward. The explicit normal math ports
///    unchanged, so a triangle's stored normal and its geometric front normal agree — which is exactly
///    what MapGenSpike asserts, per triangle, instead of eyeballing a screenshot.
/// 2. <b>Down-facing faces get down-facing normals.</b> Unity's <c>AddQuad</c> always flipped its normal
///    upward, so bridge undersides and pillar bottom caps shipped with normals pointing into the slab.
///    Here <c>faceDown</c> negates the normal along with the winding: the stored normal keeps agreeing
///    with the geometry (the spike's per-triangle check would otherwise fail on every underside), and
///    an underside is lit like an underside — ambient, not sunlit.
/// 3. <b>No map centering.</b> Unity offset the grid by -w/2; here tile (0,0)'s corner sits on the
///    world origin, matching <c>GridSpace</c> (1 tile = 1 m, grid Y → world Z).
/// 4. <b>Empty-surface compaction.</b> Unity emitted empty submeshes to keep material indices aligned;
///    Godot rejects a surface with no vertices. Empty buffers are skipped and the baked materials
///    follow the surviving surface order.
/// 5. <b>CornerHeights is the only geometry source.</b> Never re-derive from SlopeType: bank sloping
///    mutates corners after slope assignment, so a water tile can carry incline geometry while still
///    recording SlopeType.Flat.
///
/// Two Unity paths are skipped for good: <c>BuildWallTileMesh</c>/<c>AddWallCapFace</c> (per-wall-tile
/// occlusion meshes; Unity's own occlusion controller was disabled) and the material variant pickers.
/// Unity's <c>DrawShallowSkirt</c> is also not ported: its call sites are commented out in the source
/// (a bank-side skirt z-fights the bank wall, which already extends <see cref="WaterWallDepth"/> below
/// the surface for exactly that reason), so porting it would be porting dead code.
/// </summary>
public static class TerrainMeshBuilder
{
    /// <summary>
    /// Absolute corner height of the canyon floor rendered under Empty tiles. Void cliff walls drop to
    /// it and each void tile gets a floor quad at it. -40 corner units = 10 elevations = ~50 ft below
    /// ground, which is a reliably lethal fall in PF2e.
    /// </summary>
    public const int VoidFloorCornerHeight = -40;

    /// <summary>
    /// Extra depth (corner units) walls extend below the surface of a water or over-water bridge
    /// neighbour, so wave displacement reveals wall instead of sky. Must exceed the water shader's
    /// wave amplitude (0.5 world units here against the shader's 0.12).
    /// </summary>
    public const int WaterWallDepth = 4;

    /// <summary>Bridge slab thickness in corner units. 2 units x 0.125 HeightScale = 0.25 m of deck.</summary>
    public const int BridgeSlabThickness = 2;

    /// <summary>
    /// Depth of the blue water band shown at a map-edge water cross-section before it gives way to
    /// stone bedrock. 6 corner units = 1.5 elevations = ~7.5 ft of visible water.
    /// </summary>
    public const int WaterDepthCorners = 6;

    /// <summary>Inward thickness of a bridge pillar box, in world units.</summary>
    private const float PillarInset = 0.28f;

    /// <summary>Lift of top-surface grid lines above the face they sit on. Z-fight margin, world units.</summary>
    private const float GridLineYOffset = 0.004f;

    /// <summary>Lift of cliff-lip edge strips above the top face. Slightly above the grid lines.</summary>
    private const float EdgeStripYOffset = 0.005f;

    /// <summary>Push of cliff bands along the wall normal, away from the face they overlay.</summary>
    private const float CliffBandOffset = 0.003f;

    /// <summary>Surface name of the top-face lattice overlay, as it appears in <see cref="Result.SurfaceNames"/>.</summary>
    public const string TopGridLineSurface = "TopGridLine";

    /// <summary>Surface name of the cliff-lip strip overlay.</summary>
    public const string EdgeStripSurface = "EdgeStrip";

    /// <summary>Surface name of the cliff mortar-band overlay.</summary>
    public const string CliffBandSurface = "CliffBand";

    /// <summary>Surface name of the wave-animated water top faces.</summary>
    public const string WaterTopSurface = "Water:Top";

    private static readonly CardinalDirection[] Cardinals =
    {
        CardinalDirection.North, CardinalDirection.East, CardinalDirection.South, CardinalDirection.West,
    };

    private static readonly Color VertexWhite = new(1f, 1f, 1f, 1f);

    /// <summary>Alpha 0 tells the water shader to leave this vertex where it is (see the .gdshader).</summary>
    private static readonly Color VertexWaveLocked = new(1f, 1f, 1f, 0f);

    /// <summary>Meshes plus the shape facts MapGenSpike validates.</summary>
    public sealed record Result
    {
        /// <summary>Multi-surface render mesh; every surface already carries its material.</summary>
        public required ArrayMesh Visual { get; init; }

        /// <summary>Single-surface mesh for <c>CreateTrimeshShape()</c>: tops, cliff walls and void floors.</summary>
        public required ArrayMesh Collision { get; init; }

        /// <summary>Surfaces on <see cref="Visual"/> — equals the number of baked materials.</summary>
        public required int SurfaceCount { get; init; }

        /// <summary>Per visual surface: true when it holds up-facing geometry, false for cliff faces.</summary>
        public required IReadOnlyList<bool> SurfaceIsTop { get; init; }

        /// <summary>Per visual surface: "&lt;SurfaceType&gt;:Top|Wall" or an overlay name, for diagnostics.</summary>
        public required IReadOnlyList<string> SurfaceNames { get; init; }

        /// <summary>Total vertices across all visual surfaces.</summary>
        public required int VertexCount { get; init; }

        /// <summary>Total triangles across all visual surfaces.</summary>
        public required int TriangleCount { get; init; }

        /// <summary>
        /// Triangles emitted by the bridge pass — slab undersides, slab side faces, pillar boxes and the
        /// under-span floor/water fills. Zero on a layout with no Bridge tiles; the spike keys its
        /// "bridges actually generate geometry" invariant off it because the geometry lands in shared
        /// surface buffers where it can no longer be told apart.
        /// </summary>
        public required int BridgeTriangleCount { get; init; }
    }

    /// <summary>
    /// Build the terrain meshes for a layout under a theme. Deterministic: the same layout and theme
    /// always produce byte-identical arrays in the same surface order.
    /// </summary>
    public static Result Build(MapLayout layout, MapThemeDefinition theme)
    {
        ArgumentNullException.ThrowIfNull(layout);
        ArgumentNullException.ThrowIfNull(theme);

        float hs = theme.HeightScale;
        int w = layout.Width;
        int h = layout.Height;
        int cornerGridWidth = w + 1;

        int[] minCornerH = ComputeMinCornerGrid(layout);
        var palette = new SurfacePalette();
        var collision = new SubmeshBuffer();

        bool gridLines = theme.EnableTopGridLines && theme.TopGridLineWidth > 0f;
        bool edgeStrips = theme.EnableCliffEdgeStrips && theme.CliffEdgeStripWidth > 0f;
        bool cliffBands = theme.EnableCliffBands && theme.CliffBandThickness > 0f;
        int bridgeTriangles = 0;

        for (int x = 0; x < w; x++)
        {
            for (int y = 0; y < h; y++)
            {
                TileRole role = layout.GetTile(x, y);
                if (role == TileRole.Empty)
                {
                    RenderVoidTile(x, y, hs, palette, collision);
                    continue;
                }

                var corners = layout.GetCornerHeights(x, y);
                SurfaceType surface = layout.GetSurface(x, y);

                // Tile (x, y) occupies world x..x+1 on X and y..y+1 on Z (GridSpace convention).
                // SW = (x, y), SE = (x+1, y), NW = (x, y+1), NE = (x+1, y+1).
                var vSW = new Vector3(x, corners.SW * hs, y);
                var vSE = new Vector3(x + 1, corners.SE * hs, y);
                var vNW = new Vector3(x, corners.NW * hs, y + 1);
                var vNE = new Vector3(x + 1, corners.NE * hs, y + 1);

                AddQuad(palette.Top(surface, x, y), collision, vSW, vSE, vNE, vNW);

                // Grid lines skip water (its own surface animates) and walls (a wall's "top" is at wall
                // height, so a lattice there would float above the playfield rather than mark it).
                if (gridLines && role != TileRole.Water && role != TileRole.Wall)
                    AddTileGridLines(palette.Overlay(FaceKind.TopGridLine), x, y,
                        vSW, vSE, vNE, vNW, theme.TopGridLineWidth);

                if (role == TileRole.Bridge)
                {
                    int before = palette.TriangleTotal;
                    RenderBridge(layout, x, y, corners, surface, hs, palette, vSW, vSE, vNE, vNW);
                    bridgeTriangles += palette.TriangleTotal - before;
                    continue;
                }

                if (role == TileRole.Water)
                {
                    RenderWaterSkirts(layout, x, y, corners, hs, palette, vSW, vSE, vNE, vNW);
                    continue;
                }

                var wallBuffer = palette.Wall(surface, x, y);
                var bandBuffer = cliffBands ? palette.Overlay(FaceKind.CliffBand) : null;
                var stripBuffer = edgeStrips ? palette.Overlay(FaceKind.EdgeStrip) : null;

                foreach (var dir in Cardinals)
                {
                    AddEdgeWall(layout, x, y, dir, corners, hs, minCornerH, cornerGridWidth,
                        wallBuffer, collision, bandBuffer, theme.CliffBandThickness);

                    if (stripBuffer != null)
                        AddEdgeStrip(layout, x, y, dir, corners, vSW, vSE, vNE, vNW,
                            theme.CliffEdgeStripWidth, stripBuffer);
                }
            }
        }

        return Assemble(layout, theme, palette, collision, bridgeTriangles);
    }

    // ────────────────────────────── Mesh assembly ──────────────────────────────

    private static Result Assemble(
        MapLayout layout, MapThemeDefinition theme, SurfacePalette palette, SubmeshBuffer collision,
        int bridgeTriangles)
    {
        var visual = new ArrayMesh { ResourceName = $"terrain_{layout.Name ?? "map"}" };
        var isTop = new List<bool>();
        var names = new List<string>();
        int vertexCount = 0;
        int triangleCount = 0;
        int surfaceIndex = 0;

        // Empty-surface compaction: Godot's AddSurfaceFromArrays rejects an empty vertex array, so a
        // palette slot that never received geometry (a biome with no water, say) is dropped and the
        // baked materials follow the surviving order.
        foreach (var (key, buffer) in palette.Buffers)
        {
            if (buffer.IsEmpty) continue;

            visual.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles, buffer.ToArrays());
            visual.SurfaceSetMaterial(surfaceIndex, MaterialFor(theme, key));

            isTop.Add(key.Kind is FaceKind.Top or FaceKind.TopGridLine or FaceKind.EdgeStrip);
            names.Add(key.Describe());
            vertexCount += buffer.VertexCount;
            triangleCount += buffer.TriangleCount;
            surfaceIndex++;
        }

        var collisionMesh = new ArrayMesh { ResourceName = $"terrain_collision_{layout.Name ?? "map"}" };
        if (!collision.IsEmpty)
            collisionMesh.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles, collision.ToArrays());

        return new Result
        {
            Visual = visual,
            Collision = collisionMesh,
            SurfaceCount = surfaceIndex,
            SurfaceIsTop = isTop,
            SurfaceNames = names,
            VertexCount = vertexCount,
            TriangleCount = triangleCount,
            BridgeTriangleCount = bridgeTriangles,
        };
    }

    private static Material MaterialFor(MapThemeDefinition theme, PaletteKey key) => key.Kind switch
    {
        FaceKind.Top => MapMaterials.Top(theme, key.Surface),
        FaceKind.Wall => MapMaterials.Wall(theme, key.Surface),
        FaceKind.TopGridLine => MapMaterials.Overlay(theme.TopGridLineColor, "terrain_grid_line"),
        FaceKind.EdgeStrip => MapMaterials.Overlay(theme.EdgeStripColor, "terrain_edge_strip"),
        _ => MapMaterials.Overlay(theme.CliffBandColor, "terrain_cliff_band"),
    };

    // ────────────────────────────── Top faces ──────────────────────────────

    /// <summary>
    /// Two triangles for one tile top, split along the SHORTER diagonal so a non-planar corner set
    /// distorts less. Six vertices rather than four: each triangle carries its own geometrically
    /// correct normal, which is what stops the dark-triangle artifact on slopes whose halves face
    /// different ways. <paramref name="faceDown"/> flips both the normal and the winding, for the
    /// downward-looking quads (bridge undersides, pillar bottom caps).
    /// </summary>
    private static void AddQuad(
        SubmeshBuffer buffer, SubmeshBuffer? collision,
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

    private static Vector3 Face(Vector3 upNormal, bool faceDown) => faceDown ? -upNormal : upNormal;

    /// <summary>Upward-facing normal for a triangle in winding order, flipped if it points down.</summary>
    private static Vector3 ComputeUpNormal(Vector3 a, Vector3 b, Vector3 c)
    {
        Vector3 normal = (b - a).Cross(c - a).Normalized();
        if (normal.Y < 0) normal = -normal;
        return normal;
    }

    /// <summary>True when the quad should split along SW-NE rather than SE-NW: the diagonal with the smaller height difference.</summary>
    private static bool ShouldSplitAlternate(Vector3 sw, Vector3 se, Vector3 ne, Vector3 nw) =>
        MathF.Abs(sw.Y - ne.Y) <= MathF.Abs(se.Y - nw.Y);

    /// <summary>Stone floor quad under one Empty tile. Neighbouring solids drop their walls to the same height.</summary>
    private static void RenderVoidTile(int x, int y, float hs, SurfacePalette palette, SubmeshBuffer collision)
    {
        float floorY = VoidFloorCornerHeight * hs;
        var fSW = new Vector3(x, floorY, y);
        var fSE = new Vector3(x + 1, floorY, y);
        var fNW = new Vector3(x, floorY, y + 1);
        var fNE = new Vector3(x + 1, floorY, y + 1);
        AddQuad(palette.Top(SurfaceType.Stone, x, y), collision, fSW, fSE, fNE, fNW);
    }

    // ────────────────────────────── Bridges ──────────────────────────────

    /// <summary>
    /// Everything a Bridge tile owns below its deck: the slab underside, side faces on exposed slab
    /// edges, boxed pillars down to the floor where the deck overhangs a bank, and the fill (canyon
    /// floor or water surface) that stops the abyss showing through the gaps.
    ///
    /// None of it joins the collision mesh. The deck's top face already went in with every other tile
    /// top, which is the only bridge surface a creature stands on or a pick ray should ever hit; adding
    /// undersides and pillars would put a second, lower hit under the same tile column for no gain.
    /// </summary>
    private static void RenderBridge(
        MapLayout layout, int x, int y, TileCornerHeights corners, SurfaceType surface, float hs,
        SurfacePalette palette, Vector3 vSW, Vector3 vSE, Vector3 vNE, Vector3 vNW)
    {
        var drop = new Vector3(0, BridgeSlabThickness * hs, 0);
        Vector3 uSW = vSW - drop;
        Vector3 uSE = vSE - drop;
        Vector3 uNW = vNW - drop;
        Vector3 uNE = vNE - drop;

        var slab = palette.Wall(surface, x, y);

        AddQuad(slab, null, uSW, uSE, uNE, uNW, faceDown: true);

        AddBridgeSideFace(layout, x, y, CardinalDirection.North, corners, vNW, vNE, uNW, uNE, slab);
        AddBridgeSideFace(layout, x, y, CardinalDirection.East, corners, vNE, vSE, uNE, uSE, slab);
        AddBridgeSideFace(layout, x, y, CardinalDirection.South, corners, vSE, vSW, uSE, uSW, slab);
        AddBridgeSideFace(layout, x, y, CardinalDirection.West, corners, vSW, vNW, uSW, uNW, slab);

        int floorH = FindBridgeFloorHeight(layout, x, y);
        foreach (var dir in Cardinals)
            AddBridgePillarWall(layout, x, y, dir, corners, floorH, hs, slab);

        if (IsBridgeOverVoid(layout, x, y))
        {
            float floorY = VoidFloorCornerHeight * hs;
            AddFillQuad(palette.Top(SurfaceType.Stone, x, y), floorY, vSW, vSE, vNE, vNW);
            return;
        }

        // Under-span water. Unity drew it at the neighbouring water's rest level, which coincides with
        // the deck on a flush span (sewer grates sit AT water level) and z-fights it. Clamping to the
        // slab underside leaves a real river untouched — its surface is already well below the deck —
        // and turns the flush case into a visible 0.25 m recess instead of a flickering seam.
        int waterCornerH = Math.Min(
            FindAdjacentWaterCornerHeight(layout, x, y),
            RoundToInt(corners.CenterHeight) - BridgeSlabThickness);
        AddFillQuad(palette.Top(SurfaceType.Water, x, y), waterCornerH * hs, vSW, vSE, vNE, vNW);
    }

    /// <summary>Flat quad across a tile footprint at a fixed height — the under-bridge floor or water.</summary>
    private static void AddFillQuad(
        SubmeshBuffer buffer, float worldY, Vector3 vSW, Vector3 vSE, Vector3 vNE, Vector3 vNW) =>
        AddQuad(buffer, null,
            new Vector3(vSW.X, worldY, vSW.Z), new Vector3(vSE.X, worldY, vSE.Z),
            new Vector3(vNE.X, worldY, vNE.Z), new Vector3(vNW.X, worldY, vNW.Z));

    /// <summary>
    /// The exposed vertical edge of a bridge slab, drawn double-sided (a 0.25 m slab seen edge-on from
    /// under the span needs a face on both sides). Skipped where a neighbouring bridge continues the
    /// deck at roughly the same height. Adjacent solid tiles cover their own side of the gap through
    /// <see cref="AddEdgeWall"/>'s bridge-floor handling.
    /// </summary>
    private static void AddBridgeSideFace(
        MapLayout layout, int x, int y, CardinalDirection dir, TileCornerHeights corners,
        Vector3 topA, Vector3 topB, Vector3 botA, Vector3 botB, SubmeshBuffer buffer)
    {
        (int nx, int ny) = Step(x, y, dir);
        if (layout.IsInBounds(nx, ny) && layout.GetTile(nx, ny) == TileRole.Bridge)
        {
            var neighbor = layout.GetCornerHeights(nx, ny);
            if (MathF.Abs(corners.CenterHeight - neighbor.CenterHeight) <= BridgeSlabThickness) return;
        }

        // AddWallQuad derives its outward normal from the argument order, so the same four points wound
        // both ways give one front face per side — Unity's hand-rolled +normal/-normal pair, reused.
        AddWallQuad(buffer, null, topA, topB, botB, botA);
        AddWallQuad(buffer, null, topB, topA, botA, botB);
    }

    /// <summary>
    /// A boxed pillar from the slab underside down to the floor, on one edge of a bridge tile.
    ///
    /// Only at corner pockets: an approach edge is skipped (the ground tile's own cliff wall already
    /// covers the full gap, and a second face there would z-fight), and an open river-facing span is
    /// left open on purpose so the span reads as spanning. What is left is the edge where the deck
    /// overhangs a bank, detected by a ground-ish neighbour on a perpendicular edge.
    /// </summary>
    private static void AddBridgePillarWall(
        MapLayout layout, int x, int y, CardinalDirection dir, TileCornerHeights corners,
        int floorH, float hs, SubmeshBuffer buffer)
    {
        (int nx, int ny) = Step(x, y, dir);
        if (layout.IsInBounds(nx, ny))
        {
            var neighborRole = layout.GetTile(nx, ny);
            if (neighborRole == TileRole.Bridge) return;
            if (neighborRole is TileRole.Ground or TileRole.DifficultTerrain
                or TileRole.Cover or TileRole.Wall) return;
        }

        if (!HasPerpendicularGround(layout, x, y, dir)) return;

        (int topA, int topB) = corners.EdgeCorners(dir);
        topA -= BridgeSlabThickness;
        topB -= BridgeSlabThickness;
        if (topA <= floorH && topB <= floorH) return;

        (Vector3 oTL, Vector3 oTR, Vector3 oBL, Vector3 oBR) =
            GetEdgeWorldPositions(x, y, dir, topA, topB, floorH, floorH, hs);

        if (oTL.DistanceTo(oBL) < 0.001f && oTR.DistanceTo(oBR) < 0.001f) return;

        Vector3 inward = dir switch
        {
            CardinalDirection.North => new Vector3(0, 0, -PillarInset),
            CardinalDirection.South => new Vector3(0, 0, PillarInset),
            CardinalDirection.East => new Vector3(-PillarInset, 0, 0),
            _ => new Vector3(PillarInset, 0, 0),
        };

        Vector3 iTL = oTL + inward, iTR = oTR + inward, iBL = oBL + inward, iBR = oBR + inward;

        AddWallQuad(buffer, null, oTL, oTR, oBR, oBL);   // outer face
        AddWallQuad(buffer, null, iTR, iTL, iBL, iBR);   // inner face (L/R swapped = reversed)
        AddWallQuad(buffer, null, iTL, oTL, oBL, iBL);   // side
        AddWallQuad(buffer, null, oTR, iTR, iBR, oBR);   // side
        AddQuad(buffer, null, oBL, oBR, iBR, iBL, faceDown: true); // bottom cap
    }

    /// <summary>True when a ground-ish tile sits on either edge perpendicular to <paramref name="dir"/>.</summary>
    private static bool HasPerpendicularGround(MapLayout layout, int x, int y, CardinalDirection dir)
    {
        (CardinalDirection a, CardinalDirection b) =
            dir is CardinalDirection.North or CardinalDirection.South
                ? (CardinalDirection.East, CardinalDirection.West)
                : (CardinalDirection.North, CardinalDirection.South);

        return IsGroundish(layout, Step(x, y, a)) || IsGroundish(layout, Step(x, y, b));
    }

    private static bool IsGroundish(MapLayout layout, (int x, int y) tile) =>
        layout.IsInBounds(tile.x, tile.y)
        && layout.GetTile(tile.x, tile.y)
            is TileRole.Ground or TileRole.DifficultTerrain or TileRole.Cover;

    // ────────────────────────────── Water skirts ──────────────────────────────

    /// <summary>
    /// Map-edge skirts for a water tile: a band of water cross-section (the animated water material,
    /// with its bottom row locked so the seam does not oscillate) over stone bedrock down to the abyss
    /// floor. Without it the river visibly spills off the end of the world, and the edge sits at a
    /// different depth from the plateau cliffs on the same boundary.
    ///
    /// Interior edges get nothing: the bank tile's own wall already runs <see cref="WaterWallDepth"/>
    /// below the water surface (see <see cref="AddEdgeWall"/>), so a water-side skirt there would only
    /// z-fight it.
    /// </summary>
    private static void RenderWaterSkirts(
        MapLayout layout, int x, int y, TileCornerHeights corners, float hs, SurfacePalette palette,
        Vector3 vSW, Vector3 vSE, Vector3 vNE, Vector3 vNW)
    {
        bool northEdge = !layout.IsInBounds(x, y + 1);
        bool eastEdge = !layout.IsInBounds(x + 1, y);
        bool southEdge = !layout.IsInBounds(x, y - 1);
        bool westEdge = !layout.IsInBounds(x - 1, y);
        if (!northEdge && !eastEdge && !southEdge && !westEdge) return;

        int waterCorner = RoundToInt(corners.CenterHeight);
        float edgeDrop = (waterCorner - VoidFloorCornerHeight) * hs;
        float waterBand = MathF.Min(WaterDepthCorners * hs, edgeDrop);

        var waterTop = palette.Top(SurfaceType.Water, x, y);
        var bedrock = palette.Wall(SurfaceType.Stone, x, y);

        if (northEdge) AddDeepEdgeSkirt(waterTop, bedrock, vNW, vNE, waterBand, edgeDrop);
        if (eastEdge) AddDeepEdgeSkirt(waterTop, bedrock, vNE, vSE, waterBand, edgeDrop);
        if (southEdge) AddDeepEdgeSkirt(waterTop, bedrock, vSE, vSW, waterBand, edgeDrop);
        if (westEdge) AddDeepEdgeSkirt(waterTop, bedrock, vSW, vNW, waterBand, edgeDrop);
    }

    /// <summary>
    /// One map-edge skirt: water band on top, bedrock below. The band's TOP row keeps vertex alpha 1 so
    /// it bobs with the surface it joins; its BOTTOM row is locked at alpha 0 so the water/rock seam
    /// stays put.
    /// </summary>
    private static void AddDeepEdgeSkirt(
        SubmeshBuffer waterTop, SubmeshBuffer bedrock, Vector3 a, Vector3 b, float waterBand, float edgeDrop)
    {
        var band = new Vector3(0, waterBand, 0);
        Vector3 waterBotA = a - band;
        Vector3 waterBotB = b - band;
        AddWallQuad(waterTop, null, a, b, waterBotB, waterBotA, VertexWhite, VertexWaveLocked);

        if (edgeDrop <= waterBand) return;

        var full = new Vector3(0, edgeDrop, 0);
        AddWallQuad(bedrock, null, waterBotA, waterBotB, b - full, a - full);
    }

    // ────────────────────────────── Cliff walls ──────────────────────────────

    /// <summary>
    /// One cliff face on a tile edge, generated only where this tile stands above the neighbour's
    /// matching corners. Missing neighbours (map edge, Empty tiles) count as the void floor. Wall
    /// bottoms come from the min-corner grid so faces meeting at a shared vertex land on the same
    /// height and leave no triangular gap.
    /// </summary>
    private static void AddEdgeWall(
        MapLayout layout, int x, int y, CardinalDirection dir, TileCornerHeights corners,
        float hs, int[] minCornerH, int cornerGridWidth,
        SubmeshBuffer buffer, SubmeshBuffer? collision,
        SubmeshBuffer? bandBuffer, float bandThickness)
    {
        // EdgeCorners returns the pair left-to-right facing outward — the same mapping as Unity's
        // GetEdgeCornerHeights (N: NW,NE — E: NE,SE — S: SE,SW — W: SW,NW).
        (int thisA, int thisB) = corners.EdgeCorners(dir);

        int neighborA = 0, neighborB = 0;
        (int nx, int ny) = Step(x, y, dir);

        bool neighborIsVoid = !layout.IsInBounds(nx, ny) || layout.GetTile(nx, ny) == TileRole.Empty;
        TileRole neighborRole = neighborIsVoid ? TileRole.Empty : layout.GetTile(nx, ny);
        bool neighborIsWaterOrBridge =
            !neighborIsVoid && (neighborRole == TileRole.Water || neighborRole == TileRole.Bridge);

        if (!neighborIsVoid)
        {
            if (neighborRole == TileRole.Bridge)
            {
                // Treat a bridge neighbour as its floor (water level): the approach tile then cuts a
                // cliff face through the whole under-span gap rather than stopping at the deck.
                int bridgeFloor = FindBridgeFloorHeight(layout, nx, ny);
                neighborA = bridgeFloor;
                neighborB = bridgeFloor;
            }
            else
            {
                (int nA, int nB) = layout.GetCornerHeights(nx, ny).EdgeCorners(Opposite(dir));
                // The shared edge is traversed the other way round from the neighbour's side.
                neighborA = nB;
                neighborB = nA;
            }

            // Same/higher neighbour means no cliff. EXCEPTION: water and bridge neighbours still need
            // a skirt below their surface even when this tile's corners sit flush with water level
            // (sloped banks), or a wave-bobbed surface would expose the void under the bank lip.
            if (thisA <= neighborA && thisB <= neighborB && !neighborIsWaterOrBridge) return;
        }

        (int vxA, int vyA, int vxB, int vyB) = GetEdgeVertexPositions(x, y, dir);
        int bottomA = minCornerH[vyA * cornerGridWidth + vxA];
        int bottomB = minCornerH[vyB * cornerGridWidth + vxB];

        if (!neighborIsVoid && neighborRole == TileRole.Bridge)
        {
            // minCornerH only sees the bridge's deck corners, not the gap under it — force the bottoms
            // down to the bridge floor so the under-span is covered.
            int bridgeFloor = FindBridgeFloorHeight(layout, nx, ny);
            bottomA = Math.Min(bottomA, bridgeFloor);
            bottomB = Math.Min(bottomB, bridgeFloor);
        }

        if (!neighborIsVoid && neighborRole == TileRole.Water)
        {
            // Extend the bank wall below water rest level, so a wave dipping DOWN reveals wall rather
            // than a slice of sky.
            bottomA = Math.Min(bottomA, neighborA - WaterWallDepth);
            bottomB = Math.Min(bottomB, neighborB - WaterWallDepth);
        }

        if (!neighborIsVoid && neighborRole == TileRole.Bridge && !IsBridgeOverVoid(layout, nx, ny))
        {
            // Bridge over water: same gap as the water case, seen from the side under the deck.
            bottomA = Math.Min(bottomA, neighborA - WaterWallDepth);
            bottomB = Math.Min(bottomB, neighborB - WaterWallDepth);
        }

        if (neighborIsVoid)
        {
            // Walls facing the void drop to the canyon floor so the cliff reads as a clean chasm wall.
            bottomA = VoidFloorCornerHeight;
            bottomB = VoidFloorCornerHeight;
        }

        (Vector3 topLeft, Vector3 topRight, Vector3 bottomLeft, Vector3 bottomRight) =
            GetEdgeWorldPositions(x, y, dir, thisA, thisB, bottomA, bottomB, hs);

        if (topLeft.DistanceTo(bottomLeft) < 0.001f && topRight.DistanceTo(bottomRight) < 0.001f)
            return;

        AddWallQuad(buffer, collision, topLeft, topRight, bottomRight, bottomLeft);

        if (bandBuffer != null && bandThickness > 0f)
            AddCliffBands(bandBuffer, topLeft, topRight, bottomRight, bottomLeft, hs, bandThickness);
    }

    /// <summary>
    /// A wall quad with an outward normal and world-unit UVs. Four vertices, two triangles.
    /// Trapezoidal walls where one vertical edge collapses would give a zero-length cross product and
    /// a black face, so the normal falls back to the opposite vertical edge (both point "down", so the
    /// signed direction is unchanged) and finally to up.
    /// </summary>
    private static void AddWallQuad(
        SubmeshBuffer buffer, SubmeshBuffer? collision,
        Vector3 topLeft, Vector3 topRight, Vector3 bottomRight, Vector3 bottomLeft) =>
        AddWallQuad(buffer, collision, topLeft, topRight, bottomRight, bottomLeft, VertexWhite, VertexWhite);

    /// <summary>
    /// <see cref="AddWallQuad(SubmeshBuffer, SubmeshBuffer?, Vector3, Vector3, Vector3, Vector3)"/> with
    /// per-row vertex colours, so a water skirt can lock its bottom edge against the wave shader
    /// (alpha 0) while its top edge rides the surface (alpha 1).
    /// </summary>
    private static void AddWallQuad(
        SubmeshBuffer buffer, SubmeshBuffer? collision,
        Vector3 topLeft, Vector3 topRight, Vector3 bottomRight, Vector3 bottomLeft,
        Color topColor, Color bottomColor)
    {
        Vector3 edge1 = topRight - topLeft;
        Vector3 edge2 = bottomLeft - topLeft;
        Vector3 normal = edge2.Cross(edge1);
        if (normal.LengthSquared() < 1e-8f)
            normal = (bottomRight - topRight).Cross(edge1);
        if (normal.LengthSquared() < 1e-8f)
            normal = Vector3.Up;
        normal = normal.Normalized();

        // U = horizontal span, V = wall height. Both top corners share the max V so the UV quad stays
        // rectangular and a trapezoidal wall doesn't skew its texture.
        float width = new Vector3(topLeft.X, 0, topLeft.Z).DistanceTo(new Vector3(topRight.X, 0, topRight.Z));
        float heightL = topLeft.Y - bottomLeft.Y;
        float heightR = topRight.Y - bottomRight.Y;
        float maxH = MathF.Max(heightL, heightR);

        int b = buffer.VertexCount;
        buffer.Add(topLeft, normal, new Vector2(0, maxH), topColor);
        buffer.Add(topRight, normal, new Vector2(width, maxH), topColor);
        buffer.Add(bottomRight, normal, new Vector2(width, maxH - heightR), bottomColor);
        buffer.Add(bottomLeft, normal, new Vector2(0, maxH - heightL), bottomColor);
        // Unity wound (0,2,1) and (0,3,2); both are swapped for Godot's front-face convention.
        buffer.AddIndices(b, b + 1, b + 2);
        buffer.AddIndices(b, b + 2, b + 3);

        if (collision == null) return;
        int c = collision.VertexCount;
        collision.Add(topLeft, normal, new Vector2(0, maxH));
        collision.Add(topRight, normal, new Vector2(width, maxH));
        collision.Add(bottomRight, normal, new Vector2(width, maxH - heightR));
        collision.Add(bottomLeft, normal, new Vector2(0, maxH - heightL));
        collision.AddIndices(c, c + 1, c + 2);
        collision.AddIndices(c, c + 2, c + 3);
    }

    // ────────────────────────────── Overlays ──────────────────────────────

    /// <summary>
    /// The tile's share of the top-surface lattice. Each tile owns its N and E edges; the boundary
    /// tiles also own the S (y == 0) and W (x == 0) edges, so the map gets a closed grid with no line
    /// drawn twice.
    /// </summary>
    private static void AddTileGridLines(
        SubmeshBuffer buffer, int x, int y,
        Vector3 vSW, Vector3 vSE, Vector3 vNE, Vector3 vNW, float lineWidth)
    {
        AddTopGridLine(buffer, CardinalDirection.North, vSW, vSE, vNE, vNW, lineWidth);
        AddTopGridLine(buffer, CardinalDirection.East, vSW, vSE, vNE, vNW, lineWidth);
        if (y == 0) AddTopGridLine(buffer, CardinalDirection.South, vSW, vSE, vNE, vNW, lineWidth);
        if (x == 0) AddTopGridLine(buffer, CardinalDirection.West, vSW, vSE, vNE, vNW, lineWidth);
    }

    /// <summary>
    /// A thin strip along one tile edge, lying on the top face and lifted clear of it. Follows the
    /// corner heights, so it works on slopes as well as flats.
    /// </summary>
    private static void AddTopGridLine(
        SubmeshBuffer buffer, CardinalDirection dir,
        Vector3 vSW, Vector3 vSE, Vector3 vNE, Vector3 vNW, float lineWidth)
    {
        (Vector3 outerA, Vector3 outerB, Vector3 innerA, Vector3 innerB) =
            InsetEdge(dir, vSW, vSE, vNE, vNW, lineWidth);
        AddLiftedStrip(buffer, outerA, outerB, innerA, innerB, GridLineYOffset);
    }

    /// <summary>
    /// A darker, wider strip along a cliff LIP: the same inset band as a grid line, but only on edges
    /// where the tile actually stands above its neighbour. Shoreline edges are skipped — a hard dark
    /// line at the water boundary reads as a defect rather than as depth.
    /// </summary>
    private static void AddEdgeStrip(
        MapLayout layout, int x, int y, CardinalDirection dir, TileCornerHeights corners,
        Vector3 vSW, Vector3 vSE, Vector3 vNE, Vector3 vNW, float stripWidth, SubmeshBuffer buffer)
    {
        (int thisA, int thisB) = corners.EdgeCorners(dir);
        int neighborA = 0, neighborB = 0;
        (int nx, int ny) = Step(x, y, dir);

        if (layout.IsInBounds(nx, ny) && layout.GetTile(nx, ny) != TileRole.Empty)
        {
            var neighborRole = layout.GetTile(nx, ny);
            if (neighborRole == TileRole.Water) return;

            if (neighborRole == TileRole.Bridge)
            {
                int bridgeFloor = FindBridgeFloorHeight(layout, nx, ny);
                neighborA = bridgeFloor;
                neighborB = bridgeFloor;
            }
            else
            {
                (int nA, int nB) = layout.GetCornerHeights(nx, ny).EdgeCorners(Opposite(dir));
                neighborA = nB;
                neighborB = nA;
            }
        }

        if (thisA <= neighborA && thisB <= neighborB) return;

        (Vector3 outerA, Vector3 outerB, Vector3 innerA, Vector3 innerB) =
            InsetEdge(dir, vSW, vSE, vNE, vNW, stripWidth);
        AddLiftedStrip(buffer, outerA, outerB, innerA, innerB, EdgeStripYOffset);
    }

    /// <summary>The outer (tile edge) and inner (inset) corner pairs of one edge band.</summary>
    private static (Vector3 outerA, Vector3 outerB, Vector3 innerA, Vector3 innerB) InsetEdge(
        CardinalDirection dir, Vector3 vSW, Vector3 vSE, Vector3 vNE, Vector3 vNW, float width) =>
        dir switch
        {
            CardinalDirection.North => (vNW, vNE, vNW.Lerp(vSW, width), vNE.Lerp(vSE, width)),
            CardinalDirection.South => (vSE, vSW, vSE.Lerp(vNE, width), vSW.Lerp(vNW, width)),
            CardinalDirection.East => (vNE, vSE, vNE.Lerp(vNW, width), vSE.Lerp(vSW, width)),
            _ => (vSW, vNW, vSW.Lerp(vSE, width), vNW.Lerp(vNE, width)),
        };

    /// <summary>An up-facing band lifted clear of the surface it overlays. Never joins the collider.</summary>
    private static void AddLiftedStrip(
        SubmeshBuffer buffer, Vector3 outerA, Vector3 outerB, Vector3 innerA, Vector3 innerB, float yOffset)
    {
        var up = new Vector3(0, yOffset, 0);
        AddOverlayQuad(buffer, innerA + up, innerB + up, outerB + up, outerA + up, Vector3.Up);
    }

    /// <summary>
    /// Thin horizontal bands across a cliff face at every cubic-unit boundary it spans, plus one
    /// vertical band on the quad's left edge. The horizontals read as mortar joints between stacked
    /// blocks — a player can count how many elevations a drop is worth — and the verticals mark the
    /// tile boundary. Band heights come from a world-Y grid, not from the quad, so bands on adjacent
    /// wall segments line up regardless of per-corner slope.
    /// </summary>
    private static void AddCliffBands(
        SubmeshBuffer buffer, Vector3 topLeft, Vector3 topRight, Vector3 bottomRight, Vector3 bottomLeft,
        float hs, float bandThickness)
    {
        // One cubic unit in world Y: 2 elevations, which is exactly one tile of horizontal size.
        float cubeWorldY = TileCornerHeights.UnitsPerElevation * hs * 2f;
        if (cubeWorldY <= 0f) return;

        float topY = MathF.Max(topLeft.Y, topRight.Y);
        float botY = MathF.Min(bottomLeft.Y, bottomRight.Y);
        if (topY - botY < bandThickness) return;

        Vector3 edge1 = topRight - topLeft;
        Vector3 edge2 = bottomLeft - topLeft;
        Vector3 normal = edge2.Cross(edge1);
        if (normal.LengthSquared() < 1e-8f)
            normal = (bottomRight - topRight).Cross(edge1);
        if (normal.LengthSquared() < 1e-8f) return;
        normal = normal.Normalized();

        Vector3 outward = normal * CliffBandOffset;
        float halfT = bandThickness * 0.5f;
        float skip = halfT + 0.001f;

        float firstBand = MathF.Floor((topY - skip) / cubeWorldY) * cubeWorldY;
        for (float bandY = firstBand; bandY > botY + skip; bandY -= cubeWorldY)
        {
            if (topY - bandY < skip) continue;

            Vector3 leftAtY = InterpolateY(topLeft, bottomLeft, bandY);
            Vector3 rightAtY = InterpolateY(topRight, bottomRight, bandY);
            if ((rightAtY - leftAtY).LengthSquared() < 1e-6f) continue;

            var up = new Vector3(0, halfT, 0);
            AddOverlayQuad(buffer,
                leftAtY + up + outward, rightAtY + up + outward,
                rightAtY - up + outward, leftAtY - up + outward, normal);
        }

        // Vertical tile-boundary line. Each wall quad spans exactly one tile horizontally, so its LEFT
        // edge is a shared boundary; the neighbour's left-edge line covers the other one. A wall on the
        // map boundary gets a single line, which is correct.
        Vector3 horiz = topRight - topLeft;
        float tileWidth = horiz.Length();
        if (tileWidth <= 0.0001f) return;

        Vector3 inward = horiz / tileWidth * (bandThickness * 0.5f);
        Vector3 tOuter = topLeft + outward;
        Vector3 bOuter = bottomLeft + outward;
        if ((tOuter - bOuter).LengthSquared() <= 1e-6f) return;

        AddOverlayQuad(buffer, tOuter, tOuter + inward, bOuter + inward, bOuter, normal);
    }

    /// <summary>
    /// Interpolate down the edge from <paramref name="top"/> to <paramref name="bottom"/> to the point
    /// at <paramref name="targetY"/>. A vertical-collapsed edge snaps to the top.
    /// </summary>
    private static Vector3 InterpolateY(Vector3 top, Vector3 bottom, float targetY)
    {
        float dy = top.Y - bottom.Y;
        if (dy < 0.0001f) return top;
        return top.Lerp(bottom, Math.Clamp((top.Y - targetY) / dy, 0f, 1f));
    }

    /// <summary>
    /// Four vertices, two triangles, one shared normal — the flat overlay quad every overlay uses.
    /// Vertices are given in Unity's front-face order and wound for Godot. Overlays never contribute to
    /// the collision mesh: they are decoration lying on faces that are already in it.
    /// </summary>
    private static void AddOverlayQuad(
        SubmeshBuffer buffer, Vector3 v0, Vector3 v1, Vector3 v2, Vector3 v3, Vector3 normal)
    {
        int b = buffer.VertexCount;
        buffer.Add(v0, normal, new Vector2(0, 0));
        buffer.Add(v1, normal, new Vector2(1, 0));
        buffer.Add(v2, normal, new Vector2(1, 1));
        buffer.Add(v3, normal, new Vector2(0, 1));
        buffer.AddIndices(b, b + 1, b + 2);
        buffer.AddIndices(b, b + 2, b + 3);
    }

    // ────────────────────────────── Edge geometry helpers ──────────────────────────────

    private static (int x, int y) Step(int x, int y, CardinalDirection dir) => dir switch
    {
        CardinalDirection.North => (x, y + 1),
        CardinalDirection.South => (x, y - 1),
        CardinalDirection.East => (x + 1, y),
        CardinalDirection.West => (x - 1, y),
        _ => (x, y),
    };

    private static CardinalDirection Opposite(CardinalDirection dir) => dir switch
    {
        CardinalDirection.North => CardinalDirection.South,
        CardinalDirection.South => CardinalDirection.North,
        CardinalDirection.East => CardinalDirection.West,
        CardinalDirection.West => CardinalDirection.East,
        _ => dir,
    };

    /// <summary>Corner-grid positions of an edge's two corners, in the same A/B order as <c>EdgeCorners</c>.</summary>
    private static (int vxA, int vyA, int vxB, int vyB) GetEdgeVertexPositions(int x, int y, CardinalDirection dir) =>
        dir switch
        {
            CardinalDirection.North => (x, y + 1, x + 1, y + 1),
            CardinalDirection.South => (x + 1, y, x, y),
            CardinalDirection.East => (x + 1, y + 1, x + 1, y),
            CardinalDirection.West => (x, y, x, y + 1),
            _ => (0, 0, 0, 0),
        };

    /// <summary>World corners of a wall face on a tile edge. No centering offset: tile (0,0) starts at the origin.</summary>
    private static (Vector3 topLeft, Vector3 topRight, Vector3 bottomLeft, Vector3 bottomRight)
        GetEdgeWorldPositions(int x, int y, CardinalDirection dir,
            int topA, int topB, int bottomA, int bottomB, float hs)
    {
        float wx = x;
        float wz = y;

        return dir switch
        {
            CardinalDirection.North => (
                new Vector3(wx, topA * hs, wz + 1),
                new Vector3(wx + 1, topB * hs, wz + 1),
                new Vector3(wx, bottomA * hs, wz + 1),
                new Vector3(wx + 1, bottomB * hs, wz + 1)),
            CardinalDirection.South => (
                new Vector3(wx + 1, topA * hs, wz),
                new Vector3(wx, topB * hs, wz),
                new Vector3(wx + 1, bottomA * hs, wz),
                new Vector3(wx, bottomB * hs, wz)),
            CardinalDirection.East => (
                new Vector3(wx + 1, topA * hs, wz + 1),
                new Vector3(wx + 1, topB * hs, wz),
                new Vector3(wx + 1, bottomA * hs, wz + 1),
                new Vector3(wx + 1, bottomB * hs, wz)),
            CardinalDirection.West => (
                new Vector3(wx, topA * hs, wz),
                new Vector3(wx, topB * hs, wz + 1),
                new Vector3(wx, bottomA * hs, wz),
                new Vector3(wx, bottomB * hs, wz + 1)),
            _ => (Vector3.Zero, Vector3.Zero, Vector3.Zero, Vector3.Zero),
        };
    }

    /// <summary>
    /// Minimum corner height at every position of the (Width+1) x (Height+1) vertex grid. Walls use it
    /// for their bottoms so faces from different edges meeting at one corner all reach the same depth.
    /// Positions no tile touches settle at 0.
    /// </summary>
    public static int[] ComputeMinCornerGrid(MapLayout layout)
    {
        int w = layout.Width;
        int h = layout.Height;
        int cw = w + 1;
        var minCornerH = new int[cw * (h + 1)];
        for (int i = 0; i < minCornerH.Length; i++) minCornerH[i] = int.MaxValue;

        for (int x = 0; x < w; x++)
        {
            for (int y = 0; y < h; y++)
            {
                if (layout.GetTile(x, y) == TileRole.Empty) continue;
                var c = layout.GetCornerHeights(x, y);

                minCornerH[y * cw + x] = Math.Min(minCornerH[y * cw + x], c.SW);
                minCornerH[y * cw + (x + 1)] = Math.Min(minCornerH[y * cw + (x + 1)], c.SE);
                minCornerH[(y + 1) * cw + x] = Math.Min(minCornerH[(y + 1) * cw + x], c.NW);
                minCornerH[(y + 1) * cw + (x + 1)] = Math.Min(minCornerH[(y + 1) * cw + (x + 1)], c.NE);
            }
        }

        for (int i = 0; i < minCornerH.Length; i++)
            if (minCornerH[i] == int.MaxValue) minCornerH[i] = 0;

        return minCornerH;
    }

    /// <summary>
    /// Height beneath a bridge tile: the lowest relevant cardinal neighbour, or the canyon floor when
    /// the span crosses void. In corner-height units. Sizes both the pillars and the cliff faces of the
    /// tiles that approach the span.
    /// </summary>
    private static int FindBridgeFloorHeight(MapLayout layout, int x, int y)
    {
        var bridgeCorners = layout.GetCornerHeights(x, y);
        int slabBottom = RoundToInt(bridgeCorners.CenterHeight) - BridgeSlabThickness;

        bool hasVoid = false;
        int lowestNeighbor = slabBottom;

        foreach (var dir in Cardinals)
        {
            (int nx, int ny) = Step(x, y, dir);
            if (!layout.IsInBounds(nx, ny) || layout.GetTile(nx, ny) == TileRole.Empty)
            {
                hasVoid = true;
                continue;
            }

            if (layout.GetTile(nx, ny) == TileRole.Bridge) continue;

            int neighborMin = layout.GetCornerHeights(nx, ny).MinHeight;
            if (neighborMin < lowestNeighbor) lowestNeighbor = neighborMin;
        }

        return hasVoid ? Math.Min(lowestNeighbor, VoidFloorCornerHeight) : lowestNeighbor;
    }

    /// <summary>
    /// Corner height of the water a bridge spans, for the fill drawn under its slab. Searches outward
    /// on each cardinal, crossing further bridge tiles, because a mid-span tile can be several tiles
    /// from the nearest open water. Falls back to four units below the deck.
    /// </summary>
    private static int FindAdjacentWaterCornerHeight(MapLayout layout, int x, int y)
    {
        int bridgeH = RoundToInt(layout.GetCornerHeights(x, y).CenterHeight);
        int fallback = Math.Max(0, bridgeH - 4);

        foreach (var dir in Cardinals)
        {
            (int nx, int ny) = Step(x, y, dir);
            for (int step = 0; step < 8; step++)
            {
                if (!layout.IsInBounds(nx, ny)) break;
                var role = layout.GetTile(nx, ny);
                if (role == TileRole.Water)
                    return RoundToInt(layout.GetCornerHeights(nx, ny).CenterHeight);
                if (role != TileRole.Bridge) break;
                (nx, ny) = Step(nx, ny, dir);
            }
        }

        return fallback;
    }

    /// <summary>True when any cardinal neighbour of (x, y) is an Empty tile.</summary>
    private static bool IsBridgeOverVoid(MapLayout layout, int x, int y)
    {
        foreach (var dir in Cardinals)
        {
            (int nx, int ny) = Step(x, y, dir);
            if (!layout.IsInBounds(nx, ny)) continue;
            if (layout.GetTile(nx, ny) == TileRole.Empty) return true;
        }
        return false;
    }

    /// <summary>Banker's rounding, matching Unity's Mathf.RoundToInt (and TileData.EffectiveHeight).</summary>
    private static int RoundToInt(float value) => (int)Math.Round((double)value);

    // ────────────────────────────── Buffers and palette ──────────────────────────────

    /// <summary>
    /// Emit one triangle. <paramref name="a"/>/<paramref name="b"/>/<paramref name="c"/> are in UNITY
    /// front-face order; the 2nd and 3rd indices are swapped so the same face is front-facing in Godot.
    /// This is the single place the winding flip happens for triangle-at-a-time geometry;
    /// <paramref name="faceDown"/> keeps the Unity order instead, which points the face the other way
    /// (its <paramref name="normal"/> arrives already negated).
    /// </summary>
    private static void AddTriangle(
        SubmeshBuffer buffer, SubmeshBuffer? collision,
        Vector3 a, Vector3 b, Vector3 c, Vector3 normal, Vector2 uvA, Vector2 uvB, Vector2 uvC,
        bool faceDown = false)
    {
        int i = buffer.VertexCount;
        buffer.Add(a, normal, uvA);
        buffer.Add(b, normal, uvB);
        buffer.Add(c, normal, uvC);
        if (faceDown) buffer.AddIndices(i, i + 1, i + 2);
        else buffer.AddIndices(i, i + 2, i + 1);

        if (collision == null) return;
        int j = collision.VertexCount;
        collision.Add(a, normal, uvA);
        collision.Add(b, normal, uvB);
        collision.Add(c, normal, uvC);
        if (faceDown) collision.AddIndices(j, j + 1, j + 2);
        else collision.AddIndices(j, j + 2, j + 1);
    }

    private enum FaceKind
    {
        Top,
        Wall,
        TopGridLine,
        EdgeStrip,
        CliffBand,
    }

    private readonly record struct PaletteKey(SurfaceType Surface, FaceKind Kind)
    {
        /// <summary>Diagnostic name. Overlays are surface-independent, so they drop the surface half.</summary>
        public string Describe() => Kind switch
        {
            FaceKind.Top or FaceKind.Wall => $"{Surface}:{Kind}",
            _ => Kind.ToString(),
        };
    }

    /// <summary>
    /// Routes geometry to one buffer per (surface, face kind) pair, in first-use order. Unity keyed its
    /// submeshes by Material identity; keying by the pair is equivalent under a palette that gives each
    /// surface its own colour, and it keeps the top/wall split readable for the spike's normal checks.
    /// The three overlay kinds ignore the surface — they are one material each, map-wide, exactly as in
    /// Unity's palette. The (surface, x, y) signature is kept so per-tile material variants can return
    /// without touching call sites.
    /// </summary>
    private sealed class SurfacePalette
    {
        private readonly Dictionary<PaletteKey, SubmeshBuffer> _byKey = new();
        private readonly List<(PaletteKey Key, SubmeshBuffer Buffer)> _order = new();

        public IReadOnlyList<(PaletteKey Key, SubmeshBuffer Buffer)> Buffers => _order;

        /// <summary>Triangles emitted so far across every buffer. Used to attribute the bridge pass.</summary>
        public int TriangleTotal
        {
            get
            {
                int total = 0;
                foreach (var (_, buffer) in _order) total += buffer.TriangleCount;
                return total;
            }
        }

        public SubmeshBuffer Top(SurfaceType surface, int x, int y) => Get(new PaletteKey(surface, FaceKind.Top));

        public SubmeshBuffer Wall(SurfaceType surface, int x, int y) => Get(new PaletteKey(surface, FaceKind.Wall));

        public SubmeshBuffer Overlay(FaceKind kind) => Get(new PaletteKey(default, kind));

        private SubmeshBuffer Get(PaletteKey key)
        {
            if (_byKey.TryGetValue(key, out var buffer)) return buffer;
            buffer = new SubmeshBuffer();
            _byKey[key] = buffer;
            _order.Add((key, buffer));
            return buffer;
        }
    }

    /// <summary>One mesh surface under construction: parallel vertex attributes plus an index list.</summary>
    private sealed class SubmeshBuffer
    {
        private readonly List<Vector3> _verts = new();
        private readonly List<Vector3> _norms = new();
        private readonly List<Vector2> _uvs = new();
        private readonly List<Color> _colors = new();
        private readonly List<int> _indices = new();

        public int VertexCount => _verts.Count;

        public int TriangleCount => _indices.Count / 3;

        public bool IsEmpty => _indices.Count == 0;

        /// <summary>Add a vertex with the default colour: white, i.e. full wave on a water surface.</summary>
        public void Add(Vector3 vertex, Vector3 normal, Vector2 uv) => Add(vertex, normal, uv, VertexWhite);

        public void Add(Vector3 vertex, Vector3 normal, Vector2 uv, Color color)
        {
            _verts.Add(vertex);
            _norms.Add(normal);
            _uvs.Add(uv);
            _colors.Add(color);
        }

        public void AddIndices(int a, int b, int c)
        {
            _indices.Add(a);
            _indices.Add(b);
            _indices.Add(c);
        }

        /// <summary>Pack into the array layout <c>ArrayMesh.AddSurfaceFromArrays</c> expects. int32 indices, no tangents.</summary>
        public Godot.Collections.Array ToArrays()
        {
            var arrays = new Godot.Collections.Array();
            arrays.Resize((int)Mesh.ArrayType.Max);
            arrays[(int)Mesh.ArrayType.Vertex] = _verts.ToArray();
            arrays[(int)Mesh.ArrayType.Normal] = _norms.ToArray();
            arrays[(int)Mesh.ArrayType.TexUV] = _uvs.ToArray();
            arrays[(int)Mesh.ArrayType.Color] = _colors.ToArray();
            arrays[(int)Mesh.ArrayType.Index] = _indices.ToArray();
            return arrays;
        }
    }
}
