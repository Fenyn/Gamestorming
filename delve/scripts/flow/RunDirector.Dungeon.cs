using System.Linq;
using Delve.Combat;
using Delve.Dungeon;
using Delve.Run;
using Godot;
using PF2e.MapGen;

namespace Delve.Flow;

public partial class RunDirector
{
    [Export] public bool UseDungeonMap { get; set; }
    [Export] public PackedScene? DungeonScene { get; set; }
    public DungeonDirector? Dungeon => _dungeon;
    private DungeonDirector? _dungeon;

    private void BuildDungeon()
    {
        if (!UseDungeonMap) return;
        _dungeon = DungeonScene!.Instantiate<DungeonDirector>();
        _dungeon.Hosted = true;
        _dungeon.AutoPlayCombat = AutoPlayCombat;
        AddChild(_dungeon);
        _dungeon.CombatRequested += StartDungeonCombat;
        _dungeon.FloorCompleted += DescendDungeon;
        _dungeon.RunEnded += EndRun;
    }

    private void StartDungeonFloor()
    {
        var floor = DungeonFloor.Generate(_state!.StratumSeed);
        // A Wayfarer can occupy an ordinary fight room, preserving campaign recruitment.
        var meeting = floor.Map.Nodes.First(n => n.Kind == NodeKind.Combat);
        meeting.Kind = NodeKind.Meeting;
        _state.ReplaceMap(floor.Map);
        SetPhase(RunPhase.Map);
        _dungeon!.BeginFloor(_state, floor, _state.StratumSeed);
    }

    private void DescendDungeon()
    {
        if (_state == null || Phase != RunPhase.Map || _dungeon?.Phase != DungeonPhase.End) return;
        if (_transition.Busy) return;
        bool final = _state.OnFinalStratum;
        _ = PlayRunTransition(final ? "The last guardian has fallen.\nThe expedition is complete."
            : $"Descending to floor {_state.Stratum + 2}\nFind the next ward chamber.", () =>
        {
            if (final) EndRun(RunOutcome.Victory);
            else { _state.AdvanceStratum(); StartDungeonFloor(); }
        });
    }

    private void StartDungeonCombat(CombatSetup setup)
    {
        if (_state == null || _dungeon == null) return;
        _pendingRecruit = _state.CurrentNode?.Kind == NodeKind.Meeting ? _state.Recruits.Draw(_state.Party) : null;
        if (_pendingRecruit is { } guest)
        {
            var anchors = DeploymentPlanner.GetAnchors(setup.Layout!, 0, setup.Party.Count + 1);
            for (int i = 0; i < setup.Party.Count; i++)
                setup.Party[i] = (setup.Party[i].Unit, EncounterSpawner.AnchorAt(anchors, i));
            setup.Allies.Add((guest.Character, EncounterSpawner.AnchorAt(anchors, setup.Party.Count)));
            _campaign.RecordMeeting(guest.Id, _state.StoryCharacterId);
            SaveCampaign();
        }
        _pendingXp = setup.XpAward;
        SetPhase(RunPhase.Combat);
        _combat.AiActionDelaySeconds = _dungeon.CombatAiDelay;
        _combat.StartEncounter(setup, _dungeon.CurrentView.Heights);
        if (AutoPlayCombat) _combat.SetAllPlayerAi(true);
    }
}
