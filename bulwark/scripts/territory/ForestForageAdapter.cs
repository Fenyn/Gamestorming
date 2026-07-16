using System.Collections.Generic;
using Godot;

namespace Bulwark.Territory;

/// <summary>
/// Engine-aware <see cref="IForageCellProvider"/> over a painted territory's TileMapLayers — the
/// seam that keeps Godot types out of <see cref="ForageSystem"/>. Valid spawn cell =
/// grass-family Ground terrain (grass + the probed forest-floor litter/moss variants; dirt trail
/// and pond water fail the family check), no Walls/Props tile (collision), no Overhead-family tile
/// (perimeter band fill and tree canopies), inside the playable rect (the painted rect shrunk by
/// one ring). Reserved cells (authored nodes, roamer markers) and trail cells (exit trigger, entry
/// spawn — clearance is pass-specific: forage 2, debris 1) are supplied by the scene at
/// construction; the system enforces the spacing.
/// </summary>
public sealed class ForestForageAdapter : IForageCellProvider
{
    private readonly TileMapLayer _ground;
    private readonly TileMapLayer?[] _blockedLayers;
    private readonly HashSet<int> _validTerrains = new();
    private readonly List<(int X, int Y)> _reserved;
    private readonly List<(int X, int Y)> _trail;
    private readonly (int X0, int Y0, int X1, int Y1) _rect;

    /// <summary>Probe tiles for the grass-family terrains (same cells ForestPainter probes):
    /// pre-expanded forest-floor source 201, blocks (1,0) leaf litter and (1,1) moss.</summary>
    private const int ForestFloorSource = 201;
    private static readonly Vector2I LitterProbe = new(13 + 9, 2);
    private static readonly Vector2I MossProbe = new(13 + 9, 7);
    private const int GrassTerrain = 0;

    public ForestForageAdapter(
        TileMapLayer ground, IEnumerable<TileMapLayer?> blockedLayers,
        IEnumerable<(int X, int Y)> reservedCells, IEnumerable<(int X, int Y)> trailCells)
    {
        _ground = ground;
        _blockedLayers = new List<TileMapLayer?>(blockedLayers).ToArray();
        _reserved = new List<(int, int)>(reservedCells);
        _trail = new List<(int, int)>(trailCells);

        Rect2I used = ground.GetUsedRect();
        _rect = (used.Position.X + 1, used.Position.Y + 1, used.End.X - 2, used.End.Y - 2);

        _validTerrains.Add(GrassTerrain);
        AddProbedTerrain(LitterProbe);
        AddProbedTerrain(MossProbe);
    }

    public (int X0, int Y0, int X1, int Y1) PlayableRect => _rect;

    public IReadOnlyCollection<(int X, int Y)> ReservedCells => _reserved;

    public IReadOnlyCollection<(int X, int Y)> TrailCells => _trail;

    public bool IsOpenGround(int x, int y)
    {
        var cell = new Vector2I(x, y);

        TileData? ground = _ground.GetCellTileData(cell);
        if (ground == null || ground.TerrainSet != 0 || !_validTerrains.Contains(ground.Terrain))
            return false;

        foreach (TileMapLayer? layer in _blockedLayers)
        {
            if (layer != null && layer.GetCellSourceId(cell) != -1)
                return false;
        }
        return true;
    }

    /// <summary>Resolve a forest-floor terrain id from a known probe tile; skipped gracefully when
    /// the tileset lacks the source (blockout scenes fall back to plain grass).</summary>
    private void AddProbedTerrain(Vector2I probe)
    {
        if (_ground.TileSet?.GetSource(ForestFloorSource) is not TileSetAtlasSource src
            || !src.HasTile(probe))
        {
            return;
        }
        TileData data = src.GetTileData(probe, 0);
        if (data.TerrainSet == 0 && data.Terrain >= 0)
            _validTerrains.Add(data.Terrain);
    }
}
