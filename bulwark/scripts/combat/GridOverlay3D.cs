using System.Collections.Generic;
using Godot;
using PF2eVec = PF2e.Vector2Int;

namespace Bulwark.Combat;

/// <summary>
/// Draws the controller-driven tile highlights (reachable Stride, adjacent Step, Strike targets) and
/// the hovered path preview as flat unshaded quads laid just above the floor. Pools its meshes so no
/// per-frame allocation. Thin presentation adapter — no rules, only render state pushed in from the
/// player-turn controller. Same API as the old 2D GridVisual highlight surface.
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

    private readonly List<MeshInstance3D> _tilePool = new();
    private readonly List<MeshInstance3D> _pathPool = new();
    private int _tileUsed;
    private int _pathUsed;

    private QuadMesh _tileMesh = null!;
    private QuadMesh _pathMesh = null!;
    private StandardMaterial3D _moveMat = null!;
    private StandardMaterial3D _stepMat = null!;
    private StandardMaterial3D _strikeMat = null!;
    private StandardMaterial3D _pathMat = null!;

    public override void _Ready()
    {
        _tileMesh = new QuadMesh { Size = new Vector2(TileQuad, TileQuad) };
        _pathMesh = new QuadMesh { Size = new Vector2(PathQuad, PathQuad) };
        _moveMat = FlatMaterial(MoveColor);
        _stepMat = FlatMaterial(StepColor);
        _strikeMat = FlatMaterial(StrikeColor);
        _pathMat = FlatMaterial(PathColor);
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
                _ => _moveMat,
            };
            foreach (var t in tiles)
            {
                var mi = RentTile();
                mi.MaterialOverride = mat;
                mi.Position = GridSpace.GridToWorld(t) with { Y = SurfaceY };
                mi.Visible = true;
            }
        }
        for (int i = _tileUsed; i < _tilePool.Count; i++) _tilePool[i].Visible = false;
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
                mi.Position = GridSpace.GridToWorld(node) with { Y = SurfaceY + 0.01f };
                mi.Visible = true;
            }
        }
        for (int i = _pathUsed; i < _pathPool.Count; i++) _pathPool[i].Visible = false;
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
}
