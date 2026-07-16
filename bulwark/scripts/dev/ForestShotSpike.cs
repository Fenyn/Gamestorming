using System.Collections.Generic;
using Godot;

namespace Bulwark.Dev;

/// <summary>
/// Rendered look check for the painted forest territory (scenes/dev/forest_shot_spike.tscn).
/// Instances the real forest scene, hides the HUD layers, then drives its own camera through a
/// full-map shot plus region close-ups, saving one PNG per stage. Must run rendered (not --headless):
///   godot --path bulwark res://scenes/dev/forest_shot_spike.tscn
/// </summary>
public partial class ForestShotSpike : Node
{
    private const string OutDir =
        @"C:\Users\Midge\AppData\Local\Temp\claude\G--Godot-Gamestorming\9bae1582-2155-4af4-9389-b3e98d245f5f\scratchpad";

    // Window/viewport is 1920x1080 (project.godot): zoom 0.625 fits the whole 3072x1728 map.
    private static readonly (string File, Vector2 Center, float Zoom)[] Stages =
    {
        ("forest_full.png", new Vector2(1536, 864), 0.625f),
        ("forest_nw_pond.png", new Vector2(660, 480), 1.5f),
        ("forest_north.png", new Vector2(1700, 420), 1.2f),
        ("forest_center.png", new Vector2(1584, 840), 1.5f),
        ("forest_south_exit.png", new Vector2(1500, 1400), 1.5f),
        ("forest_east.png", new Vector2(2270, 1140), 1.4f),
        ("forest_corner_nw.png", new Vector2(500, 320), 1.5f),
        ("forest_corner_ne.png", new Vector2(2572, 320), 1.5f),
        ("forest_corner_sw.png", new Vector2(500, 1408), 1.5f),
        ("forest_corner_se.png", new Vector2(2572, 1408), 1.5f),
    };

    private double _time;
    private int _stage;
    private int _settleFrames;
    private Node? _forest;
    private Camera2D? _cam;

    public override void _Ready()
    {
        ProcessMode = ProcessModeEnum.Always;
        _forest = GD.Load<PackedScene>("res://scenes/territory/forest.tscn").Instantiate();
        AddChild(_forest);

        // Hide runtime UI layers (HUD/panels) so the shots judge the painted map, not chrome.
        // The Hd2dStack's own canvas layers stay: the grade is part of the look.
        foreach (Node child in _forest.GetChildren())
        {
            if (child.Name.ToString().Contains("Hd2d")) continue;
            if (child is CanvasLayer cl) cl.Visible = false;
            else if (child is Control c) c.Visible = false;
        }

        // interpolation off: the tree gets paused, which freezes physics ticks and would leave the
        // rendered camera transform stuck between stage positions
        _cam = new Camera2D { PhysicsInterpolationMode = PhysicsInterpolationModeEnum.Off };
        AddChild(_cam);
        GD.Print("[forestshot] spike ready");
    }

    public override void _Process(double delta)
    {
        _time += delta;
        if (_time < 1.5 || _stage >= Stages.Length)
            return;

        // freeze the world once the scene has fully spawned; only this spike keeps processing,
        // and every camera the scene brought along is switched off so ours owns the view
        if (!GetTree().Paused)
        {
            GetTree().Paused = true;
            if (_forest != null)
                foreach (Node cam in _forest.FindChildren("*", "Camera2D", recursive: true, owned: false))
                    ((Camera2D)cam).Enabled = false;
        }

        var (file, center, zoom) = Stages[_stage];
        if (_cam != null)
        {
            _cam.Position = center;
            _cam.Zoom = new Vector2(zoom, zoom);
            _cam.MakeCurrent();
            _cam.ResetPhysicsInterpolation();
        }
        if (++_settleFrames >= 6)
        {
            Capture(file);
            _stage++;
            _settleFrames = 0;
        }

        if (_stage >= Stages.Length)
        {
            GD.Print("[forestshot] done, quitting");
            GetTree().Quit(0);
        }
    }

    private void Capture(string file)
    {
        Image img = GetViewport().GetTexture().GetImage();
        // hdr_2d viewports hand back linear-space data; convert or the PNG comes out crushed dark.
        img.Convert(Image.Format.Rgba8);
        img.LinearToSrgb();
        img.Resize(1280, 720, Image.Interpolation.Bilinear);
        img.SavePng($"{OutDir}\\{file}");
        GD.Print($"[forestshot] saved {file}");
    }
}
