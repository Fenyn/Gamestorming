using System;
using Godot;

namespace Ungilded.Fx;

/// <summary>
/// A lit sprite's death erosion (lit_sprite.gdshader, <c>death_progress</c>), and the sprite as it was
/// when the erosion began. Each opaque texel of the frame gets a threshold in [0, 1): a sweep across
/// the body along <see cref="Direction"/>, cluster noise and a per-texel grain, weighted by the
/// material's <c>death_mix</c> and stretched so the first texel goes at 0 and the last at 1. The
/// shader discards a texel once <c>death_progress</c> passes its threshold. <see cref="Threshold"/> is
/// the same function, so <see cref="DeathDust"/> lets each texel go as a particle in the slice of the
/// sweep where the shader discards it. It must stay equal to the shader's erosion_threshold and to
/// _threshold in tools/vfx/death_dust/build_death_dust.gd.
/// </summary>
public sealed class SpriteErosion
{
    public const string ProgressParameter = "death_progress";
    private const string OriginParameter = "death_origin";
    private const string FrameParameter = "death_frame";
    private const string DirectionParameter = "death_dir";
    private const string SpanParameter = "death_span";
    private const string RangeParameter = "death_range";
    private const string SeedParameter = "death_seed";
    private const string MixParameter = "death_mix";
    private const string CellParameter = "death_cell";

    /// <summary>Alpha from which a texel is part of the body: the shader's alpha scissor.</summary>
    private const float OpaqueAlpha = 0.5f;

    /// <summary>Highest threshold, below 1 so that progress 1 discards every texel.</summary>
    private const float LastThreshold = 0.99999f;

    private readonly Vector3 _mix;
    private readonly float _cell;
    private readonly uint _seed;
    private readonly Vector2 _span;
    private readonly Vector2 _range;

    /// <param name="frame">The drawn frame as it is in its page (not flipped), RGBA8.</param>
    /// <param name="material">The sprite's lit material. The look values (<c>death_mix</c>,
    /// <c>death_cell</c>) are read from it, or from the shader's defaults.</param>
    /// <param name="direction">Direction the front moves, in frame texels (x right, y down).</param>
    public SpriteErosion(Image frame, ShaderMaterial material, Vector2 direction, uint seed)
    {
        Frame = frame;
        Direction = direction.Normalized();
        _mix = Look(material, MixParameter).AsVector3();
        _cell = Look(material, CellParameter).AsSingle();
        _seed = seed;

        float low = float.MaxValue, high = float.MinValue;
        ForEachOpaque((x, y) =>
        {
            float along = (x + 0.5f) * Direction.X + (y + 0.5f) * Direction.Y;
            low = Mathf.Min(low, along);
            high = Mathf.Max(high, along);
        });
        _span = new Vector2(low, high);

        low = float.MaxValue;
        high = float.MinValue;
        ForEachOpaque((x, y) =>
        {
            float sum = Sum(x, y);
            low = Mathf.Min(low, sum);
            high = Mathf.Max(high, sum);
        });
        _range = new Vector2(low, high);
    }

    public Image Frame { get; }
    public int Width => Frame.GetWidth();
    public int Height => Frame.GetHeight();

    /// <summary>Direction the front moves, in frame texels (x right, y down).</summary>
    public Vector2 Direction { get; }

    /// <summary>The sprite's metres per texel.</summary>
    public float PixelSize { get; init; }

    /// <summary>The sprite draws the frame mirrored.</summary>
    public bool FlipH { get; init; }

    /// <summary>The sprite's drawing offset in texels, as Sprite3D applies it (after the flip).</summary>
    public Vector2 Offset { get; init; }

    /// <summary>The sprite's centre in its owner's space: the token's feet are the origin.</summary>
    public Vector3 Centre { get; init; }

    /// <summary>The sprite's modulate when the erosion began.</summary>
    public Color Tint { get; init; } = Colors.White;

    public bool IsOpaque(int x, int y) => Frame.GetPixel(x, y).A >= OpaqueAlpha;

    /// <summary>The progress at which the texel goes.</summary>
    public float Threshold(int x, int y)
        => Mathf.Clamp((Sum(x, y) - _range.X) / Mathf.Max(_range.Y - _range.X, 0.001f), 0f, LastThreshold);

    /// <summary>Metres from the sprite's centre, in its billboard plane (x right on screen, y up), of a
    /// point given in frame texels (x right, y down from the frame's top-left corner).</summary>
    public Vector2 Place(float x, float y)
    {
        float across = x - Width * 0.5f;
        if (FlipH) across = -across;
        return new Vector2((across + Offset.X) * PixelSize, (Height * 0.5f - y) * PixelSize);
    }

    /// <summary>The texel's colour as drawn: times the sprite's tint, opaque.</summary>
    public Color Colour(int x, int y)
    {
        var c = Frame.GetPixel(x, y);
        return new Color(c.R * Tint.R, c.G * Tint.G, c.B * Tint.B);
    }

    /// <summary>Set the sprite's material to erode this frame. <paramref name="origin"/> is the frame's
    /// top-left texel in its page.</summary>
    public void Apply(ShaderMaterial material, Vector2I origin)
    {
        material.SetShaderParameter(OriginParameter, (Vector2)origin);
        material.SetShaderParameter(FrameParameter, new Vector2(Width, Height));
        material.SetShaderParameter(DirectionParameter, Direction);
        material.SetShaderParameter(SpanParameter, _span);
        material.SetShaderParameter(RangeParameter, _range);
        material.SetShaderParameter(SeedParameter, (int)_seed);
        material.SetShaderParameter(ProgressParameter, 0f);
    }

    private void ForEachOpaque(Action<int, int> visit)
    {
        for (int y = 0; y < Height; y++)
            for (int x = 0; x < Width; x++)
                if (IsOpaque(x, y)) visit(x, y);
    }

    private float Sum(int x, int y)
    {
        float along = (x + 0.5f) * Direction.X + (y + 0.5f) * Direction.Y;
        float sweep = Mathf.Clamp((along - _span.X) / Mathf.Max(_span.Y - _span.X, 0.001f), 0f, 1f);
        float noise = Noise(x, y, _seed + 1u);
        float grain = Unit((uint)x, (uint)y, _seed);
        return sweep * _mix.X + noise * _mix.Y + grain * _mix.Z;
    }

    /// <summary>Value noise on a grid of <see cref="_cell"/> texels, at the texel's centre.</summary>
    private float Noise(int x, int y, uint seed)
    {
        float fx = (x + 0.5f) / _cell;
        float fy = (y + 0.5f) / _cell;
        float ix = MathF.Floor(fx);
        float iy = MathF.Floor(fy);
        float ux = Smooth(fx - ix);
        float uy = Smooth(fy - iy);
        uint cx = (uint)ix;
        uint cy = (uint)iy;
        float a = Unit(cx, cy, seed);
        float b = Unit(cx + 1u, cy, seed);
        float c = Unit(cx, cy + 1u, seed);
        float d = Unit(cx + 1u, cy + 1u, seed);
        return Mix(Mix(a, b, ux), Mix(c, d, ux), uy);
    }

    private static float Smooth(float u) => u * u * (3f - 2f * u);

    /// <summary>GLSL mix.</summary>
    private static float Mix(float a, float b, float t) => a * (1f - t) + b * t;

    /// <summary>Integer hash of a lattice point as 24 bits in [0, 1): exact in float here and on the GPU.</summary>
    private static float Unit(uint x, uint y, uint seed)
    {
        unchecked
        {
            uint h = (x * 73856093u) ^ (y * 19349663u) ^ (seed * 83492791u);
            h ^= h >> 16;
            h *= 2246822519u;
            h ^= h >> 13;
            h *= 3266489917u;
            h ^= h >> 16;
            return (h >> 8) / 16777216f;
        }
    }

    /// <summary>The material's value, or the shader's default when the material leaves it unset.</summary>
    private static Variant Look(ShaderMaterial material, string name)
    {
        var value = material.GetShaderParameter(name);
        return value.VariantType != Variant.Type.Nil
            ? value
            : RenderingServer.ShaderGetParameterDefault(material.Shader.GetRid(), name);
    }
}
