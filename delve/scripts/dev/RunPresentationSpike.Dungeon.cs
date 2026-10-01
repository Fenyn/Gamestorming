using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Delve.Data;
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
        // Real fades even headless, so a floor start that cancels the host's veil fails here.
        transition.PlayWhenHeadless = true;
        run.ConfirmParty(picks);
        var state = run.State!;
        run.ConfirmParty(picks);
        bool held = await WaitTransition(transition);
        Check("departure enters the dungeon once", ReferenceEquals(state, run.State) && run.Phase == RunPhase.Map);
        Check("the embark goal caption holds until Enter, even as the floor begins under it", held);
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
        Check("arriving at the refuge opens no popup; the camp waits on the HUD",
            dungeon.Phase == DungeonPhase.Doors && dungeon.GetNode<DungeonHud>("%DungeonHud").GetNode<Button>("%Camp") is { Visible: true, Disabled: false });
        state.Party.Members[0].Health.SetCurrentHP(1);
        int day = state.Clock.Day, ward = state.Wardstone.Ward;
        dungeon.MakeCamp();
        dungeon.MakeCamp();
        Check("camp plays on the host's transition, the only one in the run",
            transition.Busy || state.Clock.Day == day + 1);
        await WaitTransition(transition);
        var panel = dungeon.GetNode<CanvasLayer>("%Screens").GetChildren().OfType<EventPanel>().Single();
        var report = panel.Report!;
        var wardPair = report.FigureLabels.FirstOrDefault(f => f.CaptionText == "Ward");
        var aldricHp = report.MemberRows.FirstOrDefault(r => r.MemberName == "Aldric")?.FigureLabels.FirstOrDefault(f => f.CaptionText == "HP");
        Check($"overnight event applies once and reports the morning as pairs ('{panel.TitleText}', "
            + $"Ward {wardPair?.BeforeText} → {wardPair?.ValueText}, Aldric HP {aldricHp?.BeforeText} → {aldricHp?.ValueText})",
            state.Clock.Day == day + 1 && panel.TitleText == $"Morning, day {state.Clock.Day}"
            && (state.Wardstone.Ward == ward ? wardPair == null : wardPair?.BeforeText == ward.ToString() && wardPair.ValueText == state.Wardstone.Ward.ToString())
            && aldricHp?.BeforeText == "1" && report.MemberRows.All(r => r.FigureLabels.Count > 0));
        var study = dungeon.LastStudy;
        var leadLine = BossEncounters.ForStratum(state.Stratum).Spawns[0];
        var lead = Delve.Autoload.DataManager.Instance!.ResolveCreature(leadLine.Creature)!;
        var journalPair = report.FigureLabels.FirstOrDefault(f => f.CaptionText == lead.CreatureName);
        Check($"the camp night studies the guardian and the morning shows the journal pair ({study?.Actor} {study?.Skill} {study?.Total} vs {study?.Dc}, {study?.Degree}; {journalPair?.BeforeText} → {journalPair?.ValueText})",
            study != null && study.Dc == GuardianStudy.Dc(lead, leadLine.Adjustment) && study.Skill == GuardianStudy.SkillFor(lead)
            && dungeon.Journal!.IsEncountered(lead.CreatureId)
            && study.Revealed.Count == KnowledgeRevealOrder.RevealCount(study.Degree) && journalPair != null);
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

    /// <summary>Wait out a transition, dismissing a held caption the way a click would.</summary>
    private async Task<bool> WaitTransition(SceneTransition transition)
    {
        var deadline = DateTime.UtcNow.AddSeconds(10);
        bool held = false;
        while (transition.Busy && DateTime.UtcNow < deadline)
        {
            if (transition.WaitingForInput)
            {
                held = true;
                await ToSignal(GetTree().CreateTimer(0.8), SceneTreeTimer.SignalName.Timeout);
                Check("a held caption is still up after the fade hold", transition.Busy && transition.WaitingForInput);
                transition._Input(new InputEventAction { Action = Delve.UI.InputNames.Confirm, Pressed = true });
            }
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        }
        Check("transition finished within ten seconds", !transition.Busy);
        return held;
    }
}
