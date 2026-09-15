using System.Collections.Generic;
using PF2e.Actions;
using PF2e.Data;
using PF2e.Spellcasting;

namespace Delve.Data;

public static partial class PresetSpells
{
    // Prepared casters need distinct, immutable preparations at each rank. Never change a shared
    // spell's rank to fill a slot: another character may be casting that same canonical spell.
    public static SpellCastAction AtRank(SpellCastAction original, int rank)
    {
        if (rank == original.Spell.SpellLevel) return original;
        string id = $"{original.SpellId}-rank-{rank}";
        if (_byId.TryGetValue(id, out var found)) return found;
        var s = original.Spell;
        var definition = new SpellDefinition
        {
            Identity = s.Identity, SpellLevel = rank, Traditions = new(s.Traditions),
            DefenseType = s.DefenseType, SaveType = s.SaveType, DamageType = s.DamageType,
            DamageFormula = s.GetEffectiveDamage(rank), HealingFormula = s.GetEffectiveHealing(rank),
            BonusFlatHealing = s.BonusFlatHealing,
            DamageOnCritSuccess = s.DamageOnCritSuccess, DamageOnSuccess = s.DamageOnSuccess,
            DamageOnFailure = s.DamageOnFailure, DamageOnCritFailure = s.DamageOnCritFailure,
            ConditionEffect = s.ConditionEffect, Duration = s.Duration, DurationValue = s.DurationValue,
            HeightenIncrement = s.HeightenIncrement, HeightenBonusDamage = s.HeightenBonusDamage,
            HeightenBonusHealing = s.HeightenBonusHealing, HeightenBonusFlatValue = s.HeightenBonusFlatValue,
        };
        if (s.CostVariants != null)
        {
            definition.CostVariants = new();
            foreach (var v in s.CostVariants) definition.CostVariants.Add(new SpellCostVariant
            {
                Label = v.Label, TargetNoun = v.TargetNoun, IsAreaEffect = v.IsAreaEffect, IsSelfCentered = v.IsSelfCentered,
                ChannelDualEffect = v.ChannelDualEffect, ChannelDamageType = v.ChannelDamageType, ActionCost = v.ActionCost, RangeInFeet = v.RangeInFeet, TargetMode = v.TargetMode,
                CanTargetSelf = v.CanTargetSelf, MaxTargets = v.MaxTargets, AllowDuplicateTargets = v.AllowDuplicateTargets,
                Area = v.Area, HealingFormula = v.GetEffectiveHealing(s,rank), DamageFormula = v.GetEffectiveDamage(s,rank),
                HeightenBonusFlat = v.HeightenBonusFlat, HeightenBonusDamage = v.HeightenBonusDamage,
            });
        }
        var spell = new SpellCastAction
        {
            SpellId = id, ActionName = $"{original.ActionName} (rank {rank})", Description = original.Description,
            Spell = definition, ActionCostCount = original.ActionCostCount, Traits = original.Traits,
            Area = original.Area, TargetMode = original.TargetMode, RequiresTarget = original.RequiresTarget,
            CanTargetSelf = original.CanTargetSelf, MaxTargets = original.MaxTargets,
            RequiresAreaTarget = original.RequiresAreaTarget, AllowDuplicateTargets = original.AllowDuplicateTargets,
        };
        _byId[id] = spell;
        var db = SpellDatabase.Instance;
        db.Spells.Add(spell);
        SpellDatabase.Instance = db;
        return spell;
    }
}
