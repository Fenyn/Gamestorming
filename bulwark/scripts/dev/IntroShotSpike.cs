using Godot;

namespace Bulwark.Dev;

/// <summary>
/// Rendered smoke test for the three 3D greybox intro sets (scenes/dev/intro_shot_spike.tscn). Promotes
/// each REAL intro scene to CurrentScene in turn — the director resolves markers and prop nodes through
/// <c>GetTree().CurrentScene</c>, so a shot must run against the same tree shape a real play has — lets
/// its own JSON sequence stage itself, and captures:
///   1. <c>intro_road_3d_pan.png</c> — scene 0 mid-pan, the camera holding on the broken bridge (the
///      <c>camera → MarkPilings</c> step).
///   2. <c>intro_road_3d_wide.png</c> — scene 0 after the camera returns to its home framing, squad on
///      the road.
///   3. <c>intro_homestead_ext_3d.png</c> — scene 1a past its fade-in, dusk key light on (%EveningTint),
///      squad at the ford marks with the cottage and orchard beyond.
///   4. <c>intro_homestead_int_3d.png</c> — scene 1b with the squad walked to the hearth marks and the
///      grate lit (%HearthFire revealed by the <c>prop</c> step); advance input is injected so the
///      sequence reaches that step without a human at the keyboard.
/// Must run rendered (not --headless):
///   godot --path bulwark res://scenes/dev/intro_shot_spike.tscn
/// </summary>
public partial class IntroShotSpike : Node
{
    private const string OutDir =
        @"C:\Users\Midge\AppData\Local\Temp\claude\G--Godot-Gamestorming\456819b1-cb41-4028-ad00-2e684744eae1\scratchpad";

    /// <summary>Shot script: seconds since the current scene was promoted → what to do at that mark.</summary>
    private static readonly (double At, string Scene, string? File)[] Script =
    {
        (2.6, "res://scenes/intro/road.tscn", "intro_road_3d_pan.png"),
        (5.0, "res://scenes/intro/road.tscn", "intro_road_3d_wide.png"),
        (5.6, "res://scenes/intro/homestead_exterior.tscn", null),
        (8.6, "res://scenes/intro/homestead_exterior.tscn", "intro_homestead_ext_3d.png"),
        (9.2, "res://scenes/intro/homestead_interior.tscn", null),
        (18.0, "res://scenes/intro/homestead_interior.tscn", "intro_homestead_int_3d.png"),
    };

    /// <summary>Script index from which advance input is injected — scene 1b only, so the road and
    /// exterior shots stay on their authored beat (an advanced road sequence would route itself onward
    /// and steal the swap).</summary>
    private const int AdvanceFromStage = 5;

    private double _time;
    private int _stage;
    private double _nextAdvance;

    // Deferred: the root is still setting up its children during this node's _Ready, so the first swap
    // has to wait a frame.
    public override void _Ready() => Callable.From(() => Promote("res://scenes/intro/road.tscn")).CallDeferred();

    /// <summary>Swap in an intro scene as CurrentScene, freeing the previous one. This spike node lives
    /// beside it as a sibling root child and keeps processing across the swap.</summary>
    private void Promote(string scenePath)
    {
        Node? previous = GetTree().CurrentScene;
        if (previous != null && previous != this)
            previous.QueueFree();

        var scene = GD.Load<PackedScene>(scenePath).Instantiate<Node3D>();
        GetTree().Root.AddChild(scene);
        GetTree().CurrentScene = scene;
        GD.Print($"[introshot] promoted {scenePath}");
    }

    public override void _Process(double delta)
    {
        _time += delta;

        // Scene 1b only reaches its hearth `prop` step past a spoken line, so keep tapping advance.
        if (_stage >= AdvanceFromStage && _time > _nextAdvance)
        {
            _nextAdvance = _time + 0.35;
            Input.ParseInputEvent(new InputEventAction { Action = "ui_accept", Pressed = true });
            Input.ParseInputEvent(new InputEventAction { Action = "ui_accept", Pressed = false });
        }

        if (_stage >= Script.Length || _time < Script[_stage].At)
            return;

        var step = Script[_stage];
        _stage++;

        if (step.File != null)
            Capture(step.File);
        else
            Promote(step.Scene);

        if (_stage >= Script.Length)
        {
            GD.Print("[introshot] done, quitting");
            GetTree().Quit(0);
        }
    }

    private void Capture(string fileName)
    {
        Image? image = GetViewport()?.GetTexture()?.GetImage();
        if (image == null)
        {
            GD.PushWarning($"[introshot] no viewport image for {fileName}");
            return;
        }

        // hdr_2d viewports hand back linear-space data; convert or the PNG comes out crushed dark.
        image.Convert(Image.Format.Rgba8);
        image.LinearToSrgb();
        image.Resize(1280, 720, Image.Interpolation.Bilinear);

        DirAccess.MakeDirRecursiveAbsolute(OutDir);
        string path = $"{OutDir}\\{fileName}";
        Error err = image.SavePng(path);
        GD.Print(err == Error.Ok ? $"[introshot] saved {path}" : $"[introshot] save failed ({err}): {path}");
    }
}
