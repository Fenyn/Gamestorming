using System;
using System.Collections.Generic;
using Delve.Data;
using Godot;
using PF2e.Grid;
using PF2e.MapGen;

namespace Delve.Combat.Map;

/// <summary>
/// Builds the battlefield's edge dressing so the map no longer reads as a floating slab: a terrain
/// APRON — skirt geometry stitched to the border tiles' outer top edges, rolling gently outward and
/// down until it dissolves into the backdrop's ground plane and fog — plus a PERIMETER of natural
/// props (tree wall / masonry / boulders per <see cref="BackdropThemeDefinition.Edge"/>) standing on
/// the apron just outside the playable tiles, clearly framing the arena. A TreeWall perimeter keeps
/// going as a FOREST FILL — mid rows tracking the board rectangle, then rings around the board
/// centre — so the eye reads one unbroken forest from the arena edge until the fog swallows it,
/// never two tree lines with a void between. Where a river meets the map edge a short
/// water-coloured strip continues outward so the water doesn't dead-end.
///
/// Called by <see cref="CombatBackdrop"/>, which owns idempotency (it clears its scenery children
/// before rebuilding). Structure and placement constants live here; every colour and size tunable
/// comes from the engine-free theme table in <see cref="BackdropThemes"/>.
///
/// Deterministic: all jitter derives from the layout seed. Visual-only: nothing here carries a
/// StaticBody or CollisionShape, so the terrain picker (GridInput3D) and the rules-side spatial
/// queries can never hit it, and LoS/cover remain exactly the layout's business.
/// </summary>
public static class EdgeSceneryBuilder
{
    // ── Apron rings: distance outward from the boundary, drop below the border-edge height, height
    //    noise amplitude, and the fraction of the Apron→Rim colour ramp at each ring. Ring 0 is the
    //    stitch line — zero everything so it meets the terrain edge exactly. ──
    private static readonly float[] RingDistance = { 0f, 1.8f, 3.5f, 6f, 9.5f, 14f };
    private static readonly float[] RingDrop = { 0f, 0.35f, 0.8f, 1.4f, 2.2f, 3.3f };
    private static readonly float[] RingNoise = { 0f, 0.12f, 0.22f, 0.35f, 0.45f, 0.55f };
    // Shade ramp stays near-zero through the first rings: the ground right past the boundary must
    // read as the same grass continuing, with the darkening saved for the fog-bound rim.
    private static readonly float[] RingShade = { 0f, 0.10f, 0.22f, 0.4f, 0.65f, 1f };

    /// <summary>Distance of the final flare ring, which lands exactly on the ground plane so the
    /// apron merges with it instead of ending on a floating rim.</summary>
    private const float FlareDistance = 34f;

    /// <summary>Apron vertices never sink below this clearance above the ground plane (void exits
    /// would otherwise dive under it and poke back out).</summary>
    private const float GroundPlaneClearance = 0.1f;

    /// <summary>Per-vertex brightness jitter on the apron so it reads as ground, not a tablecloth.</summary>
    private const float ApronShadeJitter = 0.10f;

    // ── Water exit strip ──
    private static readonly float[] WaterStripDistance = { 0f, 1.8f, 4.2f };
    private static readonly float[] WaterStripShade = { 0f, 0.25f, 0.55f };
    private const float WaterStripLift = 0.05f;

    // ── Tree wall (forest). Front row is short shrub-scale and each row back is taller and further
    //    out, so the wall reads dense while the silhouette near the sight line stays below the
    //    occlusion-critical height at low camera pitch. ──
    private const int TreeRows = 4;
    private const float TreeRowFirstOffset = 1.15f;
    private const float TreeRowSpacing = 1.3f;
    private static readonly int[] TreeRowCount = { 2, 2, 2, 1 };
    private static readonly float[] TreeRowSkipChance = { 0.08f, 0.12f, 0.15f, 0.2f };

    /// <summary>Widest canopy radius across the tree variants in unit-height space; the overhang
    /// guard keeps a tree's offset ≥ this × its world height so no canopy reaches over walkable tiles.</summary>
    private const float TreeMaxCanopyRatio = 0.40f;

    /// <summary>Fraction of placed band trees that roll a round deciduous variant instead of a conifer.</summary>
    private const float DeciduousChance = 0.30f;

    // ── Forest fill (TreeWall only): the woods continue outward past the perimeter band. Mid rows
    //    keep tracking the board rectangle; beyond them, rings around the board centre carry the
    //    coverage out until the fog swallows it. Structure lives here; heights and colours are
    //    theme tunables. ──
    private const int MidRows = 4;
    private const float MidRowFirstOffset = 5.6f;
    private const float MidRowSpacing = 2.1f;
    private const float MidRowSkipChance = 0.12f;

    /// <summary>First fill ring sits this far past the board's half-diagonal (just outside the
    /// corner pockets); rings then step outward with growing spacing to the outer radius.</summary>
    private const float FarRingInnerMargin = 3.5f;

    /// <summary>Outermost fill radius. Past ~100 m the forest theme's fog has swallowed the trees,
    /// so the fill hands off to the sky there. Well outside the orbit camera's 30 m worst case.</summary>
    private const float FarRingOuterRadius = 110f;

    /// <summary>Fill-tree height never exceeds 1 m + this slope × distance-from-boundary, keeping
    /// units on edge tiles visible over the near canopy at the camera's minimum pitch.</summary>
    private const float TreeHeightSlope = 1.1f;

    /// <summary>Mixed into the fill's RNG so it rolls independently of the perimeter band.</summary>
    private const int FillSeedSalt = 0x0F111;

    /// <summary>How far props sink into the apron, hiding the base seam over height noise.</summary>
    private const float PropSink = 0.14f;

    // ── Stone wall (sewer) ──
    private const float WallOffset = 0.8f;
    private const float WallSegmentLength = 1.04f;
    private const float WallThickness = 0.5f;
    private const float WallSink = 0.22f;

    // ── Boulders (default) ──
    private const float BoulderChance = 0.6f;
    private const float BoulderSecondChance = 0.25f;
    private const float BoulderOffsetMin = 1.0f;
    private const float BoulderOffsetMax = 2.6f;

    /// <summary>Low-poly sphere tessellation for boulders — chunky faceting like the trees.</summary>
    private const int BoulderRadialSegments = 6;
    private const int BoulderRings = 4;

    /// <summary>Mixed into the layout seed so edge scenery rolls differently from other consumers.</summary>
    private const int SeedSalt = 0x5ED6E;

    /// <summary>
    /// Build the whole edge-scenery subtree for one board. <paramref name="layout"/> null is the flat
    /// dev board: a level apron from the y = 0 board edge and the theme's perimeter (default:
    /// boulders). <paramref name="heightScale"/> is world Y per corner-height unit (0 on flat).
    /// <paramref name="groundPlaneY"/> is where the backdrop's ground plane sits — the apron flares
    /// down to exactly that height.
    /// </summary>
    public static Node3D Build(
        BackdropThemeDefinition theme, MapLayout? layout, int gridWidth, int gridHeight,
        float heightScale, float groundPlaneY)
    {
        var root = new Node3D { Name = "EdgeScenery" };
        int seed = (layout?.Seed ?? 0) ^ SeedSalt;

        Side[] sides = BuildSides(layout, gridWidth, gridHeight, heightScale);

        root.AddChild(BuildApron(theme, sides, seed, groundPlaneY));

        if (layout != null)
        {
            var strip = BuildWaterStrips(theme, layout, sides, groundPlaneY);
            if (strip != null) root.AddChild(strip);
        }

        if (theme.Edge != BackdropEdgeKind.None)
        {
            var props = BuildPerimeter(theme, layout, sides, seed, groundPlaneY);
            if (props != null) root.AddChild(props);
        }

        return root;
    }

    // ---------------------------------------------------------------- Boundary model

    /// <summary>
    /// One side of the board in counter-clockwise (seen from above) traversal order. Tile i runs from
    /// boundary corner i to corner i + 1; <see cref="CornerY"/> holds the stitch height (world Y) at
    /// each boundary corner.
    /// </summary>
    private sealed record Side(
        int Count,
        Vector3 Origin,
        Vector3 Along,
        Vector3 Out,
        (int x, int y)[] Tiles,
        float[] CornerY,
        bool[] CornerTouchesWater);

    private static Side[] BuildSides(MapLayout? layout, int w, int h, float hs)
    {
        // (origin, along, out, tile0, tileStep, corner0, cornerStep, count) per side, CCW:
        // south (west→east), east (south→north), north (east→west), west (north→south).
        (Vector3 origin, Vector3 along, Vector3 outward,
            (int x, int y) t0, (int dx, int dy) dt, (int x, int y) c0, (int dx, int dy) dc, int count)[] defs =
        {
            (new Vector3(0, 0, 0), new Vector3(1, 0, 0), new Vector3(0, 0, -1),
                (0, 0), (1, 0), (0, 0), (1, 0), w),
            (new Vector3(w, 0, 0), new Vector3(0, 0, 1), new Vector3(1, 0, 0),
                (w - 1, 0), (0, 1), (w, 0), (0, 1), h),
            (new Vector3(w, 0, h), new Vector3(-1, 0, 0), new Vector3(0, 0, 1),
                (w - 1, h - 1), (-1, 0), (w, h), (-1, 0), w),
            (new Vector3(0, 0, h), new Vector3(0, 0, -1), new Vector3(-1, 0, 0),
                (0, h - 1), (0, -1), (0, h), (0, -1), h),
        };

        var sides = new Side[defs.Length];
        for (int s = 0; s < defs.Length; s++)
        {
            var d = defs[s];
            var tiles = new (int x, int y)[d.count];
            for (int i = 0; i < d.count; i++)
                tiles[i] = (d.t0.x + d.dt.dx * i, d.t0.y + d.dt.dy * i);

            var cornerY = new float[d.count + 1];
            var touchesWater = new bool[d.count + 1];
            for (int i = 0; i <= d.count; i++)
            {
                int cx = d.c0.x + d.dc.dx * i;
                int cy = d.c0.y + d.dc.dy * i;
                cornerY[i] = layout == null ? 0f : BoundaryCornerHeight(layout, cx, cy) * hs;
                touchesWater[i] = layout != null && CornerTouchesWater(layout, cx, cy);
            }

            sides[s] = new Side(d.count, d.origin, d.along, d.outward, tiles, cornerY, touchesWater);
        }
        return sides;
    }

    /// <summary>
    /// Stitch height (corner units) at boundary corner-grid position (cx, cy): the minimum
    /// contribution of every in-bounds tile touching it. Ground-ish tiles contribute their actual
    /// corner height; Wall tiles contribute their BASE elevation (the apron continues from the foot
    /// of a boundary wall, not its cap); Empty tiles contribute the void floor (a canyon exiting the
    /// map keeps reading as a canyon). Taking the min leaves no gap under anything — whatever stands
    /// higher covers the seam with its own cliff face.
    /// </summary>
    private static int BoundaryCornerHeight(MapLayout layout, int cx, int cy)
    {
        int best = int.MaxValue;
        for (int tx = cx - 1; tx <= cx; tx++)
        {
            for (int ty = cy - 1; ty <= cy; ty++)
            {
                if (!layout.IsInBounds(tx, ty)) continue;
                best = Math.Min(best, TileContribution(layout, tx, ty, cx, cy));
            }
        }
        return best == int.MaxValue ? 0 : best;
    }

    private static int TileContribution(MapLayout layout, int tx, int ty, int cx, int cy)
    {
        TileRole role = layout.GetTile(tx, ty);
        if (role == TileRole.Empty) return TerrainMeshBuilder.VoidFloorCornerHeight;
        if (role == TileRole.Wall) return layout.GetElevation(tx, ty) * TileCornerHeights.UnitsPerElevation;

        var c = layout.GetCornerHeights(tx, ty);
        // Which of the tile's corners sits at (cx, cy): SW = (tx, ty) … NE = (tx+1, ty+1).
        bool east = cx == tx + 1;
        bool north = cy == ty + 1;
        return north ? (east ? c.NE : c.NW) : (east ? c.SE : c.SW);
    }

    private static bool CornerTouchesWater(MapLayout layout, int cx, int cy)
    {
        for (int tx = cx - 1; tx <= cx; tx++)
        {
            for (int ty = cy - 1; ty <= cy; ty++)
            {
                if (layout.IsInBounds(tx, ty) && layout.GetTile(tx, ty) == TileRole.Water) return true;
            }
        }
        return false;
    }

    /// <summary>Apron drop at distance <paramref name="d"/> outward — piecewise-linear over the ring table.</summary>
    private static float DropAt(float d)
    {
        for (int i = 1; i < RingDistance.Length; i++)
        {
            if (d <= RingDistance[i])
            {
                float t = (d - RingDistance[i - 1]) / (RingDistance[i] - RingDistance[i - 1]);
                return Mathf.Lerp(RingDrop[i - 1], RingDrop[i], t);
            }
        }
        return RingDrop[^1];
    }

    /// <summary>Apron surface height under a prop: stitch height lerped along tile i, minus the drop
    /// at offset <paramref name="d"/>, never below the ground-plane clearance.</summary>
    private static float SurfaceY(Side side, int i, float t, float d, float groundPlaneY)
    {
        float baseY = Mathf.Lerp(side.CornerY[i], side.CornerY[i + 1], Mathf.Clamp(t, 0f, 1f));
        return MathF.Max(baseY - DropAt(d), groundPlaneY + GroundPlaneClearance);
    }

    /// <summary>
    /// Apron surface height under an arbitrary outside point (x, z): the nearest boundary point's
    /// stitch height minus the drop for the point's distance from the board rectangle, following the
    /// flare down onto the ground plane past the last ring. Close enough to the apron mesh that fill
    /// props sink their bases into it anywhere in the field — corner wedges included, where the
    /// per-side <see cref="SurfaceY"/> doesn't apply.
    /// </summary>
    private static float ApronSurfaceAt(Side[] sides, float x, float z, float groundPlaneY)
    {
        float w = sides[0].Count;
        float h = sides[1].Count;
        float bx = Mathf.Clamp(x, 0f, w);
        float bz = Mathf.Clamp(z, 0f, h);
        float d = MathF.Sqrt((x - bx) * (x - bx) + (z - bz) * (z - bz));

        // Which side owns the boundary point, and its along-parameter (see BuildSides ordering).
        // Corner-diagonal points resolve to either adjoining side — the corner stitch Y is shared.
        (Side side, float t) = z <= 0f ? (sides[0], bx)
            : x >= w ? (sides[1], bz)
            : z >= h ? (sides[2], w - bx)
            : (sides[3], h - bz);
        int i = Mathf.Clamp((int)t, 0, side.Count - 1);
        float baseY = Mathf.Lerp(side.CornerY[i], side.CornerY[i + 1], Mathf.Clamp(t - i, 0f, 1f));

        float floorY = groundPlaneY + GroundPlaneClearance;
        if (d >= FlareDistance) return floorY;
        if (d > RingDistance[^1])
        {
            // The flare span: mesh vertices run linearly from the last ring down to the ground plane.
            float yLast = MathF.Max(baseY - RingDrop[^1], floorY);
            return Mathf.Lerp(yLast, groundPlaneY,
                (d - RingDistance[^1]) / (FlareDistance - RingDistance[^1]));
        }
        return MathF.Max(baseY - DropAt(d), floorY);
    }

    // ---------------------------------------------------------------- Apron

    /// <summary>One point of the boundary rim loop: ring-0 position plus its outward push direction
    /// (diagonal — non-unit — at the four board corners, so rings stay rectangular).</summary>
    private readonly record struct RimPoint(Vector3 Base, Vector3 Out, bool NearWater);

    private static MeshInstance3D BuildApron(
        BackdropThemeDefinition theme, Side[] sides, int seed, float groundPlaneY)
    {
        // Closed CCW rim loop: corner point (diagonal push), then that side's boundary corners.
        var rim = new List<RimPoint>();
        for (int s = 0; s < sides.Length; s++)
        {
            Side side = sides[s];
            Side prev = sides[(s + sides.Length - 1) % sides.Length];
            var cornerBase = new Vector3(side.Origin.X, side.CornerY[0], side.Origin.Z);
            rim.Add(new RimPoint(cornerBase, side.Out + prev.Out, side.CornerTouchesWater[0]));
            for (int i = 0; i <= side.Count; i++)
            {
                var p = side.Origin + side.Along * i;
                rim.Add(new RimPoint(
                    new Vector3(p.X, side.CornerY[i], p.Z), side.Out, side.CornerTouchesWater[i]));
            }
        }

        int n = rim.Count;
        int ringCount = RingDistance.Length + 1; // + the flare ring on the ground plane
        var apron = MapMaterials.ToGodot(theme.ApronColor);
        var rimCol = MapMaterials.ToGodot(theme.ApronRimColor);

        var pos = new Vector3[ringCount, n];
        var col = new Color[ringCount, n];
        for (int r = 0; r < ringCount; r++)
        {
            bool flare = r == RingDistance.Length;
            float dist = flare ? FlareDistance : RingDistance[r];
            for (int v = 0; v < n; v++)
            {
                RimPoint p = rim[v];
                float y;
                if (flare)
                {
                    y = groundPlaneY;
                }
                else
                {
                    // Water-adjacent rim columns stay noise-free so the river exit strip lies flat.
                    float amp = p.NearWater ? 0f : RingNoise[r];
                    y = p.Base.Y - RingDrop[r] + (Hash01(v, r, seed) * 2f - 1f) * amp;
                    y = MathF.Max(y, groundPlaneY + GroundPlaneClearance);
                }
                pos[r, v] = new Vector3(p.Base.X + p.Out.X * dist, y, p.Base.Z + p.Out.Z * dist);

                Color c = apron.Lerp(rimCol, flare ? 1f : RingShade[r]);
                if (r > 0 && !flare)
                    c *= 1f + (Hash01(v, r + 64, seed) - 0.5f) * 2f * ApronShadeJitter;
                col[r, v] = c with { A = 1f };
            }
        }

        var buf = new MeshBuffer();
        for (int r = 0; r < ringCount - 1; r++)
        {
            for (int v = 0; v < n; v++)
            {
                int v2 = (v + 1) % n;
                // Footprint CCW seen from above: inner A → outer A → outer B → inner B.
                buf.AddQuad(
                    pos[r, v], pos[r + 1, v], pos[r + 1, v2], pos[r, v2],
                    col[r, v], col[r + 1, v], col[r + 1, v2], col[r, v2]);
            }
        }

        return new MeshInstance3D
        {
            Name = "Apron",
            Mesh = buf.ToMesh("edge_apron", new StandardMaterial3D
            {
                ResourceName = "edge_apron",
                VertexColorUseAsAlbedo = true,
                VertexColorIsSrgb = true,
                Roughness = 1f,
                Metallic = 0f,
            }),
            CastShadow = GeometryInstance3D.ShadowCastingSetting.Off,
        };
    }

    // ---------------------------------------------------------------- Water exit strips

    /// <summary>
    /// A flat water-coloured strip continuing each map-edge water run a few metres outward over the
    /// apron (lifted just clear of it), darkening toward the rim so it dissolves with the ground.
    /// Approximate on purpose: it reads as "the river keeps going" and the fog does the rest.
    /// </summary>
    private static MeshInstance3D? BuildWaterStrips(
        BackdropThemeDefinition theme, MapLayout layout, Side[] sides, float groundPlaneY)
    {
        var water = MapMaterials.ToGodot(theme.ApronWaterColor);
        var rimCol = MapMaterials.ToGodot(theme.ApronRimColor);
        var buf = new MeshBuffer();

        foreach (Side side in sides)
        {
            for (int i = 0; i < side.Count; i++)
            {
                (int tx, int ty) = side.Tiles[i];
                if (layout.GetTile(tx, ty) != TileRole.Water) continue;

                for (int r = 0; r < WaterStripDistance.Length - 1; r++)
                {
                    Vector3 a0 = StripPoint(side, i, r, groundPlaneY);
                    Vector3 a1 = StripPoint(side, i, r + 1, groundPlaneY);
                    Vector3 b0 = StripPoint(side, i + 1, r, groundPlaneY);
                    Vector3 b1 = StripPoint(side, i + 1, r + 1, groundPlaneY);
                    Color c0 = water.Lerp(rimCol, WaterStripShade[r]);
                    Color c1 = water.Lerp(rimCol, WaterStripShade[r + 1]);
                    buf.AddQuad(a0, a1, b1, b0, c0, c1, c1, c0);
                }
            }
        }

        if (buf.IsEmpty) return null;
        return new MeshInstance3D
        {
            Name = "WaterStrips",
            Mesh = buf.ToMesh("edge_water_strip", new StandardMaterial3D
            {
                ResourceName = "edge_water_strip",
                VertexColorUseAsAlbedo = true,
                VertexColorIsSrgb = true,
                Roughness = 1f,
                Metallic = 0f,
            }),
            CastShadow = GeometryInstance3D.ShadowCastingSetting.Off,
        };
    }

    private static Vector3 StripPoint(Side side, int corner, int ring, float groundPlaneY)
    {
        float d = WaterStripDistance[ring];
        Vector3 p = side.Origin + side.Along * corner + side.Out * d;
        float y = MathF.Max(side.CornerY[corner] - DropAt(d), groundPlaneY + GroundPlaneClearance)
                  + WaterStripLift;
        return new Vector3(p.X, y, p.Z);
    }

    // ---------------------------------------------------------------- Perimeter props

    private static Node3D? BuildPerimeter(
        BackdropThemeDefinition theme, MapLayout? layout, Side[] sides, int seed, float groundPlaneY)
    {
        var rng = new Random(seed);

        switch (theme.Edge)
        {
            case BackdropEdgeKind.TreeWall:
            {
                var trees = new List<(Transform3D Xf, Color Col)>[TreeKindCount];
                for (int k = 0; k < TreeKindCount; k++) trees[k] = new();
                PlaceTreeWall(theme, layout, sides, rng, groundPlaneY, trees);
                PlaceForestFill(theme, sides, seed, groundPlaneY, trees);

                var root = new Node3D { Name = "Forest" };
                for (int k = 0; k < TreeKindCount; k++)
                {
                    var node = MultiMeshNode(
                        $"Trees{(TreeKind)k}", TreeMesh((TreeKind)k, theme), trees[k]);
                    if (node != null) root.AddChild(node);
                }
                return root;
            }
            case BackdropEdgeKind.StoneWall:
            {
                var instances = new List<(Transform3D Xf, Color Col)>();
                PlaceStoneWall(theme, layout, sides, rng, groundPlaneY, instances);
                return MultiMeshNode("PerimeterWall", WallMesh(), instances);
            }
            case BackdropEdgeKind.Boulders:
            {
                var instances = new List<(Transform3D Xf, Color Col)>();
                PlaceBoulders(theme, layout, sides, rng, groundPlaneY, instances);
                return MultiMeshNode("PerimeterBoulders", BoulderMesh(), instances);
            }
            default:
                return null;
        }
    }

    /// <summary>True when the perimeter should leave a gap at this border tile: a river/channel exit
    /// (Water/Bridge) or a chasm running off the map (Empty).</summary>
    private static bool IsGapTile(MapLayout? layout, (int x, int y) tile) =>
        layout != null && layout.GetTile(tile.x, tile.y)
            is TileRole.Water or TileRole.Empty or TileRole.Bridge;

    private static void PlaceTreeWall(
        BackdropThemeDefinition theme, MapLayout? layout, Side[] sides, Random rng,
        float groundPlaneY, List<(Transform3D, Color)>[] trees)
    {
        foreach (Side side in sides)
        {
            for (int i = 0; i < side.Count; i++)
            {
                bool gap = IsGapTile(layout, side.Tiles[i]);
                for (int row = 0; row < TreeRows; row++)
                {
                    // The river exit stays open through the near rows; the furthest row closes the
                    // horizon behind it so the gap reads as a corridor, not a missing tooth.
                    if (gap && row < TreeRows - 1) { SkipRolls(rng, TreeRowCount[row] * 6); continue; }

                    float rowHeight = Mathf.Lerp(
                        theme.EdgePropHeightMin, theme.EdgePropHeightMax, row / (float)(TreeRows - 1));
                    for (int slot = 0; slot < TreeRowCount[row]; slot++)
                    {
                        // Fixed number of rolls per slot keeps the stream aligned with SkipRolls.
                        float rSkip = (float)rng.NextDouble();
                        float t = (slot + 0.5f) / TreeRowCount[row]
                                  + ((float)rng.NextDouble() - 0.5f) * 0.36f;
                        float offJitter = ((float)rng.NextDouble() - 0.5f) * 0.6f;
                        float h = rowHeight * (0.85f + (float)rng.NextDouble() * 0.33f);
                        float shade = (float)rng.NextDouble();
                        float kindRoll = (float)rng.NextDouble();
                        if (rSkip < TreeRowSkipChance[row]) continue;

                        AddTree(theme, side, i, t,
                            TreeRowFirstOffset + row * TreeRowSpacing + offJitter,
                            h, shade, kindRoll, groundPlaneY, trees);
                    }
                }
            }
        }

        // Corner pockets: close the diagonal between two sides with a small cluster. The pocket
        // outside corner point of side s lies along its own outward normal AND the previous side's.
        for (int s = 0; s < sides.Length; s++)
        {
            Side side = sides[s];
            Vector3 prevOut = sides[(s + sides.Length - 1) % sides.Length].Out;
            (float u, float v)[] spots = { (1.5f, 1.5f), (2.7f, 1.2f), (1.2f, 2.7f) };
            foreach ((float u, float v) in spots)
            {
                float h = Mathf.Lerp(theme.EdgePropHeightMin, theme.EdgePropHeightMax,
                    0.3f + (float)rng.NextDouble() * 0.45f);
                float shade = (float)rng.NextDouble();
                float kindRoll = (float)rng.NextDouble();
                Vector3 p = side.Origin + side.Out * u + prevOut * v;
                float ground = ApronSurfaceAt(sides, p.X, p.Z, groundPlaneY);
                AddTreeInstance(theme, PickKind(kindRoll), new Vector3(p.X, ground, p.Z),
                    h, WidthRoll(kindRoll), shade, shade * Mathf.Tau, trees);
            }
        }
    }

    /// <summary>
    /// The forest fill: everything between the perimeter band and the fog line, so no empty plain
    /// ever shows. Mid rows continue each side's rows outward (closing behind the river-exit
    /// corridors the perimeter leaves open); far rings around the board centre take over where the
    /// rectangle stops mattering and run the coverage out until the fog merges it with the sky.
    /// </summary>
    private static void PlaceForestFill(
        BackdropThemeDefinition theme, Side[] sides, int seed, float groundPlaneY,
        List<(Transform3D, Color)>[] trees)
    {
        var rng = new Random(seed ^ FillSeedSalt);

        foreach (Side side in sides)
        {
            for (int i = 0; i < side.Count; i++)
            {
                for (int row = 0; row < MidRows; row++)
                {
                    float rSkip = (float)rng.NextDouble();
                    float t = 0.5f + ((float)rng.NextDouble() - 0.5f) * 0.9f;
                    float offset = MidRowFirstOffset + row * MidRowSpacing
                                   + ((float)rng.NextDouble() - 0.5f) * 1.4f;
                    float hRoll = (float)rng.NextDouble();
                    float shade = (float)rng.NextDouble();
                    float kindRoll = (float)rng.NextDouble();
                    if (rSkip < MidRowSkipChance) continue;

                    AddTree(theme, side, i, t, offset,
                        FillHeight(theme, offset, hRoll), shade, kindRoll, groundPlaneY, trees);
                }
            }
        }

        // Far rings. Spacing between rings and along each ring grows with radius — far trees are
        // taller, so coverage stays visually closed with fewer instances.
        float w = sides[0].Count;
        float h = sides[1].Count;
        var center = new Vector2(w * 0.5f, h * 0.5f);
        float halfDiag = 0.5f * MathF.Sqrt(w * w + h * h);
        for (float r = halfDiag + FarRingInnerMargin; r < FarRingOuterRadius; r += 3.2f + r * 0.055f)
        {
            float spacing = 3.0f + r * 0.045f;
            int count = Math.Max(8, (int)(Mathf.Tau * r / spacing));
            for (int i = 0; i < count; i++)
            {
                float angle = (i + (float)rng.NextDouble() * 0.9f) / count * Mathf.Tau;
                float radius = r + ((float)rng.NextDouble() - 0.5f) * 3f;
                float hRoll = (float)rng.NextDouble();
                float shade = (float)rng.NextDouble();
                float kindRoll = (float)rng.NextDouble();
                float yaw = (float)rng.NextDouble() * Mathf.Tau;

                float x = center.X + MathF.Cos(angle) * radius;
                float z = center.Y + MathF.Sin(angle) * radius;
                float dx = MathF.Max(MathF.Max(-x, x - w), 0f);
                float dz = MathF.Max(MathF.Max(-z, z - h), 0f);
                float d = MathF.Sqrt(dx * dx + dz * dz);
                if (d < MidRowFirstOffset - 1f) continue; // band + mid rows already cover this

                // Mixed canopy out here: round deciduous crowns among the conifers calm the far
                // mass into a rolling canopy instead of an overwhelming field of spikes.
                TreeKind kind = kindRoll < 0.40f ? TreeKind.Conifer3
                    : kindRoll < 0.62f ? TreeKind.Conifer2
                    : kindRoll < 0.84f ? TreeKind.Deciduous1
                    : TreeKind.Deciduous2;
                float fh = FillHeight(theme, d, hRoll);
                if (kind is TreeKind.Deciduous1 or TreeKind.Deciduous2) fh *= 0.85f;
                float ground = ApronSurfaceAt(sides, x, z, groundPlaneY);
                AddTreeInstance(theme, kind, new Vector3(x, ground, z),
                    fh, WidthRoll(kindRoll), shade, yaw, trees);
            }
        }
    }

    /// <summary>Fill-tree height at boundary distance <paramref name="d"/>: ramps from just above
    /// the perimeter's tallest row up to the theme's fog-line ceiling, always capped by the
    /// edge-visibility slope so nothing can screen an edge-tile unit at minimum camera pitch.</summary>
    private static float FillHeight(BackdropThemeDefinition theme, float d, float hRoll)
    {
        float target = Mathf.Lerp(
            theme.EdgePropHeightMax * 1.05f, theme.FarTreeHeightMax,
            Mathf.Clamp((d - MidRowFirstOffset) / 40f, 0f, 1f));
        // Modest variance: a wide roll here saw-tooths the skyline back into visual noise.
        target *= 0.88f + hRoll * 0.24f;
        return MathF.Min(target, 1f + d * TreeHeightSlope);
    }

    private static void AddTree(
        BackdropThemeDefinition theme, Side side, int i, float t, float offset, float h, float shade,
        float kindRoll, float groundPlaneY, List<(Transform3D, Color)>[] trees)
    {
        TreeKind kind = PickKind(kindRoll);
        if (kind is TreeKind.Deciduous1 or TreeKind.Deciduous2) h *= 0.85f;
        float width = WidthRoll(kindRoll);
        // Never overhang the playable tiles.
        offset = MathF.Max(offset, TreeMaxCanopyRatio * h * width + 0.3f);
        Vector3 p = side.Origin + side.Along * (i + t) + side.Out * offset;
        float ground = SurfaceY(side, i, t, offset, groundPlaneY);
        AddTreeInstance(theme, kind, new Vector3(p.X, ground, p.Z),
            h, width, shade, shade * Mathf.Tau, trees);
    }

    /// <summary>Variant from one uniform roll: ~30% deciduous split between the blob shapes, the
    /// rest conifers weighted toward the three-tier profile.</summary>
    private static TreeKind PickKind(float kindRoll) =>
        kindRoll < DeciduousChance
            ? (kindRoll < DeciduousChance * 0.5f ? TreeKind.Deciduous1 : TreeKind.Deciduous2)
            : (kindRoll < DeciduousChance + (1f - DeciduousChance) * 0.65f
                ? TreeKind.Conifer3
                : TreeKind.Conifer2);

    /// <summary>Width multiplier decorrelated from the kind roll by a golden-ish stretch.</summary>
    private static float WidthRoll(float roll) => 0.85f + (roll * 7.9f) % 1f * 0.4f;

    /// <summary>One tree at <paramref name="basePos"/> (mesh origin is the trunk base): sink it a
    /// little so height noise and slope never leave a floating root, tint the canopy by the theme's
    /// colour pair, and bucket it into its variant's MultiMesh list.</summary>
    private static void AddTreeInstance(
        BackdropThemeDefinition theme, TreeKind kind, Vector3 basePos, float h, float width,
        float shade, float yaw, List<(Transform3D, Color)>[] trees)
    {
        var basis = Basis.FromEuler(new Vector3(0f, yaw, 0f))
                    * Basis.FromScale(new Vector3(h * width, h, h * width));
        var color = MapMaterials.ToGodot(theme.EdgePropColor)
            .Lerp(MapMaterials.ToGodot(theme.EdgePropColorB), shade);
        float sink = PropSink + h * 0.05f;
        trees[(int)kind].Add(
            (new Transform3D(basis, basePos with { Y = basePos.Y - sink }), color));
    }

    private static void PlaceStoneWall(
        BackdropThemeDefinition theme, MapLayout? layout, Side[] sides, Random rng,
        float groundPlaneY, List<(Transform3D, Color)> instances)
    {
        foreach (Side side in sides)
        {
            for (int i = 0; i < side.Count; i++)
            {
                if (IsGapTile(layout, side.Tiles[i])) { SkipRolls(rng, 3); continue; }

                float h = Mathf.Lerp(
                    theme.EdgePropHeightMin, theme.EdgePropHeightMax, (float)rng.NextDouble());
                float yJitter = ((float)rng.NextDouble() - 0.5f) * 0.08f;
                float shade = (float)rng.NextDouble();

                Vector3 p = side.Origin + side.Along * (i + 0.5f) + side.Out * WallOffset;
                float ground = SurfaceY(side, i, 0.5f, WallOffset, groundPlaneY);

                var basis = new Basis(
                    side.Along * WallSegmentLength,
                    Vector3.Up * h,
                    side.Along.Cross(Vector3.Up) * WallThickness);
                var color = MapMaterials.ToGodot(theme.EdgePropColor)
                    .Lerp(MapMaterials.ToGodot(theme.EdgePropColorB), shade);
                instances.Add((new Transform3D(
                    basis, new Vector3(p.X, ground - WallSink + h * 0.5f + yJitter, p.Z)), color));
            }
        }

        // Corner posts: a slightly taller square pillar closing each corner of the circuit.
        for (int s = 0; s < sides.Length; s++)
        {
            Side side = sides[s];
            Vector3 prevOut = sides[(s + sides.Length - 1) % sides.Length].Out;
            Vector3 p = side.Origin + side.Out * WallOffset + prevOut * WallOffset;
            float h = theme.EdgePropHeightMax * 1.1f;
            float ground = MathF.Max(
                side.CornerY[0] - DropAt(WallOffset), groundPlaneY + GroundPlaneClearance);
            var basis = Basis.FromEuler(new Vector3(0f, Mathf.Pi / 4f, 0f))
                        * Basis.FromScale(new Vector3(WallThickness * 1.35f, h, WallThickness * 1.35f));
            instances.Add((new Transform3D(
                    basis, new Vector3(p.X, ground - WallSink + h * 0.5f, p.Z)),
                MapMaterials.ToGodot(theme.EdgePropColor)));
        }
    }

    private static void PlaceBoulders(
        BackdropThemeDefinition theme, MapLayout? layout, Side[] sides, Random rng,
        float groundPlaneY, List<(Transform3D, Color)> instances)
    {
        foreach (Side side in sides)
        {
            for (int i = 0; i < side.Count; i++)
            {
                if (IsGapTile(layout, side.Tiles[i])) { SkipRolls(rng, 2); continue; }

                if ((float)rng.NextDouble() < BoulderChance)
                    AddBoulder(theme, side, i, rng, groundPlaneY, instances);
                if ((float)rng.NextDouble() < BoulderSecondChance)
                    AddBoulder(theme, side, i, rng, groundPlaneY, instances);
            }
        }
    }

    private static void AddBoulder(
        BackdropThemeDefinition theme, Side side, int i, Random rng, float groundPlaneY,
        List<(Transform3D, Color)> instances)
    {
        float s = Mathf.Lerp(theme.EdgePropHeightMin, theme.EdgePropHeightMax, (float)rng.NextDouble());
        float squash = 0.55f + (float)rng.NextDouble() * 0.25f;
        float t = 0.15f + (float)rng.NextDouble() * 0.7f;
        float offset = MathF.Max(
            BoulderOffsetMin + (float)rng.NextDouble() * (BoulderOffsetMax - BoulderOffsetMin),
            s * 0.5f + 0.3f);
        float shade = (float)rng.NextDouble();

        Vector3 p = side.Origin + side.Along * (i + t) + side.Out * offset;
        float ground = SurfaceY(side, i, t, offset, groundPlaneY);

        var basis = Basis.FromEuler(new Vector3(0f, (float)rng.NextDouble() * Mathf.Tau, 0f))
                    * Basis.FromScale(new Vector3(s, s * squash, s * (0.8f + shade * 0.25f)));
        var color = MapMaterials.ToGodot(theme.EdgePropColor)
            .Lerp(MapMaterials.ToGodot(theme.EdgePropColorB), shade);
        instances.Add((new Transform3D(
            basis, new Vector3(p.X, ground + s * squash * 0.5f - s * 0.2f, p.Z)), color));
    }

    /// <summary>Burn RNG rolls so a skipped tile consumes the same stream as a placed one — the
    /// layout downstream stays identical no matter which tiles gap out.</summary>
    private static void SkipRolls(Random rng, int count)
    {
        for (int i = 0; i < count; i++) rng.NextDouble();
    }

    // ---------------------------------------------------------------- Meshes and materials

    private static StandardMaterial3D PropMaterial(string name) => new()
    {
        ResourceName = name,
        VertexColorUseAsAlbedo = true,
        // Vertex/instance colours are authored as sRGB (MapColor); without this they are read as
        // linear and the whole edge dressing washes out pale.
        VertexColorIsSrgb = true,
        Roughness = 1f,
        Metallic = 0f,
    };

    /// <summary>The tree shapes the forest is built from. Values index the per-variant MultiMesh
    /// instance buckets.</summary>
    private enum TreeKind
    {
        /// <summary>Three stacked frustum tiers on a stub trunk — the standard conifer.</summary>
        Conifer3,

        /// <summary>Two fatter tiers — a squat, broader conifer.</summary>
        Conifer2,

        /// <summary>One faceted blob canopy on a visible trunk.</summary>
        Deciduous1,

        /// <summary>A main blob plus a smaller offset blob — a lopsided broadleaf.</summary>
        Deciduous2,
    }

    private const int TreeKindCount = 4;

    /// <summary>
    /// Composed low-poly tree mesh for one variant: unit height (trunk base y = 0, crown y = 1),
    /// scaled per instance. Two surfaces — the canopy carries greyscale vertex-colour brightness
    /// bands multiplied by the per-instance tint, the trunk a fixed theme colour that ignores the
    /// tint. Conifer tiers overlap so each tier's bottom ring pokes past the tier below: the rims
    /// read as chunky banding, dark underneath and lighter toward the crown, the same flat-shaded
    /// diorama language as the terrain tiles.
    /// </summary>
    private static Mesh TreeMesh(TreeKind kind, BackdropThemeDefinition theme)
    {
        var canopy = new TreeSurface();
        var trunk = new TreeSurface();
        switch (kind)
        {
            case TreeKind.Conifer3:
                trunk.AddFrustum(0f, 0.055f, 0.24f, 0.045f, 6, 0f, 1f);
                canopy.AddTier(0.14f, 0.37f, 0.46f, 0.17f, 0.72f);
                canopy.AddTier(0.36f, 0.28f, 0.68f, 0.12f, 0.86f);
                // Truncated crown — a small flat top instead of a needle point keeps the massed
                // forest reading chunky rather than a field of spikes.
                canopy.AddTier(0.58f, 0.21f, 1.00f, 0.055f, 1.00f, capTop: true);
                break;
            case TreeKind.Conifer2:
                trunk.AddFrustum(0f, 0.065f, 0.22f, 0.05f, 6, 0f, 1f);
                canopy.AddTier(0.12f, 0.38f, 0.52f, 0.18f, 0.76f);
                canopy.AddTier(0.40f, 0.30f, 1.00f, 0.07f, 0.94f, capTop: true);
                break;
            case TreeKind.Deciduous1:
                trunk.AddFrustum(0f, 0.06f, 0.55f, 0.045f, 5, 0f, 1f);
                canopy.AddBlob(new Vector3(0f, 0.66f, 0f), new Vector3(0.38f, 0.34f, 0.34f), 0.3f);
                break;
            case TreeKind.Deciduous2:
                trunk.AddFrustum(0f, 0.06f, 0.52f, 0.045f, 5, 0f, 1f);
                canopy.AddBlob(new Vector3(-0.06f, 0.60f, 0.04f), new Vector3(0.34f, 0.30f, 0.31f), 0.2f);
                canopy.AddBlob(new Vector3(0.17f, 0.82f, -0.07f), new Vector3(0.22f, 0.18f, 0.20f), 1.1f);
                break;
        }

        var mesh = new ArrayMesh { ResourceName = $"edge_tree_{kind}" };
        canopy.Commit(mesh, PropMaterial("edge_tree_canopy"));
        trunk.Commit(mesh, MapMaterials.Build(theme.TreeTrunkColor, "edge_tree_trunk"));
        return mesh;
    }

    /// <summary>
    /// Triangle accumulator for one tree-mesh surface: flat per-face normals, greyscale vertex
    /// colour as a brightness multiplier on the instance tint. Winding is auto-oriented from an
    /// outward hint per face, so the shape code stays free of winding bookkeeping.
    /// </summary>
    private sealed class TreeSurface
    {
        private readonly List<Vector3> _verts = new();
        private readonly List<Vector3> _norms = new();
        private readonly List<Color> _colors = new();

        private int _tierParity;

        /// <summary>One conifer tier: a six-sided frustum (or cone at zero top radius) plus its
        /// underside disc, alternate tiers rotated a half segment for facet interest. A truncated
        /// CROWN tier (nothing above to cover its opening) must pass <paramref name="capTop"/> or
        /// the open frustum top reads as missing geometry from any steep camera angle.</summary>
        public void AddTier(
            float yBottom, float rBottom, float yTop, float rTop, float brightness,
            bool capTop = false)
        {
            float rot = _tierParity++ % 2 == 0 ? 0f : Mathf.Pi / 6f;
            AddFrustum(yBottom, rBottom, yTop, rTop, 6, rot, brightness);
            AddDisc(yBottom, rBottom, 6, rot, brightness * 0.55f);
            if (capTop && rTop > 1e-4f) AddCapDisc(yTop, rTop, 6, rot, brightness);
        }

        public void AddFrustum(
            float yBottom, float rBottom, float yTop, float rTop, int segments, float rot,
            float brightness)
        {
            for (int s = 0; s < segments; s++)
            {
                float a0 = rot + s * Mathf.Tau / segments;
                float a1 = rot + (s + 1) * Mathf.Tau / segments;
                Vector3 b0 = Ring(a0, rBottom, yBottom);
                Vector3 b1 = Ring(a1, rBottom, yBottom);
                Vector3 hint = Ring((a0 + a1) * 0.5f, 1f, 0f);
                if (rTop < 1e-4f)
                {
                    AddTri(b0, b1, new Vector3(0f, yTop, 0f), hint, brightness);
                }
                else
                {
                    Vector3 t0 = Ring(a0, rTop, yTop);
                    Vector3 t1 = Ring(a1, rTop, yTop);
                    AddTri(b0, b1, t1, hint, brightness);
                    AddTri(b0, t1, t0, hint, brightness);
                }
            }
        }

        /// <summary>Downward-facing disc — the shadowed underside of a tier rim.</summary>
        public void AddDisc(float y, float r, int segments, float rot, float brightness)
        {
            for (int s = 0; s < segments; s++)
            {
                float a0 = rot + s * Mathf.Tau / segments;
                float a1 = rot + (s + 1) * Mathf.Tau / segments;
                AddTri(Ring(a0, r, y), Ring(a1, r, y), new Vector3(0f, y, 0f),
                    Vector3.Down, brightness);
            }
        }

        /// <summary>Upward-facing disc — the lit flat top closing a truncated crown tier.</summary>
        public void AddCapDisc(float y, float r, int segments, float rot, float brightness)
        {
            for (int s = 0; s < segments; s++)
            {
                float a0 = rot + s * Mathf.Tau / segments;
                float a1 = rot + (s + 1) * Mathf.Tau / segments;
                AddTri(Ring(a0, r, y), Ring(a1, r, y), new Vector3(0f, y, 0f),
                    Vector3.Up, brightness);
            }
        }

        /// <summary>Faceted low-subdiv ellipsoid canopy, per-face brightness lighter toward its crown.</summary>
        public void AddBlob(Vector3 center, Vector3 radii, float rotY)
        {
            const int radial = 5;
            const int latBands = 4;
            var grid = new Vector3[latBands + 1][];
            for (int k = 0; k <= latBands; k++)
            {
                float phi = Mathf.Pi * k / latBands; // 0 = top pole, π = bottom pole
                grid[k] = new Vector3[radial];
                for (int s = 0; s < radial; s++)
                {
                    // Alternate rows twist half a step so the facets triangulate irregularly.
                    float ang = rotY + (s + k % 2 * 0.5f) * Mathf.Tau / radial;
                    grid[k][s] = center + new Vector3(
                        MathF.Sin(phi) * MathF.Cos(ang) * radii.X,
                        MathF.Cos(phi) * radii.Y,
                        MathF.Sin(phi) * MathF.Sin(ang) * radii.Z);
                }
            }

            for (int k = 0; k < latBands; k++)
            {
                for (int s = 0; s < radial; s++)
                {
                    int s2 = (s + 1) % radial;
                    Vector3 a = grid[k][s], b = grid[k][s2];
                    Vector3 c = grid[k + 1][s2], d = grid[k + 1][s];
                    if (k == 0) { AddBlobTri(a, c, d, center, radii); } // a == b at the pole
                    else if (k == latBands - 1) { AddBlobTri(a, b, c, center, radii); } // c == d
                    else
                    {
                        AddBlobTri(a, b, c, center, radii);
                        AddBlobTri(a, c, d, center, radii);
                    }
                }
            }
        }

        private void AddBlobTri(Vector3 a, Vector3 b, Vector3 c, Vector3 center, Vector3 radii)
        {
            Vector3 centroid = (a + b + c) / 3f;
            float t = Mathf.Clamp((centroid.Y - (center.Y - radii.Y)) / (2f * radii.Y), 0f, 1f);
            AddTri(a, b, c, centroid - center, 0.62f + 0.38f * t);
        }

        private static Vector3 Ring(float angle, float r, float y) =>
            new(MathF.Cos(angle) * r, y, MathF.Sin(angle) * r);

        private void AddTri(Vector3 a, Vector3 b, Vector3 c, Vector3 outwardHint, float brightness)
        {
            Vector3 rhNormal = (b - a).Cross(c - a);
            if (rhNormal.LengthSquared() < 1e-12f) return; // degenerate (pole duplicates)
            // Godot front faces wind clockwise seen from outside — the right-hand normal of a
            // correctly wound face points INWARD, so flip the winding whenever it follows the hint.
            if (rhNormal.Dot(outwardHint) > 0f)
            {
                (b, c) = (c, b);
                rhNormal = -rhNormal;
            }

            Vector3 lightNormal = -rhNormal.Normalized(); // lighting normal faces outward
            var color = new Color(brightness, brightness, brightness);
            _verts.Add(a);
            _verts.Add(b);
            _verts.Add(c);
            for (int k = 0; k < 3; k++)
            {
                _norms.Add(lightNormal);
                _colors.Add(color);
            }
        }

        /// <summary>Append this surface (non-indexed triangles) to <paramref name="mesh"/>.</summary>
        public void Commit(ArrayMesh mesh, Material material)
        {
            if (_verts.Count == 0) return;
            var arrays = new Godot.Collections.Array();
            arrays.Resize((int)Mesh.ArrayType.Max);
            arrays[(int)Mesh.ArrayType.Vertex] = _verts.ToArray();
            arrays[(int)Mesh.ArrayType.Normal] = _norms.ToArray();
            arrays[(int)Mesh.ArrayType.Color] = _colors.ToArray();

            int surface = mesh.GetSurfaceCount();
            mesh.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles, arrays);
            mesh.SurfaceSetMaterial(surface, material);
        }
    }

    /// <summary>Unit cube; each wall segment scales it via its instance basis.</summary>
    private static Mesh WallMesh() => new BoxMesh
    {
        Size = Vector3.One,
        Material = PropMaterial("edge_prop_wall"),
    };

    /// <summary>Low-poly unit sphere, squashed per instance into a squat boulder.</summary>
    private static Mesh BoulderMesh() => new SphereMesh
    {
        Radius = 0.5f,
        Height = 1f,
        RadialSegments = BoulderRadialSegments,
        Rings = BoulderRings,
        Material = PropMaterial("edge_prop_boulder"),
    };

    private static MultiMeshInstance3D? MultiMeshNode(
        string name, Mesh mesh, List<(Transform3D Xf, Color Col)> instances)
    {
        if (instances.Count == 0) return null;

        var multiMesh = new MultiMesh
        {
            TransformFormat = MultiMesh.TransformFormatEnum.Transform3D,
            UseColors = true,
            Mesh = mesh,
            InstanceCount = instances.Count,
        };
        for (int i = 0; i < instances.Count; i++)
        {
            multiMesh.SetInstanceTransform(i, instances[i].Xf);
            multiMesh.SetInstanceColor(i, instances[i].Col);
        }

        return new MultiMeshInstance3D { Name = name, Multimesh = multiMesh };
    }

    // ---------------------------------------------------------------- Geometry helpers

    private static float Hash01(int a, int b, int seed)
    {
        unchecked
        {
            uint h = (uint)seed * 374761393u + (uint)a * 668265263u + (uint)b * 974634321u;
            h = (h ^ (h >> 13)) * 1274126177u;
            h ^= h >> 16;
            return (h & 0xFFFFFFu) * (1f / 0x1000000);
        }
    }

    /// <summary>
    /// Buffer for the flat-shaded apron/strip surfaces: position + per-face normal + vertex colour.
    /// Quads arrive with their footprint counter-clockwise seen from above and emit two up-facing
    /// triangles in Godot's front-face winding (matching <see cref="TerrainMeshBuilder"/>'s
    /// convention). Never becomes collision — edge scenery is visual only.
    /// </summary>
    private sealed class MeshBuffer
    {
        private readonly List<Vector3> _verts = new();
        private readonly List<Vector3> _norms = new();
        private readonly List<Color> _colors = new();
        private readonly List<int> _indices = new();

        public bool IsEmpty => _indices.Count == 0;

        public void AddQuad(
            Vector3 a, Vector3 b, Vector3 c, Vector3 d, Color ca, Color cb, Color cc, Color cd)
        {
            AddTriangle(a, b, c, ca, cb, cc);
            AddTriangle(a, c, d, ca, cc, cd);
        }

        private void AddTriangle(Vector3 a, Vector3 b, Vector3 c, Color ca, Color cb, Color cc)
        {
            Vector3 normal = (b - a).Cross(c - a);
            if (normal.LengthSquared() < 1e-10f) return; // degenerate (corner-point duplicates)
            normal = normal.Normalized();
            if (normal.Y < 0) normal = -normal;

            int i = _verts.Count;
            _verts.Add(a);
            _verts.Add(b);
            _verts.Add(c);
            for (int k = 0; k < 3; k++) _norms.Add(normal);
            _colors.Add(ca);
            _colors.Add(cb);
            _colors.Add(cc);
            // CCW-from-above footprint + this index order = front face up (see TerrainMeshBuilder).
            _indices.Add(i);
            _indices.Add(i + 1);
            _indices.Add(i + 2);
        }

        public ArrayMesh ToMesh(string name, Material material)
        {
            var arrays = new Godot.Collections.Array();
            arrays.Resize((int)Mesh.ArrayType.Max);
            arrays[(int)Mesh.ArrayType.Vertex] = _verts.ToArray();
            arrays[(int)Mesh.ArrayType.Normal] = _norms.ToArray();
            arrays[(int)Mesh.ArrayType.Color] = _colors.ToArray();
            arrays[(int)Mesh.ArrayType.Index] = _indices.ToArray();

            var mesh = new ArrayMesh { ResourceName = name };
            mesh.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles, arrays);
            mesh.SurfaceSetMaterial(0, material);
            return mesh;
        }
    }
}
