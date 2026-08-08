using Godot;

namespace Bulwark.Dev;

/// <summary>
/// Rendered look check for the greybox 3D forest territory (scenes/dev/forest_shot_spike.tscn).
/// Instances the REAL forest scene, lets it spawn the player / roamers / resource-node views, then
/// captures three frames for eyeball judgment:
///   1. <c>forest_3d_follow.png</c> — the gameplay framing through the avatar's own follow camera.
///   2. <c>forest_3d_overview.png</c> — the whole territory from a spike-owned overview camera.
///   3. <c>forest_3d_trail.png</c> — a low pass along the south trail (exit sign, path, treeline).
/// Must run rendered (not --headless):
///   godot --path bulwark res://scenes/dev/forest_shot_spike.tscn
/// </summary>
public partial class ForestShotSpike : Node
{
    private const string OutDir =
        @"C:\Users\Midge\AppData\Local\Temp\claude\G--Godot-Gamestorming\456819b1-cb41-4028-ad00-2e684744eae1\scratchpad";

    private double _time;
    private int _stage;
    private Node3D? _forest;
    private Camera3D? _spikeCamera;

    public override void _Ready()
    {
        _forest = GD.Load<PackedScene>("res://scenes/territory/forest.tscn").Instantiate<Node3D>();
        AddChild(_forest);

        _spikeCamera = new Camera3D { Name = "SpikeCamera", Fov = 60f };
        AddChild(_spikeCamera);
        _spikeCamera.GlobalPosition = new Vector3(32f, 34f, 56f);
        _spikeCamera.LookAt(new Vector3(32f, 0f, 16f), Vector3.Up);

        GD.Print("[forestshot] spike ready (3D greybox forest instanced)");
    }

    public override void _Process(double delta)
    {
        _time += delta;

        if (_stage == 0 && _time > 2.0)
        {
            _stage = 1;
            Capture("forest_3d_follow.png");   // the avatar follow camera is `current` from the scene
            if (_spikeCamera != null)
                _spikeCamera.Current = true;   // takes over the viewport for the wide shots
        }
        else if (_stage == 1 && _time > 3.0)
        {
            _stage = 2;
            Capture("forest_3d_overview.png");
            if (_spikeCamera != null)
            {
                _spikeCamera.GlobalPosition = new Vector3(32.5f, 4.5f, 33f);
                _spikeCamera.LookAt(new Vector3(32.5f, 1.5f, 10f), Vector3.Up);
            }
        }
        else if (_stage == 2 && _time > 4.0)
        {
            _stage = 3;
            Capture("forest_3d_trail.png");
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
