using System.Linq;
using System.Reflection;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Combat;
using Delve.Data;
using Delve.Presets;
using Delve.UI;
using Godot;
using PF2e.Core;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Dev;

/// <summary>Exercise the scene's focus/staging adapter without spending actions on previews.</summary>
public partial class TacticalPresentationSpike : SpikeBase
{
    protected override async Task RunSpikeAsync(DataManager data)
    {
        PresetSpells.EnsureRegistered();
        CheckGeometry();
        var scene = GD.Load<PackedScene>("res://scenes/combat/combat.tscn").Instantiate<CombatScene>();
        AddChild(scene);
        scene.EncounterIntroEnabled = false;
        var setup = new CombatSetup { GridWidth = 16, GridHeight = 12, RngSeed = 7 };
        setup.Party.Add((PresetCharacters.BuildPlayer(2, teamId: 1), new PF2eVec(3, 5)));
        setup.Party.Add((PresetCharacters.BuildElara(2, 1), new PF2eVec(4, 5)));
        setup.Party.Add((PresetCharacters.BuildTharr(2, 1), new PF2eVec(3, 6)));
        setup.Party.Add((PresetCharacters.BuildFenwick(2, 1), new PF2eVec(4, 6)));
        setup.Enemies.Add((CreatureFactory.Create(data.ResolveCreature(EncounterTables.GoblinWarrior)!, 2), new PF2eVec(12, 5)));
        scene.StartEncounter(setup);
        var session = Field<CombatSession>(scene, "_session");
        var controller = Field<PlayerTurnController>(scene, "_controller");
        for (int i = 0; i < 120 && !controller.CanAcceptOrders; i++) await Wait(0.2);
        Check("player can issue orders", controller.CanAcceptOrders);
        if (!controller.CanAcceptOrders) return;
        var actor = session.CurrentActor!;
        var origin = actor.GridPosition;
        int actions = actor.Actions!.TotalActionsRemaining;
        var rig = scene.GetNode<OrbitCameraRig>("%CameraRig");
        var timeline = scene.GetNode<TurnOrderBar>("%TurnOrderBar");
        var bar = scene.GetNode<ActionBar>("%ActionBar");
        Check("every party member has a timeline tile", setup.Party.All(p => timeline.Numbers.ContainsKey(p.Unit.UniqueId)));
        var pose = rig.Camera.Transform;
        rig.ToggleOverview();
        await Wait(0.4);
        Check("overview changes framing", !pose.IsEqualApprox(rig.Camera.Transform));
        rig.ToggleOverview();
        rig.RestorePlanningView(); // duplicate clear signals must not interrupt the return tween
        await Wait(0.4);
        Check("overview restores exact planning pose", pose.IsEqualApprox(rig.Camera.Transform));
        rig.FrameAction(rig.GlobalPosition, rig.GlobalPosition + Vector3.Right * 4);
        await Wait(0.4);
        rig.RestorePlanningView();
        await Wait(0.1);
        rig.RestorePlanningView();
        await Wait(0.3);
        Check("action framing restores exact planning pose", pose.IsEqualApprox(rig.Camera.Transform));

        var other = setup.Party.First(p => p.Unit != actor).Unit;
        rig.Pan(Vector2.Right);
        scene.FocusPartyMember(other.UniqueId);
        await Wait(0.4);
        Check("portrait focus works after manual pan", rig.GlobalPosition.DistanceTo(
            Delve.Terrain.GridSpace.GridToWorld(other.GridPosition, Delve.Terrain.TerrainHeightMap.Flat)) < 1f);
        Check("inspection preserves actor and actions", session.CurrentActor == actor && actor.Actions.TotalActionsRemaining == actions);
        Check("the unit card shows the focused member", scene.GetNode<UnitInspectPanel>("%UnitInspect").NameText == other.Name);
        Check("the unit card clears the timeline",
            !scene.GetNode<UnitInspectPanel>("%UnitInspect").GetGlobalRect().Intersects(timeline.Row.GetGlobalRect()));
        rig.FocusOnActive();
        await Wait(0.4);
        var plan = session.PlayerActions.GetMovePlan(actor);
        var destination = plan.Options.First(p => p.Value.Kind == MoveKind.Step).Key;
        var path = plan.PathTo(destination, out _)!;
        var beforeOccupant = session.Grid.GetGroundOccupant(origin);
        var preview = DestinationTactics.Read(session.Grid, actor, destination, path, MoveKind.Step, session.Team2);
        Check("preview preserves position and occupancy", actor.GridPosition.Equals(origin) && session.Grid.GetGroundOccupant(origin) == beforeOccupant);
        Check("Step preview never warns about movement reactions", !preview.Caption.Contains("Reaction risk"));
        Check("unreachable tile cannot be staged", !controller.CanStageOrder(new PF2eVec(-1, -1)));

        bar.GetNode<CheckBox>("%StageOrders").ButtonPressed = true;
        controller.BeginMove();
        Click(scene, destination);
        Check("staging shows ghost and confirmation", scene.GetNode<DestinationPreview>("%DestinationPreview").Visible
            && bar.Decision.ConfirmOrderButton.Visible);
        Check("staging spends nothing", actor.GridPosition.Equals(origin) && actor.Actions.TotalActionsRemaining == actions);
        if (DisplayServer.GetName() != "headless")
        {
            await Wait(0.2);
            SaveViewportCapture("res://.godot/tactical-after/staged_order.png");
        }
        Invoke(scene, "OnCancel");
        Check("cancel clears ghost and pending order", !scene.GetNode<DestinationPreview>("%DestinationPreview").Visible
            && !bar.Decision.ConfirmOrderButton.Visible);
        scene.ConfirmStagedOrder();
        Check("cancelled confirmation spends nothing", actor.GridPosition.Equals(origin) && actor.Actions.TotalActionsRemaining == actions);
        Check("cancel leaves Move mode", controller.Mode == PlayerTurnMode.Idle);
        controller.BeginMove();
        Click(scene, destination);
        var hud = scene.GetNode<HudRoot>("%HudRoot");
        hud.PushModal();
        scene.ConfirmStagedOrder();
        Check("modal blocks confirmation", actor.GridPosition.Equals(origin) && actor.Actions.TotalActionsRemaining == actions);
        hud.PopModal();
        scene.ConfirmStagedOrder();
        scene.ConfirmStagedOrder();
        Check("the command menu stays closed while the move plays out", controller.Busy && !bar.MenuShown);
        for (int i = 0; i < 30 && !controller.CanAcceptOrders; i++) await Wait(0.2);
        Check("the command menu opens again when the move ends", !controller.Busy && bar.MenuShown);
        Check("confirmation moves once and spends one action", actor.GridPosition.Equals(destination)
            && actor.Actions.TotalActionsRemaining == actions - 1);
        rig.ToggleOverview();
        scene.EndHostedEncounter();
        Check("encounter teardown clears camera and cards", !rig.TacticalFraming
            && !scene.GetNode<UnitInspectPanel>("%UnitInspect").Visible);
        await Wait(0.3);
        scene.QueueFree();
        await Wait(0.1);
    }

    private void CheckGeometry()
    {
        var actor = PresetCharacters.BuildElara(2, 1);
        var ally = PresetCharacters.BuildTharr(2, 1);
        var enemy = PresetCharacters.BuildPlayer(2, teamId: 2);
        var setup = new CombatSetup { GridWidth = 10, GridHeight = 8 };
        setup.Party.Add((actor, new PF2eVec(1, 4)));
        setup.Party.Add((ally, new PF2eVec(5, 4)));
        setup.Enemies.Add((enemy, new PF2eVec(4, 4)));
        var session = new CombatSession();
        session.Setup(setup);
        foreach (var member in session.Team1.Concat(session.Team2)) CombatantRegistry.Instance.Register(member);
        try
        {
            var tile = new PF2eVec(3, 4);
            var path = new[] { actor.GridPosition, new PF2eVec(2, 4), tile };
            var view = DestinationTactics.Read(session.Grid, actor, tile, path, MoveKind.Stride, session.Team2);
            Check("destination detects a reachable flanking target", view.Targets.Contains(enemy) && view.Caption.Contains("Flank"));
            var departure = new[] { tile, new PF2eVec(2, 4) };
            Check("known reactive reach warns on departure", DestinationTactics.Read(session.Grid, actor,
                departure[1], departure, MoveKind.Stride, session.Team2).Caption.Contains("Reaction risk"));
            Check("Step suppresses that same reaction warning", !DestinationTactics.Read(session.Grid, actor,
                departure[1], departure, MoveKind.Step, session.Team2).Caption.Contains("Reaction risk"));
            var wall = session.Grid.GetTile(new PF2eVec(2, 4));
            wall.Inaccessible = true;
            wall.CornerHeights = PF2e.Grid.TileCornerHeights.Flat(8);
            var spatial = new TerrainSpatial(session.Grid);
            Check("prospective sight uses the destination rather than current position", !spatial.HasLineOfSight(actor, enemy)
                && spatial.HasLineOfSightFrom(tile, actor, enemy));
            var cover = DestinationTactics.Read(session.Grid, actor, actor.GridPosition,
                new[] { actor.GridPosition }, MoveKind.Step, session.Team2);
            Check("cover cue identifies its opposing threat", cover.Caption.Contains("Cover vs " + enemy.Name));
            Check("geometry leaves actor and occupancy unchanged", actor.GridPosition.Equals(new PF2eVec(1, 4))
                && session.Grid.GetGroundOccupant(actor.GridPosition) == actor);
        }
        finally { session.Teardown(); }
    }

    private async Task Wait(double seconds) => await ToSignal(GetTree().CreateTimer(seconds), SceneTreeTimer.SignalName.Timeout);
    private static T Field<T>(object owner, string name) => (T)owner.GetType().GetField(name, BindingFlags.Instance | BindingFlags.NonPublic)!.GetValue(owner)!;
    private static void Click(CombatScene scene, PF2eVec tile) => Invoke(scene, "OnTileClicked", tile);
    private static void Invoke(object owner, string method, params object[] args)
        => owner.GetType().GetMethod(method, BindingFlags.Instance | BindingFlags.NonPublic)!.Invoke(owner, args);
}
