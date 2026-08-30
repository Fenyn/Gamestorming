using PF2e.MapGen;

namespace Delve.Terrain;

/// <summary>
/// How one biome grows the halo of synthesized tiles AROUND its battle map — the "skirt" that
/// replaces the old flat apron. Pure data: consumed by <see cref="SkirtLayout"/>, which returns a
/// plain <see cref="MapLayout"/> the normal terrain mesh builder can chew on, so the ground outside
/// the board is the same kind of thing as the ground inside it.
///
/// Engine-free by design, exactly like <see cref="BackdropThemeDefinition"/> that carries it. The
/// wall height a tree/wall tile rises by is NOT here: it is the biome's own
/// <c>BiomeDefinition.WallHeight</c>, passed to <see cref="SkirtLayout.Build"/> at build time so the
/// halo can never drift from the board's own trees.
/// </summary>
public sealed record SkirtStyle
{
    /// <summary>Smallest halo the builder will ever use. Below this a board edge sitting on a
    /// plateau cannot descend to the ground plane within the 2-unit-per-vertex slope limit.</summary>
    public const int MinMargin = 8;

    /// <summary>Requested halo width in tiles on every side. <see cref="SkirtLayout"/> raises it to
    /// <see cref="MinMargin"/>, and further if a tall board edge needs more room to come down.</summary>
    public int Margin { get; init; } = 12;

    /// <summary>Peak hill amplitude in ELEVATIONS (1 elevation = 4 corner units = 0.5 m). Scaled by
    /// a ramp that is 0 at the board edge, peaks mid-halo and returns to 0 at the rim.</summary>
    public float HillAmplitudeElevations { get; init; }

    /// <summary>Tiles per hill-noise cell. Larger = broader, lazier hills.</summary>
    public float HillFrequency { get; init; } = 9f;

    /// <summary>How much of the halo turns to difficult terrain. Read as a threshold offset on a
    /// second-octave Perlin field: a sample above <c>1 - DifficultPatchChance</c> becomes a patch.
    /// The field is centred on 0.5 and rarely leaves ±0.35, so useful values sit near 0.30–0.45;
    /// 0 disables patches.</summary>
    public float DifficultPatchChance { get; init; }

    /// <summary>Chance a halo tile one ring out becomes a tree (a <see cref="TileRole.Wall"/> tile,
    /// which the forest theme renders as a stacked tree block).</summary>
    public float TreeDensityNear { get; init; }

    /// <summary>Chance at the outer rim. The scatter lerps from near to far with ring distance, so
    /// the woodland thickens as it recedes and never fences the board in.</summary>
    public float TreeDensityFar { get; init; }

    /// <summary>0 = open halo (a forest-style skirt of hills and trees). Above 0 = ENCLOSED halo:
    /// every halo tile is wall, except corridors that continue a board-edge Ground/Water tile
    /// straight outward for <c>WallRings + 1</c> rings before being sealed off.</summary>
    public int WallRings { get; init; }

    /// <summary>How far, in tiles, a continued river may wander sideways by the outer rim. The
    /// meander is 0 at the first ring so the join with the board's own river is always straight.</summary>
    public float RiverMeander { get; init; }

    /// <summary>Surface for synthesized open ground where no board edge tile supplies one (the
    /// biome's <c>DefaultGroundSurface</c>).</summary>
    public SurfaceType GroundSurface { get; init; } = SurfaceType.Grass;

    /// <summary>Surface for synthesized difficult patches (the biome's
    /// <c>DefaultDifficultSurface</c>).</summary>
    public SurfaceType DifficultSurface { get; init; } = SurfaceType.Dirt;

    /// <summary>Surface for synthesized trees / enclosing walls (the biome's
    /// <c>DefaultWallSurface</c>).</summary>
    public SurfaceType WallSurface { get; init; } = SurfaceType.Dirt;
}
