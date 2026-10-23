using Godot;
using PF2e.MapGen;
using Ungilded.Terrain;

namespace Ungilded.Look;

/// <summary>What a dressing needs from a finished terrain build. <see cref="Skirt"/> is the board
/// plus its halo; <see cref="SkirtHeights"/> reads in skirt tile coordinates. <see cref="Cutaway"/>
/// hides a wall prop while its wall is cut (track it by its skirt tile), or is null when the biome
/// cuts nothing.</summary>
public sealed record DressingContext(
    MapLayout Board, SkirtResult Skirt, TerrainHeightMap SkirtHeights, float HeightScale,
    TerrainCutaway? Cutaway = null);

/// <summary>
/// Props and effects a look places on each board it lights (wall torches, drips, wall fixtures).
/// A child of the look scene, so a biome's dressing travels with its lighting and goes away with
/// it. <see cref="TerrainStage"/> calls <see cref="Dress"/> after every terrain build and
/// <see cref="Clear"/> before the next.
/// </summary>
public abstract partial class LookDressing : Node3D
{
    /// <summary>Place this board's props. <paramref name="haloShade"/> is the look's brightness
    /// for scenery a number of metres outside the board.</summary>
    public abstract void Dress(DressingContext context, System.Func<float, float> haloShade);

    /// <summary>Remove every prop the last <see cref="Dress"/> placed.</summary>
    public abstract void Clear();
}
