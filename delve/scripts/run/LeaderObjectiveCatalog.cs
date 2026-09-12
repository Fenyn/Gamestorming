using System.Collections.Generic;
using Delve.Presets;

namespace Delve.Run;

public sealed record LeaderObjective(string Id, string Description, RecruitmentSignal Signal);

/// <summary>First personal milestones. Narrative quests and weighted encounter hooks extend this table.</summary>
public static class LeaderObjectiveCatalog
{
    private static readonly IReadOnlyDictionary<string, LeaderObjective> ByLeader =
        new Dictionary<string, LeaderObjective>
        {
            [PresetCharacters.PlayerId] = new("hold-the-route", "Lead the party past a floor boss.", RecruitmentSignal.FloorBossVictory),
            [PresetCharacters.ElaraId] = new("new-contacts", "Lead an expedition that meets a new Wayfarer.", RecruitmentSignal.Meeting),
            [PresetCharacters.TharrId] = new("restore-the-watch", "Lead the party to defeat a floor boss for the outpost.", RecruitmentSignal.FloorBossVictory),
            [PresetCharacters.FenwickId] = new("field-research", "Lead the party to a combat victory.", RecruitmentSignal.PartyVictory),
            [PresetCharacters.RavenId] = new("lead-the-contract", "Lead the party to defeat a floor boss.", RecruitmentSignal.FloorBossVictory),
            [PresetCharacters.ThistleId] = new("a-new-trail", "Lead an expedition that meets a Wayfarer.", RecruitmentSignal.Meeting),
        };

    public static LeaderObjective? Find(string characterId) => ByLeader.GetValueOrDefault(characterId);
}
