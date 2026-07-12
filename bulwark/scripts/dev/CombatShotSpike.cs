using Godot;

namespace Bulwark.Dev;

/// <summary>
/// Rendered smoke test for the combat board + UI fixes (scenes/dev/combat_shot_spike.tscn).
/// Instances the combat test scene, lets the encounter boot, captures an early screenshot
/// (board coverage + idle UI state) and a late one (combat log with entries), then quits.
/// Must run rendered (not --headless):
///   godot --path bulwark res://scenes/dev/combat_shot_spike.tscn
/// </summary>
public partial class CombatShotSpike : Node
{
    private const string OutDir =
        @"C:\Users\Midge\AppData\Local\Temp\claude\G--Godot-Gamestorming\d7b3748f-46da-4506-95c5-f37f804021a4\scratchpad";

    private double _time;
    private bool _earlySaved;
    private bool _lateSaved;

    public override void _Ready()
    {
        var combat = GD.Load<PackedScene>("res://scenes/dev/combat_test.tscn").Instantiate();
        AddChild(combat);
        GD.Print("[combatshot] spike ready");
    }

    public override void _Process(double delta)
    {
        _time += delta;

        if (!_earlySaved && _time > 3.5)
        {
            _earlySaved = true;
            Capture("combat_after.png");
        }
        else if (!_lateSaved && _time > 7.5)
        {
            _lateSaved = true;
            Capture("combat_after_late.png");
            GD.Print("[combatshot] done, quitting");
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
        GD.Print($"[combatshot] saved {file}");
    }
}
