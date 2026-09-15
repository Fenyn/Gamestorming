using System;
using System.Collections.Generic;
using System.Linq;
using Delve.Presets;
using PF2e.Actions;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Data;
using PF2e.RuleEvents;
using PF2e.RuleEvents.Contexts;
using PF2e.Utilities;

namespace Delve.Rules;

/// <summary>Character-owned passive feat handlers. Action and encounter consumers use the same IDs.</summary>
public sealed class RosterFeatRules(string id) : CharacterFeature,
    IRuleEventHandler<HealingRollContext>, IRuleEventHandler<DisruptionContext>,
    IRuleEventHandler<DamageMitigationContext>, IRuleEventHandler<SavingThrowContext>,
    IRuleEventHandler<DamageRollContext>, IRuleEventHandler<AttackRollContext>
{
    private ICharacter? _owner;
    private bool _addedFocus,_addedCantrips;
    public override void OnGranted(ICharacter c,RuleEventBus bus)
    {
        _owner=c;
        if (id=="cantrip-expansion" && c is PF2eCharacter pc)
        { pc.Spellcasting.Sources[0].CantripsKnown+=2; _addedCantrips=true; FeatCantrips.Apply(pc); }
        bus.Subscribe<HealingRollContext>(this,RuleEventPriority.Bonus);
        bus.Subscribe<DisruptionContext>(this,RuleEventPriority.Bonus);
        bus.Subscribe<DamageMitigationContext>(this,RuleEventPriority.Bonus);
        bus.Subscribe<SavingThrowContext>(this,RuleEventPriority.Bonus);
        bus.Subscribe<DamageRollContext>(this,RuleEventPriority.Bonus);
        bus.Subscribe<AttackRollContext>(this,RuleEventPriority.Bonus);
        if (id=="basic-lesson" && c.Spellcasting.MaxFocusPoints<3) { c.Spellcasting.IncrementMaxFocusPoints(1); _addedFocus=true; }
    }
    public override void OnRevoked(ICharacter c,RuleEventBus bus)
    {
        bus.Unsubscribe<HealingRollContext>(this); bus.Unsubscribe<DisruptionContext>(this);
        bus.Unsubscribe<DamageMitigationContext>(this); bus.Unsubscribe<SavingThrowContext>(this);
        bus.Unsubscribe<DamageRollContext>(this); bus.Unsubscribe<AttackRollContext>(this);
        if (_addedFocus) { c.Spellcasting.DecrementMaxFocusPoints(1); _addedFocus=false; }
        if (_addedCantrips && c is PF2eCharacter pc) { pc.Spellcasting.Sources[0].CantripsKnown-=2; FeatCantrips.Remove(pc); _addedCantrips=false; }
        _owner=null;
    }
    public void HandleEvent(HealingRollContext ctx)
    {
        if (id!="healing-hands" || ctx.Caster!=_owner || !ctx.SourceSpell.SpellId.StartsWith("preset-heal")) return;
        var f=ctx.ModifiedFormula;
        if (f.DieSize==8) ctx.ModifiedFormula=new DiceFormula(f.NumberOfDice,10,f.Modifier);
    }
    public void HandleEvent(DisruptionContext ctx)
    {
        if (id!="steady-spellcasting" || ctx.Target!=_owner || ctx.Prevented) return;
        if (DiceRoller.RollD20()<15) return;
        ctx.Prevented=true; ctx.PreventionSource="Steady Spellcasting";
    }
    public void HandleEvent(DamageMitigationContext ctx)
    {
        if (ctx.Target!=_owner || _owner==null) return;
        int resistance=id switch
        {
            "mental-buffer" when ctx.DamageResult.DamageType==DamageType.Mental => WayfarerFeature.State(_owner).PsycheTurns>0 ? _owner.StatProvider.Level : Math.Max(1,_owner.StatProvider.Level/2),
            "poison-resistance" when ctx.DamageResult.DamageType==DamageType.Poison => _owner.StatProvider.Level/2,
            _=>0,
        };
        ctx.DamageReduction=Math.Max(ctx.DamageReduction,resistance);
    }
    public void HandleEvent(SavingThrowContext ctx)
    {
        if (ctx.Saver!=_owner || _owner==null) return;
        var traits=ctx.SourceAction?.Traits;
        if (id=="poison-resistance" && traits?.HasTraitById("poison")==true) ctx.Modifiers.Add(ModifierType.Status,1);
        if (id=="well-versed" && new[] {"auditory","illusion","linguistic","sonic","visual"}.Any(t=>traits?.HasTraitById(t)==true))
            ctx.Modifiers.Add(ModifierType.Circumstance,1);
        var s=FeatEncounter.State(_owner);
        if (id=="esoteric-warden" && s.WardTarget==ctx.Source && s.WardSave>0)
        { ctx.Modifiers.Add(ModifierType.Status,s.WardSave); s.WardSave=0; }
        if (id=="spell-parry" && s.Parrying && ctx.SourceAction is SpellAction)
            ctx.Modifiers.Add(ModifierType.Circumstance,1);
    }
    public void HandleEvent(AttackRollContext ctx)
    {
        if (_owner==null) return;
        var s=FeatEncounter.State(_owner);
        if (ctx.Defender==_owner && id=="esoteric-warden" && s.WardTarget==ctx.Attacker && s.WardAC>0)
        { int existing=_owner.Modifiers.GetAllModifiers(StatType.AC).Where(m=>m.Type==ModifierType.Status).Select(m=>m.Value).DefaultIfEmpty(0).Max(); ctx.DefenderACBonus+=Math.Max(0,s.WardAC-existing); s.WardAC=0; }
        if (ctx.Attacker!=_owner) return;
        if (id=="combination-finisher" && WayfarerFeature.State(_owner).ResolvingFinisher)
        {
            int n=_owner.Combat.AttacksMadeThisTurn;
            int desired=n==0?0:-(ctx.StrikeHasTrait("agile")?3:4)*Math.Min(2,n);
            ctx.Modifiers.Add(ModifierType.Untyped,desired-ctx.MAP);
        }
        if (id=="hunters-aim" && s.Aiming) ctx.Modifiers.Add(ModifierType.Circumstance,2);
        if (id=="deadly-aim" && s.DeadlyAim) ctx.Modifiers.Add(ModifierType.Untyped,-2);
    }
    public void HandleEvent(DamageRollContext ctx)
    {
        if (_owner==null || ctx.Attacker!=_owner) return;
        var s=FeatEncounter.State(_owner);
        if (id=="psi-strikes" && s.PsiStrikes && ctx.Weapon==s.PsiWeapon && (s.PsiTurns==s.Turn || s.PsiUnleashed && WayfarerFeature.State(_owner).PsycheTurns>0))
            ctx.BonusDamage.Add(new BonusDamage { Source="Psi Strikes",Dice=new DiceFormula(1,6,0),Type=DamageType.Force,DoublesOnCrit=true });
    }
}
