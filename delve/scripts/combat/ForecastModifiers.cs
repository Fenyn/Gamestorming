using System.Collections.Generic;
using System.Linq;
using PF2e.Core;
using PF2e.Data;
using PF2e.Utilities;

namespace Delve.Combat;

/// <summary>
/// The forecast's modifier line. Each entry reads as its effect on the acting creature's chance:
/// the actor's own modifiers keep their sign and the other side's flip, so a target's off-guard AC -2
/// reads "Off-guard (Prone) +2". The actor's entries come first, then the target's.
/// </summary>
internal static class ForecastModifiers
{
    internal static IReadOnlyList<ModifierChip> Strike(ICharacter attacker, ICharacter target, int map)
    {
        var (weapon, type) = ModifierBreakdown.StrikeWeapon(attacker);
        var chips = Map(map);
        float distance = ModifierBreakdown.DistanceFeet(attacker, target);
        if (weapon != null)
        {
            Add(chips, "Range", weapon.GetRangeIncrementPenalty(distance));
            if (weapon.HasVolley) Add(chips, "Volley", WeaponAttackCalculator.GetVolleyPenalty(weapon, distance));
        }
        return ActorRolls(chips, ModifierBreakdown.Attack(attacker, target, type, weapon));
    }

    internal static IReadOnlyList<ModifierChip> SpellAttack(ICharacter caster, ICharacter target, int map)
        => ActorRolls(Map(map), ModifierBreakdown.Attack(caster, target, AttackType.Spell, null));

    internal static IReadOnlyList<ModifierChip> Check(ICharacter actor, ICharacter target, Skill skill, SavingThrow? save, int map)
        => ActorRolls(Map(map), ModifierBreakdown.Check(actor, skill, target, save));

    /// <summary>The target rolls: the caster's DC modifiers are the actor's own, the target's save
    /// modifiers flip.</summary>
    internal static IReadOnlyList<ModifierChip> Save(ICharacter caster, ICharacter target, SavingThrow save)
    {
        var breakdown = ModifierBreakdown.Save(caster, target, save);
        return breakdown.Defense.Concat(breakdown.Roll.Select(m => m.Negated)).ToList();
    }

    private static List<ModifierChip> ActorRolls(List<ModifierChip> chips, RollBreakdown breakdown)
    {
        chips.AddRange(breakdown.Roll);
        chips.AddRange(breakdown.Defense.Select(m => m.Negated));
        return chips;
    }

    private static List<ModifierChip> Map(int map)
    {
        var chips = new List<ModifierChip>();
        Add(chips, "MAP", map);
        return chips;
    }

    private static void Add(List<ModifierChip> chips, string label, int value)
    {
        if (value != 0) chips.Add(new ModifierChip(label, value));
    }
}
