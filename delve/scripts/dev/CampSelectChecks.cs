using System;
using System.Linq;
using System.Threading.Tasks;
using Delve.Flow;
using Delve.Presets;
using Delve.Run;
using Delve.UI;
using Godot;

namespace Delve.Dev;

internal static class CampSelectChecks
{
    internal static async Task Run(HeroSelectPanel panel, Action<string, bool> check)
    {
        var unlocks = new UnlockState();
        panel.Setup(unlocks);
        await panel.ToSignal(panel.GetTree(), SceneTree.SignalName.ProcessFrame);
        await panel.ToSignal(panel.GetTree(), SceneTree.SignalName.ProcessFrame);
        var stage = panel.GetNode<CampStage>("%CampStage");
        check("camp reserves a distinct place for every Bulwark concept", stage.SeatIds.Length == 18
            && stage.SeatIds.Distinct().Count() == 18 && stage.Seats.Length == 18);
        check("current roster placement is keyed by character identity", CharacterCatalog.All.All(def => stage.SeatFor(def.Id) >= 0));
        var aldric = HeroSelectChecks.Card(HeroSelectChecks.Cards(panel), PresetCharacters.PlayerId)!;
        check("unselected residents start seated", aldric.Resting && !aldric.Selected);
        check("transparent sprite corners do not intercept camp clicks", !aldric._HasPoint(Vector2.Zero));
        aldric.EmitSignal(Button.SignalName.Pressed);
        check("clicking a resident adds a party member", panel.SelectedIds.Contains(aldric.Id) && aldric.Selected);
        await Wait(panel);
        check("selected resident reaches the ready pose", aldric.IsReady);
        aldric.EmitSignal(Button.SignalName.Pressed);
        check("deselection clears the highlight immediately", !aldric.Selected);
        await Wait(panel);
        check("deselection returns to seated idle", aldric.Resting);
        aldric.EmitSignal(Button.SignalName.Pressed);
        aldric.EmitSignal(Button.SignalName.Pressed);
        aldric.EmitSignal(Button.SignalName.Pressed);
        await Wait(panel);
        check("rapid toggles settle to the final selection", aldric.IsReady && panel.SelectedIds.Contains(aldric.Id));
        Vector2 position = aldric.Position;
        unlocks.Unlock(PresetCharacters.RavenId);
        panel.RefreshRecruitment();
        await Wait(panel);
        var residents = HeroSelectChecks.Cards(panel);
        check("a permanent unlock adds one resident", residents.Count == 5 && residents.Any(r => r.Id == PresetCharacters.RavenId));
        check("unlock refresh preserves selected residents and their place", aldric.Selected && aldric.Position.IsEqualApprox(position));
        panel.RefreshRecruitment();
        check("repeated refresh never duplicates residents", HeroSelectChecks.Cards(panel).Count == 5);
        panel.OpenDetails();
        panel.Pick(PresetCharacters.ElaraId);
        panel.Unpick();
        check("character details block formation changes", panel.SelectedIds.Contains(aldric.Id) && panel.SelectedIds.Count == 1);
        panel.CloseDetails();
        panel.Setup(new UnlockState());
        check("a fresh setup removes residents outside its unlock state", HeroSelectChecks.Cards(panel).Count == 4 && panel.SelectedIds.Count == 0);
        panel._Input(new InputEventAction { Action = InputNames.UiDown, Pressed = true });
        panel._Input(new InputEventAction { Action = InputNames.Confirm, Pressed = true });
        check("keyboard navigation selects a resident", panel.SelectedIds.Contains(PresetCharacters.PlayerId));
        panel._Input(new InputEventAction { Action = InputNames.Confirm, Pressed = true });
        check("keyboard confirmation can deselect the same resident", panel.SelectedIds.Count == 0);
        panel.Setup(new UnlockState());
    }

    private static async Task Wait(Node node)
        => await node.ToSignal(node.GetTree().CreateTimer(0.85), SceneTreeTimer.SignalName.Timeout);
}
