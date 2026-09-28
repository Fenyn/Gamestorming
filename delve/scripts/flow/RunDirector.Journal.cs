using Delve.Run;
using PF2e.Data;

namespace Delve.Flow;

/// <summary>The campaign journal is the engine's knowledge provider for as long as this run host
/// lives. Every change is saved with the campaign.</summary>
public partial class RunDirector
{
    private MonsterJournal? _journal;

    private void ClaimJournal()
    {
        _journal = _campaign.Journal;
        _journal.Changed += SaveCampaign;
        CreatureKnowledgeLocator.Instance = _journal;
        _combat.Journal = _journal;
        if (_dungeon != null) _dungeon.Journal = _journal;
    }

    private void ReleaseJournal()
    {
        if (_journal == null) return;
        _journal.Changed -= SaveCampaign;
        if (ReferenceEquals(CreatureKnowledgeLocator.Instance, _journal))
            CreatureKnowledgeLocator.Instance = null!;
        if (IsInstanceValid(_combat)) _combat.Journal = null;
        if (_dungeon != null && IsInstanceValid(_dungeon)) _dungeon.Journal = null;
        _journal = null;
    }

    public override void _ExitTree() => ReleaseJournal();
}
