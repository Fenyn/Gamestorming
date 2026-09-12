using System.Collections.Generic;
using Delve.Autoload;
using Delve.Presets;
using Delve.Run;
using Godot;
using PF2e.Core;

namespace Delve.Flow;

public partial class RunDirector
{
    // ---------------------------------------------------------------- Combat

    private void StartFight(MapNode node)
    {
        var data = DataManager.Instance;
        _pendingRecruit = node.Kind == NodeKind.Meeting ? _state!.Recruits.Draw(_state.Party) : null;
        var setup = data == null
            ? null
            : EncounterFactory.Build(_state!, node, data.ResolveCreature, ally: _pendingRecruit?.Character);
        if (setup == null)
        {
            GD.PushError($"[RunDirector] Could not build the encounter for node {node.Id} - back to the map.");
            GoToMap();
            return;
        }

        if (_pendingRecruit is { } meeting)
        {
            _campaign.RecordMeeting(meeting.Id, _state!.Party.LeaderId);
            SaveCampaign();
        }
        _pendingXp = setup.XpAward;
        SetPhase(RunPhase.Combat);
        _combat.StartEncounter(setup);
        if (AutoPlayCombat)
            _combat.SetAllPlayerAi(true);
    }

    /// <summary>
    /// A fight ended. The wipe test reads the party BEFORE the stabilize step, which puts every
    /// downed member back on 1 HP - after it, nobody is ever wiped.
    /// </summary>
    private void OnEncounterFinished(BattleResult result)
    {
        if (_state == null || Phase != RunPhase.Combat) return;

        bool wiped = _state.Party.IsWiped;
        _combatWon = !wiped && result == BattleResult.Team1Wins;
        var rewards = new List<string>();
        if (_pendingRecruit is { } guest)
        {
            _state.Recruits.Resolve(guest.Id);
            if (!_combatWon || guest.Character.Health is { IsDead: true })
                _pendingRecruit = null;
            else PartyRecovery.CompleteEncounter(guest.Character);
        }
        PartyRecovery.CompleteEncounter(_state.Party, result);

        string progress = "";
        double fraction = 0;
        if (_combatWon)
        {
            RecordCampaignVictory();
            int xp = _pendingXp;
            int levelBefore = _state.Party.Level;
            AwardPendingXp();
            rewards.Add($"+{xp} party XP");
            if (_state.Party.Level > levelBefore)
                rewards.Add($"Level gained: {levelBefore} to {_state.Party.Level}");
            if (_pendingRecruit is { } survivor)
            {
                PresetCharacters.LevelUpInPlace(survivor.Character, _state.Party.Level);
                rewards.Add($"{survivor.Character.Name} survived. Choose whether to swap a companion next.");
            }
            if (_state.CurrentNode?.Kind == NodeKind.Boss)
            {
                int wardBefore = _state.Wardstone.Ward;
                _state.Wardstone.RefillFull();
                rewards.Add($"Wardstone restored: +{_state.Wardstone.Ward - wardBefore} ward");
            }
            bool atCap = _state.Party.Level >= _state.Leveling.MaxLevel;
            progress = atCap ? $"Party level {_state.Party.Level} - Maximum level"
                : $"Level {_state.Party.Level} - {_state.Xp} / {_state.Leveling.XpPerLevel} XP to next level";
            fraction = atCap ? 100 : 100.0 * _state.Xp / _state.Leveling.XpPerLevel;
        }
        else
        {
            _pendingXp = 0;
            rewards.Add("No combat rewards gained.");
        }
        _combat.ShowRewards(string.Join("\n", rewards), progress, fraction);
        SetPhase(RunPhase.CombatResults);
    }

    /// <summary>Rewards are already applied. Continue only advances the run, once.</summary>
    public void ContinueCombatResults()
    {
        if (_state == null || Phase != RunPhase.CombatResults) return;
        if (!_combatWon)
            EndRun(RunOutcome.Defeat);
        else if (_state.CurrentNode?.Kind == NodeKind.Boss)
        {
            if (_state.OnFinalStratum) EndRun(RunOutcome.Victory);
            else
            {
                _state.AdvanceStratum();
                GoToMap();
            }
        }
        else if (_pendingRecruit is { } guest)
        {
            _meetupPanel.Show(_state.Party, guest.Character);
            SetPhase(RunPhase.Meetup);
        }
        else GoToMap();
    }

    /// <summary>Accept the guest into one companion slot. Invalid choices leave the offer open.</summary>
    public void ReplaceCompanion(string outgoingId)
    {
        if (_state == null || Phase != RunPhase.Meetup || _pendingRecruit is not { } guest) return;
        if (!_state.Party.ReplaceCompanion(outgoingId, guest.Id, guest.Character)) return;
        _state.Recruits.Resolve(outgoingId);
        _pendingRecruit = null;
        GoToMap();
    }

    public void DeclineMeetup()
    {
        if (Phase != RunPhase.Meetup) return;
        _pendingRecruit = null;
        GoToMap();
    }

    /// <summary>Pay out the won fight's XP (stabilized party first) and level in place on a
    /// threshold cross. RAW award, accelerated threshold (design/core_concept.md "Run flow").</summary>
    private void AwardPendingXp()
    {
        if (_state == null || _pendingXp <= 0) return;
        int xp = _pendingXp;
        _pendingXp = 0;
        int gained = PartyLeveling.Award(_state, xp);
        if (gained > 0)
            GD.Print($"[RunDirector] +{xp} XP - the party reaches level {_state.Party.Level}.");
    }

}
