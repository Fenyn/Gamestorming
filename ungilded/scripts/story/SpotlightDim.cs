using System.Collections.Generic;
using Godot;

namespace Ungilded.Story;

/// <summary>
/// The tutorial dim: a full-screen rect whose spotlight shader cuts out the focus quads and draws a
/// pulsing outline round them. It swallows every click, except inside the cutout while
/// <see cref="PassThrough"/> is on, so the HUD and the board under the cutout take their own clicks,
/// and anywhere while <see cref="PassAll"/> is on.
/// </summary>
public partial class SpotlightDim : ColorRect
{
    /// <summary>Dim opacity outside the cutout while a focus shows.</summary>
    [Export(PropertyHint.Range, "0,1,0.05")] public float DimAlpha { get; set; } = 0.6f;

    /// <summary>Pixels over which the dim fades in from the cutout edge.</summary>
    [Export] public float Feather { get; set; } = 6f;

    [Export] public float OutlineWidth { get; set; } = 3f;

    /// <summary>Outline pulses per second.</summary>
    [Export] public float PulseRate { get; set; } = 1f;

    /// <summary>The outline's alpha share between pulses.</summary>
    [Export(PropertyHint.Range, "0,1,0.05")] public float PulseLow { get; set; } = 0.35f;

    /// <summary>The most quads the shader draws (its MAX_QUADS).</summary>
    [Export] public int MaxQuads { get; set; } = 16;

    /// <summary>The outline colour; the popup sets the story ember.</summary>
    public Color OutlineColor { get; set; } = Colors.White;

    /// <summary>True lets clicks inside the cutout through to whatever is under it.</summary>
    public bool PassThrough { get; set; }

    /// <summary>True lets every click through: an undimmed step tip.</summary>
    public bool PassAll { get; set; }

    private static readonly StringName CornersParam = "corners";
    private static readonly StringName CountParam = "quad_count";
    private static readonly StringName DimAlphaParam = "dim_alpha";
    private static readonly StringName FeatherParam = "feather";
    private static readonly StringName OutlineColorParam = "outline_color";
    private static readonly StringName OutlineWidthParam = "outline_width";
    private static readonly StringName PulseRateParam = "pulse_rate";
    private static readonly StringName PulseLowParam = "pulse_low";

    private ShaderMaterial _material = null!;
    private Vector2[] _corners = System.Array.Empty<Vector2>();
    private readonly List<Vector2[]> _quads = new();

    public override void _Ready()
    {
        _material = (ShaderMaterial)Material;
        _corners = new Vector2[MaxQuads * 4];
        SetCutout(null, dimmed: false);
    }

    /// <summary>Cut out <paramref name="quads"/> (null or empty: none) and outline them.
    /// <paramref name="dimmed"/> false leaves the screen undimmed; clicks follow the pass flags.</summary>
    public void SetCutout(IReadOnlyList<Vector2[]>? quads, bool dimmed)
    {
        _quads.Clear();
        int count = 0;
        if (quads != null)
            foreach (var quad in quads)
            {
                if (count == MaxQuads || quad.Length != 4) break;
                _quads.Add(quad);
                for (int i = 0; i < 4; i++) _corners[count * 4 + i] = quad[i];
                count++;
            }
        _material.SetShaderParameter(CornersParam, _corners);
        _material.SetShaderParameter(CountParam, count);
        _material.SetShaderParameter(DimAlphaParam, dimmed ? DimAlpha : 0f);
        _material.SetShaderParameter(FeatherParam, Feather);
        _material.SetShaderParameter(OutlineColorParam, OutlineColor);
        _material.SetShaderParameter(OutlineWidthParam, OutlineWidth);
        _material.SetShaderParameter(PulseRateParam, PulseRate);
        _material.SetShaderParameter(PulseLowParam, PulseLow);
    }

    /// <summary>True when <paramref name="point"/> (canvas pixels) lies inside the cutout.</summary>
    public bool CutoutContains(Vector2 point)
    {
        foreach (var quad in _quads)
            if (Inside(quad, point)) return true;
        return false;
    }

    /// <summary>True when a click at <paramref name="point"/> (canvas pixels) stops here.</summary>
    public bool TakesClick(Vector2 point) => !(PassAll || PassThrough && CutoutContains(point));

    public override bool _HasPoint(Vector2 point) => TakesClick(point);

    /// <summary>Inside a convex quad with positive shoelace area: on the inner side of every edge.</summary>
    private static bool Inside(Vector2[] quad, Vector2 p)
    {
        for (int i = 0; i < 4; i++)
        {
            var a = quad[i];
            var e = quad[(i + 1) % 4] - a;
            if ((p - a).Dot(new Vector2(e.Y, -e.X)) > 0) return false;
        }
        return true;
    }
}
