using System;
using System.Linq;
using System.Threading.Tasks;
using PF2e.Actions;
using PF2e.Actions.SkillActions;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Events;
using PF2e.Utilities;

namespace Delve.Rules;

public sealed class ClassAction : BaseAction
{
    public ClassActionSpec Spec { get; }
    public ClassAction(ClassActionSpec spec)
    {
        Spec = spec; ActionName = spec.Name; Description = spec.Description; ActionCostCount = spec.Cost;
        IsFreeAction = spec.Cost == 0; RequiresTarget = spec.Range > 0;
        TargetMode = spec.Ally ? TargetMode.Allies : TargetMode.Enemies; CanTargetSelf = spec.Ally;
        Traits = new TraitCollection();
        if (spec.Id is "recharge-spellstrike" or "hunt-prey" or "exploit-vulnerability")
            Traits.AddTrait(new TraitDefinition { TraitId = "concentrate", DisplayName = "Concentrate" });
    }

    public override bool CanPerform(ICharacter actor, ICharacter target = null!)
    {
        if (WayfarerFeature.Find(actor)?.Class != Spec.Class || !base.CanPerform(actor,target)) return false;
        if (Spec.Focus > 0 && actor.Spellcasting?.HasFocusPoints != true) return false;
        if (Spec.Id=="life-boost" && !Delve.Presets.RosterFeats.Has(actor,"basic-lesson")) return false;
        if (target != null)
        {
            if (target.Health?.IsDead != false || (Spec.Ally != (target.TeamId == actor.TeamId))) return false;
            if (actor != target && !FlankingCalculator.IsWithinReach(actor.GridPosition,actor.TileWidth,target.GridPosition,target.TileWidth,SpellReach.ClassRange(actor,Spec))) return false;
        }
        var s = WayfarerFeature.State(actor);
        return Spec.Id switch
        {
            "lingering-composition" => !s.LingeringUsed,
            "weapon-trance" => !s.WeaponTrance,
            "dimensional-assault" => target == null || TeleportDestination(actor,target).HasValue,
            "rage" => !s.Raging,
            "flurry-of-blows" => !actor.Combat.UsedFlourishThisTurn,
            "hunt-prey" or "exploit-vulnerability" => target == null || s.Prey != target,
            "spellstrike" => s.SpellstrikeReady,
            "recharge-spellstrike" => !s.SpellstrikeReady,
            "arcane-cascade" => !s.Cascade && (actor.Combat.CastSpellThisTurn || s.SpellCastThisTurn),
            "clinging-ice" or "life-boost" => !s.HexUsed,
            "chalice" => !s.ChaliceDrained,
            "unleash-psyche" => s.CastLastTurn && s.PsycheTurns == 0 && s.PsycheRecovery == 0,
            "confident-finisher" => s.Panache && !s.FinisherUsed,
            "act-together" => !s.ActTogetherUsed && EidolonLink.For(actor)?.CanStrike(target)==true,
            "eidolon-strike" => EidolonLink.For(actor)?.CanStrike(target) == true,
            "eidolon-advance" or "boost-eidolon" => EidolonLink.For(actor)?.CanAct == true,
            _ => true,
        };
    }

    public override void Execute(ICharacter actor, ICharacter target = null!) => ReactionSuspension.Track(ExecuteAsync(actor,target));
    public override async Task ExecuteAsync(ICharacter actor, ICharacter target = null!)
    {
        if (!CanPerform(actor,target) || (RequiresTarget && target == null)) return;
        var s = WayfarerFeature.State(actor);
        if (ClassMagic.Build(Spec, actor) is { } spell)
        {
            if (Spec.Id == "clinging-ice") s.HexUsed = true;
            await spell.ExecuteAsync(actor,target);
            return;
        }
        if (Spec.Id == "braggarts-boast")
        {
            int before = target.Conditions.GetConditionValue(Condition.Frightened);
            await new BraggartDemoralize { ActionName = "Demoralize", ActionCostCount = 1 }.ExecuteAsync(actor,target);
            if (target.Conditions.GetConditionValue(Condition.Frightened) > before) WayfarerFeature.SetPanache(actor,true);
            return;
        }
        if (Spec.Id=="eidolon-advance")
        {
            await EidolonLink.For(actor)!.Advance(target);
            return; // Stride consumes the shared action and publishes movement/reaction events.
        }
        if (!TryConsumeCost(actor)) return;
        if (Spec.Focus > 0) actor.Spellcasting.ConsumeFocusPoint();
        int level = actor.StatProvider.Level, rank = (level + 1) / 2;
        switch (Spec.Id)
        {
            case "rage": EnterRage(actor); break;
            case "lay-on-hands": target.Health.Heal(6*rank); s.Buff(target,"Lay on Hands",StatType.AC,2); break;
            case "life-boost": s.HexUsed = true; s.Regeneration.Add(new(target,2*rank,4)); break;
            case "cornucopia": target.Health.Heal(DiceRoller.Roll(new DiceFormula(rank,6,4*rank)).Total); break;
            case "flurry-of-blows":
                actor.Combat.MarkFlourishUsed();
                bool damaged=false;
                void FlurryHit(StrikeContext hit) { damaged |= hit.DamageResult?.TotalDamage>0; }
                await StrikeResolver.ExecuteStrike(actor,target,this,onHit:FlurryHit);
                if (target.Health.IsAlive && actor.Health.IsAlive) await StrikeResolver.ExecuteStrike(actor,target,this,onHit:FlurryHit);
                if (damaged && target.Health.IsAlive && Delve.Presets.RosterFeats.Has(actor,"stunning-blows")) await StunningBlows.Resolve(actor,target,this);
                break;
            case "hunt-prey": s.Prey = target; break;
            case "spellstrike":
                s.SpellstrikeReady = false; s.Spellstriking = true; s.SpellCastThisTurn = true;
                try { await StrikeResolver.ExecuteStrike(actor,target,this); }
                finally { s.Spellstriking = false; actor.Combat.IncrementAttackCount(); }
                break;
            case "weapon-trance":
                s.WeaponTrance = true; s.TranceUntil = s.Turns+10;
                actor.Stats.CharacterClass.MartialWeaponProficiency = actor.Stats.CharacterClass.SimpleWeaponProficiency;
                break;
            case "dimensional-assault":
                var landing = TeleportDestination(actor,target);
                if (landing.HasValue) PF2e.Utilities.ForcedMovementExecutor.Grid.MoveCreature(actor,landing.Value);
                s.SpellstrikeReady=true; s.SpellCastThisTurn=true;
                await StrikeResolver.ExecuteStrike(actor,target,this);
                break;
            case "recharge-spellstrike": s.SpellstrikeReady = true; break;
            case "arcane-cascade": s.Cascade = true; break;
            case "exploit-vulnerability":
                int[] dc = {14,15,16,18,19,20,22,23,24,26,27};
                var check = SkillCheckResolver.ResolveVsDC(actor,Skill.Occultism,dc[Math.Clamp(target.StatProvider.Level,0,10)],false,this,
                    baseBonusOverride:level+2+(level>=7?4:level>=3?2:0)+(actor.Stats.Charisma-10)/2,checkLabel:"Esoteric Lore");
                FeatEncounter.Ward(actor,target,check.Degree);
                if (check.Degree != DegreeOfSuccess.CriticalFailure) s.Prey = target;
                break;
            case "chalice": s.ChaliceDrained = true; target.Health.Heal(3*level); break;
            case "lingering-composition":
                s.LingeringUsed=true;
                int[] performanceDc={14,15,16,18,19,20,22,23,24,26,27};
                var performance=SkillCheckResolver.ResolveVsDC(actor,Skill.Performance,performanceDc[Math.Clamp(level,0,10)],false,this);
                s.NextAnthemRounds=performance.Degree==DegreeOfSuccess.CriticalSuccess?4:performance.Degree==DegreeOfSuccess.Success?3:1;
                if (s.NextAnthemRounds==1) actor.Spellcasting.RestoreFocusPoint();
                break;
            case "courageous-anthem":
                s.ClearBuffs();
                s.BuffsExpireAt=s.Turns+s.NextAnthemRounds; s.NextAnthemRounds=1;
                foreach (var ally in Delve.Combat.CombatantQuery.TargetsInRange(actor,12,false))
                { s.Buff(ally,"Courageous Anthem",StatType.AttackRoll,1); s.Buff(ally,"Courageous Anthem",StatType.DamageDealt,1); s.FearSaves(ally); }
                break;
            case "unleash-psyche": s.PsycheTurns = 2; FeatEncounter.State(actor).UnleashSequence=actor.Combat.ActionSequence; break;
            case "confident-finisher":
                s.ResolvingFinisher = true;
                try
                {
                    bool failed = false;
                    await StrikeResolver.ExecuteStrike(actor,target,this,onMiss: ctx =>
                    {
                        failed = ctx.Degree == DegreeOfSuccess.Failure;
                    });
                    if (failed)
                    {
                        int damage = DiceRoller.Roll(new DiceFormula(2+(level>=5?1:0)+(level>=9?1:0),6,0)).Total/(Delve.Presets.RosterFeats.Has(actor,"precise-finisher")?1:2);
                        await ReactionEvents.DeliverDamage(actor,target,new DamageResult { TotalDamage=damage,DamageType=DamageType.Piercing,PrecisionDamage=damage });
                    }
                }
                finally { WayfarerFeature.SetPanache(actor,false); s.ResolvingFinisher = false; s.FinisherUsed = true; }
                break;
            case "act-together":
                s.ActTogetherUsed=true;
                var arc=Delve.Data.PresetSpells.Get(Delve.Data.PresetSpells.ElectricArcId)!;
                var linkedSpell=new SpellCastAction { SpellId="act-together-arc",ActionName="Act Together: Electric Arc",Spell=arc.Spell,
                    ActionCostCount=0,IsFreeAction=true,RequiresTarget=true,TargetMode=TargetMode.Enemies,Area=arc.Area };
                await linkedSpell.ExecuteAsync(actor,target);
                if (target.Health.IsAlive && actor.Health.IsAlive) await EidolonLink.For(actor)!.Strike(target,this);
                break;
            case "eidolon-strike": await EidolonLink.For(actor)!.Strike(target,this); break;

            case "evolution-surge":
                EidolonLink.For(actor)!.Surge(); break;
            case "boost-eidolon": FeatEncounter.State(actor).Reinforced=false; EidolonLink.For(actor)!.Eidolon.Modifiers.RemoveModifier(FeatEncounter.State(actor).BuffId); s.Buff(EidolonLink.For(actor)!.Eidolon,"Boost Eidolon",StatType.DamageDealt,2); break;
        }
        CombatLog.Emit($"{actor.Name}: {ActionName}");
    }

    private static PF2e.Vector2Int? TeleportDestination(ICharacter actor,ICharacter target)
    {
        var grid=PF2e.Utilities.ForcedMovementExecutor.Grid;
        if (grid==null) return null;
        int range=Math.Max(1,Delve.Combat.MovementActions.SpeedInTiles(actor)/2);
        for (int dx=-1;dx<=target.TileWidth;dx++)
            for (int dy=-1;dy<=target.TileWidth;dy++)
            {
                var p=target.GridPosition+new PF2e.Vector2Int(dx,dy);
                if (Math.Max(Math.Abs(p.x-actor.GridPosition.x),Math.Abs(p.y-actor.GridPosition.y))<=range && grid.CanCreatureFit(p,actor.TileWidth,ignore:actor)) return p;
            }
        return null;
    }

    public static string? Restriction(ICharacter actor, BaseAction action)
    {
        var s=WayfarerFeature.State(actor);
        bool attack=action is StrikeAction || action.Traits?.HasTraitById("attack")==true ||
            action.ActionName is "Trip" or "Shove" or "Disarm" or "Grapple";
        if (s.FinisherUsed && attack) return "A finisher prevents further attacks this turn";
        if (s.Raging && (action is SpellAction || action.Traits?.HasTraitById("concentrate")==true || action.ActionName is "Demoralize" or "Recall Knowledge"))
            return "Cannot concentrate while raging";
        return null;
    }

    public static void EnterRage(ICharacter actor)
    {
        var s = WayfarerFeature.State(actor);
        if (s.Raging) return;
        s.Raging = true;
        actor.Health.GrantTempHP(actor.StatProvider.Level + (actor.Stats.Constitution-10)/2,s,10);
    }
}
