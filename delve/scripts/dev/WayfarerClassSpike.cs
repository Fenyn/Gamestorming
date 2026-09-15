using System.Linq;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Combat;
using Delve.Presets;
using Delve.Rules;
using Delve.Run;
using PF2e.Core;
using PF2e.Actions;
using PF2e.Spellcasting;
using PF2e.Data;
using PF2e.Utilities;
using V = PF2e.Vector2Int;

namespace Delve.Dev;

public partial class WayfarerClassSpike : SpikeBase
{
    protected override async Task RunSpikeAsync(DataManager data)
    {
        Check("all eighteen unique Bulwark identities",CharacterCatalog.All.Count==18 && CharacterCatalog.All.Select(c=>c.Id).Distinct().Count()==18);
        foreach (var spec in BulwarkWayfarers.All.Concat(new[] { BulwarkWayfarers.Raven,BulwarkWayfarers.Thistle }))
        {
            foreach (int level in new[] {1,2,5,10})
            {
                var c=PresetCharacters.BuildWayfarer(spec,level);
                Check($"{spec.Name} L{level}: native {spec.IntendedClass}",c.Stats.CharacterClass.ClassName==spec.IntendedClass && c.Stats.Level==level && c.Health.MaxHP>0);
                Check($"{spec.Name} L{level}: class actions reach the UI",c.Features.GetAllGrantedActions().Count>0 &&
                    c.Features.GetAllGrantedActions().All(a=>SkillActionCatalog.IdForGrantedAction(a.ActionName)!=null));
                if (c.Spellcasting!=null)
                    Check($"{spec.Name} L{level}: every available rank has usable spells",Enumerable.Range(1,9).All(r=>
                        c.Spellcasting.GetMaxSlots(r)==0 || (c.Spellcasting.IsPreparedCaster
                            ? c.Spellcasting.LeveledSpells.Any(s=>s.Spell.SpellLevel==r)
                            : c.Spellcasting.LeveledSpells.Any(s=>s.Spell.SpellLevel<=r))));
            }
            var live=PresetCharacters.BuildWayfarer(spec,1);
            PresetCharacters.LevelUpInPlace(live,5);
            var fresh=PresetCharacters.BuildWayfarer(spec,5);
            Check($"{spec.Name}: live progression matches fresh build",live.Health.MaxHP==fresh.Health.MaxHP &&
                Enumerable.Range(1,9).All(r=>(live.Spellcasting?.GetMaxSlots(r)??0)==(fresh.Spellcasting?.GetMaxSlots(r)??0)));
        }
        Check("full casters use their own key ability",Build("flick").Spellcasting.Sources[0].SpellcastingAbility==AbilityScore.Charisma &&
            Build("grub").Spellcasting.Sources[0].SpellcastingAbility==AbilityScore.Wisdom && Build("spore").Spellcasting.Sources[0].SpellcastingAbility==AbilityScore.Intelligence);
        Check("bounded casters lose old slot ranks",Build("sera",5).Spellcasting.GetMaxSlots(1)==0 && Build("hilde",5).Spellcasting.GetMaxSlots(3)==2);
        await CheckActions();
        await CheckSpellVariantBonus();
    }

    private static PF2eCharacter Build(string id,int level=2) => CharacterCatalog.Find(id)!.Builder(level);
    private static ClassAction Action(string id) => new(ClassActions.All.Single(a=>a.Id==id));
    private async Task CheckActions()
    {
        foreach (string id in new[] {"arkus","aldric","spore","josen","thistle","grub","sera","oskar","hazel","wynn","vasska","raven","hilde","flick"})
        {
            var hero=Build(id); var foe=PresetCharacters.BuildRecruit(2,teamId:2);
            foe.Health.OverrideMaxHP(1000); foe.Health.SetCurrentHP(1000);
            var session=new CombatSession();
            session.Setup(new CombatSetup { Party=new() {(hero,new V(3,3))}, Enemies=new() {(foe,new V(4,3))} });
            try
            {
                CombatantRegistry.Instance.Register(hero); CombatantRegistry.Instance.Register(foe);
                var s=WayfarerFeature.State(hero);
                if (id=="hilde")
                {
                    var link=EidolonLink.For(hero)!;
                    Check("eidolon manifests as a distinct unit with shared HP/actions/MAP",session.Team1.Count==2 && ReferenceEquals(hero.Health,link.Eidolon.Health) && ReferenceEquals(hero.Actions,link.Eidolon.Actions) && ReferenceEquals(hero.Combat,link.Eidolon.Combat));
                    await Action("eidolon-advance").ExecuteAsync(hero,foe);
                    Check("eidolon movement spends summoner action",hero.Actions.TotalActionsRemaining==2);
                    await Action("act-together").ExecuteAsync(hero,foe);
                    Check("Act Together pairs a spell and eidolon Strike for two actions",hero.Actions.TotalActionsRemaining==0 && s.ActTogetherUsed && hero.Combat.AttacksMadeThisTurn==1);
                    hero.Health.SetCurrentHP(hero.Health.MaxHP);
                    var area=new SpellCastAction { SpellId="linked-damage-fixture",ActionName="Linked damage fixture",ActionCostCount=1,
                        Spell=new SpellDefinition { SpellLevel=0,DefenseType=SpellDefenseType.None,DamageFormula=new DiceFormula(1,1,9),DamageType=DamageType.Fire } };
                    await area.ExecuteMultiTargetAsync(foe,new() {hero,link.Eidolon});
                    Check("one area effect hitting both bodies damages the shared pool once",hero.Health.CurrentHP==hero.Health.MaxHP-10);
                    hero.Actions.RefillActions();
                    hero.Health.SetCurrentHP(hero.Health.MaxHP-20);
                    var healing=new SpellCastAction { SpellId="linked-heal-fixture",ActionName="Linked healing fixture",ActionCostCount=1,
                        Spell=new SpellDefinition { SpellLevel=0,DefenseType=SpellDefenseType.None,HealingFormula=new DiceFormula(1,1,9) } };
                    await healing.ExecuteMultiTargetAsync(hero,new() {hero,link.Eidolon});
                    Check("one area heal affecting both bodies heals the shared pool once",hero.Health.CurrentHP==hero.Health.MaxHP-10);
                    continue;
                }
                string actionId=id switch
                {
                    "arkus"=>"rage","aldric"=>"lay-on-hands","spore"=>"clinging-ice","josen"=>"flurry-of-blows",
                    "thistle"=>"hunt-prey","grub"=>"cornucopia","sera"=>"spellstrike","oskar"=>"weapon-trance",
                    "hazel"=>"chalice","wynn"=>"courageous-anthem","vasska"=>"amped-daze","raven"=>"confident-finisher",_=>"elemental-toss",
                };
                var action=Action(actionId); if (id=="raven") s.Panache=true;
                hero.Health.SetCurrentHP(1);
                int focus=hero.Spellcasting?.CurrentFocusPoints??0;
                Check($"{id}: signature action is available",action.CanPerform(hero,action.Spec.Ally?hero:action.RequiresTarget?foe:null!));
                await action.ExecuteAsync(hero,action.Spec.Ally?hero:action.RequiresTarget?foe:null!);
                Check($"{id}: signature action spends correct actions",hero.Actions.TotalActionsRemaining==3-action.Spec.Cost);
                if (action.Spec.Focus>0) Check($"{id}: signature action spends focus",hero.Spellcasting!.CurrentFocusPoints==focus-1);
                if (id is "aldric" or "grub" or "hazel") Check($"{id}: class healing changes HP",hero.Health.CurrentHP>1);
                if (id=="arkus") Check("rage grants temporary HP",s.Raging && hero.Health.TempHP>0);
                if (id=="josen") Check("flurry accrues two attacks and locks flourish",hero.Combat.AttacksMadeThisTurn==2 && !action.CanPerform(hero,foe));
                if (id=="thistle") Check("hunt prey records chosen target",s.Prey==foe);
                if (id=="sera")
                {
                    Check("spellstrike discharges and accrues two attacks",!s.SpellstrikeReady && hero.Combat.AttacksMadeThisTurn==2);
                    await Action("recharge-spellstrike").ExecuteAsync(hero);
                    Check("recharge restores spellstrike",s.SpellstrikeReady && hero.Actions.TotalActionsRemaining==0);
                }
                if (id=="raven") Check("finisher consumes panache and locks attacks",!s.Panache && s.FinisherUsed);
                if (id=="oskar") Check("weapon trance grants martial proficiency",s.WeaponTrance && hero.Stats.CharacterClass.MartialWeaponProficiency==ProficiencyLevel.Trained);
            }
            finally { session.Teardown(); }
            Check($"{id}: encounter class state cleaned",!WayfarerFeature.State(hero).Raging && WayfarerFeature.State(hero).Prey==null);
        }
    }
    private async Task CheckSpellVariantBonus()
    {
        var hero=Build("flick");
        hero.Health.OverrideMaxHP(100); hero.Health.SetCurrentHP(40);
        var variant=new SpellCostVariant { Label="Test healing",ActionCost=1,HealingFormula=new DiceFormula(1,1,9),
            TargetMode=TargetMode.Allies,CanTargetSelf=true,RangeInFeet=30 };
        var original=new SpellCastAction { SpellId="potency-variant-fixture",ActionName="Potency fixture",ActionCostCount=1,
            Spell=new SpellDefinition { SpellLevel=1,DefenseType=SpellDefenseType.None,CostVariants=new() {variant} } };
        var action=new NativeSpell(original,"Sorcerer");
        action.ApplyVariant(variant);
        await action.ExecuteAsync(hero,hero);
        Check("Sorcerous Potency applies to variable-action healing",hero.Health.CurrentHP==51);
        Check("class spell bonus leaves canonical variant immutable",variant.HealingFormula.Modifier==9 && ReferenceEquals(action.Spell,original.Spell));
    }

}
