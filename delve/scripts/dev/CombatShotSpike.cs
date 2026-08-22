using Delve.Combat;
using Godot;

namespace Delve.Dev;

/// <summary>
/// Rendered smoke test for the combat board (scenes/dev/combat_shot_spike.tscn). Instances the
/// combat test scene (generated forest map, default seed), lets the encounter boot, captures the
/// viewport to dev_shots/ from the default camera, again after a 90-degree orbit (regressions
/// often hide behind one lucky angle), once at a low-pitch horizon angle (the backdrop's sky
/// gradient and far scenery only enter frame near minimum pitch), twice more near the pitch floor
/// at other yaws (edge-scenery occlusion of edge-tile units shows up only down there), then with
/// the action bar's Spells flyout opened (its Spells toggle pressed directly), and finally with
/// the Skills flyout opened, then quits. Must run rendered (not --headless):
///   godot --path delve res://scenes/dev/combat_shot_spike.tscn
/// </summary>
public partial class CombatShotSpike : Node
{
    private const string OutDir = "res://dev_shots";

    /// <summary>Default orbit pose (matches OrbitCameraRig's InitialYawDegrees/InitialPitchDegrees),
    /// restored after the horizon capture.</summary>
    private const float DefaultYaw = 45f;
    private const float DefaultPitch = 50f;

    /// <summary>Low pitch for the horizon shot — near the rig's 15-degree floor, where the sky and
    /// the backdrop's far scenery fill the top of the frame.</summary>
    private const float HorizonPitch = 18f;

    /// <summary>Pitch for the two extra yaw checks — right at the rig's floor, the worst case for
    /// perimeter props screening units on edge tiles.</summary>
    private const float LowCheckPitch = 16f;

    private double _time;
    private bool _firstSaved;
    private bool _secondSaved;
    private bool _horizonSaved;
    private bool _lowASaved;
    private bool _lowBSaved;
    private bool _thirdSaved;
    private bool _fourthSaved;

    public override void _Ready()
    {
        var combat = GD.Load<PackedScene>("res://scenes/dev/combat_test.tscn").Instantiate();
        AddChild(combat);
        GD.Print("[combatshot] spike ready");
    }

    public override void _Process(double delta)
    {
        _time += delta;

        if (!_firstSaved && _time > 3.5)
        {
            _firstSaved = true;
            DirAccess.MakeDirRecursiveAbsolute(OutDir);
            if (!Capture("combat_shot.png")) { GetTree().Quit(1); return; }

            // Second angle: swing the whole rig a quarter turn around its pivot. The rig only
            // rewrites the camera pose on input, so the rotation sticks until the next capture.
            Rig()?.RotateY(Mathf.Pi / 2f);
        }
        else if (_firstSaved && !_secondSaved && _time > 4.0)
        {
            _secondSaved = true;
            if (!Capture("combat_shot_alt.png")) { GetTree().Quit(1); return; }

            // Third angle: back to the default yaw, dropped to a near-floor pitch so the horizon
            // band — sky gradient, fog falloff, backdrop scenery — is actually in frame.
            var rig = Rig();
            rig?.RotateY(-Mathf.Pi / 2f);
            rig?.SetOrbit(DefaultYaw, HorizonPitch);
        }
        else if (_secondSaved && !_horizonSaved && _time > 4.5)
        {
            _horizonSaved = true;
            if (!Capture("combat_shot_horizon.png")) { GetTree().Quit(1); return; }

            // Two extra checks hugging the pitch floor from other yaws: units on edge tiles must
            // stay visible over the near canopy from any direction.
            Rig()?.SetOrbit(160f, LowCheckPitch);
        }
        else if (_horizonSaved && !_lowASaved && _time > 5.0)
        {
            _lowASaved = true;
            if (!Capture("combat_shot_low_a.png")) { GetTree().Quit(1); return; }
            Rig()?.SetOrbit(285f, LowCheckPitch);
        }
        else if (_lowASaved && !_lowBSaved && _time > 5.5)
        {
            _lowBSaved = true;
            if (!Capture("combat_shot_low_b.png")) { GetTree().Quit(1); return; }

            // Back to the default pose, then open the spells flyout by pressing the bar's Spells
            // toggle directly (fires Toggled, same path as a click).
            Rig()?.SetOrbit(DefaultYaw, DefaultPitch);
            if (FindChild("SpellsButton", recursive: true, owned: false) is Button spells)
                spells.ButtonPressed = true;
        }
        else if (_lowBSaved && !_thirdSaved && _time > 6.0)
        {
            _thirdSaved = true;
            if (!Capture("combat_shot_flyout.png")) { GetTree().Quit(1); return; }

            // Next: swap to the Skills flyout (pressing Skills closes Spells — the bar
            // keeps one category open at a time).
            if (FindChild("SkillsButton", recursive: true, owned: false) is Button skills)
                skills.ButtonPressed = true;
        }
        else if (_thirdSaved && !_fourthSaved && _time > 6.5)
        {
            _fourthSaved = true;
            bool ok = Capture("combat_shot_skills.png");
            GD.Print(ok ? "SPIKE RESULT: PASS" : "SPIKE RESULT: FAIL");
            GetTree().Quit(ok ? 0 : 1);
        }
    }

    private OrbitCameraRig? Rig() =>
        GetNodeOrNull<OrbitCameraRig>("CombatTest/Combat/CameraRig");

    private bool Capture(string file)
    {
        Image img = GetViewport().GetTexture().GetImage();
        // hdr_2d viewports hand back linear-space data; convert or the PNG comes out crushed dark.
        img.Convert(Image.Format.Rgba8);
        img.LinearToSrgb();
        img.Resize(1280, 720, Image.Interpolation.Bilinear);
        string path = $"{OutDir}/{file}";
        Error err = img.SavePng(path);
        GD.Print($"[combatshot] {file}: {err} ({ProjectSettings.GlobalizePath(path)})");
        return err == Error.Ok;
    }
}
