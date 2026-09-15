using System;
using System.Linq;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Flow;
using Delve.Presets;
using Delve.Run;
using Delve.UI;
using Godot;
using PF2e.Core;

namespace Delve.Dev;

/// <summary>Applied recovery/progression text, result layouts, and transition cancellation.</summary>
public partial class RunPresentationSpike : SpikeBase
{
    [Export] public PackedScene TransitionScene { get; set; } = null!;
    [Export] public PackedScene VictoryScene { get; set; } = null!;
    [Export] public PackedScene EndScene { get; set; } = null!;
    [Export] public Theme UiTheme { get; set; } = null!;

    protected override async Task RunSpikeAsync(DataManager data)
    {
        var party = Party.Build(new[] { PresetCharacters.PlayerId, PresetCharacters.ElaraId,
            PresetCharacters.TharrId, PresetCharacters.FenwickId }, new UnlockState(), 2);
        var state = RunState.Start(4711, party, new RunMapConfig());
        party.Members[1].Health.SetCurrentHP(0);
        var before = PartyChangeSummary.Capture(party);
        PartyRecovery.CompleteEncounter(party, BattleResult.Team1Wins);
        var recovery = PartyChangeSummary.Recovery(party, before).ToArray();
        Check("recovery names the downed member and actual HP", recovery.Length == 1
            && recovery[0].Contains("Elara") && recovery[0].Contains("1 HP"));
        var night = PartyChangeSummary.Capture(party);
        PartyRecovery.LongRest(party, state.Clock, wardstone: state.Wardstone);
        string rest = string.Join("\n", PartyChangeSummary.Overnight(party, night));
        Check("overnight summary reports actual healing and casting recovery", rest.Contains("spell slots and focus restored")
            && rest.Contains($"{party.Members[1].Health.CurrentHP}/{party.Members[1].Health.MaxHP} HP"));
        before = PartyChangeSummary.Capture(party);
        PartyLeveling.Award(state, state.Leveling.XpPerLevel * 2);
        Check("earned promotions have no applied level gains", !PartyChangeSummary.LevelGains(party, before).Any());
        PromotionTestDriver.Complete(party);
        string gains = string.Join("\n", PartyChangeSummary.LevelGains(party, before));
        Check("level summary includes maximum HP and casting growth", gains.Contains("maximum HP") && gains.Contains("spell slots"));
        Check("unchanged party produces no level gains", !PartyChangeSummary.LevelGains(party, PartyChangeSummary.Capture(party)).Any());

        var campaign = new CampaignProgress();
        var departure = campaign.Capture();
        string recruit = PresetCharacters.RavenId;
        campaign.RecordMeeting(recruit, PresetCharacters.ElaraId);
        foreach (int n in Enumerable.Range(0, 20))
            campaign.RecordVictory($"presentation/{n}", PresetCharacters.ElaraId, new[] { recruit }, true);
        string progress = CampaignSummary.Describe(departure, campaign);
        Check("campaign summary reports ready invitations without unlocking", progress.Contains("ready to join") && !campaign.Unlocks.IsUnlocked(recruit));
        Check("campaign summary does not repeat old step gains", !CampaignSummary.Describe(campaign.Capture(), campaign).Contains("1/1"));

        var surface = new Control { Theme = UiTheme };
        surface.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
        AddChild(surface);
        var victory = VictoryScene.Instantiate<VictoryBanner>();
        surface.AddChild(victory);
        victory.ShowResult("Victory", UiColors.Victory);
        victory.ShowParty(party.Members);
        victory.ShowRewards(string.Join("\n", recovery) + "\nLevel gained: 2 to 4\n" + gains,
            "Level 4", 0);
        await Capture("polish_rewards");
        victory.GetNode<Button>("%DetailsButton").EmitSignal(Button.SignalName.Pressed);
        Check("reward details open for the selected party member", victory.GetNode<CharacterDetailsOverlay>("%ResultDetails").Visible);
        victory.GetNode<CharacterDetailsOverlay>("%ResultDetails").Close();
        victory.HideResult();
        var end = EndScene.Instantiate<RunEndPanel>();
        surface.AddChild(end);
        state.Outcome = RunOutcome.Defeat;
        end.Show(state, true, progress);
        await Capture("polish_campaign_return");
        Check("campaign summary is present after defeat", end.GetNode<Label>("%DetailLabel").Text.Contains("ready to join"));
        surface.QueueFree();

        var transition = TransitionScene.Instantiate<SceneTransition>();
        AddChild(transition);
        int calls = 0;
        await transition.Play("Descending to floor 2", () => calls++);
        Check("transition commits once and releases input", calls == 1 && !transition.Busy && !transition.Visible);
        if (DisplayServer.GetName() != "headless")
        {
            var pending = transition.Play("Leaving the outpost", () => calls++);
            await transition.Play("Duplicate click", () => calls++);
            transition.Cancel();
            await pending;
            Check("cancelled transition and duplicate input cannot commit", calls == 1 && !transition.Busy);
        }
        transition.QueueFree();
        await CheckDungeonPresentation();
    }

    private async Task Capture(string name)
    {
        if (DisplayServer.GetName() == "headless") return;
        await ToSignal(GetTree().CreateTimer(0.4), SceneTreeTimer.SignalName.Timeout);
        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        using var image = GetViewport().GetTexture().GetImage();
        Check($"{name} captured", image.SavePng($"res://.godot/{name}.png") == Error.Ok);
    }
}
