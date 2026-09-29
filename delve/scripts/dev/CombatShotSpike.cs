using System.Linq;
using System.Threading.Tasks;
using System.Collections.Generic;
using Delve.Autoload;
using Delve.Combat;
using Delve.UI;
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
    [Export] public PackedScene? TestScene { get; set; }
    [Export] public bool CaptureEnemyCloseup { get; set; }
    [Export] public bool CaptureIndividualEnemies { get; set; }
    [Export] public string OutputDirectory { get; set; } = "user://dev_shots";
    [Export] public int ExpectedEnemyCount { get; set; } = 7;
    [Export] public int ExpectedAttackCount { get; set; } = 6;
    [Export] public int ExpectedAccentCount { get; set; } = 6;

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
        var combat = (TestScene ?? GD.Load<PackedScene>("res://scenes/dev/combat_test.tscn")).Instantiate();
        AddChild(combat);
        await WaitSeconds(0.1f);
        var terrain = combat.FindChild("TerrainStage", recursive: true, owned: false);
        Check("forest outskirts carry no mist shelves (the look's halo shading does the falloff)",
            terrain?.GetNodeOrNull<Node3D>("Backdrop/OutskirtsMist") == null);
        GD.Print("[combatshot] spike ready");

        string captureDirectory = OS.GetEnvironment("DELVE_SHOT_DIRECTORY");
        if (!string.IsNullOrEmpty(captureDirectory)) OutputDirectory = captureDirectory;
        DirAccess.MakeDirRecursiveAbsolute(OutputDirectory);
        await WaitSeconds(0.4f);
        Capture("combat_encounter_intro.png");
        await WaitSeconds(BootSeconds);
        Capture("combat_shot.png");

        // Move is a command, as in FFT: the Idle board is clear, Move shows the bands, and hovering
        // a two-action tile draws the route with its second leg in that band's colour.
        var scene = GetNode<CombatScene>("CombatTest/Combat");
        Check($"the Idle board shows no movement bands ({scene.MoveBandTileCount} tiles)",
            scene.IsPlayerTurn && scene.MoveBandTileCount == 0);
        scene.GetNode<ActionBar>("%ActionBar")._UnhandledInput(
            new InputEventAction { Action = InputNames.Move, Pressed = true });
        await WaitSeconds(0.1f);
        Check($"Move shows the movement bands ({scene.MoveBandTileCount} tiles)", scene.MoveBandTileCount > 0);
        if (scene.HoverBandTile(2))
        {
            await WaitSeconds(PoseSeconds);
            Capture("combat_shot_move_hover.png");
            scene.ClearHover();
        }
        else
        {
            Check("a two-action band tile exists to hover", false);
        }

        // Close-up on the steepest banded tile: fills, boundary strips, route dots and the hover
        // frame must all lie on the slope, not float as flat quads through it.
        if (scene.HoverSteepestBandTile(out var slopeTile) && Rig() is { } slopeRig)
        {
            var camera = slopeRig.Camera;
            var previousPose = camera.GlobalTransform;
            camera.GlobalPosition = slopeTile + new Vector3(2.2f, 1.6f, 2.2f);
            camera.LookAt(slopeTile);
            await WaitSeconds(PoseSeconds);
            Capture("combat_shot_bands_slope.png");
            camera.GlobalTransform = previousPose;
            scene.ClearHover();
        }
        else
        {
            GD.Print("[combatshot] no sloped band tile on this board; slope close-up skipped");
        }
        // A second Move puts the bands away and the command menu opens again.
        scene.GetNode<ActionBar>("%ActionBar")._UnhandledInput(
            new InputEventAction { Action = InputNames.Move, Pressed = true });
        await WaitSeconds(0.1f);
        Check("a second Move closes the bands and reopens the menu",
            scene.MoveBandTileCount == 0 && scene.GetNode<ActionBar>("%ActionBar").MenuShown);

        if (CaptureEnemyCloseup && Rig() is { } closeupRig)
        {
            Vector3 center = Vector3.Zero;
            var enemies = new List<UnitVisual3D>();
            int count = 0;
            foreach (var node in combat.FindChildren("*", "", recursive: true, owned: false))
            {
                if (node is UnitVisual3D unit && unit.Character.TeamId == 2)
                {
                    center += unit.GlobalPosition;
                    enemies.Add(unit);
                    count++;
                }
            }
            Check($"preview has {ExpectedEnemyCount} enemy species", count == ExpectedEnemyCount);
            if (count > 0)
            {
                center /= count;
                var camera = closeupRig.Camera;
                var previousPose = camera.GlobalTransform;
                camera.GlobalPosition = center + new Vector3(3, 2.5f, 4);
                camera.LookAt(center + Vector3.Up * 0.5f);
                await WaitSeconds(PoseSeconds);
                Capture("enemy_bases_closeup.png");
                int attacks = 0;
                float contactDelay = 0;
                foreach (var enemy in enemies)
                {
                    if (!enemy.PlayAttack(out float delay)) continue;
                    attacks++;
                    contactDelay = Mathf.Max(contactDelay, delay);
                }
                Check($"{ExpectedAttackCount} species start attack clips", attacks == ExpectedAttackCount);
                await WaitSeconds(contactDelay + 0.02f);
                var accentLayer = new Node3D();
                combat.AddChild(accentLayer);
                var accentPresenter = new GodotPresenter3D(accentLayer, Delve.Terrain.TerrainHeightMap.Flat);
                foreach (var enemy in enemies)
                    accentPresenter.PlayAttackAccent(enemy, new Vector3(enemy.Facing.X, 0, enemy.Facing.Y));
                Check($"{ExpectedAccentCount} attack accents accompany the contact poses", accentLayer.GetChildCount() == ExpectedAccentCount);
                await WaitSeconds(0.025f);
                Capture("enemy_attacks_contact.png");
                await WaitSeconds(0.7f);
                Check("attack accents free themselves after recovery", accentLayer.GetChildCount() == 0);
                Capture("enemy_attacks_recovered.png");
                if (CaptureIndividualEnemies)
                    await CaptureIndividuals(enemies, camera);
                camera.GlobalTransform = previousPose;
            }
        }

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
        CheckSpellRowCostPreview(scene);

        // Pressing Skills closes Spells — the bar keeps one category open at a time.
        PressToggle("SkillsButton");
        await WaitSeconds(PoseSeconds);
        Capture("combat_shot_skills.png");
        if (FindChild("SkillsButton", recursive: true, owned: false) is Button skills) skills.ButtonPressed = false;
        await CaptureHudReview(scene);
        var log = GetNode<CombatScene>("CombatTest/Combat").GetNode<Delve.UI.CombatLogPanel>("%CombatLog");
        // The OS pointer may rest over the board in a rendered run; its move hint is not idle state.
        scene.ClearHover();
        CombatLogSamples.Fill(log);
        scene.GetNode<Delve.UI.DiceRollPanel>("%DiceRoll").ClearRoll();
        await WaitSeconds(PoseSeconds);
        AssertZones(scene, "idle");
        CheckBudget(scene, "idle", IdleBudgetPercent, IdleClearBox);
        Capture("combat_log_compact.png");
        log.Rows[^1].GetNode<Button>("%Disclosure").ButtonPressed = true;
        await WaitSeconds(PoseSeconds);
        Capture("combat_log_entry_expanded.png");
        log.SetExpanded(true);
        await WaitSeconds(PoseSeconds);
        AssertZones(scene, "log expanded");
        CheckBudget(scene, "log expanded", 0, null);
        Capture("combat_log_history.png");
        log.SetExpanded(false);
        var session = Session(scene);
        // The fixture replaced the live actors; live play resumes with the fight's own names.
        log.SetActors(session.Team1.Select(u => (u.Name, Delve.UI.UiColors.LogAlly))
            .Concat(session.Team2.Select(u => (u.Name, Delve.UI.UiColors.LogEnemy))));
        log.SetEnemies(session.Team2.Select(u => u.Name));
        var spider = session.Team2.FirstOrDefault(e => e.Health?.IsAlive == true);
        log.AppendEntry($"Aldric Strikes {spider?.Name ?? "Hunting Spider A"} with Longsword", 8, false);
        log.AppendEntry(CombatLogMasks.Mask("d20(19)+10=29 vs AC 17 → CriticalSuccess", spider, session.Team2)!, 2, true);
        log.Rows[^1].GetNode<Button>("%Disclosure").ButtonPressed = true;
        // Past the hero beat and its shrink: the settled row, mid-hold.
        await WaitSettled(scene.GetNode<Delve.UI.DiceRollPanel>("%DiceRoll"));
        AssertZones(scene, "player turn roll");
        CheckBudget(scene, "player turn roll", 0, RollClearBox);
        Capture("combat_dice_roll.png");
        await CaptureHeroRolls(scene);
        await CaptureSignatures(scene);
        await CapturePlayerTurnWithEnemies(scene);
        await CaptureEnemyStrikePrompt(scene);
        await CaptureMarkers(scene, data);
        await CaptureMoveConditions(scene, data);
    }

    private OrbitCameraRig? Rig() =>
        GetNodeOrNull<OrbitCameraRig>("CombatTest/Combat/CameraRig");

    private async Task CaptureIndividuals(List<UnitVisual3D> enemies, Camera3D camera)
    {
        foreach (var subject in enemies)
        {
            foreach (var enemy in enemies) enemy.Visible = enemy == subject;
            Vector3 target = subject.GlobalPosition + Vector3.Up * 0.55f;
            camera.GlobalPosition = target + new Vector3(2.3f, 1.7f, 2.8f);
            camera.LookAt(target);
            await WaitSeconds(PoseSeconds);
            string name = subject.Character.Name.ToLowerInvariant().Replace(' ', '_');
            Capture($"{name}_idle.png");
            if (subject.PlayAttack(out float delay))
            {
                await WaitSeconds(delay + 0.01f);
                var sprite = subject.GetNode<BillboardSpriteAnimator>("%Sprite");
                sprite.Frozen = true;
                Capture($"{name}_contact.png");
                sprite.Frozen = false;
                await WaitSeconds(0.7f);
            }
        }
        foreach (var enemy in enemies) enemy.Visible = true;
    }

    private void PressToggle(string buttonName)
    {
        if (FindChild(buttonName, recursive: true, owned: false) is Button button)
            button.ButtonPressed = true;
        else
            Check($"action bar has a {buttonName}", false);
    }

    private void Capture(string file)
    {
        Check($"{file} saved", SaveViewportCapture($"{OutputDirectory}/{file}", new Vector2I(1280, 720)) == Error.Ok);
    }

    private async Task WaitSeconds(float seconds)
    {
        var timer = GetTree().CreateTimer(seconds);
        await ToSignal(timer, SceneTreeTimer.SignalName.Timeout);
        // One more rendered frame so the capture reads the pose that was just set.
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }
}
