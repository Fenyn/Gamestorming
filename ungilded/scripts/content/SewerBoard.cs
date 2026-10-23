using System;
using System.Collections.Generic;
using PF2e.Grid;
using PF2e.MapGen;
using PF2e.MapGen.Biomes;
using Ungilded.Terrain;

namespace Ungilded.Content;

/// <summary>
/// Paints an authored sewer place: the board (<see cref="Finish"/>) and the halo around it
/// (<see cref="Halo"/>). On the board: stone floor, wall pillars, full-height outline walls, mud
/// sludge as difficult terrain, and water channels sunk <see cref="ChannelRecessUnits"/> below the
/// floor. <see cref="Finish"/> writes the flat corner heights the terrain mesh and line of sight
/// read: pillars rise <see cref="PillarHeightUnits"/>, any other wall the biome's wall height,
/// channels sit below the floor, everything else is flat at 0. The terrain stage copies board corner
/// heights verbatim, so this is the per-tile height override.
///
/// Around the board: every halo tile is wall unless a halo call opens it. Halo calls take board
/// coordinates outside the board. <see cref="Run"/> reads the board as painted so far, so paint the
/// board before the runs that carry it outward.
/// </summary>
public sealed class SewerBoard
{
    public const string BiomeId = "sewer";

    /// <summary>Halo dressing marks (<see cref="Mark"/>): a water pipe pouring from the marked wall
    /// tile, a drain grate set in it, a skeleton slumped against the wall beside the marked floor
    /// tile, a drain grate in the marked floor tile. <see cref="Run"/> marks each channel or sludge
    /// tile where a run leaves the board.</summary>
    public const string OutfallMark = "outfall";
    public const string GrateMark = "grate";
    public const string SkeletonMark = "skeleton";
    public const string FloorGrateMark = "floor_grate";
    public const string CulvertMark = "culvert";

    /// <summary>Depth of a water channel below the floor, in corner units (0.25 m). Half an
    /// elevation: a step a creature takes in its stride, too shallow to block a line or give cover.</summary>
    public const int ChannelRecessUnits = 2;

    private readonly MapLayout _layout;
    private readonly BiomeDefinition _biome;
    private readonly SewerHalo _halo;

    public SewerBoard(string name, int width, int height, int seed)
    {
        _biome = MapGenRegistry.GetBiome(BiomeId);
        _layout = new MapLayout { Name = name, Seed = seed, DeploymentZones = Array.Empty<DeploymentZoneData>() };
        _layout.Initialize(width, height);
        Fill(0, 0, width - 1, height - 1, TileRole.Ground, _biome.DefaultGroundSurface, TerrainDifficulty.Normal);
        _halo = new SewerHalo(_layout, -ChannelRecessUnits);
    }

    /// <summary>Pillar top above the floor, in corner units (0.625 m). The camera never cuts a
    /// pillar, so it is kept low enough that a rat standing right behind one stays in view from the
    /// lowest camera pitch. Still above a creature's line of sight (3 units), so a pillar blocks
    /// sight and grants cover like a full wall.</summary>
    public const int PillarHeightUnits = 5;

    /// <summary>The authored halo, for the terrain stage.</summary>
    public HaloPlan Halo => _halo.Plan;

    private readonly HashSet<(int X, int Y)> _pillars = new();

    /// <summary>A stone pillar over the inclusive tile rectangle: a Wall tile at
    /// <see cref="PillarHeightUnits"/>. Blocks movement and sight.</summary>
    public SewerBoard Pillar(int x0, int y0, int x1, int y1)
    {
        Wall(x0, y0, x1, y1);
        for (int y = y0; y <= y1; y++)
            for (int x = x0; x <= x1; x++)
                _pillars.Add((x, y));
        return this;
    }

    /// <summary>Full-height masonry over the inclusive rectangle: part of the room's outline.</summary>
    public SewerBoard Wall(int x0, int y0, int x1, int y1)
        => Fill(x0, y0, x1, y1, TileRole.Wall, _biome.DefaultWallSurface, TerrainDifficulty.Normal);

    /// <summary>Cuts each board corner off with a diagonal of outline wall, <paramref name="size"/>
    /// tiles along each edge.</summary>
    public SewerBoard Chamfer(int size)
    {
        int w = _layout.Width - 1, h = _layout.Height - 1;
        for (int i = 0; i < size; i++)
            for (int j = 0; i + j < size; j++)
            {
                Wall(i, j, i, j);
                Wall(w - i, j, w - i, j);
                Wall(i, h - j, i, h - j);
                Wall(w - i, h - j, w - i, h - j);
            }
        return this;
    }

    /// <summary>Brackish sludge over the inclusive rectangle: difficult terrain, +5 ft per tile.</summary>
    public SewerBoard Sludge(int x0, int y0, int x1, int y1)
        => Fill(x0, y0, x1, y1, TileRole.DifficultTerrain, _biome.DefaultDifficultSurface, TerrainDifficulty.Difficult);

    /// <summary>A water channel over the inclusive rectangle, sunk below the floor.</summary>
    public SewerBoard Channel(int x0, int y0, int x1, int y1)
        => Fill(x0, y0, x1, y1, TileRole.Water, SurfaceType.Water, TerrainDifficulty.Normal);

    /// <summary>Open halo floor, <paramref name="floor"/> corner units above the board floor.</summary>
    public SewerBoard HaloFloor(int x0, int y0, int x1, int y1, int floor = 0)
    {
        _halo.Floor(x0, y0, x1, y1, floor);
        return this;
    }

    /// <summary>Halo channel water at the board channels' level.</summary>
    public SewerBoard HaloWater(int x0, int y0, int x1, int y1)
    {
        _halo.Water(x0, y0, x1, y1);
        return this;
    }

    /// <summary>Halo masonry over cells an earlier call opened (a pier standing on a ledge).</summary>
    public SewerBoard HaloWall(int x0, int y0, int x1, int y1)
    {
        _halo.Wall(x0, y0, x1, y1);
        return this;
    }

    /// <summary>A footbridge in the halo, over the channel it crosses.</summary>
    public SewerBoard HaloBridge(int x0, int y0, int x1, int y1)
    {
        _halo.Bridge(x0, y0, x1, y1);
        return this;
    }

    /// <summary>Carries board edge tiles <paramref name="from"/>..<paramref name="to"/> on
    /// <paramref name="side"/> out to the rim as a passage, channel or culvert.</summary>
    public SewerBoard Run(BoardSide side, int from, int to, int rise = 0)
    {
        _halo.Run(side, from, to, rise);
        return this;
    }

    /// <summary>The side every run of water and sludge on this board flows toward. The culvert
    /// streaks, the water scroll and the sludge ripple all follow it.</summary>
    public SewerBoard Flow(BoardSide side)
    {
        _halo.Flow(side);
        return this;
    }

    /// <summary>A dressing mark at a halo tile: <see cref="OutfallMark"/> and <see cref="GrateMark"/>
    /// on a wall tile, <see cref="SkeletonMark"/> on a floor tile.</summary>
    public SewerBoard Mark(string kind, int x, int y)
    {
        _halo.Mark(kind, x, y);
        return this;
    }

    public MapLayout Finish()
    {
        for (int y = 0; y < _layout.Height; y++)
            for (int x = 0; x < _layout.Width; x++)
                _layout.SetCornerHeights(x, y, TileCornerHeights.Flat(TopAt(x, y)));
        return _layout;
    }

    private int TopAt(int x, int y) => _layout.GetTile(x, y) switch
    {
        TileRole.Wall => _pillars.Contains((x, y)) ? PillarHeightUnits : _biome.WallHeight,
        TileRole.Water => -ChannelRecessUnits,
        _ => 0,
    };

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
                if (role != TileRole.Wall) _pillars.Remove((x, y));
            }
        return this;
    }
}
