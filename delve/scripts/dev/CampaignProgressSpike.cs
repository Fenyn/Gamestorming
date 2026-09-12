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
        Check("recruitment shared across leaders", campaign.RecruitmentCount(PresetCharacters.RavenId, "trust") == 2);
        Check("shared outpost progress", campaign.HasOutpostProgress("defeated-floor-boss"));
        Check("only active leader earned focus", campaign.HasPersonalProgress(PresetCharacters.TharrId, "restore-the-watch")
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

        foreach (var definition in CharacterCatalog.All.Where(definition => !definition.StartsUnlocked))
        {
            var character = definition.Builder(2);
            PresetCharacters.LevelUpInPlace(character, 3);
            Check($"{definition.DisplayName} identity survives level-up", character.Id == definition.Id && character.Stats?.Level == 3);
        }
        return Task.CompletedTask;
    }
}
