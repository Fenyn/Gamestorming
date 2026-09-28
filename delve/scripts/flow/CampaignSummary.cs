using System.Collections.Generic;
using System.Linq;
using Delve.Run;

namespace Delve.Flow;

public static class CampaignSummary
{
    public static string Describe(CampaignProgressData before, CampaignProgress campaign)
    {
        var lines = Gains(before, campaign);
        foreach (var arc in RecruitmentCatalog.All)
            if (campaign.CanBindAtOutpost(arc.CharacterId))
                lines.Add($"{CharacterCatalog.Find(arc.CharacterId)!.DisplayName} is ready to join. Invite them to stay through the outpost's unlock journal.");
        return lines.Count == 0 ? "Campaign progress carries between expeditions." :
            "Campaign progress retained\n" + string.Join("\n", lines);
    }

    /// <summary>Recruitment steps, personal objectives and outpost milestones gained since <paramref name="before"/>.</summary>
    public static List<string> Gains(CampaignProgressData before, CampaignProgress campaign)
    {
        var lines = new List<string>();
        foreach (var arc in RecruitmentCatalog.All)
            foreach (var step in arc.Steps)
            {
                int old = before.Recruitment.GetValueOrDefault($"{arc.CharacterId}/{step.Id}");
                int now = campaign.RecruitmentCount(arc.CharacterId, step.Id);
                if (now > old) lines.Add(step.Required > 1 ? $"{step.Description} ({now} of {step.Required})" : $"{step.Description} Done.");
            }
        var after = campaign.Capture();
        foreach (var (id, objectives) in after.Personal)
        {
            var objective = PersonalObjectiveCatalog.Find(id);
            if (objective != null && objectives.Contains(objective.Id)
                && !before.Personal.GetValueOrDefault(id, System.Array.Empty<string>()).Contains(objective.Id))
                lines.Add($"{CharacterCatalog.Find(id)?.DisplayName}: {objective.Description} Complete.");
        }
        if (after.Outpost.Contains("defeated-floor-boss") && !before.Outpost.Contains("defeated-floor-boss"))
            lines.Add("Outpost milestone: defeated a floor guardian.");
        return lines;
    }
}
