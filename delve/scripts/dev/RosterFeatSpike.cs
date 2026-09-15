using System.Linq;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Combat;
using Delve.Data;
using Delve.Presets;
using Delve.Rules;
using Delve.Run;
using PF2e.Actions;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Events;
using PF2e.RuleEvents;
using PF2e.RuleEvents.Contexts;
using PF2e.Utilities;
using V=PF2e.Vector2Int;

namespace Delve.Dev;

public partial class RosterFeatSpike : SpikeBase
{
    protected override async Task RunSpikeAsync(DataManager data)
    {
        foreach(var spec in CharacterCatalog.All)
        {
            var live=spec.Builder(1);
            for(int level=1;level<=10;level++)
            {
                if(level>1) PresetCharacters.LevelUpInPlace(live,level);
                var fresh=spec.Builder(level);
                var expected=RosterFeats.Tracks[spec.Id].Where(p=>p.Level<=level).Select(p=>p.Id).Order().ToArray();
                string[] Feats(PF2eCharacter c)=>c.Features.ChosenFeats.Where(f=>f.Feature.Category==FeatureCategory.ClassFeat).Select(f=>f.Feature.FeatureId.Replace('_','-')).Order().ToArray();
                Check($"{spec.Id} L{level}: fresh and live feat grants",expected.SequenceEqual(Feats(fresh)) && expected.SequenceEqual(Feats(live)));
                Check($"{spec.Id} L{level}: legal levels and player action mapping",fresh.Features.ChosenFeats.All(f=>f.Level>=f.Feature.LevelRequirement) &&
                    fresh.Features.GetAllGrantedActions().All(a=>SkillActionCatalog.IdForGrantedAction(a.ActionName)!=null));
                RosterFeats.Apply(live);
                Check($"{spec.Id} L{level}: repeat application is idempotent",expected.SequenceEqual(Feats(live)));
            }
            Check($"{spec.Id}: at least three authored class feats by L10",RosterFeats.Tracks[spec.Id].Length>=3);
        }
        foreach(var id in new[]{"fenwick","sera","oskar","flick"})
        {
            int at=RosterFeats.Tracks[id].Single(p=>p.Id=="cantrip-expansion").Level;
            var before=CharacterCatalog.Find(id)!.Builder(at-1); var after=CharacterCatalog.Find(id)!.Builder(at);
            Check($"{id}: Expansion adds two distinct cantrips",after.Spellcasting.Cantrips.Select(s=>s.SpellId).Distinct().Count()==before.Spellcasting.Cantrips.Select(s=>s.SpellId).Distinct().Count()+2);
        }
        var healer=CharacterCatalog.Find("tharr")!.Builder(2);
        var heal=new HealingRollContext { Caster=healer,SourceSpell=PresetSpells.Get(PresetSpells.HealId),BaseFormula=new DiceFormula(2,8,16) };
        healer.RuleEvents.Publish(heal);
        Check("Healing Hands upgrades dice without changing flat healing",heal.ModifiedFormula.DieSize==10 && heal.ModifiedFormula.NumberOfDice==2 && heal.ModifiedFormula.Modifier==16);
        var psychic=CharacterCatalog.Find("vasska")!.Builder(10);
        var incoming=new DamageMitigationContext { Target=psychic,DamageResult=new DamageResult { TotalDamage=20,DamageType=DamageType.Mental } };
        psychic.RuleEvents.Publish(incoming);
        Check("Mental Buffer scales with level",incoming.DamageReduction==5);
        WayfarerFeature.State(psychic).PsycheTurns=2;
        incoming.DamageReduction=0; psychic.RuleEvents.Publish(incoming);
        Check("Mental Buffer strengthens during Unleash",incoming.DamageReduction==10);
        var spore=CharacterCatalog.Find("spore")!.Builder(2);
        int focus=spore.Spellcasting.MaxFocusPoints;
        var lesson=spore.Features.GetFeatureById("basic-lesson");
        spore.Features.RevokeFeature(lesson);
        Check("revoking Basic Lesson removes its focus contribution",spore.Spellcasting.MaxFocusPoints==focus-1);
        spore.Features.ResolveAndGrantFeatures();
        Check("regranting Basic Lesson restores one focus contribution",spore.Spellcasting.MaxFocusPoints==focus);
        var expanded=CharacterCatalog.Find("flick")!.Builder(2);
        int cantrips=expanded.Spellcasting.Cantrips.Count;
        expanded.Features.RevokeFeature(expanded.Features.GetFeatureById("cantrip-expansion"));
        Check("revoking Expansion removes its two cantrips",expanded.Spellcasting.Cantrips.Count==cantrips-2);
        expanded.Features.ResolveAndGrantFeatures();
        Check("regranting Expansion restores exactly two cantrips",expanded.Spellcasting.Cantrips.Count==cantrips);
        await CheckEncounter();
    }
    private async Task CheckEncounter()
    {
        var wizard=CharacterCatalog.Find("fenwick")!.Builder(10);
        var summoner=CharacterCatalog.Find("hilde")!.Builder(10);
        var champion=CharacterCatalog.Find("aldric")!.Builder(10);
        var foe=PresetCharacters.BuildRecruit(2,teamId:2);
        foe.Health.OverrideMaxHP(1000); foe.Health.SetCurrentHP(1000);
        var session=new CombatSession();
        session.Setup(new CombatSetup { Party=new() {(wizard,new V(2,2)),(summoner,new V(3,3)),(champion,new V(3,4))},Enemies=new() {(foe,new V(4,3))} });
        try
        {
            await new RosterFeatAction("reach-spell").ExecuteAsync(wizard);
            Check("Reach costs an action and extends 30 feet",wizard.Actions.TotalActionsRemaining==2 && SpellReach.Feet(wizard,30)==60 && SpellReach.Feet(wizard,0)==30);
            wizard.Actions.TryConsumeActions(1);
            Check("intervening action invalidates Reach",!SpellReach.Pending(wizard));
            var link=EidolonLink.For(summoner)!;
            Check("eidolon gains its reaction without an independent action pool",RosterFeats.Has(link.Eidolon,"eidolons-opportunity") && ReferenceEquals(link.Eidolon.Actions,summoner.Actions));
            int ac=StatsCalculator.CalculateAC(link.Eidolon);
            await new RosterFeatAction("reinforce-eidolon").ExecuteAsync(summoner);
            Check("Reinforce raises eidolon AC",StatsCalculator.CalculateAC(link.Eidolon)==ac+1);
            summoner.Health.SetCurrentHP(summoner.Health.MaxHP);
            await ReactionEvents.DeliverDamage(foe,link.Eidolon,new DamageResult { TotalDamage=10,DamageType=DamageType.Fire });
            Check("Reinforce resists damage to the eidolon",summoner.Health.CurrentHP==summoner.Health.MaxHP-8);
            int hp=summoner.Health.CurrentHP;
            await ReactionEvents.DeliverDamage(foe,summoner,new DamageResult { TotalDamage=10,DamageType=DamageType.Fire });
            Check("Reinforce does not grant summoner the eidolon's resistance",summoner.Health.CurrentHP==hp-10);
            var turns=PF2e.TurnManagement.TurnManager.Instance;
            turns.StartEncounterWithFixedOrder(new(){champion,foe,summoner,wizard});
            Check("Quick Shield Block grants its restricted reaction on turn start",champion.Actions.HasBonusReaction(BonusReactionType.ShieldBlock));
            champion.Actions.TryConsumeReactionFor(BonusReactionType.ShieldBlock);
            Check("bonus Shield Block preserves the normal reaction",champion.Actions.ReactionAvailable && !champion.Actions.HasBonusReaction(BonusReactionType.ShieldBlock));
            turns.AdvanceToCharacter(summoner);
            Check("Reinforce expires on summoner turn start",!FeatEncounter.State(summoner).Reinforced && StatsCalculator.CalculateAC(link.Eidolon)==ac);
        }
        finally {session.Teardown();}
        Check("feat encounter state and buffs are cleared",!FeatEncounter.State(summoner).Reinforced && !SpellReach.Pending(wizard));
    }
}
