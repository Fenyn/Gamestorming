using System;
using System.Collections.Generic;
using PF2e.Actions;
using PF2e.Classes;
using PF2e.Core;
using PF2e.Equipment;
using PF2e.Spellcasting;
using PF2e.Utilities;

namespace Delve.Flow;

/// <summary>The caster's two contributions to the sheet: the spell DC that headlines the header
/// band, and the one row of prepared-magic chips.</summary>
internal sealed record SheetCasting(SheetHeadline Signature, SheetRow Row);

/// <summary>
/// The gear-and-magic half of <see cref="HeroSheetBuilder"/>: the strike chips, the defence chips
/// and the caster's row, each entry carrying the tip that explains it. Split out so each file owns
/// one part of the sheet. Pure - no Godot types.
/// </summary>
internal static class HeroSheetLoadout
{
    /// <summary>Every equipped weapon as a chip - "Scimitar +5" - or the unarmed fallback when
    /// both hands are empty. Damage, traits and the arithmetic are on the hover.</summary>
    internal static IReadOnlyList<SheetEntry> Strikes(
        PF2eCharacter character, ClassDefinition? characterClass, int level)
    {
        var equipment = character.Equipment;
        var weapons = new List<WeaponInstance>(2);

        if (equipment?.MainHandWeapon != null) weapons.Add(equipment.MainHandWeapon);
        if (equipment?.OffHandWeapon != null && equipment.OffHandWeapon != equipment.MainHandWeapon)
            weapons.Add(equipment.OffHandWeapon);
        if (weapons.Count == 0)
        {
            var unarmed = equipment?.UnarmedAttack ?? WeaponAttackCalculator.DefaultUnarmedInstance;
            if (unarmed != null) weapons.Add(unarmed);
        }

        var chips = new List<SheetEntry>(weapons.Count);
        foreach (var weapon in weapons)
        {
            if (weapon.WeaponDef == null) continue;
            chips.Add(Strike(character, characterClass, level, weapon));
        }
        return chips;
    }

    /// <summary>A martial's signature number: the weapon it leads with and what it hits at.</summary>
    internal static SheetHeadline? StrikeHeadline(IReadOnlyList<SheetEntry> strikes)
    {
        if (strikes.Count == 0) return null;

        var first = strikes[0];
        int split = first.Label.LastIndexOf(' ');
        if (split <= 0) return new SheetHeadline(first.Label.ToUpperInvariant(), "", first.Tip);

        return new SheetHeadline(
            first.Label[..split].ToUpperInvariant(), first.Label[(split + 1)..], first.Tip);
    }

    private static SheetEntry Strike(
        PF2eCharacter character, ClassDefinition? characterClass, int level, WeaponInstance weapon)
    {
        var definition = weapon.WeaponDef;
        int attack = WeaponAttackCalculator.CalculateAttackBonus(character, weapon);
        int damageMod = WeaponAttackCalculator.GetEffectiveDamageAbilityModifier(
            character.Stats, weapon, characterClass, level, character.Features,
            character.BuildChoices?.ChosenWeaponGroup, character.BuildChoices?.GetFavoredWeapon());

        var dice = definition.GetEffectiveDamageDice();
        string flat = damageMod == 0 ? "" : HeroSheetBuilder.Signed(damageMod);
        string damage =
            $"{(int)weapon.Striking}d{dice.DieSize}{flat} {definition.DamageType.ToString().ToLowerInvariant()}";

        return new SheetEntry(
            $"{definition.ItemName ?? "Strike"} {HeroSheetBuilder.Signed(attack)}",
            HeroSheetGearTips.Strike(
                character, characterClass, level, weapon, attack, damageMod, damage,
                Traits(definition)));
    }

    /// <summary>The traits that change how the strike is used, read off the weapon's own trait
    /// flags. Ordered by how often they matter at the table.</summary>
    private static IReadOnlyList<string> Traits(WeaponDefinition weapon)
    {
        var traits = new List<string>();
        if (weapon.IsAgile) traits.Add("agile");
        if (weapon.IsFinesse) traits.Add("finesse");
        if (weapon.HasReach) traits.Add("reach");
        if (weapon.HasTwoHand) traits.Add($"two-hand d{weapon.TwoHandDieSize}");
        if (weapon.HasDeadly) traits.Add($"deadly d{weapon.DeadlyDieSize}");
        if (weapon.HasFatal) traits.Add($"fatal d{weapon.FatalDieSize}");
        if (weapon.HasThrownTrait) traits.Add("thrown");
        if (weapon.HasSweep) traits.Add("sweep");
        if (weapon.HasForceful) traits.Add("forceful");
        if (weapon.HasBackswing) traits.Add("backswing");
        if (weapon.HasParry) traits.Add("parry");
        if (weapon.HasBackstabber) traits.Add("backstabber");
        if (weapon.IsPropulsive) traits.Add("propulsive");
        if (weapon.IsNonlethal) traits.Add("nonlethal");
        return traits;
    }

    /// <summary>Worn armour - or the unarmoured chip, which is what a wizard's AC is actually
    /// built on - and a carried shield. The bonuses and penalties are on the hover.</summary>
    internal static IReadOnlyList<SheetEntry> Defences(PF2eCharacter character)
    {
        var equipment = character.Equipment;
        var chips = new List<SheetEntry>(2);

        var armor = equipment?.WornArmorDef;
        chips.Add(armor != null
            ? new SheetEntry(armor.ItemName ?? "Armour", HeroSheetGearTips.Armor(armor))
            : new SheetEntry("Unarmoured", HeroSheetGearTips.Unarmoured()));

        var shield = equipment?.Shield?.EquippedShield;
        if (shield != null)
            chips.Add(new SheetEntry(shield.ItemName ?? "Shield", HeroSheetGearTips.Shield(shield)));
        return chips;
    }

    // ---------------------------------------------------------------- Spellcasting

    /// <summary>
    /// The caster's spell DC and one chip per group of prepared magic - "Cantrips ×4",
    /// "Rank 1 ×4", "Focus ×1", "Divine Font ×4". The spells themselves are on each chip's hover:
    /// a name list on the page is the wall the sheet was rebuilt to remove.
    /// </summary>
    internal static SheetCasting? Casting(PF2eCharacter character)
    {
        var casting = character.Spellcasting;
        SpellcastingSource? source = casting is { Sources.Count: > 0 } ? casting.Sources[0] : null;
        if (casting == null || source == null) return null;

        var cantrips = new List<SpellAction>();
        var focus = new List<SpellAction>();
        foreach (var spell in casting.Cantrips)
        {
            if (spell?.Spell == null) continue;
            (spell.Spell.IsFocusSpell ? focus : cantrips).Add(spell);
        }

        var byRank = new SortedDictionary<int, List<SpellAction>>();
        foreach (var spell in casting.LeveledSpells)
        {
            if (spell?.Spell == null) continue;
            if (spell.Spell.IsFocusSpell) { focus.Add(spell); continue; }

            if (!byRank.TryGetValue(spell.Spell.SpellLevel, out var prepared))
            {
                prepared = new List<SpellAction>();
                byRank[spell.Spell.SpellLevel] = prepared;
            }
            prepared.Add(spell);
        }

        var chips = new List<SheetEntry>();
        Group(chips, "Cantrips", cantrips);
        foreach (var (rank, prepared) in byRank) Group(chips, $"Rank {rank}", prepared);
        Group(chips, "Focus", focus);

        var font = casting.DivineFont;
        string fontSpell = font?.FontSpellIdentity?.SpellName ?? "";
        if (fontSpell.Length > 0 && font is { MaxSlots: > 0 })
        {
            chips.Add(new SheetEntry(
                $"Divine Font ×{font.MaxSlots}",
                HeroSheetGearTips.DivineFont(fontSpell, font.MaxSlots)));
        }
        if (chips.Count == 0) return null;

        int dc = StatsCalculator.CalculateSpellDC(character);
        int attack = StatsCalculator.CalculateSpellAttack(character);
        string tradition = casting.PrimaryTradition.ToString();
        string keyAbility = source.SpellcastingAbility.ToString();

        return new SheetCasting(
            new SheetHeadline("SPELL DC", dc.ToString(), new SheetTip(
                "Spell DC",
                "",
                "What a target must beat to save against your spells.",
                Meta: new[]
                {
                    new SheetMetaRow("Save DC", dc.ToString()),
                    new SheetMetaRow("Spell attack", HeroSheetBuilder.Signed(attack)),
                    new SheetMetaRow("Tradition", $"{tradition} · {keyAbility}"),
                },
                Footer: $"{dc} = 10 + proficiency + {keyAbility}")),
            new SheetRow(HeroSheetBuilder.SpellsRow, chips, SheetRowStyle.Chips));
    }

    /// <summary>One chip for a group of prepared magic, counting the slots rather than naming
    /// them. Duplicates count twice: two prepared Breathe Fire are two castings.</summary>
    private static void Group(List<SheetEntry> chips, string term, List<SpellAction> spells)
    {
        if (spells.Count == 0) return;
        chips.Add(new SheetEntry(
            $"{term} ×{spells.Count}", HeroSheetGearTips.SpellGroup(term, spells)));
    }
}
