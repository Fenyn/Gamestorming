using System;
using System.Collections.Generic;
using System.Linq;
using Delve.Autoload;
using Delve.Combat;
using Delve.Flow;
using Delve.Presets;
using Delve.Run;
using Delve.Run.Events;
using Delve.Terrain;
using Godot;
using PF2e.Core;

namespace Delve.Dungeon;

public partial class DungeonDirector
{
    private void Enter(DoorSide entry)
    {
        Current.Discovered = true;
        RefreshVisibility();
        bool first = AnnounceEntry(entry);
        if (Current.Completed)
        {
            ShowDoors();
            return;
        }

        // Rooms that open a panel or a fight are named by it; the card names only quiet arrivals.
        if (Current.Id == Floor.EntranceId)
        {
            // The embark caption already states the goal. The hall adds the station's history.
            CompleteRoom();
            ShowDoors();
            if (first) _hud.ShowRoomCard(StationPlan.Name(Current.Purpose), StationPlan.Account(Floor.History));
            return;
        }

        switch (DungeonFloor.Kind(Current.Family))
        {
            case NodeKind.Boss when !Instant:
                _ = RevealRoster(_epoch, GuardianRevealSeconds, SignatureProp("ward_engine"));
                break;
            case NodeKind.Elite when !Instant && first:
                _ = RevealRoster(_epoch, LairRevealSeconds, null);
                break;
            case NodeKind.Combat:
            case NodeKind.Elite:
            case NodeKind.Boss:
                StartCombat(_encounters[Current.Id]);
                break;
            case NodeKind.Rest:
                // The night waits for the player: Make camp stays on the HUD while the refuge is unused.
                ShowDoors();
                if (first) _hud.ShowRoomCard(StationPlan.Name(Current.Purpose));
                break;
            default:
                var scene = DungeonEncounters.AtLevel(DungeonEncounters.StationEvent(Current, Floor.History), State.Party.Level);
                if (StationScenes.AppliesOnArrival(scene.Options))
                {
                    // A free scene with nothing to decide happens on arrival; Leave would only compete with it.
                    var result = EventResolver.Resolve(State, scene, 0, null);
                    CompleteRoom();
                    ShowDoors();
                    _hud.ShowRoomCard(StationPlan.Name(Current.Purpose), string.Join("  ", result.Lines));
                    break;
                }
                Phase = DungeonPhase.Event;
                _openEvent = scene;
                _event.Show(_openEvent, State);
                FrameEventScenery();
                RefreshHud();
                break;
        }
    }

    public void ResolveEvent(int index, PF2eCharacter? actor)
    {
        if (Phase != DungeonPhase.Event || _openEvent == null || Current.Resolved || _transition.Busy)
            return;
        var result = EventResolver.Resolve(State, _openEvent, index, actor);
        if (!result.Resolved)
        {
            _event.Show(_openEvent, State);
            return;
        }

        var option = _openEvent.Options[index];
        var outcome = result.Degree is { } degree ? EventResolver.OutcomeFor(option, degree) : option.Success;
        foreach (var reveal in outcome.Effects.Where(e => e.Kind == EventEffectKind.RevealKinds))
            RevealKinds(reveal.Value);
        FinishEvent(result);
        // Leaving a room says nothing the ward bar does not already show, so it needs no Continue.
        if (option.Check == null && outcome.Effects.All(e => e.Kind == EventEffectKind.WardDelta))
            CloseEvent();
    }

    /// <summary>Marks rooms as scouted for the floor plan. Reach 0: rooms next to this one;
    /// 1: rooms next to any visited room; 2: every room.</summary>
    private void RevealKinds(int reach)
    {
        foreach (var room in Floor.Rooms)
        {
            bool nearHere = room.Doors.Any(d => d.Other(room.Id) == Current.Id);
            bool nearVisited = room.Doors.Any(d => Floor.Rooms[d.Other(room.Id)].Discovered);
            if (reach >= 2 || (reach == 1 && nearVisited) || nearHere) room.Scouted = true;
        }
        RefreshHud();
    }

    /// <summary>One night in the refuge: long rest, a new day, the camp's ward, then the morning report.</summary>
    public void MakeCamp()
    {
        if (_details.Visible || Phase != DungeonPhase.Doors || Current.Family != RoomFamily.Camp || Current.Resolved || _transition.Busy)
            return;
        Phase = DungeonPhase.Event;
        RefreshHud();
        _fx.Rested();
        var before = PartyChangeSummary.Capture(State.Party);
        int ward = State.Wardstone.Ward;
        _ = _transition.Play("The fire burns low.\nThe party rests until morning.", () =>
        {
            PartyRecovery.LongRest(State.Party, State.Clock, wardstone: State.Wardstone);
            var figures = new List<FigureView>();
            if (CombatResults.Ward(ward, State.Wardstone.Ward) is { } pair) figures.Add(pair);
            if (StudyAtCamp() is { } journal) figures.Add(journal);
            Current.Resolved = true;
            CurrentView.SetResolved();
            _event.ShowReport($"Morning, day {State.Clock.Day}", figures, CombatResults.RestMembers(State.Party.Living(), before));
            RefreshHud();
        }, Instant);
    }

    private void FinishEvent(EventResult result)
    {
        Current.Resolved = true;
        CurrentView.SetResolved();
        _openEvent = null;
        _event.ShowResult(result);
        RefreshHud();
    }

    public void CloseEvent()
    {
        if (Phase != DungeonPhase.Event || !Current.Resolved || _transition.Busy)
            return;
        CompleteRoom();
        _event.Visible = false;
        ShowDoors();
    }

    private Dictionary<string, PartyMemberSnapshot> _fightStart = new();

    private void StartCombat(CombatSetup setup)
    {
        Phase = DungeonPhase.Combat;
        _fightStart = PartyChangeSummary.Capture(State.Party);
        _partyLayer.Visible = false;
        CurrentView.SetDoorsOpen(false, Instant);
        _camera.ProcessMode = ProcessModeEnum.Disabled;
        if (Hosted || _combat == null)
        {
            CombatRequested?.Invoke(setup);
            RefreshHud();
            return;
        }
        _combat.StartEncounter(setup, CurrentView.Heights);
        _combat.SetPresentationVisible(true);
        if (AutoPlayCombat)
            _combat.SetAllPlayerAi(true);
        RefreshHud();
    }

    private void FinishCombat(BattleResult result)
    {
        if (Phase != DungeonPhase.Combat || _combat == null)
            return;
        _won = !State.Party.IsWiped && result == BattleResult.Team1Wins;
        PartyRecovery.CompleteEncounter(State.Party, result);
        int xp = _won ? _encounters[Current.Id].XpAward : 0;
        int xpBefore = State.Xp, levelBefore = State.Party.Level;
        if (_won && !Current.Resolved)
        {
            PartyLeveling.Award(State, xp);
            Current.Resolved = true;
        }

        Phase = DungeonPhase.Results;
        if (!_won)
        {
            Callable.From(ContinueCombat).CallDeferred();
            return;
        }
        bool atCap = State.Party.Level >= State.Leveling.MaxLevel;
        _combat.ShowRewards(new CombatResultsView
        {
            Figures = CombatResults.Progress(xpBefore, State.Xp, levelBefore, State.Party.Level, atCap),
            Members = CombatResults.Members(State.Party.Members, _fightStart),
            Progress = atCap ? null : 100.0 * State.Xp / State.Leveling.XpPerLevel,
            Party = State.Party.Members,
        });
        RefreshHud();
    }

    public void ContinueCombat()
    {
        if (Phase != DungeonPhase.Results)
            return;
        _combat?.EndHostedEncounter();
        if (!_won)
        {
            End(false);
            return;
        }

        CompleteRoom();
        SpawnTravelParty(true);
        Frame();
        ShowDoors();
    }

    private void ShowDoors()
    {
        Phase = DungeonPhase.Doors;
        _camera.ProcessMode = ProcessModeEnum.Inherit;
        _camera.Camera.Current = true;
        _partyLayer.Visible = true;
        OpenShutters();
        _camera.FocusOn(new Vector3(CurrentView.Width / 2f, 0, CurrentView.Width / 2f), 0.3f, false);
        _focusedDoor = null;
        _announcedDoor = null;
        // Door keys (Tab, arrows, Enter) reach the room only while no button holds focus.
        if (IsInsideTree()) GetViewport().GuiReleaseFocus();
        RefreshHud();
    }

    private void FrameEventScenery()
    {
        // The event panel occupies the right third; move the room into the remaining view.
        var center = new Vector3(CurrentView.Width / 2f, 0, CurrentView.Width / 2f);
        _camera.FocusOn(center + _camera.Camera.GlobalBasis.X * CurrentView.Width * 0.3f, 0.3f, false);
    }

    private void OpenRest()
    {
        if (_details.Visible || Phase != DungeonPhase.Doors)
            return;
        Phase = DungeonPhase.Rest;
        _restUsed = false;
        _rest.Show(State);
        RefreshHud();
    }

    private void TakeRest(IReadOnlyList<RestAssignment> assignments)
    {
        if (Phase != DungeonPhase.Rest || _restUsed)
            return;
        int before = State.Wardstone.Ward;
        var party = PartyChangeSummary.Capture(State.Party);
        var result = ShortRest.PerformSchedule(State, assignments, new RecoveryRules(), _rest.UseFree);
        _restUsed = result.Performed;
        if (result.Performed) _fx.Rested();
        _rest.ShowResult(result, State, before, party);
        RefreshHud();
    }

}
