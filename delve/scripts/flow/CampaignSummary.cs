using System.Collections.Generic;
using System.Linq;
using Delve.Run;

namespace Delve.Flow;

/// <summary>One line of campaign progress: who it concerns ("Raven", "Outpost"), what happened, and
/// how far along it is ("Done", "3 of 3", "Ready").</summary>
public sealed record CampaignLine(string Who, string What, string Status = "")
{
    /// <summary>The line as one sentence, for the victory notes: "Raven: Meet Raven in the delve. Done."</summary>
    public string Sentence => $"{Who}: {What.TrimEnd('.')}" + (Status.Length == 0 ? "" : $" · {Status}");
}

public static class CampaignSummary
{
    public const string Done = "Done";
    public const string Ready = "Ready";
    public const string Milestone = "Milestone";
    public const string OutpostWho = "Outpost";
    public const string ReadyToJoin = "All objectives complete";

    /// <summary>What the expedition gained for the campaign, then every recruit now ready to join.</summary>
    public static List<CampaignLine> Describe(CampaignProgressData before, CampaignProgress campaign)
    {
        var lines = Lines(before, campaign);
        foreach (var arc in RecruitmentCatalog.All)
            if (campaign.CanBindAtOutpost(arc.CharacterId))
                lines.Add(new CampaignLine(CharacterCatalog.Find(arc.CharacterId)!.DisplayName, ReadyToJoin, Ready));
        return lines;
    }

    /// <summary>Recruitment steps, personal objectives and outpost milestones gained since <paramref name="before"/>.</summary>
    public static List<CampaignLine> Lines(CampaignProgressData before, CampaignProgress campaign)
    {
        var lines = new List<CampaignLine>();
        foreach (var arc in RecruitmentCatalog.All)
        {
            string who = CharacterCatalog.Find(arc.CharacterId)?.DisplayName ?? arc.CharacterId;
            foreach (var step in arc.Steps)
            {
                int old = before.Recruitment.GetValueOrDefault($"{arc.CharacterId}/{step.Id}");
                int now = campaign.RecruitmentCount(arc.CharacterId, step.Id);
                if (now > old) lines.Add(new CampaignLine(who, step.Description, step.Required > 1 ? $"{now} of {step.Required}" : Done));
            }
        }
        var after = campaign.Capture();
        foreach (var (id, objectives) in after.Personal)
        {
            var objective = PersonalObjectiveCatalog.Find(id);
            if (objective != null && objectives.Contains(objective.Id)
                && !before.Personal.GetValueOrDefault(id, System.Array.Empty<string>()).Contains(objective.Id))
                lines.Add(new CampaignLine(CharacterCatalog.Find(id)?.DisplayName ?? id, objective.Description, Done));
        }
        if (after.Outpost.Contains("defeated-floor-boss") && !before.Outpost.Contains("defeated-floor-boss"))
            lines.Add(new CampaignLine(OutpostWho, "Floor guardian defeated", Milestone));
        return lines;
    }

    /// <summary>The gains as sentences, for the victory screen's notes.</summary>
    public static List<string> Gains(CampaignProgressData before, CampaignProgress campaign)
        => Lines(before, campaign).Select(line => line.Sentence).ToList();
}
