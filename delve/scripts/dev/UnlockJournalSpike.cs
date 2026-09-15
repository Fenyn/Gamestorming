using System.Linq;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Flow;
using Delve.Run;
using Godot;

namespace Delve.Dev;

public partial class UnlockJournalSpike : SpikeBase
{
    [Export] public PackedScene CampScene { get; set; } = null!;
    private RecruitmentPanel _journal = null!;
    protected override async Task RunSpikeAsync(DataManager data)
    {
        var layer = new CanvasLayer();
        AddChild(layer);
        var camp = CampScene.Instantiate<HeroSelectPanel>();
        layer.AddChild(camp);
        var campaign = new CampaignProgress();
        camp.Setup(campaign.Unlocks, campaign);
        _journal = camp.GetNode<RecruitmentPanel>("%Recruitment");
        _journal.Open();
        Check("normal camp has four residents", HeroSelectChecks.Cards(camp).Count == 4);
        _journal.SelectCharacter("aldric");
        Check("champion renamed without changing saved ID", CharacterCatalog.Find("aldric")?.DisplayName == "Sir Garran"
            && CharacterCatalog.Find("aldric")!.Builder(2).Name == "Sir Garran");
        Check("starter still Aldric", CharacterCatalog.Find("player")?.DisplayName == "Aldric");
        Check("unmet page shows discovery only", _journal.GetNode<VBoxContainer>("%JournalSteps").GetChildCount() == 1
            && _journal.GetNode<TextureRect>("%JournalPortrait").Texture == null);
        await Capture("undiscovered");
        campaign.RecordMeeting("aldric", "player");
        campaign.RecordMeeting("raven", "player");
        campaign.RecordVictory("journal/1", "player", new[] { "player", "aldric" }, false);
        camp.RefreshRecruitment();
        Check("refresh preserves inspected character", _journal.SelectedId == "aldric");
        Check("meeting reveals three objectives", _journal.GetNode<VBoxContainer>("%JournalSteps").GetChildCount() == 3
            && _journal.GetNode<Button>("%StayButton").IsVisibleInTree());
        Check("partial progress cannot invite", _journal.GetNode<Button>("%StayButton").Disabled);
        _journal.SelectFilter(2);
        Check("in-progress filter shows two met travelers", _journal.GetNode<GridContainer>("%RecruitEntries").GetChildCount() == 2);
        await Capture("in-progress");
        campaign.RecordVictory("journal/2", "player", new[] { "player", "aldric" }, true);
        camp.RefreshRecruitment();
        _journal.SelectFilter(3);
        Check("ready filter follows completed objectives", _journal.SelectedId == "aldric"
            && !_journal.GetNode<Button>("%StayButton").Disabled);
        camp.RecruitmentRequested += id => { campaign.BindAtOutpost(id); camp.RefreshRecruitment(); };
        await Capture("ready");
        _journal.GetNode<Button>("%StayButton").EmitSignal(Button.SignalName.Pressed);
        Check("invitation adds one camp resident", campaign.Unlocks.IsUnlocked("aldric") && HeroSelectChecks.Cards(camp).Count == 5);
        Check("empty ready filter clears detail page", _journal.SelectedId == null
            && _journal.GetNode<Label>("%JournalEmpty").Visible);
        _journal.SelectFilter(4);
        Check("joined page has no repeated invitation", _journal.SelectedId == "aldric"
            && !_journal.GetNode<Button>("%StayButton").Visible);
        await Capture("joined");
        _journal.SelectFilter(0);
        Check("all filter restores every arc", _journal.GetNode<GridContainer>("%RecruitEntries").GetChildCount() == RecruitmentCatalog.All.Count);
        layer.QueueFree();
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }

    private async Task Capture(string name)
    {
        await ToSignal(GetTree().CreateTimer(0.3), SceneTreeTimer.SignalName.Timeout);
        string output = OS.GetEnvironment("DELVE_SHOT_DIRECTORY");
        if (string.IsNullOrEmpty(output) || DisplayServer.GetName() == "headless") return;
        DirAccess.MakeDirRecursiveAbsolute(output);
        var image = GetViewport().GetTexture().GetImage();
        image.Convert(Image.Format.Rgba8);
        image.LinearToSrgb();
        Check($"{name} capture saved", image.SavePng($"{output}/{name}.png") == Error.Ok);
        var page = _journal.GetNode<Control>("%JournalPage");
        var scroll = page.GetParent<ScrollContainer>();
        Check($"{name} page fits without horizontal scrolling", page.Size.X <= scroll.Size.X + 1);
    }
}
