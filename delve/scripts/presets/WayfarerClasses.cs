using System.Collections.Generic;
using Delve.Rules;
using PF2e.Classes;
using PF2e.Equipment;
using PF2e.Core;
using PF2e.Data;
using PF2e.RuleEvents;
using PF2e.RuleEvents.Features;

namespace Delve.Presets;

internal static partial class WayfarerClasses
{
    internal static AbilityScore Key(string name) => Initial(name).KeyAbility;
    internal static string Specialty(string name) => name switch
    {
        "Barbarian" => "Fury instinct", "Champion" => "Justice cause", "Witch" => "Grandmother Mulch",
        "Monk" => "Quiet Hand", "Ranger" => "Precision edge", "Druid" => "Leaf order",
        "Magus" => "Laughing Shadow", "Oracle" => "Battle mystery", "Thaumaturge" => "Chalice implement",
        "Bard" => "Maestro muse", "Psychic" => "Silent Whisper", "Swashbuckler" => "Braggart style",
        "Summoner" => "Earth eidolon", "Sorcerer" => "Elemental bloodline", _ => name,
    };

    internal static ClassDefinition Build(string name, int level)
    {
        var c = Initial(name);
        c.SpellcastingSource = WayfarerCasting.Source(name, level);
        c.ClassFeatures = new List<LeveledFeature>();
        c.ClassFeatures.Add(new() { Level = 1, Feature = new WayfarerFeature(name, Specialty(name)) });
        if (name is "Champion" or "Druid")
            c.ClassFeatures.Add(new() { Level = 1, Feature = new ShieldBlockFeature
                { FeatureId = "shield-block", DisplayName = "Shield Block", Category = FeatureCategory.ClassFeature } });
        if (name == "Champion") c.ClassFeatures.Add(new() { Level = 1, Feature = new JusticeReaction() });
        if (name == "Druid")
            c.ClassFeatures.Add(new() { Level = 1, Feature = new WildEmpathyFeature
                { FeatureId = "voice-of-nature", DisplayName = "Voice of Nature", Category = FeatureCategory.ClassFeature } });
        // Campaign level band: 1-10. Fresh and persistent characters query the same progression.
        void Bump(int at, ProficiencyLevel rank, params ProficiencyTarget[] targets)
        {
            foreach (var target in targets) c.ProficiencyProgressions.Add(new() { Level = at, Target = target, NewProficiency = rank });
        }
        var e = ProficiencyLevel.Expert;
        var m = ProficiencyLevel.Master;
        if (name is "Barbarian" or "Champion" or "Monk" or "Ranger" or "Magus" or "Thaumaturge" or "Swashbuckler")
            Bump(5, e, ProficiencyTarget.SimpleWeapon, ProficiencyTarget.UnarmedAttack,
                name == "Monk" ? ProficiencyTarget.SimpleWeapon : ProficiencyTarget.MartialWeapon);
        if (c.SpellProficiency != ProficiencyLevel.Untrained && name != "Champion")
            Bump(name is "Magus" or "Summoner" ? 9 : 7, e, ProficiencyTarget.SpellAttack);
        switch (name)
        {
            case "Barbarian": Bump(7,m,ProficiencyTarget.Fortitude); Bump(9,e,ProficiencyTarget.Reflex); break;
            case "Champion": Bump(7,e,ProficiencyTarget.Unarmored,ProficiencyTarget.LightArmor,ProficiencyTarget.MediumArmor,ProficiencyTarget.HeavyArmor); Bump(9,e,ProficiencyTarget.Reflex,ProficiencyTarget.ClassDC); Bump(9,m,ProficiencyTarget.Fortitude); break;
            case "Witch": case "Sorcerer": Bump(5,e,ProficiencyTarget.Fortitude); Bump(9,e,ProficiencyTarget.Reflex); break;
            case "Monk": Bump(5,e,ProficiencyTarget.Perception); Bump(7,m,ProficiencyTarget.Will); Bump(9,e,ProficiencyTarget.ClassDC); break;
            case "Ranger": Bump(3,e,ProficiencyTarget.Will); Bump(7,m,ProficiencyTarget.Reflex,ProficiencyTarget.Perception); Bump(9,e,ProficiencyTarget.ClassDC); break;
            case "Druid": Bump(3,e,ProficiencyTarget.Perception,ProficiencyTarget.Fortitude); Bump(5,e,ProficiencyTarget.Reflex); break;
            case "Magus": Bump(5,e,ProficiencyTarget.Reflex); Bump(9,e,ProficiencyTarget.Perception); Bump(9,m,ProficiencyTarget.Will); break;
            case "Oracle": Bump(7,m,ProficiencyTarget.Will); Bump(9,e,ProficiencyTarget.Fortitude); break;
            case "Thaumaturge": Bump(3,e,ProficiencyTarget.Reflex); Bump(7,m,ProficiencyTarget.Will); Bump(9,m,ProficiencyTarget.Perception); Bump(9,e,ProficiencyTarget.ClassDC); break;
            case "Bard": Bump(3,e,ProficiencyTarget.Reflex); Bump(9,e,ProficiencyTarget.Fortitude); Bump(9,m,ProficiencyTarget.Will); break;
            case "Psychic": Bump(5,e,ProficiencyTarget.Reflex); Bump(5,m,ProficiencyTarget.Will); Bump(9,e,ProficiencyTarget.Fortitude); break;
            case "Swashbuckler": Bump(3,e,ProficiencyTarget.Fortitude); Bump(7,m,ProficiencyTarget.Reflex); Bump(9,e,ProficiencyTarget.ClassDC); break;
            case "Summoner": Bump(3,e,ProficiencyTarget.Perception); Bump(9,e,ProficiencyTarget.Reflex); break;
        }
        return c;
    }

    internal static WeaponDefinition PowerfulFist() => new()
    {
        ItemName = "Powerful Fist", DamageDice = new DiceFormula(1,6,0), DamageType = DamageType.Bludgeoning,
        Category = WeaponCategory.Unarmed, Group = WeaponGroup.Brawling,
        Traits = new TraitCollection(new[] { new TraitDefinition { TraitId="agile",DisplayName="Agile" }, new TraitDefinition { TraitId="finesse",DisplayName="Finesse" }, new TraitDefinition { TraitId="unarmed",DisplayName="Unarmed" } }),
    };
}
