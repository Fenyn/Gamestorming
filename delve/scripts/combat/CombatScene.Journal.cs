using System.Collections.Generic;
using Delve.Run;
using Delve.UI;
using Godot;
using PF2e.Core;
using PF2e.Data;

namespace Delve.Combat;

/// <summary>The creature journal in combat: lists the fight's species, applies Recall Knowledge
/// reveals, logs what was learned and feeds the Journal panel.</summary>
public partial class CombatScene
{
    /// <summary>The campaign journal, set by the run host. Null in a standalone fight, which records
    /// nothing.</summary>
    public MonsterJournal? Journal { get; set; }

    private CombatJournalPanel _journalPanel = null!;

    public CombatJournalPanel JournalPanel => _journalPanel;

    /// <summary>The Journal button sits in the log heading and hides while a modal holds the HUD,
    /// because J is inert then. Neither opens the journal over the encounter intro.</summary>
    private void BuildJournal()
    {
        _journalPanel = GetNode<CombatJournalPanel>("%CombatJournal");
        var button = GetNode<Button>("%JournalButton");
        var hud = GetNode<HudRoot>("%HudRoot");
        button.Pressed += () => { if (!hud.ModalActive && !hud.IntroPlaying) _journalPanel.Toggle(); };
        hud.ModalChanged += modal => button.Visible = !modal;
    }

    private static string SpeciesName(ICharacter creature)
        => creature.CreatureStats?.SourceDefinition?.CreatureName ?? creature.Name;

    /// <summary>Every species in the fight is encountered from its first turn on the board.</summary>
    private void NoteEncountered()
    {
        if (Journal != null)
            foreach (var enemy in _session.Team2)
                if (enemy.CreatureStats is { } stats)
                    Journal.MarkEncountered(stats.CreatureId, SpeciesName(enemy));
        RefreshJournal();
    }

    private void OnKnowledgeLearned(ICharacter target, DegreeOfSuccess degree)
    {
        if (Journal == null || target.CreatureStats == null) return;
        IReadOnlyList<CreatureKnowledgeField> fields = Journal.Reveal(target.CreatureStats.CreatureId, degree, SpeciesName(target));
        if (fields.Count == 0) return;
        _log.AppendEntry(CombatJournalRows.LearnedLine(target, _session.Letters.BaseNameFor(target), fields),
            (int)CombatLogSeverity.Info, false);
        RefreshJournal();
        RefreshCard();
    }

    private void RefreshJournal()
        => _journalPanel.Render(_session == null
            ? new List<JournalGroupView>()
            : CombatJournalRows.Build(_session.Team2, _session.Letters));
}
