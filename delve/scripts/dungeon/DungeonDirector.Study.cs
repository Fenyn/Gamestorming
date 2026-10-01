using Delve.Autoload;
using Delve.Combat;
using Delve.Data;
using Delve.Run;
using PF2e.Data;

namespace Delve.Dungeon;

/// <summary>The refuge night's Recall Knowledge on the floor's guardian, and banked potions.</summary>
public partial class DungeonDirector
{
    /// <summary>The campaign's knowledge journal, set by the host. The standalone crawl has none,
    /// so its camp studies nothing.</summary>
    public MonsterJournal? Journal { get; set; }

    private bool _studied;

    /// <summary>The last camp study, for spikes; null until a camp with a journal.</summary>
    public StudyResult? LastStudy { get; private set; }

    /// <summary>The guardian roster's first line, the creature the party studies.</summary>
    private (EnemyDefinition Creature, CreatureAdjustment Adjustment)? GuardianLead()
    {
        var spec = BossEncounters.ForStratum(State.Stratum);
        if (spec.Spawns.Count == 0) return null;
        var lead = spec.Spawns[0];
        var creature = DataManager.Instance?.ResolveCreature(lead.Creature);
        return creature == null ? null : (creature, lead.Adjustment);
    }

    /// <summary>Over the refuge night the party recalls what it knows of the guardian, once per
    /// floor. Returns the journal pair for the morning report, or null without a journal.</summary>
    private FigureView? StudyAtCamp()
    {
        if (Journal == null || _studied || GuardianLead() is not { } lead) return null;
        _studied = true;
        int total = MonsterJournal.TotalFields;
        int before = Journal.KnownCount(lead.Creature.CreatureId);
        LastStudy = GuardianStudy.Study(State.Party, lead.Creature, Journal, lead.Adjustment);
        if (LastStudy == null) return null;
        return new FigureView(LastStudy.Species, $"{Journal.KnownCount(lead.Creature.CreatureId)}/{total}") { Before = $"{before}/{total}" };
    }

    /// <summary>The most wounded hero drinks a banked potion.</summary>
    public void DrinkPotion()
    {
        if (ScreenOpen || Phase != DungeonPhase.Doors) return;
        string? line = Delve.Run.Events.HealingPotions.Drink(State);
        RefreshHud();
        if (line != null) _hud.ShowNotice(line);
    }
}
