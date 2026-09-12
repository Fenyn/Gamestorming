using System.Collections.Generic;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Combat;
using Delve.Data;
using Delve.Presets;
using Delve.UI;
using Godot;
using PF2e.Core;
using PF2e.MapGen;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Dev;

/// <summary>
/// Regression for the spell-targeting click path through REAL input: opens the Spells flyout with
/// its hotkey, presses the Electric Arc chip with a pushed mouse click, then pushes left clicks on
/// the goblin at its head, its body and its feet and records which tile each click resolves to.
/// Runs the flat board first, then a generated forest board (physics picking). Headless-safe.
/// </summary>
public partial class TargetClickSpike : SpikeBase
{
    [Export] public PackedScene? CombatScene { get; set; }

    /// <summary>Seconds to wait for the player's turn (the goblin may win initiative).</summary>
    private const float TurnWaitSeconds = 20f;

    private readonly List<PF2eVec> _clicks = new();

    protected override string Banner => "==================== TARGET CLICK SPIKE ====================";

    protected override async Task RunSpikeAsync(DataManager data)
    {
        PresetSpells.EnsureRegistered();
        if (CombatScene == null) { AbortFail("[TargetClick] CombatScene not assigned."); return; }

        var scene = CombatScene.Instantiate<CombatScene>();
        AddChild(scene);
        var input = scene.GetNode<GridInput3D>("%GridInput");
        input.TileClicked += tile => _clicks.Add(tile);

        await RunBoard(data, scene, terrain: false);
        await RunBoard(data, scene, terrain: true);
    }

    private async Task RunBoard(DataManager data, CombatScene scene, bool terrain)
    {
        string tag = terrain ? "terrain" : "flat";
        GD.Print($"-------------------- {tag} board --------------------");
        var fenwick = PresetCharacters.BuildFenwick(level: 2, teamId: 1);
        var goblin = CreatureFactory.Create(data.ResolveCreature(EncounterTables.GoblinWarrior)!, teamId: 2);

        CombatSetup setup;
        if (terrain)
        {
            var layout = MapGenerator.GenerateValidated("forest", 20260804);
            var anchor = DeploymentPlanner.GetAnchors(layout, teamId: 0, count: 1)[0];
            var goblinPos = NearestWalkable(layout, new PF2eVec(anchor.x + 3, anchor.y), anchor);
            setup = new CombatSetup
            {
                Layout = layout, BiomeId = "forest", RngSeed = 7,
                Party = { (fenwick, anchor) }, Enemies = { (goblin, goblinPos) },
            };
        }
        else
        {
            setup = new CombatSetup
            {
                GridWidth = 12, GridHeight = 10, RngSeed = 7,
                Party = { (fenwick, new PF2eVec(3, 5)) }, Enemies = { (goblin, new PF2eVec(6, 5)) },
            };
        }

        scene.StartEncounter(setup);
        await WaitSeconds(0.5f);

        float waited = 0f;
        while (!scene.IsPlayerTurn && waited < TurnWaitSeconds)
        {
            await WaitSeconds(0.25f);
            waited += 0.25f;
        }
        Check($"[{tag}] player turn arrived", scene.IsPlayerTurn);
        if (!scene.IsPlayerTurn) return;
        await WaitSeconds(0.5f);

        var bar = scene.GetNode<ActionBar>("%ActionBar");
        var hint = bar.GetNode<Label>("%TargetingHint");
        var flyout = bar.GetNode<Control>("%Flyout");

        bar._UnhandledInput(new InputEventAction { Action = InputNames.Spells, Pressed = true });
        await Frames(2);
        Check($"[{tag}] spell flyout opens", flyout.Visible);

        var chip = FindChip(flyout, "Electric Arc");
        Check($"[{tag}] Electric Arc chip present and enabled", chip != null && !chip.Disabled);
        if (chip == null) return;

        Click(chip.GetGlobalRect().GetCenter());
        await Frames(2);
        Check($"[{tag}] chip click closes the flyout", !flyout.Visible);
        Check($"[{tag}] chip click enters targeting (hint = '{hint.Text}')", hint.Text.StartsWith("LMB  confirm"));

        var unit = FindUnit(scene, goblin);
        Check($"[{tag}] goblin visual found", unit != null);
        if (unit == null) return;

        var camera = GetViewport().GetCamera3D();
        var feet = unit.GlobalPosition;
        GD.Print($"[TargetClick] goblin tile {goblin.GridPosition} feet {feet} body height {unit.GetNode<BillboardSpriteAnimator>("%Sprite").BodyHeight}");

        // Picking geometry: which tile does each click land on? A cast fires on the first hit, so
        // read the tile the click resolved to rather than the encounter state.
        await ProbeClick(camera, feet + Vector3.Up * 1.0f, goblin.GridPosition, $"[{tag}] click on the goblin's head");
        await ProbeClick(camera, feet + Vector3.Up * 0.5f, goblin.GridPosition, $"[{tag}] click on the goblin's body");
        await ProbeClick(camera, feet + Vector3.Up * 0.05f, goblin.GridPosition, $"[{tag}] click on the goblin's feet");

        await WaitSeconds(1.5f);
        Check($"[{tag}] a click on the goblin cast the spell (actions {fenwick.Actions?.TotalActionsRemaining})",
            (fenwick.Actions?.TotalActionsRemaining ?? 3) < 3);
    }

    private async Task ProbeClick(Camera3D camera, Vector3 world, PF2eVec expected, string label)
    {
        var screen = camera.UnprojectPosition(world);
        _clicks.Clear();
        Move(screen);
        await Frames(3);
        Click(screen);
        await Frames(2);
        string got = _clicks.Count == 0 ? "no tile" : _clicks[0].ToString();
        Check($"{label} resolves to {expected} (got {got}, screen {screen})",
            _clicks.Count > 0 && _clicks[0].Equals(expected));
    }

    private void Move(Vector2 screen)
    {
        GetViewport().WarpMouse(screen);
        GetViewport().PushInput(new InputEventMouseMotion { Position = screen, GlobalPosition = screen });
    }

    private void Click(Vector2 screen)
    {
        GetViewport().PushInput(new InputEventMouseButton
        {
            ButtonIndex = MouseButton.Left, Pressed = true, Position = screen, GlobalPosition = screen,
        });
        GetViewport().PushInput(new InputEventMouseButton
        {
            ButtonIndex = MouseButton.Left, Pressed = false, Position = screen, GlobalPosition = screen,
        });
    }

    private static Button? FindChip(Node flyout, string name)
    {
        foreach (var node in flyout.FindChildren("*", "Button", recursive: true, owned: false))
        {
            if (node is Button button && button.GetNodeOrNull<Label>("%NameLabel")?.Text == name)
                return button;
        }
        return null;
    }

    private static UnitVisual3D? FindUnit(Node scene, ICharacter character)
    {
        foreach (var node in scene.FindChildren("*", "", recursive: true, owned: false))
            if (node is UnitVisual3D unit && ReferenceEquals(unit.Character, character)) return unit;
        return null;
    }

    private static PF2eVec NearestWalkable(MapLayout layout, PF2eVec wanted, PF2eVec avoid)
    {
        PF2eVec best = wanted;
        int bestDistance = int.MaxValue;
        for (int y = 0; y < layout.Height; y++)
            for (int x = 0; x < layout.Width; x++)
            {
                var p = new PF2eVec(x, y);
                if (!layout.IsWalkable(x, y) || p.Equals(avoid)) continue;
                int d = System.Math.Abs(x - wanted.x) + System.Math.Abs(y - wanted.y);
                if (d < bestDistance) { bestDistance = d; best = p; }
            }
        return best;
    }

    private async Task Frames(int count)
    {
        for (int i = 0; i < count; i++)
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }

    private async Task WaitSeconds(float seconds)
    {
        var timer = GetTree().CreateTimer(seconds);
        await ToSignal(timer, SceneTreeTimer.SignalName.Timeout);
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }
}
