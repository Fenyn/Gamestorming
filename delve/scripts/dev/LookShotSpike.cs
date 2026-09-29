using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Combat;
using Godot;

namespace Delve.Dev;

/// <summary>
/// Rendered look check (scenes/dev/look_shot_spike.tscn): photographs the combat board with the HUD
/// hidden, for reference comparisons and UI mockups, and measures the frame rate with the full
/// look stack on (depth of field, SSAO, glow). Must run rendered, NOT --headless:
///   godot --path delve res://scenes/dev/look_shot_spike.tscn
/// </summary>
public partial class LookShotSpike : SpikeBase
{
    [Export] public PackedScene? CombatTest { get; set; }

    /// <summary>Lowest acceptable mean frame rate at the capture size. Below the 60 target because
    /// this machine often runs other projects' headless sims at the same time; the printed figure
    /// is the one to read.</summary>
    [Export] public float MinFps { get; set; } = 45f;

    [Export] public float BootSeconds { get; set; } = 3.5f;

    [Export] public float MeasureSeconds { get; set; } = 2f;

    protected override string Banner => "===================== LOOK SHOT SPIKE =====================";

    protected override async Task RunSpikeAsync(DataManager data)
    {
        if (CombatTest == null)
        {
            AbortFail("CombatTest scene is not wired");
            return;
        }
        var test = CombatTest.Instantiate();
        AddChild(test);
        await Wait(BootSeconds);

        var scene = test.GetNode<CombatScene>("Combat");
        Check("combat HUD saved", SaveViewportCapture("user://dev_shots/look_combat_hud.png") == Error.Ok);
        var menu = scene.GetNode<Delve.UI.ActionBar>("%ActionBar").BarPanel.GetGlobalRect();
        Node3D? activeCrystal = null;
        foreach (var node in scene.GetNode<Node3D>("%UnitLayer").FindChildren("Crystal", "", true, false))
            if (node is Node3D { Visible: true } crystal) activeCrystal = crystal;
        if (activeCrystal != null)
        {
            var unit = scene.ActiveCamera.UnprojectPosition(activeCrystal.GlobalPosition);
            float gap = Mathf.Min(Mathf.Abs(menu.Position.X - unit.X), Mathf.Abs(unit.X - menu.End.X));
            Check($"the command menu opens beside the active unit ({gap:F0} px from it, menu {menu})",
                gap < 260f && unit.Y > menu.Position.Y - 200f && unit.Y < menu.End.Y);
        }
        scene.GetNode<CanvasLayer>("%HUD").Visible = false;
        await Wait(0.3f);
        Check("clean combat board saved", SaveViewportCapture("user://dev_shots/look_combat_clean.png") == Error.Ok);

        Check("the forest look turns the halo on",
            scene.GetNode<Delve.Terrain.TerrainStage>("%TerrainStage").Look?.HaloOn == true);
        var crystals = scene.GetNode<Node3D>("%UnitLayer").FindChildren("Crystal", "", true, false);
        int shown = 0;
        foreach (var crystal in crystals) if (crystal is Node3D { Visible: true }) shown++;
        Check($"exactly one turn crystal shows ({shown} of {crystals.Count})", shown == 1);
        Check("every token has a blob shadow",
            scene.GetNode<Node3D>("%UnitLayer").FindChildren("Shadow", "Decal", true, false).Count == crystals.Count);

        var rig = scene.GetNode<OrbitCameraRig>("%CameraRig");
        var before = rig.Camera.GlobalPosition - rig.GlobalPosition;
        rig._UnhandledInput(new InputEventAction { Action = Delve.UI.InputNames.RotateRight, Pressed = true });
        await Wait(0.5f);
        var after = rig.Camera.GlobalPosition - rig.GlobalPosition;
        float turned = Mathf.RadToDeg(new Vector2(before.X, before.Z).AngleTo(new Vector2(after.X, after.Z)));
        Check($"a rotate press turns the view a quarter turn ({turned:F0} degrees)", Mathf.Abs(Mathf.Abs(turned) - 90f) < 3f);
        await Wait(0.3f);
        Check("clean second angle saved", SaveViewportCapture("user://dev_shots/look_combat_alt.png") == Error.Ok);
        rig._UnhandledInput(new InputEventAction { Action = Delve.UI.InputNames.RotateLeft, Pressed = true });
        await Wait(0.5f);

        var hud = scene.GetNode<CanvasLayer>("%HUD");
        hud.Visible = true;
        scene.GetNode<Delve.UI.ActionBar>("%ActionBar")._UnhandledInput(
            new InputEventAction { Action = Delve.UI.InputNames.Move, Pressed = true });
        hud.Visible = false;
        await Wait(0.4f);
        Check($"Move shows the bands ({scene.MoveBandTileCount} tiles)", scene.MoveBandTileCount > 0);
        var prompt = scene.GetNode<Delve.UI.CommandPromptView>("%CommandPrompt");
        Check($"Move shows the instruction pill ('{prompt.InstructionText}')",
            prompt.PillShown && prompt.InstructionText == CommandPrompts.For(PlayerTurnMode.Moving).Instruction);
        Check("the command menu closes while a tile is picked", !scene.GetNode<Delve.UI.ActionBar>("%ActionBar").MenuShown);
        Check("clean move bands saved", SaveViewportCapture("user://dev_shots/look_combat_move.png") == Error.Ok);
        var card = scene.GetNode<Delve.UI.UnitInspectPanel>("%UnitInspect");
        bool hovered = scene.HoverBandTile(2);
        Check($"hovering a two-action tile hollows two of the actor's pips ({card.PreviewedSpend})",
            hovered && card.PreviewedSpend == 2);
        scene.ClearHover();
        Check($"leaving the bands clears the preview ({card.PreviewedSpend})", card.PreviewedSpend == 0);
        CheckBoardNumbers(scene);
        CheckTileReadout(scene);

        var bar = scene.GetNode<Delve.UI.ActionBar>("%ActionBar");
        // Hotkeys answer only while the HUD is up; a second Move puts the bands away.
        hud.Visible = true;
        bar._UnhandledInput(new InputEventAction { Action = Delve.UI.InputNames.Move, Pressed = true });
        hud.Visible = false;
        await Wait(0.2f);
        float nearScale = bar.MenuScale;
        rig.ToggleOverview();
        await Wait(0.6f);
        Check($"the command menu snaps to the crisp two-thirds step in the overview ({nearScale:0.000} → {bar.MenuScale:0.000})",
            bar.MenuShown && Mathf.IsEqualApprox(nearScale, 1f) && Mathf.IsEqualApprox(bar.MenuScale, ZoomScale.Small));
        Check("clean overview saved", SaveViewportCapture("user://dev_shots/look_combat_overview.png") == Error.Ok);
        hud.Visible = true;
        await Wait(0.2f);
        Check("overview with HUD saved", SaveViewportCapture("user://dev_shots/look_combat_overview_hud.png") == Error.Ok);
        hud.Visible = false;
        rig.ToggleOverview();
        await Wait(0.6f);

        ulong start = Time.GetTicksUsec();
        int frames = Engine.GetFramesDrawn();
        await Wait(MeasureSeconds);
        double seconds = (Time.GetTicksUsec() - start) / 1_000_000.0;
        double fps = (Engine.GetFramesDrawn() - frames) / seconds;
        GD.Print($"[look] mean fps {fps:F1} at {GetViewport().GetVisibleRect().Size}");
        Check($"mean frame rate {fps:F0} is at least {MinFps:F0}", fps >= MinFps);
    }

    /// <summary>Each unit's board plate carries the number its timeline tile shows, and an enemy's
    /// carries its log letter in the same label ("3C").</summary>
    private void CheckBoardNumbers(CombatScene scene)
    {
        var numbers = scene.GetNode<Delve.UI.TurnOrderBar>("%TurnOrderBar").Numbers;
        var letters = ((CombatSession)typeof(CombatScene).GetField("_session",
            System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic)!.GetValue(scene)!).Letters;
        var mismatches = new System.Collections.Generic.List<string>();
        foreach (var node in scene.GetNode<Node3D>("%UnitLayer").GetChildren())
        {
            if (node is not UnitVisual3D unit || unit.Character.Health?.IsAlive != true) continue;
            string letter = unit.Character.TeamId == 1 ? "" : letters.LetterFor(unit.Character);
            string expected = numbers.TryGetValue(unit.Character.UniqueId, out int n) ? $"{n}{letter}" : "";
            if (unit.TimelineNumberText != expected) mismatches.Add($"{unit.Character.Name} '{unit.TimelineNumberText}' vs '{expected}'");
        }
        Check($"board plates carry the timeline numbers ({string.Join("; ", mismatches)})", mismatches.Count == 0);
    }

    /// <summary>Hovering a tile shows its height in feet and its surface at the top right.</summary>
    private void CheckTileReadout(CombatScene scene)
    {
        var hover = typeof(CombatScene).GetMethod("OnTileHovered",
            System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic)!;
        hover.Invoke(scene, new object?[] { (PF2e.Vector2Int?)new PF2e.Vector2Int(1, 1) });
        var readout = scene.GetNode<Delve.UI.TileReadout>("%TileReadout");
        Check($"a hovered tile shows its height ('{readout.HeightText}')", readout.Visible && readout.HeightText.EndsWith(" ft"));
        hover.Invoke(scene, new object?[] { null });
        Check("the readout hides off the board", !readout.Visible);
    }

    private async Task Wait(float seconds) =>
        await ToSignal(GetTree().CreateTimer(seconds), Timer.SignalName.Timeout);
}
