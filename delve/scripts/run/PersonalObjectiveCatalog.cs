using System.Collections.Generic;
using Delve.Presets;

namespace Delve.Run;

public sealed record PersonalObjective(string Id, string Description, RecruitmentSignal Signal);

/// <summary>First personal milestones. Narrative quests and weighted encounter hooks extend this table.</summary>
public static class PersonalObjectiveCatalog
{
    private static readonly IReadOnlyDictionary<string, PersonalObjective> ByCharacter =
        new Dictionary<string, PersonalObjective>
        {
            [PresetCharacters.PlayerId] = new("hold-the-route", "Help the party defeat a floor boss.", RecruitmentSignal.FloorBossVictory),
            [PresetCharacters.ElaraId] = new("new-contacts", "Meet a new Wayfarer.", RecruitmentSignal.Meeting),
            [PresetCharacters.TharrId] = new("restore-the-watch", "Help defeat a floor boss for the outpost.", RecruitmentSignal.FloorBossVictory),
            [PresetCharacters.FenwickId] = new("field-research", "Win a combat encounter with the party.", RecruitmentSignal.PartyVictory),
            [PresetCharacters.RavenId] = new("lead-the-contract", "Help defeat a floor boss.", RecruitmentSignal.FloorBossVictory),
            [PresetCharacters.ThistleId] = new("a-new-trail", "Meet a Wayfarer.", RecruitmentSignal.Meeting),
        };

    public static PersonalObjective? Find(string characterId) => ByCharacter.GetValueOrDefault(characterId)
        ?? (BulwarkWayfarers.Find(characterId) is { } spec
            ? new PersonalObjective("face-the-guardian", spec.PersonalGoal, RecruitmentSignal.FloorBossVictory) : null);
}
