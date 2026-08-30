using System.Collections.Generic;
using PF2e.MapGen;

namespace Delve.Terrain;

internal enum FaceKind
{
    Top,
    Wall,
    TopGridLine,
    EdgeStrip,
    CliffBand,
}

internal readonly record struct PaletteKey(SurfaceType Surface, FaceKind Kind);

/// <summary>
/// Routes geometry to one buffer per (surface, face kind) pair, in first-use order. Unity keyed its
/// submeshes by Material identity; keying by the pair is equivalent under a palette that gives each
/// surface its own colour, and it keeps the top/wall split readable for the spike's normal checks.
/// The three overlay kinds ignore the surface — they are one material each, map-wide, exactly as in
/// Unity's palette.
/// </summary>
internal sealed class SurfacePalette
{
    private readonly Dictionary<PaletteKey, MeshBuffer> _byKey = new();
    private readonly List<(PaletteKey Key, MeshBuffer Buffer)> _order = new();

    public IReadOnlyList<(PaletteKey Key, MeshBuffer Buffer)> Buffers => _order;

    public MeshBuffer Top(SurfaceType surface) => Get(new PaletteKey(surface, FaceKind.Top));

    public MeshBuffer Wall(SurfaceType surface) => Get(new PaletteKey(surface, FaceKind.Wall));

    public MeshBuffer Overlay(FaceKind kind) => Get(new PaletteKey(default, kind));

    private MeshBuffer Get(PaletteKey key)
    {
        if (_byKey.TryGetValue(key, out var buffer)) return buffer;
        buffer = new MeshBuffer();
        _byKey[key] = buffer;
        _order.Add((key, buffer));
        return buffer;
    }
}
