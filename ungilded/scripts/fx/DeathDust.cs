using System;
using System.Collections.Generic;
using Godot;

namespace Ungilded.Fx;

/// <summary>
/// One-shot death of a creature: its body breaks into its own pixels and they drift away as ash. Two
/// halves play together. The token erodes its sprite (<see cref="SpriteErosion"/>, lit_sprite.gdshader
/// <c>death_progress</c> from 0 to 1 over <see cref="SweepSeconds"/>), and this effect lets each texel
/// go as a pixel-square particle in the slice of the sweep where the shader discards it. An HD-2D
/// effect like <see cref="AcidSplash"/>: the scene (scenes/fx/death_dust.tscn) is written by
/// tools/vfx/death_dust/build_death_dust.gd, whose NOTES.md holds the round log and the hook.
///
/// <c>%Body</c> sits at the sprite's centre and turns to the camera every frame, as the billboard does.
/// It holds one emitter per slice of the erosion threshold (<see cref="Bands"/>), and <c>%Anim</c>
/// starts band k at k/n of the sweep. Each band's point and colour textures are built here from the
/// frame in <see cref="Erosion"/>: one particle per opaque texel (per 2x2 block above
/// <see cref="MaxParticles"/>) at the texel's place, in its colour times the sprite's tint, a square of
/// the sprite's pixel size. The wind the build aimed along the sheet camera's right is turned to the
/// game camera's right, so the dust blows the same way on screen from any yaw. <c>%Preview</c>, the
/// build's stand-in rat, hides.
///
/// The caller places the root at the unit's FEET and sets <see cref="Erosion"/> before AddChild.
/// <see cref="OneShotFx.Tint"/> and <see cref="OneShotFx.FxScale"/> are unused.
/// </summary>
public partial class DeathDust : OneShotFx
{
    public DeathDust()
    {
        // build_death_dust.gd: the last band starts at 0.5 s and its pixels live up to 0.65 s.
        Lifetime = 1.3f;
    }

    /// <summary>Seconds the body takes to break up: build_death_dust.gd SWEEP, the length of
    /// <c>%Anim</c>'s "play".</summary>
    [Export] public float SweepSeconds { get; set; } = 0.6f;

    /// <summary>Side of the draw pass square in metres (build_death_dust.gd PX).</summary>
    [Export] public float DrawPixelSize { get; set; } = 0.02f;

    /// <summary>Most particles one body sends; a bigger body sends one per 2x2 block of texels.</summary>
    [Export] public int MaxParticles { get; set; } = 1200;

    /// <summary>The dying sprite's erosion, from <c>UnitVisual3D.Disintegrate</c>. Null plays nothing.</summary>
    public SpriteErosion? Erosion { get; set; }

    private const string PlayAnimation = "play";

    /// <summary>Texels per row of the point and colour textures (build_death_dust.gd TEX_WIDTH).</summary>
    private const int TextureWidth = 256;

    private static readonly string[] Bands = { "%Dust0", "%Dust1", "%Dust2", "%Dust3", "%Dust4", "%Dust5" };

    /// <summary>The band emitters' unique names, first band first (build_death_dust.gd BANDS).</summary>
    public static IReadOnlyList<string> BandNames => Bands;

    private Node3D _body = null!;

    protected override void Build(Tween tween)
    {
        GetNode<Node3D>("%Preview").Hide();
        _body = GetNode<Node3D>("%Body");
        var camera = GetViewport().GetCamera3D();
        if (Erosion == null || camera == null)
        {
            foreach (string band in Bands) GetNode<Node3D>(band).Hide();
            tween.TweenInterval(0.0);
            return;
        }

        _body.Position = Erosion.Centre;
        _body.GlobalBasis = camera.GlobalBasis;
        var right = new Vector3(camera.GlobalBasis.X.X, 0f, camera.GlobalBasis.X.Z).Normalized();
        var texels = SortTexels(Erosion, out int block);
        float scale = Erosion.PixelSize * block / DrawPixelSize;
        for (int i = 0; i < Bands.Length; i++)
            Fill(GetNode<GpuParticles3D>(Bands[i]), texels[i], scale, right);
        GetNode<AnimationPlayer>("%Anim").Play(PlayAnimation);
        tween.TweenInterval(Lifetime);
    }

    public override void _Process(double delta)
    {
        if (GetViewport().GetCamera3D() is { } camera) _body.GlobalBasis = camera.GlobalBasis;
    }

    /// <summary>Each opaque texel (or block) as a place in <c>%Body</c> space and a colour, in the band
    /// of its threshold. A block leaves with its first texel to go.</summary>
    private List<(Vector3 At, Color Colour)>[] SortTexels(SpriteErosion erosion, out int block)
    {
        int opaque = 0;
        for (int y = 0; y < erosion.Height; y++)
            for (int x = 0; x < erosion.Width; x++)
                if (erosion.IsOpaque(x, y)) opaque++;
        block = opaque > MaxParticles ? 2 : 1;

        var bands = new List<(Vector3, Color)>[Bands.Length];
        for (int i = 0; i < bands.Length; i++) bands[i] = new List<(Vector3, Color)>();
        for (int y = 0; y < erosion.Height; y += block)
            for (int x = 0; x < erosion.Width; x += block)
            {
                float first = float.MaxValue;
                Color colour = default;
                for (int dy = 0; dy < block && y + dy < erosion.Height; dy++)
                    for (int dx = 0; dx < block && x + dx < erosion.Width; dx++)
                    {
                        if (!erosion.IsOpaque(x + dx, y + dy)) continue;
                        float threshold = erosion.Threshold(x + dx, y + dy);
                        if (threshold >= first) continue;
                        first = threshold;
                        colour = erosion.Colour(x + dx, y + dy);
                    }
                if (first == float.MaxValue) continue;
                var at = erosion.Place(x + block * 0.5f, y + block * 0.5f);
                int band = Math.Min((int)(first * Bands.Length), Bands.Length - 1);
                bands[band].Add((new Vector3(at.X, at.Y, 0f), colour));
            }
        return bands;
    }

    /// <summary>Give one band its texels: a copy of its process material with the point and colour
    /// textures, the square's scale and the wind turned to <paramref name="right"/>.</summary>
    private static void Fill(GpuParticles3D band, List<(Vector3 At, Color Colour)> texels, float scale, Vector3 right)
    {
        if (texels.Count == 0)
        {
            band.Hide();
            return;
        }
        int width = Math.Min(texels.Count, TextureWidth);
        int height = (texels.Count + width - 1) / width;
        var places = new float[width * height * 3];
        var colours = Image.CreateEmpty(width, height, false, Image.Format.Rgba8);
        for (int i = 0; i < texels.Count; i++)
        {
            places[i * 3] = texels[i].At.X;
            places[i * 3 + 1] = texels[i].At.Y;
            places[i * 3 + 2] = texels[i].At.Z;
            colours.SetPixel(i % width, i / width, texels[i].Colour);
        }
        var bytes = new byte[places.Length * sizeof(float)];
        Buffer.BlockCopy(places, 0, bytes, 0, bytes.Length);

        var material = (ParticleProcessMaterial)band.ProcessMaterial.Duplicate();
        material.EmissionPointTexture = ImageTexture.CreateFromImage(
            Image.CreateFromData(width, height, false, Image.Format.Rgbf, bytes));
        material.EmissionColorTexture = ImageTexture.CreateFromImage(colours);
        material.EmissionPointCount = texels.Count;
        material.ScaleMin = scale;
        material.ScaleMax = scale;
        var pull = material.Gravity;
        material.Gravity = new Vector3(0f, pull.Y, 0f) + right * new Vector2(pull.X, pull.Z).Length();
        band.ProcessMaterial = material;
        band.Amount = texels.Count;
        band.Show();
        band.Restart();
    }
}
