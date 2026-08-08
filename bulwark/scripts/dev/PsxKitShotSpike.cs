using Godot;

namespace Bulwark.Dev;

/// <summary>
/// Rendered A/B for the PSX modular-asset direction (scenes/dev/psx_kit_spike.tscn).
///
/// The scene authors the SAME vignette twice — 3-segment wall run, well in front, two pines and an
/// oak behind, boulder by the path, on a 12x12 grass plane — from two model sets that differ only in
/// which textures are baked into the .glb:
///   a_winlu — 64x64 tiles cropped out of the Winlu RPG-Maker sheets (the art the game ships today).
///   b_fresh — 64x64 tiles authored procedurally in Spyro/MediEvil-era style, hues inherited from
///             the Winlu crops so the shot compares painting style rather than colour choice.
/// Vignette B sits 40 m along +X, so both are lit by one Sun and neither can drift from the other
/// through reload timing. Each group carries its own CamWidePos/CamWideTarget and
/// CamClosePos/CamCloseTarget markers at identical LOCAL offsets, which is what makes the four
/// captures share a framing.
///
/// Captures (1280x720 each):
///   psxkit_wide_a_winlu.png  / psxkit_wide_b_fresh.png   — the game angle, ~54 deg pitch.
///   psxkit_close_a_winlu.png / psxkit_close_b_fresh.png  — a closer 3/4 on the well and wall.
///
/// Must run rendered (not --headless):
///   Godot_v4.6.2-stable_mono_win64.exe --path bulwark res://scenes/dev/psx_kit_spike.tscn
/// </summary>
public partial class PsxKitShotSpike : Node3D
{
    private const string OutDir =
        @"C:\Users\Midge\AppData\Local\Temp\claude\G--Godot-Gamestorming\2bd27b51-0eee-4938-8f02-f94cf931795f\scratchpad";

    private const double SettleSeconds = 0.35;

    private readonly (string Framing, float Fov)[] _framings =
    {
        ("Wide", 45f),
        ("Close", 42f),
    };

    private readonly (string Group, string Suffix)[] _variants =
    {
        ("%VignetteA", "a_winlu"),
        ("%VignetteB", "b_fresh"),
    };

    private Camera3D? _camera;
    private int _shot = -1;
    private double _timer;

    public override void _Ready()
    {
        _camera = new Camera3D { Name = "ShotCamera", Current = true };
        AddChild(_camera);
        GD.Print($"[psxkit] ready, {_framings.Length * _variants.Length} captures queued");
    }

    public override void _Process(double delta)
    {
        _timer += delta;
        if (_timer < (_shot < 0 ? 1.0 : SettleSeconds))
            return;

        if (_shot >= 0)
            Capture();

        _shot++;
        _timer = 0;

        if (_shot >= _framings.Length * _variants.Length)
        {
            GD.Print("[psxkit] done, quitting");
            GetTree().Quit(0);
            return;
        }

        Aim();
    }

    /// <summary>Point the shared camera at the current framing/variant pair. Position and target
    /// come from markers authored in the scene, so the C# side never hand-builds a rotation basis
    /// (a Transform3D literal in a .tscn is row-major while the constructor takes columns).</summary>
    private void Aim()
    {
        (string framing, float fov) = _framings[_shot / _variants.Length];
        (string group, _) = _variants[_shot % _variants.Length];

        Node3D vignette = GetNode<Node3D>(group);
        var pos = vignette.GetNode<Marker3D>($"Cam{framing}Pos");
        var target = vignette.GetNode<Marker3D>($"Cam{framing}Target");

        _camera!.Fov = fov;
        _camera.GlobalPosition = pos.GlobalPosition;
        _camera.LookAt(target.GlobalPosition, Vector3.Up);
    }

    private void Capture()
    {
        (string framing, _) = _framings[_shot / _variants.Length];
        (_, string suffix) = _variants[_shot % _variants.Length];
        string file = $"psxkit_{framing.ToLowerInvariant()}_{suffix}.png";

        Image img = GetViewport().GetTexture().GetImage();
        // hdr_2d viewports hand back linear-space data; convert or the PNG comes out crushed dark.
        img.Convert(Image.Format.Rgba8);
        img.LinearToSrgb();
        img.Resize(1280, 720, Image.Interpolation.Bilinear);
        img.SavePng($"{OutDir}\\{file}");
        GD.Print($"[psxkit] saved {file}");
    }
}
