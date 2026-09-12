using System;
using System.Collections.Generic;
using System.Linq;

namespace Delve.Run;

/// <summary>Save-wide recruitment and outpost progress, with independent personal leader journals.</summary>
public sealed class CampaignProgress
{
    private readonly Dictionary<string, int> _recruitment = new();
    private readonly Dictionary<string, HashSet<string>> _personal = new();
    private readonly HashSet<string> _outpost = new();
    private readonly HashSet<string> _recordedEncounters = new();

    public UnlockState Unlocks { get; } = new();

    /// <summary>There is no run resume yet; only current-run encounter deduplication is needed.</summary>
    public void BeginRun() => _recordedEncounters.Clear();

    public int RecruitmentCount(string characterId, string stepId) =>
        _recruitment.GetValueOrDefault($"{characterId}/{stepId}");

    public bool HasPersonalProgress(string leaderId, string objectiveId) =>
        _personal.TryGetValue(leaderId, out var objectives) && objectives.Contains(objectiveId);

    public bool HasOutpostProgress(string objectiveId) => _outpost.Contains(objectiveId);

    public bool RecordPersonalProgress(string leaderId, string objectiveId)
    {
        if (CharacterCatalog.Find(leaderId) == null || string.IsNullOrWhiteSpace(objectiveId)) return false;
        if (!_personal.TryGetValue(leaderId, out var objectives))
            _personal.Add(leaderId, objectives = new HashSet<string>());
        return objectives.Add(objectiveId);
    }

    public bool RecordOutpostProgress(string objectiveId) =>
        !string.IsNullOrWhiteSpace(objectiveId) && _outpost.Add(objectiveId);

    public void RecordMeeting(string characterId, string leaderId)
    {
        if (CharacterCatalog.Find(characterId) == null) return;
        ApplySignal(characterId, RecruitmentSignal.Meeting);
        RecordPersonalProgress(leaderId, $"met/{characterId}");
        ApplyLeaderSignal(leaderId, RecruitmentSignal.Meeting);
    }

    /// <summary>Encounter keys include a unique run id and node id, so replays cannot award twice.</summary>
    public void RecordVictory(string encounterKey, string leaderId, IEnumerable<string> partyIds, bool floorBoss)
    {
        if (string.IsNullOrWhiteSpace(encounterKey) || !_recordedEncounters.Add(encounterKey)) return;
        ApplyLeaderSignal(leaderId, RecruitmentSignal.PartyVictory);
        foreach (string id in partyIds.Distinct())
        {
            // Fighting beside a guest is not membership. Only the supplied four party ids count.
            ApplySignal(id, RecruitmentSignal.PartyVictory);
            if (floorBoss) ApplySignal(id, RecruitmentSignal.FloorBossVictory);
        }
        if (floorBoss)
        {
            RecordPersonalProgress(leaderId, "defeated-floor-boss");
            ApplyLeaderSignal(leaderId, RecruitmentSignal.FloorBossVictory);
            RecordOutpostProgress("defeated-floor-boss");
        }
    }

    public bool CanBindAtOutpost(string characterId)
    {
        var arc = RecruitmentCatalog.Find(characterId);
        return arc != null && !Unlocks.IsUnlocked(characterId)
            && arc.Steps.All(step => RecruitmentCount(characterId, step.Id) >= step.Required);
    }

    /// <summary>Call only from an explicit overnight stay at the outpost, never from a meetup swap.</summary>
    public bool BindAtOutpost(string characterId) => CanBindAtOutpost(characterId) && Unlocks.Unlock(characterId);

    private void ApplyLeaderSignal(string leaderId, RecruitmentSignal signal)
    {
        if (LeaderObjectiveCatalog.Find(leaderId) is { } objective && objective.Signal == signal)
            RecordPersonalProgress(leaderId, objective.Id);
    }

    private void ApplySignal(string characterId, RecruitmentSignal signal)
    {
        var arc = RecruitmentCatalog.Find(characterId);
        if (arc == null || Unlocks.IsUnlocked(characterId)) return;
        if (signal != RecruitmentSignal.Meeting && RecruitmentCount(characterId, "meet") == 0) return;
        foreach (var step in arc.Steps.Where(step => step.Signal == signal))
        {
            string key = $"{characterId}/{step.Id}";
            _recruitment[key] = Math.Min(step.Required, _recruitment.GetValueOrDefault(key) + 1);
        }
    }

    public CampaignProgressData Capture() => new()
    {
        UnlockedIds = Unlocks.UnlockedIds.ToArray(),
        Recruitment = new Dictionary<string, int>(_recruitment),
        Personal = _personal.ToDictionary(pair => pair.Key, pair => pair.Value.ToArray()),
        Outpost = _outpost.ToArray(),
    };

    public static CampaignProgress Restore(CampaignProgressData data)
    {
        if (data.Version != CampaignProgressData.CurrentVersion)
            throw new ArgumentException($"Unsupported campaign version {data.Version}.", nameof(data));
        var result = new CampaignProgress();
        foreach (string id in data.UnlockedIds ?? Array.Empty<string>()) result.Unlocks.Unlock(id);
        foreach (var arc in RecruitmentCatalog.All)
            foreach (var step in arc.Steps)
            {
                string key = $"{arc.CharacterId}/{step.Id}";
                result._recruitment[key] = Math.Clamp(data.Recruitment?.GetValueOrDefault(key) ?? 0, 0, step.Required);
            }
        foreach (var entry in data.Personal ?? new())
            foreach (string objective in entry.Value ?? Array.Empty<string>()) result.RecordPersonalProgress(entry.Key, objective);
        foreach (string objective in data.Outpost ?? Array.Empty<string>()) result.RecordOutpostProgress(objective);
        return result;
    }
}

public sealed class CampaignProgressData
{
    public const int CurrentVersion = 1;
    public int Version { get; set; } = CurrentVersion;
    public string[] UnlockedIds { get; set; } = Array.Empty<string>();
    public Dictionary<string, int> Recruitment { get; set; } = new();
    public Dictionary<string, string[]> Personal { get; set; } = new();
    public string[] Outpost { get; set; } = Array.Empty<string>();
}
