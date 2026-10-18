using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Delve.Flow;
using Delve.Presets;
using Delve.Run;
using Delve.UI;
using Delve.Village;
using Godot;

namespace Delve.Dev;

/// <summary>
/// The outpost as the player meets it: the village with its residents, the Delve trail opening
/// party assembly, a slot filled from the roster with the pick walking in, a pick sent back to
/// town, Esc keeping the picks, and G embarking only at four.
/// </summary>
internal static class CampSelectChecks
{
    internal static async Task Run(HeroSelectPanel panel, Action<string, bool> check)
    {
        var unlocks = new UnlockState();
        panel.Setup(unlocks);
        await Frames(panel, 2);
        var village = panel.Village;
        var accents = CharacterCatalog.All.Select(def => UiColors.CharacterAccent(def.Id)).ToArray();
        check("every roster member has a unique identity color", accents.Distinct().Count() == accents.Length);
        check("no roster member uses the fallback accent", accents.All(color => color != UiColors.Accent && color.A == 1f));
        check("every unlocked resident is at home in the village", HeroSelectChecks.Residents(panel).Count == unlocks.UnlockedIds.Count
            && village.Residents.Unplaced.Count == 0);
        check("the camp opens in town", !panel.Assembling && village.Camera.Stop?.Id == village.HomeStop);

        var trail = village.Stations.First(s => s.Id == "delve");
        trail.EmitSignal(VillageStation.SignalName.Pressed, trail.Id);
        check("clicking the Delve trail enters party assembly", panel.Assembling && village.Camera.Stop?.Id == village.AssemblyStop);
        check("Q and E stop moving the camera during assembly", !village.Browsing || await BrowsingAfterFrame(panel) == false);

        panel.OpenPicker(0);
        check("a slot opens the roster on every free resident", panel.Picker.Visible
            && panel.Picker.Offered.Count == unlocks.UnlockedIds.Count);
        PressTile(panel, 0);
        string first = panel.SelectedIds.FirstOrDefault() ?? "";
        check("choosing from the roster fills the slot and closes it", panel.SelectedIds.Count == 1 && !panel.Picker.Visible);
        check("the pick leaves their spot in the village", HeroSelectChecks.Residents(panel).All(id => id != first));
        check("the pick is called from offscreen", village.Lineup.IsCalled(first) && !village.Lineup.HasArrived(first));
        await Wait(panel, 4.5);
        check("the pick walks in and takes slot 1", village.Lineup.HasArrived(first) && village.Lineup.SlotOf(first) == 0);

        panel.OpenPicker(2);
        check("the roster leaves out who is already in the party", !panel.Picker.Offered.Contains(first));
        PressTile(panel, 0);
        string second = panel.SelectedIds.FirstOrDefault(id => id != first) ?? "";
        check("the roster fills the slot it was opened on", village.Lineup.SlotOf(second) == 2);

        panel.OpenPicker(2);
        panel.Picker.GetNode<Button>("%PickerVacate").EmitSignal(Button.SignalName.Pressed);
        check("sending a pick back empties the slot", panel.SelectedIds.Count == 1 && !village.Lineup.IsCalled(second));
        check("the sent-back pick walks out and is home again", village.Lineup.Leaving == 1
            && HeroSelectChecks.Residents(panel).Contains(second));

        panel._Input(new InputEventAction { Action = InputNames.UiCancel, Pressed = true });
        check("Esc goes back to town and keeps the picks", !panel.Assembling && panel.SelectedIds.SequenceEqual(new[] { first }));
        check("the party waits at the trailhead while the camera is in town", village.Lineup.HasArrived(first));
        panel._Input(new InputEventAction { Action = InputNames.ExploreDescend, Pressed = true });
        check("G walks to the trail", panel.Assembling);

        IReadOnlyList<string>? embarked = null;
        void OnConfirmed(IReadOnlyList<string> members) => embarked = members;
        panel.Confirmed += OnConfirmed;
        foreach (var id in unlocks.UnlockedIds.Where(id => id != first).Take(2)) panel.Pick(id);
        panel._Input(new InputEventAction { Action = InputNames.ExploreDescend, Pressed = true });
        check("G does not embark with three", embarked == null && !panel.CanEmbark);
        panel.Pick(unlocks.UnlockedIds.First(id => !panel.SelectedIds.Contains(id)));
        panel._Input(new InputEventAction { Action = InputNames.ExploreDescend, Pressed = true });
        panel.Confirmed -= OnConfirmed;
        check("G embarks at four", embarked is { Count: 4 });

        panel.Unpick();
        panel.Pick(PresetCharacters.PlayerId);
        unlocks.Unlock(PresetCharacters.RavenId);
        panel.RefreshRecruitment();
        check("a permanent unlock moves one resident into the village", HeroSelectChecks.Residents(panel).Count(id => id == PresetCharacters.RavenId) == 1);
        panel.RefreshRecruitment();
        check("repeated refresh never duplicates residents", HeroSelectChecks.Residents(panel).Count == unlocks.UnlockedIds.Count - 1);
        check("unlock refresh keeps the party", panel.SelectedIds.SequenceEqual(new[] { PresetCharacters.PlayerId }));

        panel.OpenDetails();
        panel.Pick(PresetCharacters.ElaraId);
        panel.Unpick();
        check("character details block formation changes", panel.SelectedIds.SequenceEqual(new[] { PresetCharacters.PlayerId }));
        panel.CloseDetails();
        panel.Setup(new UnlockState());
        check("a fresh setup sends everyone home and leaves town", panel.SelectedIds.Count == 0 && !panel.Assembling
            && HeroSelectChecks.Residents(panel).Count == 4);
    }

    private static void PressTile(HeroSelectPanel panel, int index)
    {
        var tiles = panel.Picker.GetNode<GridContainer>("%Tiles");
        tiles.GetChild<Button>(index).EmitSignal(Button.SignalName.Pressed);
    }

    private static async Task<bool> BrowsingAfterFrame(HeroSelectPanel panel)
    {
        await Frames(panel, 1);
        return panel.Village.Browsing;
    }

    private static async Task Frames(Node node, int count)
    {
        for (int i = 0; i < count; i++) await node.ToSignal(node.GetTree(), SceneTree.SignalName.ProcessFrame);
    }

    private static async Task Wait(Node node, double seconds)
        => await node.ToSignal(node.GetTree().CreateTimer(seconds), SceneTreeTimer.SignalName.Timeout);
}
