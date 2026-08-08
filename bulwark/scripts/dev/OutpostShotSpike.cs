using System.Collections.Generic;
using Bulwark.Cozy;
using Godot;

namespace Bulwark.Dev;

/// <summary>
/// Rendered smoke test for the 3D greybox outpost (scenes/dev/outpost_shot_spike.tscn). Instances the
/// REAL outpost scene, lets its loaders spawn the player / villagers / buildings, then captures four
/// frames for eyeball judgment against the expanded 96x96 walled interior (terrain -18..114 on both
/// axes):
///   1. <c>outpost_3d_follow.png</c> — the gameplay framing through the avatar's own follow camera,
///      centred on %PlayerSpawn (48, 60) — the town-centre plaza.
///   2. <c>outpost_3d_overview.png</c> — the whole site from a spike-owned overview camera, high and
///      wide enough to frame the full walled interior, in the real day-one state (Command Post
///      standing, the other three still rubble).
///   3. <c>outpost_3d_gate_plaza.png</c> — a pass from inside the plaza looking south at the gate
///      opening and its flanking towers (the approach the player and the intro Scene 2 cutscene use).
///   4. <c>outpost_3d_farm_pond.png</c> — a wide angle centred between the farm plot (~32, 51) and the
///      pond (~84, 44), captured with every placed building driven to its TOP stage so the restored
///      skyline is visible in the background too.
/// Must run rendered (not --headless):
///   godot --path bulwark res://scenes/dev/outpost_shot_spike.tscn
/// </summary>
public partial class OutpostShotSpike : Node
{
    private const string OutDir =
        @"C:\Users\Midge\AppData\Local\Temp\claude\G--Godot-Gamestorming\2bd27b51-0eee-4938-8f02-f94cf931795f\scratchpad";

    private double _time;
    private int _stage;
    private Node3D? _outpost;
    private Camera3D? _overview;

    public override void _Ready()
    {
        _outpost = GD.Load<PackedScene>("res://scenes/outpost/outpost.tscn").Instantiate<Node3D>();
        AddChild(_outpost);

        _overview = new Camera3D { Name = "OverviewCamera", Fov = 60f };
        AddChild(_overview);
        _overview.GlobalPosition = new Vector3(48f, 85f, 155f);
        _overview.LookAt(new Vector3(48f, 0f, 45f), Vector3.Up);

        GD.Print("[outpostshot] spike ready (3D greybox outpost instanced, 96x96 layout)");
    }

    public override void _Process(double delta)
    {
        _time += delta;

        if (_stage == 0 && _time > 2.0)
        {
            _stage = 1;
            Capture("outpost_3d_follow.png");     // avatar follow camera is `current` from the scene
            if (_overview != null)
                _overview.Current = true;         // takes over the viewport for the wide shots
        }
        else if (_stage == 1 && _time > 3.0)
        {
            _stage = 2;
            Capture("outpost_3d_overview.png");
            // Gate + plaza pass: inside the walls looking south at the X 45..51 gate opening.
            _overview!.GlobalPosition = new Vector3(48f, 20f, 55f);
            _overview.LookAt(new Vector3(48f, 3f, 92f), Vector3.Up);
        }
        else if (_stage == 2 && _time > 4.0)
        {
            _stage = 3;
            Capture("outpost_3d_gate_plaza.png");
            // Farm + pond pass: X 58 sits midway between the farm plot (~32) and the pond (~84).
            _overview!.GlobalPosition = new Vector3(58f, 45f, 100f);
            _overview.LookAt(new Vector3(58f, 0f, 48f), Vector3.Up);
            ShowTopStages();
        }
        else if (_stage == 3 && _time > 5.0)
        {
            _stage = 4;
            Capture("outpost_3d_farm_pond.png");
            GD.Print("[outpostshot] done, quitting");
            GetTree().Quit(0);
        }
    }

    /// <summary>Drive every placed building to its highest authored stage — a visual-only override so
    /// one screenshot shows the whole restored skyline instead of three rubble piles.</summary>
    private void ShowTopStages()
    {
        foreach (BuildingInstance building in Buildings(_outpost))
        {
            var stages = building.GetNodeOrNull("%Stages");
            if (stages != null && stages.GetChildCount() > 0)
                building.SetStage(stages.GetChildCount() - 1);
        }
    }

    private static IEnumerable<BuildingInstance> Buildings(Node? host)
    {
        if (host == null)
            yield break;
        foreach (Node child in host.GetChildren())
            if (child is BuildingInstance bi)
                yield return bi;
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
