using System.Collections.Generic;
using System.Linq;
using Delve.Run;

namespace Delve.Flow;

public static class CampaignSummary
{
    public static string Describe(CampaignProgressData before, CampaignProgress campaign)
    {
        var lines = new List<string>();
        foreach (var arc in RecruitmentCatalog.All)
        {
            string name = CharacterCatalog.Find(arc.CharacterId)!.DisplayName;
            foreach (var step in arc.Steps)
            {
                int old = before.Recruitment.GetValueOrDefault($"{arc.CharacterId}/{step.Id}");
                int now = campaign.RecruitmentCount(arc.CharacterId, step.Id);
                if (now > old) lines.Add($"{name}: {step.Description} {now}/{step.Required}");
            }
            if (campaign.CanBindAtOutpost(arc.CharacterId))
                lines.Add($"{name} is ready to join. Invite them to stay through the outpost's unlock journal.");
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
        return lines.Count == 0 ? "Campaign progress carries between expeditions." :
            "Campaign progress retained\n" + string.Join("\n", lines);
    }
}
