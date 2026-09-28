using Delve.Autoload;
using Delve.Run;
using Godot;

namespace Delve.Flow;

public partial class HeroSelectPanel
{
    private Button _bestiaryButton = null!;
    private BestiaryPanel _bestiary = null!;

    public BestiaryPanel Bestiary => _bestiary;

    /// <summary>A full-screen page (unlock journal or bestiary) holds the camp's input.</summary>
    private bool OverlayOpen => _recruitment.Visible || _bestiary.Visible;

    private void ReadyBestiary()
    {
        _bestiaryButton = GetNode<Button>("%BestiaryButton");
        _bestiary = GetNode<BestiaryPanel>("%Bestiary");
        _bestiaryButton.Pressed += OpenBestiary;
        _bestiary.Closed += () => _bestiaryButton.GrabFocus();
    }

    private void SetupBestiary(CampaignProgress? campaign)
    {
        _bestiary.Hide();
        _bestiaryButton.Disabled = campaign == null;
        _bestiaryButton.TooltipText = campaign == null ? "Unavailable: no campaign loaded" : "Every creature the expedition can meet, with what the party knows about the ones it has met";
        if (campaign != null)
            _bestiary.Setup(campaign.Journal, name => DataManager.Instance?.FindCreature(name));
    }

    public void OpenBestiary()
    {
        if (_campaign == null || _recruitment.Visible || _details.Visible) return;
        _bestiary.Open();
    }
}
