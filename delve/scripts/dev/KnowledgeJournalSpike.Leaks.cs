using Delve.Autoload;
using Delve.Combat;
using Delve.Data;
using Delve.Run;
using Godot;
using PF2e.Core;
using PF2e.Data;
using PF2e.Utilities;

namespace Delve.Dev;

public partial class KnowledgeJournalSpike
{
    /// <summary>Weakness and resistance amounts, a check's save DC and the engine's critical Recall
    /// Knowledge line stay out of the log until the journal reveals the field.</summary>
    private void CheckLeakMasking(DataManager data)
    {
        GD.Print("-------------------- log leaks --------------------");
        var goblin = CreatureFactory.Create(data.ResolveCreature(EncounterTables.GoblinWarrior)!, teamId: 2);
        var enemies = new ICharacter[] { goblin };
        var journal = new MonsterJournal();
        journal.MarkEncountered(Goblin, "Goblin Warrior");
        var previous = CreatureKnowledgeLocator.Instance;
        CreatureKnowledgeLocator.Instance = journal;
        const string weakness = "Weakness increases damage by 5";
        const string resistance = "Resistance reduces damage by 3";
        int reflexDc = 10 + StatsCalculator.CalculateSave(goblin, SavingThrow.Reflex);
        string trip = $"Athletics: 12 + 5 = 17 vs DC {reflexDc} → Failure";
        try
        {
            Check($"before a reveal the weakness line drops its number ('{CombatLogMasks.Mask(weakness, goblin, enemies)}')",
                CombatLogMasks.Mask(weakness, goblin, enemies) == CombatLogMasks.WeaknessMasked
                && CombatLogMasks.Mask(weakness, null, enemies) == CombatLogMasks.WeaknessMasked);
            Check("before a reveal the resistance line drops its number",
                CombatLogMasks.Mask(resistance, goblin, enemies) == CombatLogMasks.ResistanceMasked);
            Check($"before a reveal a check against the goblin's Reflex prints vs DC ? ('{CombatLogMasks.Mask(trip, goblin, enemies)}')",
                CombatLogMasks.Mask(trip, goblin, enemies) == $"Athletics: 12 + 5 = 17 vs DC ? → Failure");
            Check("a flat DC that matches no save still prints",
                CombatLogMasks.Mask("Nature: 12 + 5 = 17 vs DC 99 → Failure", goblin, enemies)!.Contains("vs DC 99"));
            Check("the engine's critical Recall Knowledge line is dropped",
                CombatLogMasks.Mask(CombatLogMasks.CriticalRecall, goblin, enemies) == null);

            journal.Reveal(Goblin, DegreeOfSuccess.CriticalSuccess);
            Check("once Weaknesses is revealed the weakness line prints its number",
                CombatLogMasks.Mask(weakness, goblin, enemies) == weakness && CombatLogMasks.Mask(weakness, null, enemies) == weakness);
            Check("resistances stay masked until their own field", CombatLogMasks.Mask(resistance, goblin, enemies) == CombatLogMasks.ResistanceMasked);
            journal.Reveal(Goblin, DegreeOfSuccess.CriticalSuccess);
            Check("once Resistances is revealed the resistance line prints its number",
                CombatLogMasks.Mask(resistance, goblin, enemies) == resistance);
            while (!journal.IsFieldRevealed(Goblin, CreatureKnowledgeField.RefSave))
                journal.Reveal(Goblin, DegreeOfSuccess.Success);
            Check("once Reflex is revealed the check prints its DC", CombatLogMasks.Mask(trip, goblin, enemies) == trip);
        }
        finally { CreatureKnowledgeLocator.Instance = previous; }
    }
}
