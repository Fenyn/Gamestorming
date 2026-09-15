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
        if (Current.Completed)
        {
            ShowDoors();
            return;
        }

        switch (DungeonFloor.Kind(Current.Family))
        {
            case NodeKind.Combat:
            case NodeKind.Elite:
            case NodeKind.Boss:
                StartCombat(_encounters[Current.Id]);
                break;
            case NodeKind.Rest:
                Phase = DungeonPhase.Event;
                _openEvent = new EventDefinition
                {
                    Id = "dungeon-camp",
                    Title = "A sheltered camp",
                    Body = $"Dry bedrolls surround a protected fire pit. Rest here once to recover some HP, clear Wounded, and restore spell slots and focus. A new day begins and the Wardstone regains up to {State.Wardstone.Rules.CampsiteRefill} ward.",
                    Options = new[]
                    {
                        new EventOption
                        {
                            Label = "Make camp",
                            Success = EventOutcome.Nothing("The party rests and prepares for the way ahead.")
                        }
                    }
                };
                _event.Show(_openEvent, State);
                FrameEventScenery();
                RefreshHud();
                break;
            default:
                Phase = DungeonPhase.Event;
                _openEvent = DungeonEncounters.StationEvent(Current, Floor.History);
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

        if (Current.Family == RoomFamily.Camp)
        {
            var before = PartyChangeSummary.Capture(State.Party);
            int ward = State.Wardstone.Ward;
            _ = _transition.Play("The fire burns low.\nThe party rests until morning.", () =>
            {
                PartyRecovery.LongRest(State.Party, State.Clock, wardstone: State.Wardstone);
                var lines = new List<string> { $"Morning, day {State.Clock.Day}. Ward restored: +{State.Wardstone.Ward - ward}." };
                lines.AddRange(PartyChangeSummary.Overnight(State.Party, before));
                FinishEvent(new EventResult { Resolved = true, Lines = lines });
            }, AutoPlayCombat);
            return;
        }
        FinishEvent(result);
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
        Current.Completed = true;
        _event.Visible = false;
        ShowDoors();
    }

    private void StartCombat(CombatSetup setup)
    {
        Phase = DungeonPhase.Combat;
        _partyLayer.Visible = false;
        CurrentView.SetDoorsOpen(false);
        _camera.ProcessMode = ProcessModeEnum.Disabled;
        if (Hosted)
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
        if (Phase != DungeonPhase.Combat)
            return;
        _won = !State.Party.IsWiped && result == BattleResult.Team1Wins;
        PartyRecovery.CompleteEncounter(State.Party, result);
        int xp = _won ? _encounters[Current.Id].XpAward : 0;
        if (_won && !Current.Resolved)
        {
            PartyLeveling.Award(State, xp);
            Current.Resolved = true;
        }

        _combat.ShowResultParty(_won ? State.Party.Members : Array.Empty<PF2eCharacter>());
        string promotion = CharacterPromotion.HasPending(State.Party) ? "\nPromotion available. Open a character sheet to choose a feat." : "";
        _combat.ShowRewards(_won ? $"+{xp} party XP{promotion}" : "The expedition has fallen.", $"Ward {State.Wardstone.Ward}", 0);
        Phase = DungeonPhase.Results;
        RefreshHud();
    }

    public void ContinueCombat()
    {
        if (Phase != DungeonPhase.Results)
            return;
        _combat.EndHostedEncounter();
        if (!_won)
        {
            End(false);
            return;
        }

        Current.Completed = true;
        CurrentView.SetResolved();
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
        CurrentView.SetDoorsOpen(true);
        _camera.FocusOn(new Vector3(CurrentView.Width / 2f, 0, CurrentView.Width / 2f), 0.3f, false);
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
        var result = ShortRest.PerformSchedule(State.Party, State.Clock, assignments, new RecoveryRules(), State.Wardstone);
        _restUsed = result.Performed;
        _rest.ShowResult(result, State, before);
        RefreshHud();
    }

}
