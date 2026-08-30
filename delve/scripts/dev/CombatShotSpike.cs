using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Combat;
using Godot;

namespace Delve.Dev;

/// <summary>
/// Rendered smoke test for the combat board (scenes/dev/combat_shot_spike.tscn). Instances the
/// combat test scene (generated forest map, default seed), lets the encounter boot, then captures
/// the viewport once per camera pose: the default angle, a 90-degree orbit (regressions often hide
/// behind one lucky angle), a low-pitch horizon angle (the backdrop's sky gradient and far scenery
/// only enter frame near minimum pitch), two more near the pitch floor at other yaws (edge-scenery
/// occlusion of edge-tile units shows up only down there), then the action bar's Spells flyout and
/// finally its Skills flyout.
///
/// Captures go to user://dev_shots (a run artifact, never repo content); each save prints its
/// globalized OS path. Must run rendered, NOT --headless:
///   godot --path delve res://scenes/dev/combat_shot_spike.tscn
/// </summary>
public partial class CombatShotSpike : SpikeBase
{
    private const string OutDir = "user://dev_shots";

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

    /// <summary>Seconds the encounter gets to boot before the first capture.</summary>
    private const float BootSeconds = 3.5f;

    /// <summary>Seconds between poses, so the rig and the HUD settle before the next capture.</summary>
    private const float PoseSeconds = 0.5f;

    protected override string Banner => "==================== COMBAT SHOT SPIKE ====================";

    protected override async Task RunSpikeAsync(DataManager data)
    {
        var combat = GD.Load<PackedScene>("res://scenes/dev/combat_test.tscn").Instantiate();
        AddChild(combat);
        GD.Print("[combatshot] spike ready");

        DirAccess.MakeDirRecursiveAbsolute(OutDir);
        await WaitSeconds(BootSeconds);
        Capture("combat_shot.png");

        // Second angle: swing the whole rig a quarter turn around its pivot. The rig only rewrites
        // the camera pose on input, so the rotation sticks until the next capture.
        Rig()?.RotateY(Mathf.Pi / 2f);
        await WaitSeconds(PoseSeconds);
        Capture("combat_shot_alt.png");

        // Third angle: back to the default yaw, dropped to a near-floor pitch so the horizon band
        // — sky gradient, fog falloff, backdrop scenery — is actually in frame.
        var rig = Rig();
        rig?.RotateY(-Mathf.Pi / 2f);
        rig?.SetOrbit(DefaultYaw, HorizonPitch);
        await WaitSeconds(PoseSeconds);
        Capture("combat_shot_horizon.png");

        // Two extra checks hugging the pitch floor from other yaws: units on edge tiles must stay
        // visible over the near canopy from any direction.
        Rig()?.SetOrbit(160f, LowCheckPitch);
        await WaitSeconds(PoseSeconds);
        Capture("combat_shot_low_a.png");

        Rig()?.SetOrbit(285f, LowCheckPitch);
        await WaitSeconds(PoseSeconds);
        Capture("combat_shot_low_b.png");

        // Back to the default pose, then open the spells flyout by pressing the bar's Spells toggle
        // directly (fires Toggled, the same path as a click).
        Rig()?.SetOrbit(DefaultYaw, DefaultPitch);
        PressToggle("SpellsButton");
        await WaitSeconds(PoseSeconds);
        Capture("combat_shot_flyout.png");

        // Pressing Skills closes Spells — the bar keeps one category open at a time.
        PressToggle("SkillsButton");
        await WaitSeconds(PoseSeconds);
        Capture("combat_shot_skills.png");
    }

    private OrbitCameraRig? Rig() =>
        GetNodeOrNull<OrbitCameraRig>("CombatTest/Combat/CameraRig");

    private void PressToggle(string buttonName)
    {
        if (FindChild(buttonName, recursive: true, owned: false) is Button button)
            button.ButtonPressed = true;
        else
            Check($"action bar has a {buttonName}", false);
    }

    private void Capture(string file)
    {
        Image img = GetViewport().GetTexture().GetImage();
        // hdr_2d viewports hand back linear-space data; convert or the PNG comes out crushed dark.
        img.Convert(Image.Format.Rgba8);
        img.LinearToSrgb();
        img.Resize(1280, 720, Image.Interpolation.Bilinear);
        string path = $"{OutDir}/{file}";
        Error err = img.SavePng(path);
        GD.Print($"[combatshot] {file}: {err} ({ProjectSettings.GlobalizePath(path)})");
        Check($"{file} saved", err == Error.Ok);
    }

    private async Task WaitSeconds(float seconds)
    {
        var timer = GetTree().CreateTimer(seconds);
        await ToSignal(timer, SceneTreeTimer.SignalName.Timeout);
        // One more rendered frame so the capture reads the pose that was just set.
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }
}
