using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using Delve.UI;
using PF2e.Core;
using PF2e.Data;
using PF2e.Utilities;

namespace Delve.Combat;

/// <summary>Masks engine log lines that state a fact the journal has not revealed. The subject is the
/// creature the current action names; with no subject, a creature fact shows only when every enemy
/// in the fight has that field revealed.</summary>
internal static class CombatLogMasks
{
    /// <summary>The engine's critical Recall Knowledge line. The journal's own learned line replaces it.</summary>
    internal const string CriticalRecall = "Identified creature weaknesses!";

    private static readonly Regex Weakness = new(@"^Weakness increases damage by \d+$");
    private static readonly Regex Resistance = new(@"^Resistance reduces damage by \d+$");

    internal const string WeaknessMasked = "Weakness increases damage";
    internal const string ResistanceMasked = "Resistance reduces damage";

    private static readonly (SavingThrow Save, CreatureKnowledgeField Field)[] Saves =
    {
        (SavingThrow.Fortitude, CreatureKnowledgeField.FortSave),
        (SavingThrow.Reflex, CreatureKnowledgeField.RefSave),
        (SavingThrow.Will, CreatureKnowledgeField.WillSave),
    };

    /// <summary>The line as the log should print it, or null to drop it.</summary>
    internal static string? Mask(string message, ICharacter? subject, IEnumerable<ICharacter> enemies)
    {
        if (message == CriticalRecall) return null;
        if (Weakness.IsMatch(message))
            return Known(subject, enemies, CreatureKnowledgeField.Weaknesses) ? message : WeaknessMasked;
        if (Resistance.IsMatch(message))
            return Known(subject, enemies, CreatureKnowledgeField.Resistances) ? message : ResistanceMasked;
        if (subject == null) return message;
        if (!Known(subject, CreatureKnowledgeField.AC)) message = CombatRoll.MaskArmorClass(message);
        if (CombatRoll.IsCheckLine(message) && CombatRoll.Parse(message) is { DcMasked: false } check
            && !CheckDcKnown(subject, check.DC))
            message = CombatRoll.MaskCheckDc(message);
        return message;
    }

    /// <summary>The same reveal check the forecast uses. Allies are never masked.</summary>
    internal static bool Known(ICharacter target, CreatureKnowledgeField field)
        => target.TeamId == 1 || target.CreatureStats == null
           || UnitInspectFactory.IsCreatureFieldKnown(target.CreatureStats.CreatureId, field);

    private static bool Known(ICharacter? subject, IEnumerable<ICharacter> enemies, CreatureKnowledgeField field)
        => subject != null ? Known(subject, field) : enemies.All(enemy => Known(enemy, field));

    /// <summary>A check against a save DC shows its number once that save is revealed. The engine does
    /// not say which save, so every save whose DC matches must be known. A DC that matches no save
    /// is a flat DC (Recall Knowledge, Escape) and shows.</summary>
    internal static bool CheckDcKnown(ICharacter target, int dc)
        => Saves.Where(s => 10 + StatsCalculator.CalculateSave(target, s.Save) == dc).All(s => Known(target, s.Field));
}
