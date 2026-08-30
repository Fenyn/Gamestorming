using System.Collections.Generic;
using Delve.Terrain;
using Godot;
using PF2e.Grid;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Combat;

/// <summary>
/// Draws the controller-driven tile highlights (reachable Stride, adjacent Step, Strike targets) and
/// the hovered path preview just above the board surface. Pools its meshes so no per-frame allocation.
/// Thin presentation adapter — no rules, only render state pushed in from the player-turn controller.
///
/// Two rendering modes, chosen once per encounter by <see cref="SetHeightMap"/>:
/// <list type="bullet">
/// <item><b>Flat</b> (no terrain) — one shared <see cref="QuadMesh"/> rotated flat, exactly as before.</item>
/// <item><b>Terrain</b> — a per-tile <see cref="ArrayMesh"/> whose four corners follow the tile's corner
/// heights, so a highlight lies ON a ramp instead of slicing through it. Built lazily and cached for
/// the encounter; the cache is dropped whenever the height map changes.</item>
/// </list>
/// Highlight meshes carry NO baked material either way — colour is a <c>MaterialOverride</c> on the
/// pooled instance, because one mesh is shared by every tile of a given shape. (Terrain meshes are the
/// opposite case and bake their materials; see <see cref="Map.MapMaterials"/>.)
/// </summary>
public partial class GridOverlay3D : Node3D
{
    private const float SurfaceY = 0.02f;
    private const float TileQuad = 0.9f;
    private const float PathQuad = 0.35f;

    private static readonly Color MoveColor = new(0.25f, 0.5f, 1f, 0.35f);
    private static readonly Color StepColor = new(0.2f, 0.95f, 0.95f, 0.35f);
    private static readonly Color StrikeColor = new(1f, 0.28f, 0.28f, 0.45f);
    private static readonly Color PathColor = new(1f, 0.92f, 0.25f, 0.8f);
    private static readonly Color SpellEnemyColor = new(0.85f, 0.3f, 1f, 0.45f);
    private static readonly Color AllyColor = new(0.35f, 1f, 0.45f, 0.4f);
    private static readonly Color AreaOriginColor = new(1f, 0.65f, 0.2f, 0.3f);
    private static readonly Color AreaTemplateColor = new(1f, 0.5f, 0.1f, 0.55f);

    private readonly List<MeshInstance3D> _tilePool = new();
    private readonly List<MeshInstance3D> _pathPool = new();
    private readonly List<MeshInstance3D> _areaPool = new();
    private int _tileUsed;
    private int _pathUsed;
    private int _areaUsed;

    private QuadMesh _tileMesh = null!;
    private QuadMesh _pathMesh = null!;
    private StandardMaterial3D _moveMat = null!;
    private StandardMaterial3D _stepMat = null!;
    private StandardMaterial3D _strikeMat = null!;
    private StandardMaterial3D _pathMat = null!;
    private StandardMaterial3D _spellEnemyMat = null!;
    private StandardMaterial3D _allyMat = null!;
    private StandardMaterial3D _areaOriginMat = null!;
    private StandardMaterial3D _areaTemplateMat = null!;

    private TerrainHeightMap _height = TerrainHeightMap.Flat;
    private readonly Dictionary<PF2eVec, ArrayMesh> _conformCache = new();

    public override void _Ready()
    {
        _tileMesh = new QuadMesh { Size = new Vector2(TileQuad, TileQuad) };
        _pathMesh = new QuadMesh { Size = new Vector2(PathQuad, PathQuad) };
        _moveMat = FlatMaterial(MoveColor);
        _stepMat = FlatMaterial(StepColor);
        _strikeMat = FlatMaterial(StrikeColor);
        _pathMat = FlatMaterial(PathColor);
        _spellEnemyMat = FlatMaterial(SpellEnemyColor);
        _allyMat = FlatMaterial(AllyColor);
        _areaOriginMat = FlatMaterial(AreaOriginColor);
        _areaTemplateMat = FlatMaterial(AreaTemplateColor);
    }

    /// <summary>
    /// Tell the overlay which surface it is drawing on. Called once per encounter, before any
    /// highlights. Passing <see cref="TerrainHeightMap.Flat"/> (the default) keeps the flat quad path.
    /// Drops the conforming-mesh cache, so a new encounter never reuses the previous map's shapes.
    /// </summary>
    public void SetHeightMap(TerrainHeightMap heightMap)
    {
        _height = heightMap;
        _conformCache.Clear();
    }

    /// <summary>Replace the highlighted tiles and how they render.</summary>
    public void SetHighlights(IReadOnlyCollection<PF2eVec> tiles, HighlightKind kind)
    {
        _tileUsed = 0;
        if (kind != HighlightKind.None)
        {
            var mat = kind switch
            {
                HighlightKind.Move => _moveMat,
                HighlightKind.Step => _stepMat,
                HighlightKind.StrikeTarget => _strikeMat,
                HighlightKind.SpellEnemyTarget => _spellEnemyMat,
                HighlightKind.AllyTarget => _allyMat,
                HighlightKind.AreaOrigin => _areaOriginMat,
                _ => _moveMat,
            };
            foreach (var t in tiles)
            {
                var mi = RentTile();
                mi.MaterialOverride = mat;
                PlaceTileMarker(mi, t, 0f);
                mi.Visible = true;
            }
        }
        for (int i = _tileUsed; i < _tilePool.Count; i++) _tilePool[i].Visible = false;
    }

    /// <summary>Replace the area-template highlight (distinct colour) shown while aiming an area spell.</summary>
    public void SetAreaPreview(IReadOnlyCollection<PF2eVec> tiles)
    {
        _areaUsed = 0;
        if (tiles != null)
        {
            foreach (var t in tiles)
            {
                var mi = RentArea();
                PlaceTileMarker(mi, t, 0.005f);
                mi.Visible = true;
            }
        }
        for (int i = _areaUsed; i < _areaPool.Count; i++) _areaPool[i].Visible = false;
    }

    /// <summary>Replace the hovered path-preview markers.</summary>
    public void SetPathPreview(IReadOnlyList<PF2eVec>? path)
    {
        _pathUsed = 0;
        if (path != null)
        {
            foreach (var node in path)
            {
                var mi = RentPath();
                // Path dots stay small flat quads whatever the terrain does — they only have to read as
                // a dotted trail, and a 0.35 m quad on a ramp is imperceptibly non-conforming. They are
                // lifted to the tile's centre height so they still sit on the surface.
                var at = GridSpace.GridToWorld(node, _height);
                mi.Position = at with { Y = at.Y + SurfaceY + 0.01f };
                mi.Visible = true;
            }
        }
        for (int i = _pathUsed; i < _pathPool.Count; i++) _pathPool[i].Visible = false;
    }

    /// <summary>
    /// Position one pooled tile-sized marker over <paramref name="t"/>, giving it the conforming mesh
    /// (and no rotation) when terrain is present. <paramref name="lift"/> separates markers that would
    /// otherwise z-fight with the highlight beneath them.
    /// </summary>
    private void PlaceTileMarker(MeshInstance3D mi, PF2eVec t, float lift)
    {
        if (!_height.HasTerrain)
        {
            // Pooled markers are shared between encounters. One that carried a conforming mesh on a
            // terrain board must go back to the flat quad and its -90 degree rotation, or it would
            // render the previous map's slope over a flat tile.
            if (mi.Mesh != _tileMesh)
            {
                mi.Mesh = _tileMesh;
                mi.RotationDegrees = new Vector3(-90f, 0f, 0f);
            }
            mi.Position = GridSpace.GridToWorld(t) with { Y = SurfaceY + lift };
            return;
        }

        // The conforming mesh is authored around the tile centre and already carries the SurfaceY lift
        // plus each corner's offset from the centre height, so the node sits at the tile centre and
        // needs no rotation (the mesh is already horizontal, unlike the flat QuadMesh).
        mi.Mesh = ConformingMesh(t);
        mi.Rotation = Vector3.Zero;
        var at = GridSpace.GridToWorld(t, _height);
        mi.Position = at with { Y = at.Y + lift };
    }

    private MeshInstance3D RentTile()
    {
        MeshInstance3D mi;
        if (_tileUsed < _tilePool.Count) mi = _tilePool[_tileUsed];
        else { mi = MakeFlatQuad(_tileMesh); _tilePool.Add(mi); AddChild(mi); }
        _tileUsed++;
        return mi;
    }

    private MeshInstance3D RentPath()
    {
        MeshInstance3D mi;
        if (_pathUsed < _pathPool.Count) mi = _pathPool[_pathUsed];
        else { mi = MakeFlatQuad(_pathMesh); mi.MaterialOverride = _pathMat; _pathPool.Add(mi); AddChild(mi); }
        _pathUsed++;
        return mi;
    }

    private MeshInstance3D RentArea()
    {
        MeshInstance3D mi;
        if (_areaUsed < _areaPool.Count) mi = _areaPool[_areaUsed];
        else { mi = MakeFlatQuad(_tileMesh); mi.MaterialOverride = _areaTemplateMat; _areaPool.Add(mi); AddChild(mi); }
        _areaUsed++;
        return mi;
    }

    private static MeshInstance3D MakeFlatQuad(QuadMesh mesh) => new()
    {
        Mesh = mesh,
        RotationDegrees = new Vector3(-90f, 0f, 0f),
        Visible = false,
        CastShadow = GeometryInstance3D.ShadowCastingSetting.Off,
    };

    private static StandardMaterial3D FlatMaterial(Color color) => new()
    {
        ShadingMode = BaseMaterial3D.ShadingModeEnum.Unshaded,
        Transparency = BaseMaterial3D.TransparencyEnum.Alpha,
        AlbedoColor = color,
        CullMode = BaseMaterial3D.CullModeEnum.Disabled,
    };

    // ────────────────────────── Slope-conforming highlight meshes ──────────────────────────

    private ArrayMesh ConformingMesh(PF2eVec t)
    {
        if (_conformCache.TryGetValue(t, out var cached)) return cached;
        var mesh = BuildHighlightMesh(_height.Corners(t), _height.HeightScale, SurfaceY, TileQuad);
        _conformCache[t] = mesh;
        return mesh;
    }

    /// <summary>
    /// One tile-shaped overlay quad whose corners follow <paramref name="corners"/>, expressed RELATIVE
    /// to the tile centre (so the instance is positioned by <c>GridToWorld</c> and the mesh supplies the
    /// slope). Ported from the Unity Tactics <c>TileMeshBuilder.BuildHighlightMesh</c>: four corner
    /// vertices, up normals, split along the shorter diagonal — with two Godot differences.
    ///
    /// 1. Winding is flipped (2nd and 3rd index of each triangle swapped), matching
    ///    <see cref="Map.TerrainGeometry"/>, whose diagonal-split rule this shares, so the lit
    ///    face points up in Godot's convention and lies on the terrain triangle it marks.
    /// 2. <paramref name="size"/> insets the quad inside its tile (0.9 by default, the same inset the
    ///    flat <see cref="QuadMesh"/> path uses, so the two modes read identically). The inset corner
    ///    heights come from <c>SampleHeight</c>, which reproduces the raw corners exactly at size 1.
    /// </summary>
    private static ArrayMesh BuildHighlightMesh(
        TileCornerHeights corners, float heightScale, float yOffset, float size)
    {
        float half = size * 0.5f;
        // Corner (u, v) in tile space: u along +X (west→east), v along +Z (south→north).
        float lo = 0.5f - half;
        float hi = 0.5f + half;
        float centerY = corners.CenterHeight * heightScale;

        // Tile-local offsets: 1 tile = 1 m (see GridSpace).
        Vector3 Corner(float u, float v) => new(
            u - 0.5f,
            corners.SampleHeight(u, v) * heightScale - centerY + yOffset,
            v - 0.5f);

        Vector3 vSW = Corner(lo, lo);
        Vector3 vSE = Corner(hi, lo);
        Vector3 vNE = Corner(hi, hi);
        Vector3 vNW = Corner(lo, hi);

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

        return buffer.ToArrayMesh("tile_highlight");
    }
}
