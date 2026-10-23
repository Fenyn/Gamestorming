using PF2e.Actions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Equipment;
using PF2e.Utilities;
using Ungilded.Combat;

namespace Ungilded.Tutorial.Encounters;

/// <summary>
/// The d20 that gives a wanted degree for the rolls the Prologue scripts force, read from the live
/// numbers: a Strike (MAP, off-guard and range included), a Reactive Strike (which takes no MAP), a
/// bomb throw and the DC 15 flat check. Call right before the roll.
/// </summary>
internal static class TutorialRolls
{
    /// <summary>The DC of a persistent damage recovery check and of trained Treat Wounds.</summary>
    internal const int FlatDc = 15;

    internal static int Strike(ICharacter attacker, ICharacter target, DegreeOfSuccess degree, int? mapOverride = null)
    {
        var ctx = AttackResolver.PreviewStrike(attacker, target,
            creatureStrikeIndex: StrikeActions.CreatureStrikeIndex(attacker), mapOverride: mapOverride);
        return TutorialHooks.D20ForCheck(ctx.EffectiveBonus, ctx.TargetAC, degree);
    }

    /// <summary>A reaction Strike never takes the multiple attack penalty.</summary>
    internal static int ReactionStrike(ICharacter attacker, ICharacter target, DegreeOfSuccess degree)
        => Strike(attacker, target, degree, mapOverride: 0);

    internal static int Bomb(ICharacter thrower, ICharacter target, BombDefinition bomb, DegreeOfSuccess degree)
    {
        var ctx = AttackResolver.PreviewStrike(thrower, target, new WeaponInstance(bomb.ToWeaponDefinition(null)),
            sourceAction: new ThrowBombAction(bomb));
        return TutorialHooks.D20ForCheck(ctx.EffectiveBonus, ctx.TargetAC, degree);
    }

    internal static int Flat(DegreeOfSuccess degree) => TutorialHooks.D20ForCheck(0, FlatDc, degree);

    /// <summary>The d20 for <paramref name="degree"/> on this Strike, or null when no d20 gives it.</summary>
    internal static int? TryStrike(ICharacter attacker, ICharacter target, DegreeOfSuccess degree)
    {
        try { return Strike(attacker, target, degree); }
        catch (System.InvalidOperationException) { return null; }
    }

    /// <summary>True when the target is off-guard to the attacker's next Strike (flanked, for one).</summary>
    internal static bool OffGuardTo(ICharacter attacker, ICharacter target)
        => AttackResolver.PreviewStrike(attacker, target,
            creatureStrikeIndex: StrikeActions.CreatureStrikeIndex(attacker)).IsOffGuard;

    /// <summary>True when this d20 makes the Strike a critical failure only through the natural 1:
    /// its total alone misses the AC by less than 10.</summary>
    internal static bool FumbleByNaturalOne(ICharacter attacker, ICharacter target, int d20)
    {
        var ctx = AttackResolver.PreviewStrike(attacker, target,
            creatureStrikeIndex: StrikeActions.CreatureStrikeIndex(attacker));
        return d20 == 1 && d20 + ctx.EffectiveBonus > ctx.TargetAC - 10;
    }

    /// <summary>Weapon dice for a plain hit that brings the target to 0 HP, lowest faces first
    /// that do it, each die at its maximum when no faces can. <paramref name="extraDie"/> adds one
    /// more die of that size after the weapon dice (Sneak Attack), 0 for none.</summary>
    internal static int[] KillDice(ICharacter attacker, ICharacter target, int extraDie = 0)
    {
        var weapon = WeaponAttackCalculator.ResolveWeapon(attacker);
        var dice = weapon.GetEffectiveDamageDice();
        var preview = CombatPreviewCalculator.CalculateAttackPreview(attacker, target);
        int flat = preview.DamageMin - dice.NumberOfDice;
        var sizes = new System.Collections.Generic.List<int>();
        for (int i = 0; i < dice.NumberOfDice; i++) sizes.Add(dice.DieSize);
        if (extraDie > 0) sizes.Add(extraDie);
        int need = (target.Health?.CurrentHP ?? 0) - flat;
        var faces = new int[sizes.Count];
        for (int i = 0; i < sizes.Count; i++)
        {
            int left = sizes.Count - i - 1;
            faces[i] = System.Math.Clamp(need - left, 1, sizes[i]);
            need -= faces[i];
        }
        return faces;
    }
}
