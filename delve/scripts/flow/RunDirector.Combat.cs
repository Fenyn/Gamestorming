using System.Collections.Generic;
using System.Linq;
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
            _campaign.RecordMeeting(meeting.Id, _state!.StoryCharacterId);
            SaveCampaign();
        }
        _pendingXp = setup.XpAward;
        _fightStart = PartyChangeSummary.Capture(_state!.Party);
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
        if (_pendingRecruit is { } guest)
        {
            _state.Recruits.Resolve(guest.Id);
            if (!_combatWon || guest.Character.Health is { IsDead: true })
                _pendingRecruit = null;
            else PartyRecovery.CompleteEncounter(guest.Character);
        }
        PartyRecovery.CompleteEncounter(_state.Party, result);
        if (!_combatWon)
        {
            // A defeat has no rewards to show: the run end is the one defeat screen. Deferred so the
            // session finishes unwinding before the host tears the encounter down.
            _pendingXp = 0;
            var state = _state;
            Callable.From(() =>
            {
                if (ReferenceEquals(state, _state) && Phase == RunPhase.Combat) EndRun(RunOutcome.Defeat);
            }).CallDeferred();
            return;
        }

        var notes = new List<string>();
        var campaignBefore = _campaign.Capture();
        RecordCampaignVictory();
        int xpBefore = _state.Xp, levelBefore = _state.Party.Level;
        AwardPendingXp();
        bool atCap = _state.Party.Level >= _state.Leveling.MaxLevel;
        var figures = CombatResults.Progress(xpBefore, _state.Xp, levelBefore, _state.Party.Level, atCap);
        if (_pendingRecruit is { } survivor)
        {
            PresetCharacters.LevelUpInPlace(survivor.Character, _state.Party.Level);
            notes.Add($"{survivor.Character.Name} survived. Choose whether to swap a companion next.");
        }
        if (_state.CurrentNode?.Kind == NodeKind.Boss)
        {
            int wardBefore = _state.Wardstone.Ward;
            var attune = WardAttunement.Roll(_state.Party, _state.Wardstone, GuardianLevel());
            if (attune != null) notes.Add($"{attune.Actor} attunes the Wardstone to the ward engine: {attune.Skill} {attune.Total} vs DC {attune.Dc}, "
                + $"{attune.Degree}. The stone regains {attune.RefillPercent}% of its missing ward.");
            if (CombatResults.Ward(wardBefore, _state.Wardstone.Ward) is { } ward) figures.Add(ward);
        }
        notes.AddRange(CampaignSummary.Gains(campaignBefore, _campaign));
        _combat.ShowRewards(new CombatResultsView
        {
            Figures = figures,
            Members = CombatResults.Members(_state.Party.Members, _fightStart),
            Notes = notes,
            Progress = atCap ? null : 100.0 * _state.Xp / _state.Leveling.XpPerLevel,
            Party = _state.Party.Members,
        });
        SetPhase(RunPhase.CombatResults);
    }

    /// <summary>Party HP and Wounded as the fight began. The results rows compare against it.</summary>
    private Dictionary<string, PartyMemberSnapshot> _fightStart = new();

    private bool _continuingCombat;

    /// <summary>Rewards are already applied. Continue only advances the run, once.</summary>
    public async void ContinueCombatResults()
    {
        if (_state == null || Phase != RunPhase.CombatResults || _continuingCombat) return;
        if (UseDungeonMap)
        {
            var state = _state;
            var pose = _combat.ActiveCamera.GlobalTransform;
            float fov = _combat.ActiveCamera.Fov;
            _combat.EndHostedEncounter();
            if (!_combatWon) { EndRun(RunOutcome.Defeat); return; }
            _continuingCombat = true;
            try { await _dungeon!.ReturnFromHostedCombat(pose, fov); }
            finally { _continuingCombat = false; }
            if (!IsInsideTree() || !ReferenceEquals(state, _state)) return;
            if (_pendingRecruit is { } recruit)
            {
                _meetupPanel.Show(_state.Party, recruit.Character);
                SetPhase(RunPhase.Meetup);
            }
            else GoToMap();
            return;
        }
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
        string outgoingName = _state.Party.Members.FirstOrDefault(m => m.Id == outgoingId)?.Name ?? outgoingId;
        if (!_state.Party.ReplaceCompanion(outgoingId, guest.Id, guest.Character)) return;
        _state.Recruits.Resolve(outgoingId);
        _pendingRecruit = null;
        GoToMap();
        _dungeon?.ShowPartyNotice($"{guest.Character.Name} joins this expedition. {outgoingName} heads back to the outpost.");
    }

    public void DeclineMeetup()
    {
        if (Phase != RunPhase.Meetup) return;
        string name = _pendingRecruit?.Character.Name ?? "The Wayfarer";
        _pendingRecruit = null;
        GoToMap();
        _dungeon?.ShowPartyNotice($"{name} parts ways with the party. Your meeting remains in the unlock journal.");
    }

    /// <summary>Pay out the won fight's XP (stabilized party first) and queue promotions on a
    /// threshold cross. RAW award, accelerated threshold (design/core_concept.md "Run flow").</summary>
    private void AwardPendingXp()
    {
        if (_state == null || _pendingXp <= 0) return;
        int xp = _pendingXp;
        _pendingXp = 0;
        int gained = PartyLeveling.Award(_state, xp);
        if (gained > 0)
            GD.Print($"[RunDirector] +{xp} XP - promotions earned through level {_state.Party.Level}.");
    }

}
