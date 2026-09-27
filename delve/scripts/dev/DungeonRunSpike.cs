using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Data;
using Delve.Dungeon;
using Delve.Flow;
using Delve.Presets;
using Delve.Run;
using Godot;

namespace Delve.Dev;

/// <summary>Main-run wiring: real opening combat, then completed-floor fixtures for stairs.</summary>
public partial class DungeonRunSpike : SpikeBase
{
    [Export] public PackedScene RunScene { get; set; } = null!;
    protected override async Task RunSpikeAsync(DataManager data)
    {
        var run = RunScene.Instantiate<RunDirector>();
        run.TestFullRoster = false;
        run.AutoPlayCombat = true;
        run.Seed = 90210;
        AddChild(run);
        var dungeon = run.Dungeon!;
        dungeon.CombatAiDelay = 0;
        dungeon.TravelSecondsPerTile = 0.001f;
        double oldScale = Engine.TimeScale;
        Engine.TimeScale = 8;
        try
        {
            Check("main scene starts at hero selection with dungeon parked", run.UseDungeonMap
                && run.Phase == RunPhase.HeroSelect && !dungeon.Visible);
            var picks = new[] { PresetCharacters.FenwickId, PresetCharacters.PlayerId,
                PresetCharacters.TharrId, PresetCharacters.ElaraId };
            run.ConfirmParty(picks);
            var state = run.State!;
            Check("crawl uses the selected party and the run state", ReferenceEquals(state, dungeon.State)
                && state.Party.MemberIds.SequenceEqual(picks) && ReferenceEquals(state.Map, dungeon.Floor.Map));
            Check("node map is hidden in the main run", run.GetNode<CanvasLayer>("%Screens").GetChildren()
                .OfType<RunMapPanel>().All(p => !p.Visible));
            dungeon.UseStairs();
            Check("stairs cannot skip an unresolved floor", state.Stratum == 0);
            dungeon.ResolveEvent(0, null);
            dungeon.CloseEvent();
            await Capture("dungeon_run_exploration");
            int target = state.Map.Nodes.First(n => n.Kind == NodeKind.Meeting).Id;
            // Reach the real Wayfarer fight; fixture corridors are already cleared.
            foreach (var room in dungeon.Floor.Rooms.Where(r => r.Id != target)) room.Completed = true;
            state.Xp = state.Leveling.XpPerLevel - 1;
            while (dungeon.Current.Id != target) await Step(dungeon, target);
            Check("entering a fight switches the main run to combat", run.Phase == RunPhase.Combat);
            // Recruitment order is seeded across fourteen native builds. Keep this integration
            // fixture about the surviving-guest route, independent of a random recruit's balance.
            foreach (var guest in PF2e.Core.CombatantRegistry.Instance.All.Where(c => c.TeamId==1 && !picks.Contains(c.Id)))
            { guest.Health.OverrideMaxHP(500); guest.Health.SetCurrentHP(500); }
            var deadline = DateTime.UtcNow.AddSeconds(150);
            while (run.Phase == RunPhase.Combat && DateTime.UtcNow < deadline)
                await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            Check("hosted fight reaches the existing reward screen", run.Phase == RunPhase.CombatResults);
            if (run.Phase != RunPhase.CombatResults) return;
            int xp = state.Xp, level = state.Party.Level;
            Check("victory awards XP and queues promotions for the same party", level > Party.DefaultLevel
                && CharacterPromotion.HasPending(state.Party) && state.Party.Members.All(c => c.Stats.Level == Party.DefaultLevel));
            PromotionTestDriver.Complete(state.Party);
            if (DisplayServer.GetName() != "headless") dungeon.AutoPlayCombat = false;
            run.ContinueCombatResults();
            run.ContinueCombatResults();
            while (run.Phase == RunPhase.CombatResults && DateTime.UtcNow < deadline)
                await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            dungeon.AutoPlayCombat = true;
            Check("surviving Wayfarer reaches companion selection", run.Phase == RunPhase.Meetup);
            if (run.Phase == RunPhase.Meetup) run.DeclineMeetup();
            run.ContinueCombatResults();
            Check("returning closes combat and cannot award XP twice", run.Phase == RunPhase.Map
                && dungeon.Phase == DungeonPhase.Doors && state.Xp == xp && state.Party.Level == level);
            if (run.Phase != RunPhase.Map) return;

            var party = state.Party;
            var clock = state.Clock;
            var recruits = state.Recruits;
            for (int floor = 0; floor < FloorThemes.Count; floor++)
            {
                state.Wardstone.RefillFull();
                foreach (var room in dungeon.Floor.Rooms) room.Completed = true;
                while (dungeon.Current.Id != dungeon.Floor.GuardianId) await Step(dungeon, dungeon.Floor.GuardianId);
                var guardian = dungeon.Current;
                var setup = DungeonEncounters.Build(state, guardian, dungeon.CurrentView.Generated,
                    DoorSide.South, data.ResolveCreature, campaign: true);
                Check($"floor {floor + 1} uses its authored boss roster", setup != null
                    && setup.Enemies.Count == BossEncounters.ForStratum(floor).Spawns.Sum(s => s.Count));
                // Completed-floor fixtures isolate stairs from random attrition balance.
                state.Wardstone.RefillFull();
                int previousSeed = dungeon.Seed;
                dungeon.UseStairs();
                dungeon.UseStairs();
                if (floor + 1 < FloorThemes.Count)
                {
                    Check($"stairs generate floor {floor + 2} exactly once", state.Stratum == floor + 1
                        && dungeon.Seed != previousSeed && dungeon.Current.Id == 0 && !dungeon.Current.Completed);
                    Check("floor transition preserves party, recovery and recruitment state", ReferenceEquals(party, state.Party)
                        && ReferenceEquals(clock, state.Clock) && ReferenceEquals(recruits, state.Recruits));
                    dungeon.ResolveEvent(0, null);
                    dungeon.CloseEvent();
                }
            }
            Check("final stairs show the normal victory summary", run.Phase == RunPhase.RunEnd
                && state.Outcome == RunOutcome.Victory && !dungeon.Visible);
            run.NewRun();
            Check("new run returns to hero selection", run.State == null && run.Phase == RunPhase.HeroSelect);
            run.ConfirmParty(picks);
            Check("next run has a fresh first floor and party", run.State!.Stratum == 0
                && !ReferenceEquals(run.State.Party, party) && dungeon.Current.Id == 0);
            dungeon.ResolveEvent(0, null);
            dungeon.CloseEvent();
            while (!run.State.Wardstone.IsSpent) run.State.Wardstone.BurnShortRest();
            await Step(dungeon, dungeon.Current.Doors[0].Other(dungeon.Current.Id));
            Check("spent ward reaches the normal defeat summary", run.Phase == RunPhase.RunEnd
                && run.State.Outcome == RunOutcome.Defeat);
        }
        finally
        {
            run.QueueFree();
            Engine.TimeScale = oldScale;
        }
    }

    private static async Task Step(DungeonDirector dungeon, int destination)
    {
        int start = dungeon.Current.Id;
        var previous = new Dictionary<int, int> { [start] = start };
        var queue = new Queue<int>();
        queue.Enqueue(start);
        while (queue.TryDequeue(out int id))
            foreach (var door in dungeon.Floor.Rooms[id].Doors)
                if (previous.TryAdd(door.Other(id), id)) queue.Enqueue(door.Other(id));
        int next = destination;
        while (previous[next] != start) next = previous[next];
        var exit = dungeon.Current.Doors.First(d => d.Other(start) == next);
        await dungeon.Travel(exit.Side(start));
        if (dungeon.Current.Id == start && dungeon.Phase != DungeonPhase.End)
            throw new InvalidOperationException("Door travel did not reach its destination.");
    }

    private async Task Capture(string name)
    {
        if (DisplayServer.GetName() == "headless") return;
        await ToSignal(GetTree().CreateTimer(0.2), SceneTreeTimer.SignalName.Timeout);
        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        SaveViewportCapture($"res://.godot/{name}.png");
    }
}
