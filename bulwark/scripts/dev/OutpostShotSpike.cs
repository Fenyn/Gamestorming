using Bulwark.Fx;
using Godot;

namespace Bulwark.Dev;

/// <summary>
/// Rendered grade check for the HD-2D world look (scenes/dev/outpost_shot_spike.tscn). Instances
/// the real outpost scene, captures Day, then drives its Hd2dStack through Dusk and Night,
/// saving one screenshot per preset for A/B judgment. Must run rendered (not --headless):
///   godot --path bulwark res://scenes/dev/outpost_shot_spike.tscn
/// </summary>
public partial class OutpostShotSpike : Node
{
    private const string OutDir =
        @"C:\Users\Midge\AppData\Local\Temp\claude\G--Godot-Gamestorming\d7b3748f-46da-4506-95c5-f37f804021a4\scratchpad";

    private double _time;
    private int _stage;
    private Hd2dStack? _stack;

    public override void _Ready()
    {
        var outpost = GD.Load<PackedScene>("res://scenes/outpost/outpost.tscn").Instantiate();
        AddChild(outpost);
        _stack = outpost.FindChild("Hd2dStack", recursive: true, owned: false) as Hd2dStack;
        GD.Print($"[outpostshot] spike ready, stack found: {_stack != null}");
    }

    public override void _Process(double delta)
    {
        _time += delta;

        if (_stage == 0 && _time > 1.5)
        {
            _stage = 1;
            Capture("outpost_day.png");
            _stack?.Apply(Hd2dStack.TimeOfDay.Dusk);
        }
        else if (_stage == 1 && _time > 2.5)
        {
            _stage = 2;
            Capture("outpost_dusk.png");
            _stack?.Apply(Hd2dStack.TimeOfDay.Night);
        }
        else if (_stage == 2 && _time > 3.5)
        {
            _stage = 3;
            Capture("outpost_night.png");
            GD.Print("[outpostshot] done, quitting");
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
        GD.Print($"[outpostshot] saved {file}");
    }
}
