using Godot;

namespace Delve.Look;

/// <summary>
/// Root of one lighting setup (<c>scenes/looks/*.tscn</c>): the WorldEnvironment with its camera
/// attributes, the key light and the post layer (grain, vignette) are authored children, tuned in
/// the editor. This node only switches the setup on and off and fits the authored fog to the
/// board size.
///
/// A world has one active environment. A host that hands the stage to another scene's look (a
/// dungeon-hosted fight) turns its own look off with <see cref="SetActive"/>.
/// </summary>
public partial class LookScene : Node3D
{
    [Export] public WorldEnvironment Environment { get; set; } = null!;

    /// <summary>Screen overlay drawn over the 3D view and under the HUD. A CanvasLayer ignores the
    /// visibility of a 3D parent, so it is switched explicitly.</summary>
    [Export] public CanvasLayer? Post { get; set; }

    /// <summary>Board size, in tiles, the fog density was authored against. A larger board is
    /// framed from further out, so its fog is thinned by the same ratio.</summary>
    [Export] public float FogReferenceBoardTiles { get; set; } = 14f;

    /// <summary>Floor on that thinning. Past it the board reads as unfogged and loses the depth cue.</summary>
    [Export] public float FogScaleMin { get; set; } = 0.8f;

    /// <summary>How far terrain outside the board loses its colour, 0..1.</summary>
    [Export(PropertyHint.Range, "0,1,0.05")] public float HaloDesaturate { get; set; }

    /// <summary>How far terrain outside the board darkens, 0..1.</summary>
    [Export(PropertyHint.Range, "0,1,0.05")] public float HaloDarken { get; set; }

    /// <summary>Metres past the board edge over which the halo treatment reaches full strength.</summary>
    [Export] public float HaloFalloffMetres { get; set; } = 6f;

    /// <summary>Tint on unit sprites under this look. Sprites are drawn unshaded, so a dim interior
    /// needs them dimmed by hand or they glow against the floor.</summary>
    [Export] public Color SpriteTint { get; set; } = Colors.White;

    /// <summary>The <see cref="SpriteTint"/> of the look switched on last. A world has one active
    /// look, so tokens read it when they spawn instead of each host passing its look down.</summary>
    public static Color ActiveSpriteTint { get; private set; } = Colors.White;

    /// <summary>Shader global names, declared in project.godot and read by look_halo.gdshaderinc.</summary>
    public const string HaloGlobal = "look_halo";
    public const string BoardRectGlobal = "look_board_rect";

    private Godot.Environment? _authored;
    private CameraAttributes? _authoredAttributes;
    private float _authoredFogDensity;

    public override void _Ready()
    {
        _authored = Environment.Environment;
        _authoredAttributes = Environment.CameraAttributes;
        _authoredFogDensity = _authored?.FogDensity ?? 0f;
        if (Visible) ApplyHalo(true);
    }

    /// <summary>Show or hide the whole setup. Off, the environment slots are empty so another
    /// WorldEnvironment in the world takes over.</summary>
    public void SetActive(bool active)
    {
        Visible = active;
        Environment.Environment = active ? _authored : null;
        Environment.CameraAttributes = active ? _authoredAttributes : null;
        if (Post != null) Post.Visible = active;
        ApplyHalo(active);
    }

    /// <summary>Brightness for halo scenery standing <paramref name="metres"/> outside the board,
    /// matching the terrain shading of look_halo.gdshaderinc.</summary>
    public float HaloShade(float metres) =>
        1f - HaloDarken * Mathf.SmoothStep(0f, Mathf.Max(HaloFalloffMetres, 0.01f), metres);

    /// <summary>True while this look has the halo treatment switched on.</summary>
    public bool HaloOn { get; private set; }

    private void ApplyHalo(bool active)
    {
        if (active) ActiveSpriteTint = SpriteTint;
        bool on = HaloOn = active && (HaloDesaturate > 0f || HaloDarken > 0f);
        RenderingServer.GlobalShaderParameterSet(HaloGlobal,
            new Vector4(HaloDesaturate, HaloDarken, HaloFalloffMetres, on ? 1f : 0f));
    }

    /// <summary>Thin the authored fog for a board of the given tile size. Never thickens: the
    /// authored density is already the worst case.</summary>
    public void FitBoard(int width, int height)
    {
        if (_authored == null) return;
        _authored.FogDensity = _authoredFogDensity * Mathf.Clamp(
            FogReferenceBoardTiles / Mathf.Max(1, Mathf.Max(width, height)), FogScaleMin, 1f);
    }
}
