using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Presets;
using Delve.Run;

namespace Delve.Dev;

public partial class CampaignProgressSpike : SpikeBase
{
    protected override Task RunSpikeAsync(DataManager data)
    {
        var campaign = new CampaignProgress();
        Check("four starter unlocks", campaign.Unlocks.UnlockedIds.Count == Party.MaxSize);
        Check("guests locked", !campaign.Unlocks.IsUnlocked(PresetCharacters.RavenId)
            && !campaign.Unlocks.IsUnlocked(PresetCharacters.ThistleId));
        Check("no early binding", !campaign.BindAtOutpost(PresetCharacters.RavenId));
        campaign.RecordMeeting(PresetCharacters.RavenId, PresetCharacters.ElaraId);
        Check("meeting does not unlock", !campaign.Unlocks.IsUnlocked(PresetCharacters.RavenId));
        Check("meeting fulfills Elara focus", campaign.HasPersonalProgress(PresetCharacters.ElaraId, "new-contacts"));
        Check("personal focus does not transfer", !campaign.HasPersonalProgress(PresetCharacters.PlayerId, "new-contacts"));
        string[] party = { PresetCharacters.PlayerId, PresetCharacters.RavenId, PresetCharacters.TharrId, PresetCharacters.FenwickId };
        campaign.RecordVictory("run-a/1", PresetCharacters.PlayerId, party, false);
        campaign.RecordVictory("run-a/1", PresetCharacters.PlayerId, party, false);
        Check("victory credited once", campaign.RecruitmentCount(PresetCharacters.RavenId, "trust") == 1);
        campaign.BeginRun();
        Check("new run retains shared progress", campaign.RecruitmentCount(PresetCharacters.RavenId, "trust") == 1);
        campaign.RecordVictory("run-b/1", PresetCharacters.TharrId, party, true);
        Check("recruitment shared across story anchors", campaign.RecruitmentCount(PresetCharacters.RavenId, "trust") == 2);
        Check("shared outpost progress", campaign.HasOutpostProgress("defeated-floor-boss"));
        Check("only selected story character earned focus", campaign.HasPersonalProgress(PresetCharacters.TharrId, "restore-the-watch")
            && !campaign.HasPersonalProgress(PresetCharacters.PlayerId, "hold-the-route"));
        Check("boss alone insufficient", !campaign.CanBindAtOutpost(PresetCharacters.RavenId));
        campaign.RecordVictory("run-b/2", PresetCharacters.TharrId, party, false);
        Check("requirements enable explicit stay", campaign.CanBindAtOutpost(PresetCharacters.RavenId)
            && !campaign.Unlocks.IsUnlocked(PresetCharacters.RavenId));

        string path = Path.Combine(Path.GetTempPath(), $"delve-campaign-spike-{Guid.NewGuid():N}.json");
        try
        {
            CampaignProgressStore.Save(path, campaign);
            var loaded = CampaignProgressStore.Load(path);
            Check("progress survives file roundtrip", loaded.CanBindAtOutpost(PresetCharacters.RavenId)
                && loaded.HasPersonalProgress(PresetCharacters.TharrId, "restore-the-watch"));
            Check("explicit overnight binds", loaded.BindAtOutpost(PresetCharacters.RavenId));
            Check("binding is idempotent", !loaded.BindAtOutpost(PresetCharacters.RavenId));
            CampaignProgressStore.Save(path, loaded);
            Check("unlock survives next load", CampaignProgressStore.Load(path).Unlocks.IsUnlocked(PresetCharacters.RavenId));
        }
        finally { if (File.Exists(path)) File.Delete(path); }

        CheckTown();

        foreach (var definition in CharacterCatalog.All.Where(definition => !definition.StartsUnlocked))
        {
            var character = definition.Builder(2);
            PresetCharacters.LevelUpInPlace(character, 3);
            Check($"{definition.DisplayName} identity survives level-up", character.Id == definition.Id && character.Stats?.Level == 3);
        }
        return Task.CompletedTask;
    }

    /// <summary>Town tier and camp time: defaults, growth, the day's cycle, the save, and a version 2 save.</summary>
    private void CheckTown()
    {
        var campaign = new CampaignProgress();
        Check("a new campaign is a morning camp", campaign.TownTier == TownTier.Camp && campaign.CampTime == CampTimeOfDay.Morning);
        Check("a floor boss alone does not grow the town", RecordBoss(campaign).TownTier == TownTier.Camp);
        Check("upgrading to the hamlet records the outpost too", campaign.UpgradeTown(TownTier.Hamlet)
            && campaign.TownTier == TownTier.Hamlet && campaign.HasOutpostProgress(TownMilestones.Outpost));
        Check("the town never shrinks", !campaign.UpgradeTown(TownTier.Outpost) && campaign.TownTier == TownTier.Hamlet);
        campaign.AdvanceCampTime();
        Check("a run end moves the camp to afternoon", campaign.CampTime == CampTimeOfDay.Afternoon);
        campaign.AdvanceCampTime();
        campaign.AdvanceCampTime();
        Check("evening turns back to morning", campaign.CampTime == CampTimeOfDay.Morning);
        campaign.AdvanceCampTime();

        string path = Path.Combine(Path.GetTempPath(), $"delve-town-spike-{Guid.NewGuid():N}.json");
        try
        {
            CampaignProgressStore.Save(path, campaign);
            var loaded = CampaignProgressStore.Load(path);
            Check("tier and time survive the save", loaded.TownTier == TownTier.Hamlet && loaded.CampTime == CampTimeOfDay.Afternoon);
            File.WriteAllText(path, "{\"Version\":2,\"UnlockedIds\":[],\"Recruitment\":{},\"Personal\":{},\"Outpost\":[\"defeated-floor-boss\"]}");
            var legacy = CampaignProgressStore.Load(path);
            Check("a version 2 save loads as a morning camp", legacy.CampTime == CampTimeOfDay.Morning && legacy.TownTier == TownTier.Camp
                && legacy.HasOutpostProgress("defeated-floor-boss"));
        }
        finally { if (File.Exists(path)) File.Delete(path); }
    }

    private static CampaignProgress RecordBoss(CampaignProgress campaign)
    {
        campaign.RecordVictory("town/boss", PresetCharacters.PlayerId, new[] { PresetCharacters.PlayerId }, true);
        return campaign;
    }
}
