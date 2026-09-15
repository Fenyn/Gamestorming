using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Dungeon;
using Delve.Run;
using Godot;

namespace Delve.Dev;
/// <summary>Walk the actual scene through encounters, camp, guardian results, and the stairs.</summary>
public partial class DungeonFlowSpike : SpikeBase
{
    [Export]
    public PackedScene TestScene { get; set; } = null!;

    protected override async Task RunSpikeAsync(DataManager data)
    {
        var host = TestScene.Instantiate<DungeonDirector>();
        host.Seed = 137;
        host.AutoPlayCombat = true;
        host.CombatAiDelay = 0;
        host.TravelSecondsPerTile = 0.001f;
        double oldScale = Engine.TimeScale;
        Engine.TimeScale = 8;
        AddChild(host);
        try
        {
            host.UseStairs();
            Check("stairs cannot skip the floor", host.Phase == DungeonPhase.Event);
            int encounters = 0;
            while (host.Current.Id != host.Floor.GuardianId || !host.Current.Completed)
            {
                if (host.Phase == DungeonPhase.Event)
                {
                    host.ResolveEvent(0, null);
                    host.CloseEvent();
                }

                if (host.Phase == DungeonPhase.Combat)
                {
                    var deadline = DateTime.UtcNow.AddSeconds(120);
                    while (host.Phase == DungeonPhase.Combat && DateTime.UtcNow < deadline)
                        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
                    Check("fight reaches results", host.Phase == DungeonPhase.Results);
                    if (host.Phase != DungeonPhase.Results)
                        return;
                    host.ContinueCombat();
                    encounters++;
                }

                if (host.Phase == DungeonPhase.End)
                {
                    Check("party survives the selected test route", false);
                    return;
                }

                if (host.Current.Id == host.Floor.GuardianId && host.Current.Completed)
                    break;
                Check("resolved room offers doors", host.Phase == DungeonPhase.Doors);
                if (host.Phase != DungeonPhase.Doors)
                    return;
                int next = NextTowardGuardian(host);
                var door = host.Current.Doors.First(d => d.Other(host.Current.Id) == next);
                await host.Travel(door.Side(host.Current.Id));
                Check("door reaches its destination", host.Current.Id == next);
                if (host.Current.Id != next)
                    return;
            }

            Check("route includes real combat", encounters > 0);
            Check("guardian is complete and waits for stairs", host.Current.Family == RoomFamily.Guardian && host.Phase == DungeonPhase.Doors);
            Check("camp resolved on the approach", host.Floor.Rooms[10].Completed);
            host.UseStairs();
            host.UseStairs();
            Check("stairs finish the isolated floor once", host.State.Outcome == RunOutcome.Victory && host.Phase == DungeonPhase.End);
        }
        finally
        {
            host.QueueFree();
            Engine.TimeScale = oldScale;
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        }
    }

    private static int NextTowardGuardian(DungeonDirector host)
    {
        int start = host.Current.Id;
        var previous = new Dictionary<int, int>
        {
            {
                start,
                start
            }
        };
        var queue = new Queue<int>();
        queue.Enqueue(start);
        while (queue.TryDequeue(out int id))
        {
            if (id == host.Floor.GuardianId)
                break;
            foreach (var d in host.Floor.Rooms[id].Doors)
            {
                int next = d.Other(id);
                if (previous.TryAdd(next, id))
                    queue.Enqueue(next);
            }
        }

        int step = host.Floor.GuardianId;
        while (previous[step] != start)
            step = previous[step];
        return step;
    }
}
