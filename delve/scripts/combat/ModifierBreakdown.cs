using System.Collections.Generic;
using System.Linq;
using PF2e.CharacterComponents;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Equipment;
using PF2e.Utilities;

namespace Delve.Combat;

/// <summary>
/// Reads which modifiers the engine applies to a roll and names their sources. It walks the same
/// modifier stack buckets as <see cref="ModifierStack.GetModifierTotal(StatType, ModifierContext)"/>
/// and keeps the entries PF2e stacking lets through, so the values always sum to the engine's own
/// total. A condition names itself with its value, and a granted condition names its source in
/// parentheses. Nothing here changes a number.
/// </summary>
internal static class ModifierBreakdown
{
    /// <summary>A Strike or spell attack: the attacker's attack modifiers and the target's AC modifiers,
    /// including cover and per-attacker off-guard, which the engine adds outside the stack.</summary>
    internal static RollBreakdown Attack(ICharacter attacker, ICharacter target, AttackType type, WeaponInstance? weapon)
    {
        var rollContext = ModifierContext.General();
        if (weapon != null && attacker.Stats?.CharacterClass != null)
            rollContext = rollContext.WithUsedAbility(WeaponAttackCalculator.GetAttackAbility(attacker.Stats, weapon));
        var stat = type switch { AttackType.Ranged => StatType.RangedAttack, AttackType.Spell => StatType.SpellAttack, _ => StatType.MeleeAttack };
        var roll = Applied(attacker, stat, rollContext);

        float distance = type == AttackType.Spell ? 0 : DistanceFeet(attacker, target);
        var cover = CoverHelper.GetEffectiveCoverLevel(attacker, target);
        var extra = cover == CoverLevel.None ? null : new[]
        {
            new ConditionModifier { TargetStat = StatType.AC, Type = ModifierType.Circumstance,
                Value = CoverHelper.GetACBonus(cover), Source = $"{cover} cover" },
        };
        var defense = Applied(target, StatType.AC, ModifierContext.Attack(attacker, type, distance), extra);
        if (OffGuardHelper.IsOffGuardTo(target, attacker, type) && !OffGuardHelper.HasGlobalOffGuard(target))
            defense.Add(new ModifierChip(OffGuardLabel(OffGuardHelper.GetOffGuardReason(target, attacker, type)), -2));
        return new RollBreakdown(roll, defense);
    }

    /// <summary>A skill check against a creature: the roller's skill modifiers and, when the check
    /// targets a save DC, that save's modifiers on the target.</summary>
    internal static RollBreakdown Check(ICharacter actor, Skill skill, ICharacter? target, SavingThrow? save)
        => new(Applied(actor, SkillCalculator.GetSkillStatType(skill), null),
            target != null && save is { } s ? Applied(target, SaveStat(s), null) : new List<ModifierChip>());

    /// <summary>A save against a spell DC: the saver's modifiers roll, the caster's DC modifiers defend.</summary>
    internal static RollBreakdown Save(ICharacter caster, ICharacter target, SavingThrow save)
        => new(Applied(target, SaveStat(save), null), Applied(caster, StatType.SpellDC, ModifierContext.General()));

    /// <summary>The weapon a Strike forecast resolves, and its attack type.</summary>
    internal static (WeaponInstance? Weapon, AttackType Type) StrikeWeapon(ICharacter attacker, string? strikeName = null)
    {
        if (attacker.CreatureStats is { StrikeCount: > 0 } stats)
        {
            var strikes = Enumerable.Range(0, stats.StrikeCount).Select(stats.GetStrike).OfType<CreatureStrike>().ToList();
            var strike = strikes.FirstOrDefault(s => s.StrikeName == strikeName, strikes[0]);
            return (null, strike.IsRanged ? AttackType.Ranged : AttackType.Melee);
        }
        var weapon = WeaponAttackCalculator.ResolveWeapon(attacker);
        return (weapon, weapon?.GetAttackType() ?? AttackType.Melee);
    }

    /// <summary>The distance the strike pipeline measures, altitude included when the host registers it.</summary>
    internal static float DistanceFeet(ICharacter a, ICharacter b)
    {
        var anchorA = AreaCalculator.WorldToGridAnchor(a.Position, a.TileWidth);
        var anchorB = AreaCalculator.WorldToGridAnchor(b.Position, b.TileWidth);
        int tiles = AreaCalculator.GetCharacterAltitudeFeet is { } altitude
            ? AreaCalculator.GetPF2eDistance(anchorA, a.TileWidth, altitude(a), anchorB, b.TileWidth, altitude(b))
            : AreaCalculator.GetPF2eDistance(anchorA, a.TileWidth, anchorB, b.TileWidth);
        return tiles * PF2eRules.FeetPerTile;
    }

    internal static StatType SaveStat(SavingThrow save) => save switch
    {
        SavingThrow.Fortitude => StatType.Fortitude,
        SavingThrow.Reflex => StatType.Reflex,
        _ => StatType.Will,
    };

    private static string OffGuardLabel(string? reason) => string.IsNullOrEmpty(reason) || reason == "feature"
        ? "Off-guard" : $"Off-guard ({char.ToUpperInvariant(reason[0])}{reason[1..]})";

    /// <summary>The non-zero modifiers on <paramref name="stat"/> after PF2e stacking. A null context
    /// reads the contextless modifiers, as the engine does for tooltips, checks and saves.</summary>
    internal static List<ModifierChip> Applied(ICharacter owner, StatType stat, ModifierContext? context,
        IEnumerable<ConditionModifier>? extra = null)
    {
        var stack = owner.Modifiers;
        if (stack == null) return new List<ModifierChip>();
        var buckets = new[] { stat }.Concat(context is { } c ? ModifierStack.GetUmbrellaTypes(stat, c) : ModifierStack.GetUmbrellaTypes(stat));
        var mods = buckets.SelectMany(s => stack.GetAllModifiers(s))
            .Where(m => context is { } c ? m.IsApplicable(c) : m.IsContextless)
            .Concat(extra ?? Enumerable.Empty<ConditionModifier>()).ToList();
        return Stacked(mods).Where(m => m.Value != 0).Select(m => Chip(owner, m)).ToList();
    }

    /// <summary>Untyped entries all count; a typed bonus or penalty counts only as the best or worst of
    /// its type, the first such entry standing for its type.</summary>
    private static IEnumerable<ConditionModifier> Stacked(List<ConditionModifier> mods)
    {
        foreach (bool bonus in new[] { true, false })
        {
            var side = mods.Where(m => bonus ? m.Value > 0 : m.Value < 0).ToList();
            foreach (var m in side.Where(m => m.Type == ModifierType.Untyped)) yield return m;
            foreach (var group in side.Where(m => m.Type != ModifierType.Untyped).GroupBy(m => m.Type))
                yield return bonus ? group.MaxBy(m => m.Value) : group.MinBy(m => m.Value);
        }
    }

    private static ModifierChip Chip(ICharacter owner, ConditionModifier modifier)
    {
        var all = owner.Conditions?.GetAllConditions();
        var instance = all?.FirstOrDefault(c => c.InstanceId == modifier.SourceInstanceId);
        if (all == null || instance == null) return new ModifierChip(modifier.Source ?? "Other", modifier.Value);
        var root = instance;
        while (root.ParentConditionId is { } parentId && all.FirstOrDefault(c => c.InstanceId == parentId) is { } parent)
            root = parent;
        string label = ConditionMarks.Label(owner, instance);
        if (root != instance) label += $" ({ConditionMarks.Name(root.Definition)})";
        return new ModifierChip(label, modifier.Value, ConditionMarks.IconKey(root));
    }
}
