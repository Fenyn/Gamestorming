using System.Collections.Generic;
using System.Linq;
using Delve.Presets;

namespace Delve.Run;

public enum RecruitmentSignal { Meeting, PartyVictory, FloorBossVictory }

public sealed record RecruitmentStep(string Id, string Description, RecruitmentSignal Signal, int Required);
public sealed record RecruitmentArc(string CharacterId, string Title, IReadOnlyList<RecruitmentStep> Steps);

/// <summary>Initial playable recruitment arcs. Completion permits a separate outpost binding.</summary>
public static class RecruitmentCatalog
{
    public static readonly IReadOnlyList<RecruitmentArc> All = new[]
    {
        new RecruitmentArc(PresetCharacters.RavenId, "A contract worth keeping", new[]
        {
            new RecruitmentStep("meet", "Meet Raven in the delve.", RecruitmentSignal.Meeting, 1),
            new RecruitmentStep("trust", "Win three fights with Raven in the party.", RecruitmentSignal.PartyVictory, 3),
            new RecruitmentStep("bounty", "Defeat a floor boss with Raven in the party.", RecruitmentSignal.FloorBossVictory, 1),
        }),
        new RecruitmentArc(PresetCharacters.ThistleId, "A trail beyond routine", new[]
        {
            new RecruitmentStep("meet", "Find Thistle on the trail.", RecruitmentSignal.Meeting, 1),
            new RecruitmentStep("trail", "Win two fights with Thistle in the party.", RecruitmentSignal.PartyVictory, 2),
            new RecruitmentStep("horizon", "Open the next route with Thistle by defeating a floor boss.", RecruitmentSignal.FloorBossVictory, 1),
        }),
    }.Concat(BulwarkWayfarers.All.Select(spec => new RecruitmentArc(spec.Id, spec.ArcTitle, new[]
    {
        new RecruitmentStep("meet", $"Meet {spec.Name} in the delve.", RecruitmentSignal.Meeting, 1),
        new RecruitmentStep("trust", $"Win two fights with {spec.Name} in the party.", RecruitmentSignal.PartyVictory, 2),
        new RecruitmentStep("guardian", spec.PersonalGoal, RecruitmentSignal.FloorBossVictory, 1),
    }))).ToArray();

    public static RecruitmentArc? Find(string characterId)
    {
        foreach (var arc in All)
            if (arc.CharacterId == characterId) return arc;
        return null;
    }
}
