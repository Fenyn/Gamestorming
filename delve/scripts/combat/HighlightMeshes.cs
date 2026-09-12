using System.Collections.Generic;
using Delve.Terrain;
using Godot;
using PF2e.Grid;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Combat;

/// <summary>The board-marker shapes an overlay places: a tile fill, a route dot, and the four
/// boundary strips that hug one edge of a tile from the inside.</summary>
public enum MarkerShape { Fill, Dot, EdgeEast, EdgeWest, EdgeNorth, EdgeSouth }

/// <summary>
/// Board-marker meshes for one board surface. Every shape is a rectangle in tile space. Flat boards
/// share one <see cref="QuadMesh"/> per shape; terrain boards get a per-(tile, shape)
/// <see cref="ArrayMesh"/> whose corners follow the tile's sampled heights, so a fill, a strip and a
/// dot all lie ON a ramp instead of slicing through it. Built lazily and cached for the encounter;
/// <see cref="SetHeightMap"/> drops the cache so a new board never reuses the previous map's shapes.
/// Shared by <see cref="GridOverlay3D"/> and <see cref="MoveBandOverlay3D"/>, which each pool their
/// own instances and only ask here for the shape and placement.
/// </summary>
public sealed class HighlightMeshes
{
    /// <summary>Height above the surface the overlays float at, so they never z-fight the ground.</summary>
    public const float SurfaceY = 0.02f;

    /// <summary>Inset quad size (1 tile = 1 m), leaving a hairline of ground between highlights.</summary>
    public const float TileQuad = 0.9f;

    /// <summary>Side of a route-preview dot.</summary>
    public const float DotQuad = 0.35f;

    private readonly float _edgeWidth;
    private readonly Dictionary<MarkerShape, QuadMesh> _flat = new();
    private readonly Dictionary<(PF2eVec tile, MarkerShape shape), ArrayMesh> _conformCache = new();
    private TerrainHeightMap _height = TerrainHeightMap.Flat;

    /// <param name="edgeWidth">Width (m) of the boundary strips.</param>
    public HighlightMeshes(float edgeWidth = 0.06f)
    {
        _edgeWidth = edgeWidth;
        foreach (MarkerShape shape in System.Enum.GetValues<MarkerShape>())
        {
            var (u0, u1, v0, v1) = Rect(shape);
            _flat[shape] = new QuadMesh { Size = new Vector2(u1 - u0, v1 - v0) };
        }
    }

    public TerrainHeightMap Height => _height;

    public void SetHeightMap(TerrainHeightMap heightMap)
    {
        _height = heightMap;
        _conformCache.Clear();
    }

    /// <summary>The strip shape hugging the edge of a tile that faces its (dx, dy) neighbour.</summary>
    public static MarkerShape EdgeToward(int dx, int dy) => (dx, dy) switch
    {
        (1, 0) => MarkerShape.EdgeEast,
        (-1, 0) => MarkerShape.EdgeWest,
        (0, 1) => MarkerShape.EdgeNorth,
        _ => MarkerShape.EdgeSouth,
    };

    /// <summary>
    /// Give <paramref name="mi"/> the mesh for <paramref name="shape"/> on <paramref name="tile"/> and
    /// position it there. On a flat board that is the shared quad, rotated flat and offset inside the
    /// tile; on terrain it is the conforming mesh, authored around the tile centre with no rotation.
    /// <paramref name="lift"/> separates markers that would otherwise z-fight the one beneath them.
    /// </summary>
    public void Place(MeshInstance3D mi, PF2eVec tile, MarkerShape shape, float lift)
    {
        if (!_height.HasTerrain)
        {
            // Pooled markers are shared between encounters. One that carried a conforming mesh on a
            // terrain board must go back to the flat quad and its -90 degree rotation, or it would
            // render the previous map's slope over a flat tile.
            var flat = _flat[shape];
            if (mi.Mesh != flat)
            {
                mi.Mesh = flat;
                mi.RotationDegrees = new Vector3(-90f, 0f, 0f);
            }
            var (u0, u1, v0, v1) = Rect(shape);
            var centre = GridSpace.GridToWorld(tile);
            mi.Position = new Vector3(
                centre.X + (u0 + u1) * 0.5f - 0.5f,
                SurfaceY + lift,
                centre.Z + (v0 + v1) * 0.5f - 0.5f);
            return;
        }

        // The conforming mesh is authored around the tile centre and already carries the SurfaceY lift
        // plus each corner's offset from the centre height, so the node sits at the tile centre and
        // needs no rotation (the mesh is already horizontal, unlike the flat QuadMesh).
        mi.Mesh = ConformingMesh(tile, shape);
        mi.Rotation = Vector3.Zero;
        var at = GridSpace.GridToWorld(tile, _height);
        mi.Position = at with { Y = at.Y + lift };
    }

    /// <summary>A hidden, shadowless marker ready for <see cref="Place"/>.</summary>
    public static MeshInstance3D NewMarker() => new()
    {
        RotationDegrees = new Vector3(-90f, 0f, 0f),
        Visible = false,
        CastShadow = GeometryInstance3D.ShadowCastingSetting.Off,
    };

    public static StandardMaterial3D FlatMaterial(Color color) => new()
    {
        ShadingMode = BaseMaterial3D.ShadingModeEnum.Unshaded,
        Transparency = BaseMaterial3D.TransparencyEnum.Alpha,
        AlbedoColor = color,
        CullMode = BaseMaterial3D.CullModeEnum.Disabled,
    };

    /// <summary>A shape's rectangle in tile space: u along +X (west→east), v along +Z
    /// (south→north), both 0..1 across the tile. Strips sit inside the fill's inset edge.</summary>
    private (float u0, float u1, float v0, float v1) Rect(MarkerShape shape)
    {
        float lo = 0.5f - TileQuad * 0.5f;
        float hi = 0.5f + TileQuad * 0.5f;
        float dot = DotQuad * 0.5f;
        float w = _edgeWidth;
        return shape switch
        {
            MarkerShape.Fill => (lo, hi, lo, hi),
            MarkerShape.Dot => (0.5f - dot, 0.5f + dot, 0.5f - dot, 0.5f + dot),
            MarkerShape.EdgeEast => (hi - w, hi, lo, hi),
            MarkerShape.EdgeWest => (lo, lo + w, lo, hi),
            MarkerShape.EdgeNorth => (lo, hi, hi - w, hi),
            _ => (lo, hi, lo, lo + w),
        };
    }

    // ────────────────────────── Slope-conforming marker meshes ──────────────────────────

    private ArrayMesh ConformingMesh(PF2eVec tile, MarkerShape shape)
    {
        var key = (tile, shape);
        if (_conformCache.TryGetValue(key, out var cached)) return cached;
        var (u0, u1, v0, v1) = Rect(shape);
        var mesh = BuildMarkerMesh(_height.Corners(tile), _height.HeightScale, SurfaceY, u0, u1, v0, v1);
        _conformCache[key] = mesh;
        return mesh;
    }

    /// <summary>
    /// One rectangle of a tile whose corners follow <paramref name="corners"/>, expressed RELATIVE to
    /// the tile centre (so the instance is positioned by <c>GridToWorld</c> and the mesh supplies the
    /// slope). Ported from the Unity Tactics <c>TileMeshBuilder.BuildHighlightMesh</c>: four corner
    /// vertices, up normals, split along the shorter diagonal — with two Godot differences.
    ///
    /// 1. Winding is flipped (2nd and 3rd index of each triangle swapped), matching
    ///    <see cref="Map.TerrainGeometry"/>, whose diagonal-split rule this shares, so the lit
    ///    face points up in Godot's convention and lies on the terrain triangle it marks.
    /// 2. The rectangle is any sub-region of the tile in u/v, so the same builder serves the inset
    ///    fill, a boundary strip and a route dot. Corner heights come from <c>SampleHeight</c>, which
    ///    reproduces the raw corners exactly at the tile's own corners.
    /// </summary>
    private static ArrayMesh BuildMarkerMesh(
        TileCornerHeights corners, float heightScale, float yOffset,
        float u0, float u1, float v0, float v1)
    {
        float centerY = corners.CenterHeight * heightScale;

        // Tile-local offsets: 1 tile = 1 m (see GridSpace).
        Vector3 Corner(float u, float v) => new(
            u - 0.5f,
            corners.SampleHeight(u, v) * heightScale - centerY + yOffset,
            v - 0.5f);

        Vector3 vSW = Corner(u0, v0);
        Vector3 vSE = Corner(u1, v0);
        Vector3 vNE = Corner(u1, v1);
        Vector3 vNW = Corner(u0, v1);

        var buffer = new MeshBuffer(withColor: false);
        buffer.Add(vSW, Vector3.Up, new Vector2(0, 0));
        buffer.Add(vSE, Vector3.Up, new Vector2(1, 0));
        buffer.Add(vNE, Vector3.Up, new Vector2(1, 1));
        buffer.Add(vNW, Vector3.Up, new Vector2(0, 1));

        // Unity wound (0,2,1)+(0,3,2) / (0,3,1)+(1,3,2); both pairs swapped for Godot's front face.
        if (TerrainGeometry.ShouldSplitAlternate(vSW, vSE, vNE, vNW))
        {
            buffer.AddIndices(0, 1, 2);
            buffer.AddIndices(0, 2, 3);
        }
        else
        {
            buffer.AddIndices(0, 1, 3);
            buffer.AddIndices(1, 2, 3);
        }

        return buffer.ToArrayMesh("board_marker");
    }
}
