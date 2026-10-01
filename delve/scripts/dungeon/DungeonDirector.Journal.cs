using System.Linq;
using Delve.Autoload;
using Delve.Flow;
using Delve.Run;
using Godot;

namespace Delve.Dungeon;

/// <summary>The journal (bestiary and unlocks) opened from the party menu or J while exploring.</summary>
public partial class DungeonDirector
{
    /// <summary>The campaign whose journal the crawl shows, set by the host. The standalone crawl
    /// has none, so its Journal row stays disabled.</summary>
    public CampaignProgress? Campaign
    {
        get => _campaign;
        set
        {
            _campaign = value;
            if (!IsInstanceValid(_journalScreen)) return;
            _hud.SetJournalAvailable(value != null);
            if (value != null) _journalScreen.Setup(value, name => DataManager.Instance?.FindCreature(name));
        }
    }

    private CampaignProgress? _campaign;
    private JournalScreen _journalScreen = null!;

    public JournalScreen JournalScreen => _journalScreen;

    private void ReadyJournal()
    {
        _journalScreen = GetNode<JournalScreen>("%Journal");
        _journalScreen.Closed += () =>
        {
            RefreshHud();
            if (IsVisibleInTree() && Phase == DungeonPhase.Doors) _camera.ProcessMode = ProcessModeEnum.Inherit;
        };
        _hud.JournalPressed += OpenJournal;
        _hud.PartyPressed += () =>
        {
            // A member with a feat to choose comes first; otherwise the party leader.
            var living = State?.Party.Living();
            if ((living?.FirstOrDefault(CombatResults.HasFeatChoice) ?? living?.FirstOrDefault()) is { } first)
                OpenMemberDetails(first.UniqueId);
        };
        Campaign = _campaign;
    }

    public void OpenJournal()
    {
        if (_campaign == null || Phase != DungeonPhase.Doors || ScreenOpen || _event.Visible) return;
        _hud.HideDoorTip();
        _journalScreen.Open(JournalScreen.BestiaryPage);
        _camera.ProcessMode = ProcessModeEnum.Disabled;
    }

    /// <summary>A full-screen frame (a character sheet or the journal) holds the crawl's input.</summary>
    private bool ScreenOpen => _details.Visible || _journalScreen.Visible;
}
