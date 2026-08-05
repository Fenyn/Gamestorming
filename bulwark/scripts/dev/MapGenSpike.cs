using System;
using System.Collections.Generic;
using Bulwark.Combat.Map;
using Bulwark.Data;
using Godot;
using PF2e.Grid;
using PF2e.MapGen;
using PF2e.MapGen.Biomes;
using PF2eVec = PF2e.Vector2Int;

namespace Bulwark.Dev;

/// <summary>
/// Headless proof for the 3D battle-map slice: every shipped biome, over a spread of seeds, generates
/// a layout that <see cref="TerrainMeshBuilder"/> turns into well-formed Godot meshes, and the same
/// layout populates a BattleGrid that agrees with it.
///
///  (1) Mesh well-formedness — per surface: index count divisible by 3, indices inside the vertex
///      range, vertex/normal/uv/colour arrays the same length, unit normals.
///  (2) Winding — the top visual risk of a Unity→Godot geometry port. Checked arithmetically rather
///      than by screenshot: for every triangle, the GODOT front-face normal (Cross(c-a, b-a), which is
///      the negation of Unity's convention) must point the same way as the normal the builder stored.
///      A missed flip inverts the sign on every triangle and this fails immediately.
///  (3) Shape sanity — top-face surfaces are up-facing, no vertex escapes the band between the void
///      floor and the tallest possible wall, materials are baked one per surviving surface, and the
///      collision mesh is non-empty.
///  (4) Determinism — the same (biome, seed) twice gives identical counts and an identical FNV-1a hash
///      over vertex positions.
///  (5) Grid consistency — GenerateBattle's grid matches its layout: walkable tiles are standable with
///      matching corner heights, Wall is Inaccessible, Empty has no tile at all.
///  (6) Deployment — two zones, and DeploymentPlanner anchors that are distinct and walkable.
///  (7) Scene assembly — MapView3D.Build produces a terrain MeshInstance3D and a trimesh StaticBody3D
///      under the headless dummy renderer.
///  (8) Feature geometry — a Bridge tile emits geometry under its deck; map-edge water, and only
///      map-edge water, emits wave-locked vertices, on the water surface and nowhere else; water tops
///      carry the wave ShaderMaterial while everything else stays StandardMaterial3D; the overlay
///      surfaces are present, non-empty and unshaded-alpha at render priority 1. The block closes with
///      a cross-biome coverage check, so none of it can quietly pass by never firing.
///
/// Results are aggregated per biome: one [PASS]/[FAIL] per invariant, with the first few offending
/// (seed, detail) pairs printed under a failure. Prints a final SPIKE RESULT line.
/// </summary>
public partial class MapGenSpike : SpikeBase
{
    private static readonly int[] Seeds = { 1, 7, 42, 101, 555, 1337, 99999, 20260804 };

    /// <summary>
    /// Slack on the vertex-Y bounds for the overlay decals, which lie on terrain faces but stick out by
    /// their own thickness: a mortar band is 0.03 tall and stands 0.003 off the wall, and the vertical
    /// tile-boundary strip is inset along a top edge that may be sloped, so its lower end can sit a few
    /// millimetres past the wall's bottom. Cheaper than exempting the overlay surfaces from the check.
    /// </summary>
    private const float OverlayMargin = 0.05f;

    /// <summary>Lowest legal vertex Y: the canyon floor void tiles and void-facing walls drop to.</summary>
    private static readonly float MinVertexY =
        TerrainMeshBuilder.VoidFloorCornerHeight * MapThemes.DefaultHeightScale - OverlayMargin;

    /// <summary>
    /// Highest legal vertex Y. Shipped biomes cap at MaxElevation 6 with wall heights of 8-16 corner
    /// units; 8 elevations of wall slack on top of the 6 covers both with room to spare.
    /// </summary>
    private static readonly float MaxVertexY =
        (6 + 8) * TileCornerHeights.UnitsPerElevation * MapThemes.DefaultHeightScale + OverlayMargin;

    private const string InvLayout = "layout generated (sized, tiles present)";
    private const string InvSurfaces = "visual mesh has surfaces";
    private const string InvIndexMod3 = "surface index counts divisible by 3";
    private const string InvIndexRange = "indices inside vertex range";
    private const string InvArrayLen = "vertex/normal/uv/colour lengths match per surface";
    private const string InvUnitNormals = "normals unit length (+/- 0.01)";
    private const string InvWinding = "triangle winding agrees with stored normal";
    private const string InvTopFaces = "top-face surfaces >= 60% up-facing (normal.Y > 0.5)";
    private const string InvNormalFloor = "no normal Y below -1.01";
    private const string InvYBounds = "vertex Y inside [void floor, max wall height]";
    private const string InvMaterials = "SurfaceCount == baked material count";
    private const string InvCollision = "collision mesh non-empty";
    private const string InvDeterminism = "same (biome, seed) -> identical counts + position hash";
    private const string InvGridWalkable = "walkable tile -> standable grid tile with matching corners";
    private const string InvGridWall = "Wall -> Inaccessible grid tile";
    private const string InvGridEmpty = "Empty -> no grid tile";
    private const string InvZones = "two deployment zones with distinct walkable anchors";
    private const string InvView = "MapView3D.Build assembles terrain + trimesh body";
    private const string InvVertexAlpha = "vertex colour alpha is 0 or 1, locked only on water tops";
    private const string InvWaterMaterial = "water tops use the wave shader, other surfaces do not";
    private const string InvOverlayMaterial = "overlay surfaces are unshaded alpha at render priority 1";
    private const string InvGridLines = "top-grid-line overlay surface non-empty";
    private const string InvBridge = "bridge tiles emit under-deck geometry (and none is emitted without them)";
    private const string InvSkirt = "wave-locked vertices appear exactly when water reaches the map edge";

    private static readonly string[] Invariants =
    {
        InvLayout, InvSurfaces, InvIndexMod3, InvIndexRange, InvArrayLen, InvUnitNormals, InvWinding,
        InvTopFaces, InvNormalFloor, InvYBounds, InvMaterials, InvCollision, InvDeterminism,
        InvGridWalkable, InvGridWall, InvGridEmpty, InvZones, InvView,
        InvVertexAlpha, InvWaterMaterial, InvOverlayMaterial, InvGridLines, InvBridge, InvSkirt,
    };

    /// <summary>Under-deck triangles a Bridge tile always owes: its slab underside plus its under-span fill.</summary>
    private const int MinBridgeTrianglesPerTile = 4;

    // Cross-biome coverage. The feature invariants above only fire on a layout that actually contains
    // the feature, so a run where no biome ever produced a bridge would pass them all without testing
    // anything; these turn that into a failure.
    private bool _sawBridgeGeometry;
    private bool _sawLockedWaveVertices;
    private bool _sawEdgeStrips;
    private bool _sawCliffBands;

    public override void _Ready()
    {
        GD.Print("==================== MAP GEN SPIKE ====================");
        try
        {
            Run();
        }
        catch (Exception e)
        {
            GD.PushError($"[MapGenSpike] Unhandled exception: {e}");
            Fail();
        }

        FinishAndQuit("MapGenSpike");
    }

    private void Run()
    {
        GD.Print("-------------------- (0) Catalogs --------------------");
        var registryErrors = MapGenRegistry.Validate();
        Check("(0) MapGenRegistry.Validate() reports no catalog defects", registryErrors.Count == 0);
        foreach (var error in registryErrors) GD.Print($"        · {error}");

        var biomes = MapGenRegistry.AllBiomes;
        Check("(0) registry ships at least one biome", biomes.Count > 0);

        foreach (var biome in biomes)
        {
            bool themed = MapThemes.TryGet(biome.Id, out _);
            Check($"(0) biome '{biome.Id}' has a MapThemes entry", themed);
        }

        foreach (var biome in biomes)
            RunBiome(biome.Id);

        GD.Print("-------------------- (9) feature coverage --------------------");
        Check("(9) some seed produced bridge geometry", _sawBridgeGeometry);
        Check("(9) some seed produced wave-locked water skirt vertices", _sawLockedWaveVertices);
        Check("(9) some seed produced cliff edge strips", _sawEdgeStrips);
        Check("(9) some seed produced cliff mortar bands", _sawCliffBands);
    }

    private void RunBiome(string biomeId)
    {
        GD.Print($"-------------------- ({biomeId}) {Seeds.Length} seeds --------------------");
        var theme = MapThemes.Get(biomeId);
        var log = new InvariantLog(Invariants);

        int totalTris = 0;
        int totalVerts = 0;
        int degenerate = 0;
        int maxSurfaces = 0;
        int bridgeTiles = 0;
        int edgeWaterTiles = 0;
        int bridgeTris = 0;

        foreach (int seed in Seeds)
        {
            var layout = MapGenerator.Generate(biomeId, seed);
            log.Expect(InvLayout, seed,
                layout != null && layout.Width > 0 && layout.Height > 0 && layout.Tiles != null
                && layout.Tiles.Length == layout.Width * layout.Height,
                "layout missing or malformed");
            if (layout == null || layout.Tiles == null) continue;

            var built = TerrainMeshBuilder.Build(layout, theme);
            totalTris += built.TriangleCount;
            totalVerts += built.VertexCount;
            maxSurfaces = Math.Max(maxSurfaces, built.SurfaceCount);
            bridgeTris += built.BridgeTriangleCount;

            var tally = InspectMesh(log, seed, built);
            degenerate += tally.Degenerate;

            var counts = CountFeatureTiles(layout);
            bridgeTiles += counts.Bridge;
            edgeWaterTiles += counts.EdgeWater;
            InspectFeatures(log, seed, counts, built, tally);

            InspectDeterminism(log, seed, biomeId, theme, built);
            InspectGrid(log, seed, biomeId);
            InspectDeployment(log, seed, layout);
            InspectView(log, seed, layout, theme, built);
        }

        foreach (var (name, fails) in log.Results())
        {
            Check($"({biomeId}) {name}", fails.Count == 0);
            int shown = Math.Min(3, fails.Count);
            for (int i = 0; i < shown; i++) GD.Print($"        · {fails[i]}");
            if (fails.Count > shown) GD.Print($"        · ... and {fails.Count - shown} more");
        }

        GD.Print($"  [stats] surfaces<={maxSurfaces}  verts={totalVerts}  tris={totalTris}  "
                 + $"degenerate-tris={degenerate} (skipped by the winding check)");
        GD.Print($"  [stats] bridge tiles={bridgeTiles} (under-deck tris={bridgeTris})  "
                 + $"map-edge water tiles={edgeWaterTiles}");
    }

    /// <summary>Bridge tiles and water tiles that touch the map boundary — what the feature checks key off.</summary>
    private static (int Bridge, int EdgeWater) CountFeatureTiles(MapLayout layout)
    {
        int bridge = 0;
        int edgeWater = 0;
        for (int y = 0; y < layout.Height; y++)
        {
            for (int x = 0; x < layout.Width; x++)
            {
                var role = layout.GetTile(x, y);
                if (role == TileRole.Bridge) bridge++;
                if (role == TileRole.Water
                    && (x == 0 || y == 0 || x == layout.Width - 1 || y == layout.Height - 1))
                    edgeWater++;
            }
        }
        return (bridge, edgeWater);
    }

    /// <summary>
    /// The geometry contracts that need the layout as well as the mesh: bridges emit under-deck
    /// geometry in proportion to their tile count, and wave-locked vertices exist exactly when water
    /// reaches the map boundary (the only thing that draws a deep-edge skirt).
    /// </summary>
    private void InspectFeatures(
        InvariantLog log, int seed, (int Bridge, int EdgeWater) counts,
        TerrainMeshBuilder.Result built, MeshTally tally)
    {
        int wanted = counts.Bridge * MinBridgeTrianglesPerTile;
        log.Expect(InvBridge, seed, built.BridgeTriangleCount >= wanted,
            $"{counts.Bridge} bridge tiles but only {built.BridgeTriangleCount} under-deck triangles "
            + $"(want >= {wanted})");
        log.Expect(InvBridge, seed, counts.Bridge > 0 || built.BridgeTriangleCount == 0,
            $"no bridge tiles but {built.BridgeTriangleCount} under-deck triangles");

        log.Expect(InvSkirt, seed, counts.EdgeWater > 0 == tally.LockedVertices > 0,
            $"{counts.EdgeWater} map-edge water tiles vs {tally.LockedVertices} locked vertices");

        if (built.BridgeTriangleCount > 0) _sawBridgeGeometry = true;
        if (tally.LockedVertices > 0) _sawLockedWaveVertices = true;
        if (tally.SawEdgeStrips) _sawEdgeStrips = true;
        if (tally.SawCliffBands) _sawCliffBands = true;
    }

    // ─────────────────────────── Mesh inspection ───────────────────────────

    /// <summary>What one pass over the visual mesh learned, beyond the pass/fail of each invariant.</summary>
    private record struct MeshTally(
        int Degenerate, int LockedVertices, bool SawGridLines, bool SawEdgeStrips, bool SawCliffBands);

    /// <summary>Walks every surface of the visual mesh, checking it and tallying the feature geometry.</summary>
    private static MeshTally InspectMesh(InvariantLog log, int seed, TerrainMeshBuilder.Result built)
    {
        var mesh = built.Visual;
        int surfaces = mesh.GetSurfaceCount();

        log.Expect(InvSurfaces, seed, surfaces > 0, "visual mesh has no surfaces");
        log.Expect(InvMaterials, seed, surfaces == built.SurfaceCount,
            $"reported SurfaceCount {built.SurfaceCount} != mesh surfaces {surfaces}");
        log.Expect(InvMaterials, seed, built.SurfaceIsTop.Count == built.SurfaceCount,
            "SurfaceIsTop is not parallel to the surface list");

        var tally = new MeshTally();

        for (int s = 0; s < surfaces; s++)
        {
            var arrays = mesh.SurfaceGetArrays(s);
            var verts = arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array();
            var norms = arrays[(int)Mesh.ArrayType.Normal].AsVector3Array();
            var uvs = arrays[(int)Mesh.ArrayType.TexUV].AsVector2Array();
            var colors = arrays[(int)Mesh.ArrayType.Color].AsColorArray();
            var indices = arrays[(int)Mesh.ArrayType.Index].AsInt32Array();
            string name = built.SurfaceNames[s];
            string where = $"surface {s} ({name})";

            var material = mesh.SurfaceGetMaterial(s);
            log.Expect(InvMaterials, seed, material != null, $"{where}: no baked material");
            InspectSurfaceMaterial(log, seed, name, material, where);

            int locked = 0;
            bool alphaOk = true;
            foreach (var c in colors)
            {
                if (c.A == 0f) locked++;
                else if (c.A != 1f) alphaOk = false;
            }
            log.Expect(InvVertexAlpha, seed, alphaOk, $"{where}: vertex alpha is neither 0 nor 1");
            log.Expect(InvVertexAlpha, seed, locked == 0 || name == TerrainMeshBuilder.WaterTopSurface,
                $"{where}: {locked} wave-locked vertices outside the water surface");
            tally.LockedVertices += locked;

            if (name == TerrainMeshBuilder.TopGridLineSurface) tally.SawGridLines = true;
            if (name == TerrainMeshBuilder.EdgeStripSurface) tally.SawEdgeStrips = true;
            if (name == TerrainMeshBuilder.CliffBandSurface) tally.SawCliffBands = true;

            log.Expect(InvIndexMod3, seed, indices.Length > 0 && indices.Length % 3 == 0,
                $"{where}: {indices.Length} indices");
            log.Expect(InvArrayLen, seed,
                norms.Length == verts.Length && uvs.Length == verts.Length && colors.Length == verts.Length,
                $"{where}: v={verts.Length} n={norms.Length} uv={uvs.Length} c={colors.Length}");

            bool indexRangeOk = true;
            foreach (int index in indices)
            {
                if (index >= 0 && index < verts.Length) continue;
                indexRangeOk = false;
                break;
            }
            log.Expect(InvIndexRange, seed, indexRangeOk, $"{where}: index outside 0..{verts.Length - 1}");

            bool unitOk = true;
            bool floorOk = true;
            foreach (var n in norms)
            {
                if (MathF.Abs(n.Length() - 1f) > 0.01f) unitOk = false;
                if (n.Y < -1.01f) floorOk = false;
            }
            log.Expect(InvUnitNormals, seed, unitOk, $"{where}: non-unit normal");
            log.Expect(InvNormalFloor, seed, floorOk, $"{where}: normal Y below -1.01");

            bool boundsOk = true;
            float worstY = 0f;
            foreach (var v in verts)
            {
                if (v.Y >= MinVertexY && v.Y <= MaxVertexY) continue;
                boundsOk = false;
                worstY = v.Y;
                break;
            }
            log.Expect(InvYBounds, seed, boundsOk,
                $"{where}: vertex Y {worstY:F3} outside [{MinVertexY:F3}, {MaxVertexY:F3}]");

            if (!indexRangeOk || indices.Length % 3 != 0 || norms.Length != verts.Length) continue;

            int upFacing = 0;
            int triangles = 0;
            bool windingOk = true;
            for (int i = 0; i + 2 < indices.Length; i += 3)
            {
                triangles++;
                Vector3 a = verts[indices[i]];
                Vector3 b = verts[indices[i + 1]];
                Vector3 c = verts[indices[i + 2]];

                // Godot's front face is the side the NEGATED Unity cross product points at, so the
                // geometric front normal is Cross(c - a, b - a). It must agree with the normal the
                // builder stored on the vertices; disagreement means a triangle was not flipped.
                Vector3 geo = (c - a).Cross(b - a);
                if (geo.LengthSquared() < 1e-10f)
                {
                    tally.Degenerate++;
                }
                else if (geo.Normalized().Dot(norms[indices[i]]) <= 0f)
                {
                    windingOk = false;
                }

                if (norms[indices[i]].Y > 0.5f) upFacing++;
            }

            log.Expect(InvWinding, seed, windingOk, $"{where}: triangle wound against its normal");

            if (built.SurfaceIsTop[s])
            {
                log.Expect(InvTopFaces, seed, triangles > 0 && upFacing >= triangles * 0.6f,
                    $"{where}: only {upFacing}/{triangles} triangles face up");
            }
        }

        var collisionMesh = built.Collision;
        bool collisionOk = collisionMesh.GetSurfaceCount() == 1
            && collisionMesh.SurfaceGetArrays(0)[(int)Mesh.ArrayType.Vertex].AsVector3Array().Length > 0;
        log.Expect(InvCollision, seed, collisionOk, "collision mesh empty");

        // Every layout has walkable non-water tops, so the lattice is the one overlay that must always
        // be there. Strips need a cliff and bands need a cliff two elevations tall, so those two are
        // only guaranteed across the whole run — see the coverage checks in Run().
        log.Expect(InvGridLines, seed, tally.SawGridLines, "no top-grid-line surface in the mesh");

        return tally;
    }

    /// <summary>
    /// Material contract per surface kind: water tops animate through the wave shader, overlays are
    /// unshaded translucent decals that draw after the geometry they sit on, and nothing else is
    /// either of those.
    /// </summary>
    private static void InspectSurfaceMaterial(
        InvariantLog log, int seed, string name, Material? material, string where)
    {
        bool isWaterTop = name == TerrainMeshBuilder.WaterTopSurface;
        bool isOverlay = name is TerrainMeshBuilder.TopGridLineSurface
            or TerrainMeshBuilder.EdgeStripSurface or TerrainMeshBuilder.CliffBandSurface;

        if (isWaterTop)
        {
            log.Expect(InvWaterMaterial, seed,
                material is ShaderMaterial { Shader: not null }, $"{where}: not a wave ShaderMaterial");
            return;
        }

        log.Expect(InvWaterMaterial, seed, material is not ShaderMaterial,
            $"{where}: a non-water surface carries the wave shader");

        if (!isOverlay) return;

        log.Expect(InvOverlayMaterial, seed,
            material is StandardMaterial3D
            {
                ShadingMode: BaseMaterial3D.ShadingModeEnum.Unshaded,
                Transparency: BaseMaterial3D.TransparencyEnum.Alpha,
                RenderPriority: 1,
            },
            $"{where}: overlay material is not unshaded/alpha/priority-1");
    }

    private static void InspectDeterminism(
        InvariantLog log, int seed, string biomeId, MapThemeDefinition theme, TerrainMeshBuilder.Result first)
    {
        var again = TerrainMeshBuilder.Build(MapGenerator.Generate(biomeId, seed), theme);
        bool same = again.SurfaceCount == first.SurfaceCount
            && again.VertexCount == first.VertexCount
            && again.TriangleCount == first.TriangleCount
            && PositionHash(again.Visual) == PositionHash(first.Visual);
        log.Expect(InvDeterminism, seed, same,
            $"rebuild differs (v {first.VertexCount}->{again.VertexCount}, "
            + $"t {first.TriangleCount}->{again.TriangleCount})");
    }

    private static void InspectGrid(InvariantLog log, int seed, string biomeId)
    {
        var (layout, grid) = MapGenerator.GenerateBattle(biomeId, seed);
        if (layout == null || grid == null)
        {
            log.Expect(InvGridWalkable, seed, false, "GenerateBattle returned null");
            return;
        }

        for (int y = 0; y < layout.Height; y++)
        {
            for (int x = 0; x < layout.Width; x++)
            {
                var pos = new PF2eVec(x, y);
                var role = layout.GetTile(x, y);

                if (role == TileRole.Empty)
                {
                    log.Expect(InvGridEmpty, seed, !grid.HasTile(pos), $"Empty ({x},{y}) has a grid tile");
                    continue;
                }

                var tile = grid.GetTile(pos);
                if (role == TileRole.Wall)
                {
                    log.Expect(InvGridWall, seed, tile != null && tile.Inaccessible,
                        $"Wall ({x},{y}) is {(tile == null ? "absent" : "accessible")}");
                    continue;
                }

                var corners = layout.GetCornerHeights(x, y);
                bool ok = tile != null && !tile.Inaccessible && SameCorners(tile.CornerHeights, corners);
                log.Expect(InvGridWalkable, seed, ok,
                    $"{role} ({x},{y}) -> "
                    + (tile == null ? "no grid tile" : tile.Inaccessible ? "inaccessible" : "corner mismatch"));
            }
        }
    }

    private static void InspectDeployment(InvariantLog log, int seed, MapLayout layout)
    {
        var zones = layout.DeploymentZones;
        if (zones == null || zones.Length != 2)
        {
            log.Expect(InvZones, seed, false, $"{(zones?.Length ?? 0)} deployment zones (want 2)");
            return;
        }

        foreach (var zone in zones)
        {
            var anchors = DeploymentPlanner.GetAnchors(layout, zone.TeamId, 4);
            if (anchors.Count == 0)
            {
                log.Expect(InvZones, seed, false, $"team {zone.TeamId} got no anchors");
                continue;
            }

            var seen = new HashSet<PF2eVec>();
            foreach (var anchor in anchors)
            {
                log.Expect(InvZones, seed, seen.Add(anchor),
                    $"team {zone.TeamId} repeated anchor ({anchor.x},{anchor.y})");
                log.Expect(InvZones, seed, layout.IsWalkable(anchor.x, anchor.y),
                    $"team {zone.TeamId} anchor ({anchor.x},{anchor.y}) is not walkable");
            }
        }
    }

    private void InspectView(
        InvariantLog log, int seed, MapLayout layout, MapThemeDefinition theme, TerrainMeshBuilder.Result built)
    {
        var view = new MapView3D();
        AddChild(view);
        try
        {
            view.Build(layout, theme);

            var terrain = view.GetNodeOrNull<MeshInstance3D>("Terrain");
            var body = view.GetNodeOrNull<StaticBody3D>("TerrainBody");
            var shape = body?.GetNodeOrNull<CollisionShape3D>("TerrainShape");

            log.Expect(InvView, seed, terrain?.Mesh != null, "no terrain MeshInstance3D");
            log.Expect(InvView, seed, body != null && body.CollisionLayer == MapView3D.TerrainCollisionLayer,
                "terrain body missing or off the Terrain layer");
            log.Expect(InvView, seed, shape?.Shape is ConcavePolygonShape3D,
                "collision shape is not a trimesh");
            log.Expect(InvView, seed, view.SurfaceCount == built.SurfaceCount,
                $"view reports {view.SurfaceCount} surfaces, builder {built.SurfaceCount}");

            // Rebuild must replace, not accumulate: two children, always.
            view.Build(layout, theme);
            log.Expect(InvView, seed, view.GetChildCount() == 2,
                $"rebuild left {view.GetChildCount()} children (want 2)");
        }
        finally
        {
            RemoveChild(view);
            view.QueueFree();
        }
    }

    // ─────────────────────────── Helpers ───────────────────────────

    private static bool SameCorners(TileCornerHeights a, TileCornerHeights b) =>
        a.NW == b.NW && a.NE == b.NE && a.SE == b.SE && a.SW == b.SW;

    /// <summary>FNV-1a over every vertex position of every surface, in surface order.</summary>
    private static ulong PositionHash(ArrayMesh mesh)
    {
        ulong hash = 14695981039346656037UL;
        for (int s = 0; s < mesh.GetSurfaceCount(); s++)
        {
            var verts = mesh.SurfaceGetArrays(s)[(int)Mesh.ArrayType.Vertex].AsVector3Array();
            foreach (var v in verts)
            {
                MixFloat(ref hash, v.X);
                MixFloat(ref hash, v.Y);
                MixFloat(ref hash, v.Z);
            }
        }
        return hash;
    }

    private static void MixFloat(ref ulong hash, float value)
    {
        uint bits = (uint)BitConverter.SingleToInt32Bits(value);
        for (int i = 0; i < 4; i++)
        {
            hash ^= (byte)(bits >> (i * 8));
            hash *= 1099511628211UL;
        }
    }

    /// <summary>
    /// Collects failures per named invariant so 8 seeds collapse into one [PASS]/[FAIL] line each
    /// instead of eighteen lines per seed.
    /// </summary>
    private sealed class InvariantLog
    {
        private readonly string[] _names;
        private readonly Dictionary<string, List<string>> _failures = new();

        public InvariantLog(string[] names)
        {
            _names = names;
            foreach (string name in names) _failures[name] = new List<string>();
        }

        public void Expect(string invariant, int seed, bool ok, string detail)
        {
            if (ok) return;
            var list = _failures[invariant];
            // One line per seed keeps a systematic break from burying the interesting cases.
            if (list.Count < 32) list.Add($"seed {seed}: {detail}");
        }

        public IEnumerable<(string Name, List<string> Failures)> Results()
        {
            foreach (string name in _names) yield return (name, _failures[name]);
        }
    }
}
