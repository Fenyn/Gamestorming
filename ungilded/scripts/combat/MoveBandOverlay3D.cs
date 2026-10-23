using System.Collections.Generic;
using Ungilded.Terrain;
using Ungilded.UI;
using Godot;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Combat;

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

    /// <summary>Glowing-rim shader for the band fills. Unset, fills are flat colour.</summary>
    [Export] public Shader? TileShader { get; set; }

    /// <summary>Rim alpha of the two-action and further band tiles.</summary>
    [Export(PropertyHint.Range, "0,1,0.05")] public float OuterBandRimAlpha { get; set; } = 0f;

    private const string RimAlphaUniform = "rim_alpha";

    /// <summary>Alpha the gold guide tiles fall to between pulses; they rise to the palette alpha.</summary>
    [Export(PropertyHint.Range, "0,1,0.05")] public float GuideAlphaLow { get; set; } = 0.2f;

    /// <summary>Guide pulses per second, low to high and back counting as two.</summary>
    [Export(PropertyHint.Range, "0,5,0.1")] public float GuidePulseRate { get; set; } = 1.8f;

    private const float GuideLift = 0.003f;
    private const float EdgeLift = 0.006f;
    private const float GuideEdgeLift = 0.009f;
    private const float CursorLift = 0.012f;

    private readonly List<MeshInstance3D> _guidePool = new();
    private int _guideUsed;
    private StandardMaterial3D _guideFill = null!;
    private StandardMaterial3D _guideEdge = null!;
    private Color _guideColor;
    private double _guideClock;

    private HighlightMeshes _meshes = null!;
    private readonly List<MeshInstance3D> _fillPool = new();
    private readonly List<MeshInstance3D> _edgePool = new();
    private readonly MeshInstance3D[] _cursor = new MeshInstance3D[4];
    private int _fillUsed;
    private int _edgeUsed;

    private Material _stepFill = null!;
    private StandardMaterial3D _stepEdge = null!;
    private readonly Dictionary<int, Material> _strideFill = new();
    private readonly Dictionary<int, StandardMaterial3D> _strideEdge = new();

    private static readonly (int dx, int dy)[] Cardinals = { (1, 0), (-1, 0), (0, 1), (0, -1) };

    public override void _Ready()
    {
        _meshes = new HighlightMeshes(BandEdgeWidth);
        _stepFill = HighlightMeshes.TileMaterial(TileShader, UiColors.BoardStep);
        _stepEdge = HighlightMeshes.FlatMaterial(UiColors.BoardStep with { A = BandEdgeAlpha });

        _guideColor = UiColors.BoardGuide;
        _guideFill = HighlightMeshes.FlatMaterial(_guideColor);
        _guideEdge = HighlightMeshes.FlatMaterial(_guideColor with { A = BandEdgeAlpha });
        SetProcess(false);

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
        ShowBands(!_guided);
    }

    /// <summary>Show or hide the placed band fills and strips without forgetting them.</summary>
    private void ShowBands(bool shown)
    {
        for (int i = 0; i < _fillUsed; i++) _fillPool[i].Visible = shown;
        for (int i = 0; i < _edgeUsed; i++) _edgePool[i].Visible = shown;
    }

    private bool _guided;

    /// <summary>Pulsing gold tiles, each framed on all four sides: the only tiles a tutorial move
    /// accepts. While any show, the bands hide, so the gold tiles are the only move markers on the
    /// board; the bands come back when the guide clears. Empty hides them. With
    /// <paramref name="hint"/> the tiles are a suggestion over a free move and the bands stay.</summary>
    public void SetGuideTiles(IReadOnlyCollection<PF2eVec> tiles, bool hint = false)
    {
        _guided = tiles.Count > 0 && !hint;
        ShowBands(!_guided);
        _guideUsed = 0;
        foreach (var tile in tiles)
        {
            var fill = Rent(_guidePool, ref _guideUsed);
            fill.MaterialOverride = _guideFill;
            _meshes.Place(fill, tile, MarkerShape.Fill, GuideLift);
            fill.Visible = true;
            foreach (var (dx, dy) in Cardinals)
            {
                var edge = Rent(_guidePool, ref _guideUsed);
                edge.MaterialOverride = _guideEdge;
                _meshes.Place(edge, tile, HighlightMeshes.EdgeToward(dx, dy), GuideEdgeLift);
                edge.Visible = true;
            }
        }
        for (int i = _guideUsed; i < _guidePool.Count; i++) _guidePool[i].Visible = false;
        _guideClock = 0;
        SetProcess(tiles.Count > 0);
        Pulse();
    }

    /// <summary>How many gold guide tiles show. Dev spikes read it.</summary>
    public int GuideTileCount => _guideUsed / 5;

    public override void _Process(double delta)
    {
        _guideClock += delta;
        Pulse();
    }

    private void Pulse()
    {
        float t = Mathf.PingPong((float)_guideClock * GuidePulseRate, 1f);
        _guideFill.AlbedoColor = _guideColor with { A = Mathf.Lerp(GuideAlphaLow, _guideColor.A, t) };
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

    private Material FillFor(MoveOption option)
    {
        if (option.Kind == MoveKind.Step) return _stepFill;
        if (!_strideFill.TryGetValue(option.Actions, out var mat))
        {
            mat = HighlightMeshes.TileMaterial(TileShader, UiColors.BoardStride(option.Actions));
            // Only the nearest band rims each tile; further bands rimmed tile by tile draw a lattice
            // across the board, and the boundary strips already outline them.
            if (option.Actions >= 2 && mat is ShaderMaterial glow) glow.SetShaderParameter(RimAlphaUniform, OuterBandRimAlpha);
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
