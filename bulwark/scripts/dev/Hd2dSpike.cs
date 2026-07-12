using Bulwark.Fx;
using Godot;

namespace Bulwark.Dev;

/// <summary>
/// Rendered smoke test for the HD-2D ambiance stack (scenes/dev/hd2d_spike.tscn). Lets the
/// composed scene settle, captures a Night screenshot, switches the stack to Day, captures a
/// second screenshot, then quits. Must run rendered (not --headless):
///   godot --path bulwark res://scenes/dev/hd2d_spike.tscn
/// </summary>
public partial class Hd2dSpike : Node2D
{
    private const string OutDir =
        @"C:\Users\Midge\AppData\Local\Temp\claude\G--Godot-Gamestorming\d7b3748f-46da-4506-95c5-f37f804021a4\scratchpad";

    private Hd2dStack _stack = null!;
    private double _time;
    private bool _nightSaved;
    private bool _daySaved;

    public override void _Ready()
    {
        _stack = GetNode<Hd2dStack>("Hd2dStack");
        GD.Print("[hd2d] spike ready");
    }

    public override void _Process(double delta)
    {
        _time += delta;

        if (!_nightSaved && _time > 1.4)
        {
            _nightSaved = true;
            Capture("hd2d_night.png");
            _stack.Apply(Hd2dStack.TimeOfDay.Day);
            GD.Print("[hd2d] night captured, switched to day");
        }
        else if (!_daySaved && _time > 2.8)
        {
            _daySaved = true;
            Capture("hd2d_day.png");
            GD.Print("[hd2d] day captured, quitting");
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
        GD.Print($"[hd2d] saved {file}");
    }
}
