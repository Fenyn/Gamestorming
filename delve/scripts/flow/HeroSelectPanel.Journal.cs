using System.Linq;
using Delve.Autoload;
using Delve.Run;
using Godot;

namespace Delve.Flow;

public partial class HeroSelectPanel
{
    private Button _bestiaryButton = null!;
    private JournalScreen _journal = null!;

    public JournalScreen Journal => _journal;
    public BestiaryPanel Bestiary => _journal.Bestiary;
    public RecruitmentPanel Recruitment => _journal.Unlocks;

    /// <summary>A full-screen frame (the journal or a character sheet) holds the camp's input.</summary>
    private bool OverlayOpen => _journal.Visible || _details.Visible;

    private void ReadyJournal()
    {
        _bestiaryButton = GetNode<Button>("%BestiaryButton");
        _journal = GetNode<JournalScreen>("%Journal");
        _bestiaryButton.Pressed += () => OpenJournal(JournalScreen.BestiaryPage);
        _recruitmentButton.Pressed += () => OpenJournal(JournalScreen.UnlocksPage);
        _journal.Unlocks.StayRequested += id => RecruitmentRequested?.Invoke(id);
    }

    private void SetupJournal(CampaignProgress? campaign)
    {
        _journal.Close();
        foreach (var button in new[] { _bestiaryButton, _recruitmentButton })
        {
            button.Disabled = campaign == null;
            if (campaign == null) button.TooltipText = "Unavailable: no campaign loaded";
        }
        if (campaign == null) return;
        _bestiaryButton.TooltipText = "Every creature the expedition can meet, with what the party knows about the ones it has met";
        _recruitmentButton.TooltipText = "Travelers who may join the outpost, and what each one is waiting for";
        _journal.Setup(campaign, name => DataManager.Instance?.FindCreature(name));
        var pool = BestiaryPanel.CampaignPool(campaign.Journal);
        _bestiaryButton.Text = $"Bestiary  {pool.Count(s => campaign.Journal.IsEncountered(s.Id))}/{pool.Count}";
    }

    public void OpenBestiary() => OpenJournal(JournalScreen.BestiaryPage);

    public void OpenJournal(int page)
    {
        if (_campaign == null || OverlayOpen) return;
        _journal.Open(page, page == JournalScreen.BestiaryPage ? _bestiaryButton : _recruitmentButton);
    }
}
