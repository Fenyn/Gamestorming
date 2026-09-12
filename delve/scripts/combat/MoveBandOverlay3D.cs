using System.Collections.Generic;
using Delve.Terrain;
using Delve.UI;
using Godot;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Combat;

/// <summary>
/// The Idle-mode movement bands: every tile the active unit can end a smart move on, filled per
/// action cost (Step tiles in the safe colour), with a boundary strip along each edge where the
/// band changes, plus a bright frame on the hovered tile. Every marker is placed through
/// <see cref="HighlightMeshes"/>, so fills, strips and the frame all follow the terrain surface.
/// Pooled meshes, no rules — render state is pushed in from the player-turn controller. Its own
/// node so a targeting mode's <see cref="GridOverlay3D"/> highlights and these bands never share a pool.
/// </summary>
public partial class MoveBandOverlay3D : Node3D
{
    /// <summary>Width (m) of the strip drawn inside a tile along a band boundary.</summary>
    [Export] public float BandEdgeWidth { get; set; } = 0.06f;

    /// <summary>Alpha of the boundary strips (the band fill colour, lifted to this alpha).</summary>
    [Export(PropertyHint.Range, "0,1,0.05")] public float BandEdgeAlpha { get; set; } = 0.85f;

    private const float EdgeLift = 0.006f;
    private const float CursorLift = 0.012f;

    private HighlightMeshes _meshes = null!;
    private readonly List<MeshInstance3D> _fillPool = new();
    private readonly List<MeshInstance3D> _edgePool = new();
    private readonly MeshInstance3D[] _cursor = new MeshInstance3D[4];
    private int _fillUsed;
    private int _edgeUsed;

    private StandardMaterial3D _stepFill = null!;
    private StandardMaterial3D _stepEdge = null!;
    private readonly Dictionary<int, StandardMaterial3D> _strideFill = new();
    private readonly Dictionary<int, StandardMaterial3D> _strideEdge = new();

    private static readonly (int dx, int dy)[] Cardinals = { (1, 0), (-1, 0), (0, 1), (0, -1) };

    public override void _Ready()
    {
        _meshes = new HighlightMeshes(BandEdgeWidth);
        _stepFill = HighlightMeshes.FlatMaterial(UiColors.BoardStep);
        _stepEdge = HighlightMeshes.FlatMaterial(UiColors.BoardStep with { A = BandEdgeAlpha });

        var cursorMat = HighlightMeshes.FlatMaterial(UiColors.BoardCursor);
        for (int i = 0; i < 4; i++)
        {
            _cursor[i] = HighlightMeshes.NewMarker();
            _cursor[i].MaterialOverride = cursorMat;
            AddChild(_cursor[i]);
        }
    }

    /// <summary>Which surface to draw on. Called once per encounter, before any bands.</summary>
    public void SetHeightMap(TerrainHeightMap heightMap) => _meshes.SetHeightMap(heightMap);

    /// <summary>Replace the bands. An empty set hides them.</summary>
    public void SetBands(IReadOnlyDictionary<PF2eVec, MoveOption> options)
    {
        _fillUsed = 0;
        _edgeUsed = 0;
        foreach (var (tile, option) in options)
        {
            var fill = Rent(_fillPool, ref _fillUsed);
            fill.MaterialOverride = FillFor(option);
            _meshes.Place(fill, tile, MarkerShape.Fill, 0f);
            fill.Visible = true;

            foreach (var (dx, dy) in Cardinals)
            {
                var neighbour = new PF2eVec(tile.x + dx, tile.y + dy);
                if (options.TryGetValue(neighbour, out var other) && other == option) continue;
                var edge = Rent(_edgePool, ref _edgeUsed);
                edge.MaterialOverride = EdgeFor(option);
                _meshes.Place(edge, tile, HighlightMeshes.EdgeToward(dx, dy), EdgeLift);
                edge.Visible = true;
            }
        }
        for (int i = _fillUsed; i < _fillPool.Count; i++) _fillPool[i].Visible = false;
        for (int i = _edgeUsed; i < _edgePool.Count; i++) _edgePool[i].Visible = false;
    }

    /// <summary>Frame the hovered tile; null hides the frame.</summary>
    public void SetHoverTile(PF2eVec? tile)
    {
        for (int i = 0; i < 4; i++)
        {
            var strip = _cursor[i];
            strip.Visible = tile.HasValue;
            if (!tile.HasValue) continue;
            var (dx, dy) = Cardinals[i];
            _meshes.Place(strip, tile.Value, HighlightMeshes.EdgeToward(dx, dy), CursorLift);
        }
    }

    private StandardMaterial3D FillFor(MoveOption option)
    {
        if (option.Kind == MoveKind.Step) return _stepFill;
        if (!_strideFill.TryGetValue(option.Actions, out var mat))
        {
            mat = HighlightMeshes.FlatMaterial(UiColors.BoardStride(option.Actions));
            _strideFill[option.Actions] = mat;
        }
        return mat;
    }

    private StandardMaterial3D EdgeFor(MoveOption option)
    {
        if (option.Kind == MoveKind.Step) return _stepEdge;
        if (!_strideEdge.TryGetValue(option.Actions, out var mat))
        {
            mat = HighlightMeshes.FlatMaterial(UiColors.BoardStride(option.Actions) with { A = BandEdgeAlpha });
            _strideEdge[option.Actions] = mat;
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
}
