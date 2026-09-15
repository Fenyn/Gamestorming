using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Delve.Dungeon;
using Delve.Flow;
using Delve.Presets;
using Delve.Run;
using Godot;

namespace Delve.Dev;

public partial class RunPresentationSpike
{
    [Export] public PackedScene RunScene { get; set; } = null!;

    private async Task CheckDungeonPresentation()
    {
        var run = RunScene.Instantiate<RunDirector>();
        run.AutoPlayCombat = true;
        run.CampaignSavePath = "";
        AddChild(run);
        run.AutoPlayCombat = false;
        var dungeon = run.Dungeon!;
        dungeon.AutoPlayCombat = false;
        dungeon.TravelSecondsPerTile = 0.001f;
        var picks = new[] { PresetCharacters.PlayerId, PresetCharacters.ElaraId,
            PresetCharacters.TharrId, PresetCharacters.FenwickId };
        var transition = run.GetNode<SceneTransition>("%SceneTransition");
        run.ConfirmParty(picks);
        var state = run.State!;
        run.ConfirmParty(picks);
        await WaitTransition(transition);
        Check("departure enters the dungeon once", ReferenceEquals(state, run.State) && run.Phase == RunPhase.Map);
        dungeon.ResolveEvent(0, null);
        dungeon.CloseEvent();
        int camp = dungeon.Floor.Rooms.First(r => r.Family == RoomFamily.Camp).Id;
        foreach (var room in dungeon.Floor.Rooms) room.Completed = room.Id != camp;
        while (dungeon.Current.Id != camp)
        {
            int start = dungeon.Current.Id;
            var previous = new Dictionary<int, int> { [start] = start };
            var queue = new Queue<int>();
            queue.Enqueue(start);
            while (queue.TryDequeue(out int id))
                foreach (var door in dungeon.Floor.Rooms[id].Doors)
                    if (previous.TryAdd(door.Other(id), id)) queue.Enqueue(door.Other(id));
            int next = camp;
            while (previous[next] != start) next = previous[next];
            await dungeon.Travel(dungeon.Current.Doors.First(d => d.Other(start) == next).Side(start));
        }
        state.Party.Members[0].Health.SetCurrentHP(1);
        int day = state.Clock.Day, ward = state.Wardstone.Ward;
        dungeon.ResolveEvent(0, null);
        dungeon.ResolveEvent(0, null);
        await WaitTransition(dungeon.GetNode<SceneTransition>("%SceneTransition"));
        var panel = dungeon.GetNode<CanvasLayer>("%Screens").GetChildren().OfType<EventPanel>().Single();
        string result = panel.GetNode<Label>("%ResultLabel").Text;
        Check("overnight event applies once and reports the applied ward", state.Clock.Day == day + 1
            && result.Contains($"Ward restored: +{state.Wardstone.Ward - ward}") && result.Contains("Aldric:"));
        await Capture("polish_morning");
        dungeon.CloseEvent();
        run.EndRun(RunOutcome.Defeat);
        var end = run.GetNode<CanvasLayer>("%Screens").GetChildren().OfType<RunEndPanel>().Single();
        end.GetNode<Button>("%NewRunButton").EmitSignal(Button.SignalName.Pressed);
        await WaitTransition(transition);
        Check("return transition opens a fresh outpost", run.Phase == RunPhase.HeroSelect && run.State == null);
        if (DisplayServer.GetName() != "headless")
        {
            run.ConfirmParty(picks);
            run.NewRun();
            await WaitTransition(transition);
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            Check("restart cancels a pending departure", run.State == null && !dungeon.Visible);
        }
        run.QueueFree();
    }

    private async Task WaitTransition(SceneTransition transition)
    {
        var deadline = DateTime.UtcNow.AddSeconds(10);
        while (transition.Busy && DateTime.UtcNow < deadline)
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        Check("transition finished within ten seconds", !transition.Busy);
    }
}
