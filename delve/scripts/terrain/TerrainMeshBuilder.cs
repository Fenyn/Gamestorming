using System;
using Delve.Data;
using Godot;
using PF2e.Grid;
using PF2e.MapGen;

namespace Delve.Terrain;

/// <summary>
/// Turns a generated <see cref="MapLayout"/> into the two meshes a battle map needs: a multi-surface
/// visual <see cref="ArrayMesh"/> with its materials baked on, and a single-surface collision
/// <see cref="ArrayMesh"/> for the trimesh picker. Static and pure — no scene, no state, no RNG.
///
/// This class owns the tile loop only. It builds one <see cref="TerrainBuildContext"/> and calls the
/// per-feature passes (<see cref="GroundPass"/>, <see cref="BridgePass"/>, <see cref="WaterPass"/>,
/// <see cref="CliffPass"/>) in a fixed order, because the palette assigns surface indices in
/// first-touch order. Vertex maths lives in <see cref="TerrainGeometry"/>, layout reads in
/// <see cref="LayoutQueries"/>.
///
/// Ported from the Unity Tactics <c>TileMeshBuilder</c>, with five deliberate differences:
///
/// 1. <b>Winding is flipped on every triangle.</b> A triangle (a, b, c) is front-facing in Unity when
///    <c>Cross(b-a, c-a)</c> points at the viewer, and in Godot when it points AWAY (Godot's
///    right-handed space inverts the relationship). Emitting the Unity vertex order with the 2nd and
///    3rd indices swapped keeps the same face pointing outward. The explicit normal math ports
///    unchanged, so a triangle's stored normal and its geometric front normal agree.
/// 2. <b>Down-facing faces get down-facing normals.</b> Unity's <c>AddQuad</c> always flipped its normal
///    upward, so bridge undersides and pillar bottom caps shipped with normals pointing into the slab.
///    Here <c>faceDown</c> negates the normal along with the winding: the stored normal keeps agreeing
///    with the geometry, and an underside is lit like an underside — ambient, not sunlit.
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

    /// <summary>The two meshes plus their surface, vertex and triangle totals.</summary>
    public sealed record Result
    {
        /// <summary>Multi-surface render mesh; every surface already carries its material.</summary>
        public required ArrayMesh Visual { get; init; }

        /// <summary>Single-surface mesh for <c>CreateTrimeshShape()</c>: tops, cliff walls and void floors.</summary>
        public required ArrayMesh Collision { get; init; }

        /// <summary>Surfaces on <see cref="Visual"/> — equals the number of baked materials.</summary>
        public required int SurfaceCount { get; init; }

        /// <summary>Total vertices across all visual surfaces.</summary>
        public required int VertexCount { get; init; }

        /// <summary>Total triangles across all visual surfaces.</summary>
        public required int TriangleCount { get; init; }
    }

    /// <summary>
    /// Build the terrain meshes for a layout under a theme. Deterministic: the same layout and theme
    /// always produce byte-identical arrays in the same surface order.
    /// </summary>
    /// <param name="options">Where the layout sits in the world and which of its tiles get grid
    /// lines. Null = the layout IS the board, at the world origin, gridded end to end.</param>
    /// <param name="debug">Optional sink for the cliff faces the build emits — see
    /// <see cref="TerrainDebugFaces"/>. Null (the normal case) records nothing.</param>
    public static Result Build(
        MapLayout layout, MapThemeDefinition theme,
        TerrainMeshOptions? options = null, TerrainDebugFaces? debug = null)
    {
        ArgumentNullException.ThrowIfNull(layout);
        ArgumentNullException.ThrowIfNull(theme);

        int w = layout.Width;
        int h = layout.Height;

        var ctx = new TerrainBuildContext
        {
            Layout = layout,
            Theme = theme,
            HeightScale = theme.HeightScale,
            Width = w,
            Height = h,
            EffectiveSurfaces = EffectiveSurfaceGrid.Build(layout),
            Palette = new SurfacePalette(),
            Collision = new MeshBuffer(),
            Debug = debug,
            GridLines = options?.GridLineRect ?? new TileRect(0, 0, w, h),
        };

        // The pass order below is load-bearing: the palette numbers its surfaces in first-touch order,
        // so moving a pass renames every surface after it.
        for (int x = 0; x < w; x++)
        {
            for (int y = 0; y < h; y++)
            {
                TileRole role = layout.GetTile(x, y);
                if (role == TileRole.Empty)
                {
                    GroundPass.RenderVoidTile(ctx, x, y);
                    continue;
                }

                var corners = layout.GetCornerHeights(x, y);
                SurfaceType surface = ctx.SurfaceAt(x, y);
                (Vector3 vSW, Vector3 vSE, Vector3 vNE, Vector3 vNW) = ctx.CornerWorld(x, y, corners);

                GroundPass.Render(ctx, x, y, role, surface, vSW, vSE, vNE, vNW);

                if (role == TileRole.Bridge)
                {
                    BridgePass.Render(ctx, x, y, corners, surface, vSW, vSE, vNE, vNW);
                    continue;
                }

                if (role == TileRole.Water)
                {
                    WaterPass.Render(ctx, x, y, corners, vSW, vSE, vNE, vNW);
                    continue;
                }

                CliffPass.Render(ctx, x, y, corners, surface, vSW, vSE, vNE, vNW);
            }
        }

        // One autotiled ground texture spans the board; every non-water top face shares it. Baked
        // here rather than inside Assemble so the build reads as its two steps: fill the buffers,
        // then bake the ground texture and assemble the meshes around it. Null (a theme with no
        // textured surfaces) keeps the per-surface flat-colour path.
        var bakedGround = GroundTextureBaker.Bake(
            layout, theme, ctx.EffectiveSurfaces, options?.WorldOrigin ?? Vector2.Zero);

        return Assemble(ctx, bakedGround);
    }

    // ────────────────────────────── Mesh assembly ──────────────────────────────

    private static Result Assemble(TerrainBuildContext ctx, Material? bakedGround)
    {
        var layout = ctx.Layout;
        var visual = new ArrayMesh { ResourceName = $"terrain_{layout.Name ?? "map"}" };
        int vertexCount = 0;
        int triangleCount = 0;
        int surfaceIndex = 0;

        // Empty-surface compaction: Godot's AddSurfaceFromArrays rejects an empty vertex array, so a
        // palette slot that never received geometry (a biome with no water, say) is dropped and the
        // baked materials follow the surviving order.
        foreach (var (key, buffer) in ctx.Palette.Buffers)
        {
            if (buffer.IsEmpty) continue;

            buffer.AppendTo(visual, MaterialFor(ctx.Theme, key, bakedGround));

            vertexCount += buffer.VertexCount;
            triangleCount += buffer.TriangleCount;
            surfaceIndex++;
        }

        var collisionMesh = ctx.Collision.ToArrayMesh($"terrain_collision_{layout.Name ?? "map"}");

        return new Result
        {
            Visual = visual,
            Collision = collisionMesh,
            SurfaceCount = surfaceIndex,
            VertexCount = vertexCount,
            TriangleCount = triangleCount,
        };
    }

    private static Material MaterialFor(MapThemeDefinition theme, PaletteKey key, Material? bakedGround) => key.Kind switch
    {
        FaceKind.Top when key.Surface != SurfaceType.Water && bakedGround != null => bakedGround,
        FaceKind.Top => MapMaterials.Top(theme, key.Surface),
        FaceKind.Wall => MapMaterials.Wall(theme, key.Surface),
        FaceKind.TopGridLine => MapMaterials.Overlay(theme.TopGridLineColor, "terrain_grid_line"),
        FaceKind.EdgeStrip => MapMaterials.Overlay(theme.EdgeStripColor, "terrain_edge_strip"),
        _ => MapMaterials.Overlay(theme.CliffBandColor, "terrain_cliff_band"),
    };
}
