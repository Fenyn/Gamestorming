using System.Collections.Generic;
using Delve.Terrain;
using Delve.UI;
using Godot;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Combat;

/// <summary>
/// Draws the controller-driven targeting highlights (Strike targets, spell and skill targets, the
/// Shielded Stride tiles) and the hovered path preview just above the board surface. Pools its meshes
/// so no per-frame allocation. Thin presentation adapter — no rules, only render state pushed in from
/// the player-turn controller. Marker shapes come from <see cref="HighlightMeshes"/> (flat quad or
/// slope-conforming per tile); colours come from the palette through <see cref="UiColors"/>.
/// The Idle movement bands are a sibling, <see cref="MoveBandOverlay3D"/>.
///
/// Markers carry NO baked material — colour is a <c>MaterialOverride</c> on the pooled instance,
/// because one mesh is shared by every tile of a given shape. (Terrain meshes are the opposite case
/// and bake their materials; see <see cref="Map.MapMaterials"/>.)
/// </summary>
public partial class GridOverlay3D : Node3D
{
    private const float PathLift = 0.01f;
    private const float AreaLift = 0.005f;

    private readonly HighlightMeshes _meshes = new();
    private readonly List<MeshInstance3D> _tilePool = new();
    private readonly List<MeshInstance3D> _pathPool = new();
    private readonly List<MeshInstance3D> _areaPool = new();
    private int _tileUsed;
    private int _pathUsed;
    private int _areaUsed;

    private readonly Dictionary<HighlightKind, StandardMaterial3D> _highlightMats = new();
    private StandardMaterial3D _pathMat = null!;
    private readonly Dictionary<int, StandardMaterial3D> _pathBandMats = new();
    private StandardMaterial3D _areaTemplateMat = null!;

    /// <summary>The Idle bands, kept so a path dot can take the colour of the band it crosses.</summary>
    private IReadOnlyDictionary<PF2eVec, MoveOption>? _bands;

    public override void _Ready()
    {
        foreach (HighlightKind kind in System.Enum.GetValues<HighlightKind>())
        {
            if (kind != HighlightKind.None)
                _highlightMats[kind] = HighlightMeshes.FlatMaterial(UiColors.BoardHighlight(kind));
        }
        _pathMat = HighlightMeshes.FlatMaterial(UiColors.BoardPath);
        _areaTemplateMat = HighlightMeshes.FlatMaterial(UiColors.BoardArea);
    }

    /// <summary>
    /// Tell the overlay which surface it is drawing on. Called once per encounter, before any
    /// highlights. Passing <see cref="TerrainHeightMap.Flat"/> (the default) keeps the flat quad path.
    /// </summary>
    public void SetHeightMap(TerrainHeightMap heightMap) => _meshes.SetHeightMap(heightMap);

    /// <summary>Replace the highlighted tiles and how they render.</summary>
    public void SetHighlights(IReadOnlyCollection<PF2eVec> tiles, HighlightKind kind)
    {
        _tileUsed = 0;
        if (kind != HighlightKind.None)
        {
            var mat = _highlightMats[kind];
            foreach (var t in tiles)
            {
                var mi = Rent(_tilePool, ref _tileUsed);
                mi.MaterialOverride = mat;
                _meshes.Place(mi, t, MarkerShape.Fill, 0f);
                mi.Visible = true;
            }
        }
        HideRest(_tilePool, _tileUsed);
    }

    /// <summary>Replace the area-template highlight (distinct colour) shown while aiming an area spell.</summary>
    public void SetAreaPreview(IReadOnlyCollection<PF2eVec> tiles)
    {
        _areaUsed = 0;
        if (tiles != null)
        {
            foreach (var t in tiles)
            {
                var mi = Rent(_areaPool, ref _areaUsed);
                mi.MaterialOverride = _areaTemplateMat;
                _meshes.Place(mi, t, MarkerShape.Fill, AreaLift);
                mi.Visible = true;
            }
        }
        HideRest(_areaPool, _areaUsed);
    }

    /// <summary>The current Idle bands (empty when hidden); the next path preview colours its dots by them.</summary>
    public void SetPathBands(IReadOnlyDictionary<PF2eVec, MoveOption> bands)
        => _bands = bands.Count > 0 ? bands : null;

    /// <summary>Replace the hovered path-preview markers. A dot past the first Stride takes that
    /// band's colour, so the trail shows where the second action begins.</summary>
    public void SetPathPreview(IReadOnlyList<PF2eVec>? path)
    {
        _pathUsed = 0;
        if (path != null)
        {
            foreach (var node in path)
            {
                var mi = Rent(_pathPool, ref _pathUsed);
                mi.MaterialOverride = PathMaterialFor(node);
                _meshes.Place(mi, node, MarkerShape.Dot, PathLift);
                mi.Visible = true;
            }
        }
        HideRest(_pathPool, _pathUsed);
    }

    private StandardMaterial3D PathMaterialFor(PF2eVec node)
    {
        if (_bands == null || !_bands.TryGetValue(node, out var option) || option.Actions <= 1)
            return _pathMat;
        if (!_pathBandMats.TryGetValue(option.Actions, out var mat))
        {
            var colour = UiColors.BoardStride(option.Actions) with { A = UiColors.BoardPath.A };
            mat = HighlightMeshes.FlatMaterial(colour);
            _pathBandMats[option.Actions] = mat;
        }
        return mat;
    }

    private MeshInstance3D Rent(List<MeshInstance3D> pool, ref int used)
    {
        MeshInstance3D mi;
        if (used < pool.Count) mi = pool[used];
        else { mi = HighlightMeshes.NewMarker(); pool.Add(mi); AddChild(mi); }
        used++;
        return mi;
    }

    private static void HideRest(List<MeshInstance3D> pool, int used)
    {
        for (int i = used; i < pool.Count; i++) pool[i].Visible = false;
    }
}
