using System.Collections.Generic;
using PF2e.Conditions;
using PF2e.Core;

namespace Delve.Flow;

/// <summary>
/// The sheet's STATUS line: what the last fight or rest left behind. Wounded, Doomed, and the focus
/// pool and shield when either is down. A fresh character has no status line at all. Godot-free.
/// </summary>
public static class HeroSheetStatus
{
    /// <summary>A creature dies at this Dying value, less its Doomed value.</summary>
    private const int DyingDeath = 4;

    public static IReadOnlyList<SheetEntry> Entries(PF2eCharacter character)
    {
        var entries = new List<SheetEntry>(4);
        int wounded = character.Conditions?.GetConditionValue(Condition.Wounded) ?? 0;
        int doomed = character.Conditions?.GetConditionValue(Condition.Doomed) ?? 0;
        var casting = character.Spellcasting;
        var shield = character.Equipment?.Shield is { HasShieldEquipped: true } held ? held : null;
        bool focusDown = casting != null && casting.CurrentFocusPoints < casting.MaxFocusPoints;
        bool shieldDown = shield != null && shield.CurrentShieldHP < shield.MaxShieldHP;
        if (wounded == 0 && doomed == 0 && !focusDown && !shieldDown) return entries;

        if (wounded > 0) entries.Add(new SheetEntry($"Wounded {wounded}", new SheetTip("Wounded",
            $"Wounded {wounded}", "Gaining Dying adds this much more. A successful Treat Wounds removes it, "
            + "as does resting ten minutes at full HP.")));
        if (doomed > 0) entries.Add(new SheetEntry($"Doomed {doomed}", new SheetTip("Doomed",
            $"Dies at Dying {DyingDeath - doomed}", "Death comes at a lower Dying value. A full night's rest lowers Doomed by 1.")));
        if (casting is { MaxFocusPoints: > 0 }) entries.Add(new SheetEntry($"Focus {casting.CurrentFocusPoints}/{casting.MaxFocusPoints}",
            new SheetTip("Focus points", "", "Spent on focus spells. Refocus during a rest restores one.")));
        if (shield != null) entries.Add(new SheetEntry(
            $"Shield {shield.CurrentShieldHP}/{shield.MaxShieldHP} (BT {shield.ShieldInstance.ShieldDef.BrokenThreshold})",
            new SheetTip("Shield", "", "Shield Block spends shield HP. At or below the Broken Threshold the shield is broken "
                + "and gives no AC until repaired. Repair during a rest restores it.")));
        return entries;
    }
}
