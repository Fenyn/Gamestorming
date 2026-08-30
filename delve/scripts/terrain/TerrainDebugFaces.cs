using System;
using System.Collections.Generic;
using Godot;
using PF2e.Grid;

namespace Delve.Terrain;

/// <summary>
/// Optional record of the cliff faces one terrain build emitted, for the spikes that assert on them.
/// <see cref="TerrainMeshBuilder.Build"/> takes one only when a caller hands it one, so a normal
/// encounter build collects nothing.
/// </summary>
public sealed class TerrainDebugFaces
{
    /// <summary>
    /// One emitted cliff wall, in corner-height units. A/B follow
    /// <c>TileCornerHeights.EdgeCorners</c>, so <c>BottomA</c> belongs under <c>TopA</c>.
    /// </summary>
    public readonly record struct WallFace(
        int X, int Y, CardinalDirection Dir, int TopA, int TopB, int BottomA, int BottomB);

    /// <summary>One emitted cliff-lip strip, as its axis-aligned footprint on the XZ plane.</summary>
    public readonly record struct StripFace(
        int X, int Y, CardinalDirection Dir, float MinX, float MinZ, float MaxX, float MaxZ)
    {
        /// <summary>The strip's footprint from its four world corners. Strips are axis-aligned in XZ.</summary>
        public static StripFace Around(
            int x, int y, CardinalDirection dir, Vector3 a, Vector3 b, Vector3 c, Vector3 d) =>
            new(x, y, dir,
                MathF.Min(MathF.Min(a.X, b.X), MathF.Min(c.X, d.X)),
                MathF.Min(MathF.Min(a.Z, b.Z), MathF.Min(c.Z, d.Z)),
                MathF.Max(MathF.Max(a.X, b.X), MathF.Max(c.X, d.X)),
                MathF.Max(MathF.Max(a.Z, b.Z), MathF.Max(c.Z, d.Z)));

        /// <summary>Area of overlap with another footprint. Strips that only touch score 0.</summary>
        public float OverlapArea(StripFace other)
        {
            float w = MathF.Min(MaxX, other.MaxX) - MathF.Max(MinX, other.MinX);
            float h = MathF.Min(MaxZ, other.MaxZ) - MathF.Max(MinZ, other.MinZ);
            return w <= 0f || h <= 0f ? 0f : w * h;
        }
    }

    public List<WallFace> Walls { get; } = new();

    public List<StripFace> Strips { get; } = new();
}
