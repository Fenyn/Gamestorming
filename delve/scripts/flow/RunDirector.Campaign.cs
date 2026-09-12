using System;
using System.IO;
using System.Linq;
using System.Text.Json;
using Delve.Run;
using Godot;

namespace Delve.Flow;

/// <summary>Campaign persistence and authored recruitment signals at run boundaries.</summary>
public partial class RunDirector
{
    [Export] public string CampaignSavePath { get; set; } = "";
    private CampaignProgress _campaign = new();
    private string _runId = "";
    private bool _campaignSaveFailed;

    public CampaignProgress Campaign => _campaign;

    private void LoadCampaign()
    {
        if (AutoPlayCombat || string.IsNullOrWhiteSpace(CampaignSavePath)) return;
        try { _campaign = CampaignProgressStore.Load(ProjectSettings.GlobalizePath(CampaignSavePath)); }
        catch (Exception exception) when (exception is IOException or UnauthorizedAccessException or JsonException or ArgumentException)
        {
            // Keep the unreadable file intact. A later save must not overwrite it with empty progress.
            _campaignSaveFailed = true;
            GD.PushWarning($"[RunDirector] Campaign could not be loaded: {exception.Message}");
        }
    }

    private void SaveCampaign()
    {
        if (AutoPlayCombat || _campaignSaveFailed || string.IsNullOrWhiteSpace(CampaignSavePath)) return;
        try { CampaignProgressStore.Save(ProjectSettings.GlobalizePath(CampaignSavePath), _campaign); }
        catch (Exception exception) when (exception is IOException or UnauthorizedAccessException)
        {
            GD.PushWarning($"[RunDirector] Campaign could not be saved: {exception.Message}");
        }
    }

    private void RecordCampaignVictory()
    {
        if (_state == null) return;
        _campaign.RecordVictory($"{_runId}/{_state.Stratum}/{_state.CurrentNodeId}", _state.Party.LeaderId,
            _state.Party.Members.Select(member => member.Id), _state.CurrentNode?.Kind == NodeKind.Boss);
        SaveCampaign();
    }

    /// <summary>Explicit outpost stay after authored requirements. Cannot bind during a run.</summary>
    public void BindAtOutpost(string characterId)
    {
        if (Phase != RunPhase.HeroSelect || !_campaign.BindAtOutpost(characterId)) return;
        SaveCampaign();
        _heroSelect.RefreshRecruitment();
    }
}
