using System;
using System.Collections.Generic;
using PF2e.Grid;
using PF2e.MapGen;
using PF2e.MapGen.Biomes;

namespace Ungilded.Content;

/// <summary>
/// Paints an authored sewer <see cref="MapLayout"/>: stone floor, wall pillars, mud sludge as
/// difficult terrain, and water channels. Every tile sits at elevation 0. <see cref="Finish"/>
/// writes the flat corner heights the terrain mesh and line of sight read: pillars rise
/// <see cref="PillarHeightUnits"/>, any other wall the biome's wall height, everything else is
/// flat at 0. The terrain stage copies board corner heights verbatim, so this is the per-tile
/// height override. The walls around the board come from the terrain stage's halo.
/// </summary>
public sealed class SewerBoard
{
    public const string BiomeId = "sewer";

    private readonly MapLayout _layout;
    private readonly BiomeDefinition _biome;

    public SewerBoard(string name, int width, int height, int seed)
    {
        _biome = MapGenRegistry.GetBiome(BiomeId);
        _layout = new MapLayout { Name = name, Seed = seed, DeploymentZones = Array.Empty<DeploymentZoneData>() };
        _layout.Initialize(width, height);
        Fill(0, 0, width - 1, height - 1, TileRole.Ground, _biome.DefaultGroundSurface, TerrainDifficulty.Normal);
    }

    /// <summary>Pillar top above the floor, in corner units: half the biome's wall height, so a
    /// unit behind a pillar stays visible to the combat camera. Still well above a creature's
    /// line of sight, so a pillar blocks sight and grants cover like a full wall.</summary>
    public int PillarHeightUnits => _biome.WallHeight / 2;

    private readonly HashSet<(int X, int Y)> _pillars = new();

    /// <summary>A stone pillar over the inclusive tile rectangle: a Wall tile at
    /// <see cref="PillarHeightUnits"/>. Blocks movement and sight.</summary>
    public SewerBoard Pillar(int x0, int y0, int x1, int y1)
    {
        Fill(x0, y0, x1, y1, TileRole.Wall, _biome.DefaultWallSurface, TerrainDifficulty.Normal);
        for (int y = y0; y <= y1; y++)
            for (int x = x0; x <= x1; x++)
                _pillars.Add((x, y));
        return this;
    }

    /// <summary>Brackish sludge over the inclusive rectangle: difficult terrain, +5 ft per tile.</summary>
    public SewerBoard Sludge(int x0, int y0, int x1, int y1)
        => Fill(x0, y0, x1, y1, TileRole.DifficultTerrain, _biome.DefaultDifficultSurface, TerrainDifficulty.Difficult);

    /// <summary>A water channel over the inclusive rectangle.</summary>
    public SewerBoard Channel(int x0, int y0, int x1, int y1)
        => Fill(x0, y0, x1, y1, TileRole.Water, SurfaceType.Water, TerrainDifficulty.Normal);

    public MapLayout Finish()
    {
        for (int y = 0; y < _layout.Height; y++)
            for (int x = 0; x < _layout.Width; x++)
                _layout.SetCornerHeights(x, y, TileCornerHeights.Flat(WallTopAt(x, y)));
        return _layout;
    }

    private int WallTopAt(int x, int y)
    {
        if (_layout.GetTile(x, y) != TileRole.Wall) return 0;
        return _pillars.Contains((x, y)) ? PillarHeightUnits : _biome.WallHeight;
    }

    private SewerBoard Fill(int x0, int y0, int x1, int y1, TileRole role, SurfaceType surface, TerrainDifficulty difficulty)
    {
        for (int y = y0; y <= y1; y++)
            for (int x = x0; x <= x1; x++)
            {
                if (!_layout.IsInBounds(x, y))
                    throw new ArgumentOutOfRangeException($"({x}, {y}) is outside the {_layout.Width}x{_layout.Height} board '{_layout.Name}'.");
                _layout.SetTile(x, y, role);
                _layout.SetSurface(x, y, surface);
                _layout.SetTerrainDifficulty(x, y, difficulty);
            }
        return this;
    }
}
