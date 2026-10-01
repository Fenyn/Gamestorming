using Delve.Run;
using Delve.UI;
using Godot;

namespace Delve.Flow;

/// <summary>
/// The journal: the bestiary and the unlock journal as two pages of one frame, reachable from the
/// outpost and, with J, while exploring. Reading it never changes campaign state; the unlock page's
/// invitation is signalled outward.
/// </summary>
public partial class JournalScreen : ScreenFrame
{
    public const int BestiaryPage = 0;
    public const int UnlocksPage = 1;

    public BestiaryPanel Bestiary { get; private set; } = null!;
    public RecruitmentPanel Unlocks { get; private set; } = null!;

    public override void _Ready()
    {
        Bestiary = GetNode<BestiaryPanel>("%Bestiary");
        Unlocks = GetNode<RecruitmentPanel>("%Recruitment");
        base._Ready();
        PageChanged += FocusPage;
    }

    public void Setup(CampaignProgress campaign, System.Func<string, PF2e.Data.EnemyDefinition?> lookup)
    {
        Bestiary.Setup(campaign.Journal, lookup);
        Unlocks.Setup(campaign);
    }

    public void Open(int page, Control? opener = null)
    {
        OpenFrame(opener);
        Bestiary.Refresh();
        Unlocks.Refresh();
        SelectPage(page);
    }

    /// <summary>J closes the journal it opened, like Esc.</summary>
    public override void _Input(InputEvent e)
    {
        if (IsVisibleInTree() && !e.IsEcho() && e.IsActionPressed(InputNames.ExploreJournal))
        {
            Close();
            GetViewport().SetInputAsHandled();
            return;
        }
        base._Input(e);
    }

    private void FocusPage(int page)
    {
        if (!Visible) return;
        if (page == BestiaryPage) Bestiary.FocusSelected();
        else Unlocks.Refresh();
    }
}
