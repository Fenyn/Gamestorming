using System;
using System.Collections.Generic;
using System.Linq;
using Delve.Rules;
using PF2e.Actions;
using PF2e.Core;
using PF2e.Data;
using PF2e.RuleEvents;
using PF2e.RuleEvents.Features;

namespace Delve.Presets;

/// <summary>Authored class-feat selections. These use chosen-feat slots, never Free Archetype slots.
/// Each factory creates a character-owned feature; resolving a build again cannot duplicate it.</summary>
public static class RosterFeats
{
    public sealed record Pick(int Level,string Id);
    public static readonly IReadOnlyDictionary<string,Pick[]> Tracks = new Dictionary<string,Pick[]>
    {
        ["player"] = [new(1,"sudden-charge"),new(2,"lunge"),new(4,"shielded-stride"),new(6,"reflexive-shield"),new(8,"quick-shield-block"),new(10,"intimidating-strike")],
        ["elara"] = [new(1,"nimble-dodge"),new(2,"mobility"),new(4,"dread-striker"),new(6,"gang-up"),new(8,"opportune-backstab"),new(10,"sly-striker")],
        ["tharr"] = [new(2,"healing-hands"),new(6,"steady-spellcasting"),new(10,"reach-spell")],
        ["fenwick"] = [new(2,"cantrip-expansion"),new(6,"steady-spellcasting"),new(10,"reach-spell")],
        ["arkus"] = [new(1,"sudden-charge"),new(6,"reactive-strike"),new(10,"renewed-vigor")],
        ["aldric"] = [new(2,"divine-grace"),new(6,"reactive-strike"),new(10,"quick-shield-block")],
        ["spore"] = [new(2,"basic-lesson"),new(6,"steady-spellcasting"),new(10,"reach-spell")],
        ["josen"] = [new(2,"stunning-blows"),new(6,"guarded-movement"),new(10,"stand-still")],
        ["thistle"] = [new(2,"hunters-aim"),new(6,"scouts-warning"),new(10,"deadly-aim")],
        ["grub"] = [new(2,"poison-resistance"),new(6,"steady-spellcasting"),new(10,"reach-spell")],
        ["sera"] = [new(2,"spell-parry"),new(6,"reactive-strike"),new(10,"cantrip-expansion")],
        ["oskar"] = [new(2,"cantrip-expansion"),new(6,"steady-spellcasting"),new(10,"reach-spell")],
        ["hazel"] = [new(1,"root-to-life"),new(6,"esoteric-warden"),new(10,"sympathetic-vulnerabilities")],
        ["wynn"] = [new(2,"well-versed"),new(6,"steady-spellcasting"),new(10,"reach-spell")],
        ["vasska"] = [new(2,"mental-buffer"),new(6,"steady-spellcasting"),new(10,"psi-strikes")],
        ["raven"] = [new(2,"tumble-behind-swashbuckler"),new(6,"combination-finisher"),new(10,"precise-finisher")],
        ["hilde"] = [new(2,"reinforce-eidolon"),new(6,"eidolons-opportunity"),new(10,"advanced-weaponry")],
        ["flick"] = [new(2,"cantrip-expansion"),new(6,"steady-spellcasting"),new(10,"reach-spell")],
    };
    public static bool Has(ICharacter c,string id) => c.Features?.ActiveFeatures.Any(f=>f.FeatureId.Replace('_','-')==id)==true;
    public static void Apply(PF2eCharacter c)
    {
        if (Delve.Run.CharacterPromotion.IsManaged(c)) return;
        if (!Tracks.TryGetValue(c.Id,out var picks)) return;
        foreach (var pick in picks.Where(p=>p.Level<=c.Stats.Level))
        {
            if (c.Features.ChosenFeats.Any(f=>f.Feature.FeatureId.Replace('_','-')==pick.Id)) continue;
            var feature=Build(pick.Id);
            c.Features.AddChosenFeat(new LeveledFeature { Level=pick.Level,Feature=feature });
        }
        c.Features.ResolveAndGrantFeatures();
    }
    public static CharacterFeature Build(string id)
    {
        CharacterFeature f=id switch
        {
            "sudden-charge"=>new SuddenChargeFeature(), "lunge"=>new LungeFeature(),
            "shielded-stride"=>new ShieldedStrideFeature(), "reflexive-shield"=>new ReflexiveShieldFeature(),
            "intimidating-strike"=>new RosterFeatRules("intimidating-strike"), "nimble-dodge"=>new NimbleDodgeFeature(),
            "tumble-behind-swashbuckler"=>new ScopedTumbleBehindFeat(), "mobility"=>new MobilityFeature(), "dread-striker"=>new DreadStrikerFeature(),
            "gang-up"=>new GangUpFeature(), "opportune-backstab"=>new OpportuneBackstabFeature(),
            "sly-striker"=>new SlyStrikerFeature(), "reactive-strike"=>new ReactiveStrikeFeature(),
            "divine-grace"=>new DivineGraceFeat(), "stand-still"=>new StandStillFeat(),
            _=>new RosterFeatRules(id),
        };
        f.FeatureId=id=="gang-up"?GangUpFeature.Id:id; f.DisplayName=Name(id); f.Category=FeatureCategory.ClassFeat;
        f.Description=Descriptions.GetValueOrDefault(id,$"{f.DisplayName}: authored class feat. See its rules card for details.");
        f.LevelRequirement=MinimumLevel(id);
        if (RosterFeatAction.Ids.Contains(id)) f.GrantedActions.Add(new RosterFeatAction(id));
        if (id=="basic-lesson") f.GrantedActions.Add(new ClassAction(ClassActions.All.Single(a=>a.Id=="life-boost")));
        return f;
    }
    public static string Name(string id) => id switch
    {
        "tumble-behind-swashbuckler"=>"Tumble Behind", "basic-lesson"=>"Basic Lesson (Life)",
        "hunters-aim"=>"Hunter's Aim", "scouts-warning"=>"Scout's Warning", "eidolons-opportunity"=>"Eidolon's Opportunity",
        _=>System.Globalization.CultureInfo.InvariantCulture.TextInfo.ToTitleCase(id.Replace('-',' ')),
    };
    public static int MinimumLevel(string id) => id switch
    {
        "healing-hands" or "sudden-charge" or "nimble-dodge" or "root-to-life" or "well-versed" or "mental-buffer" or "reach-spell" or "advanced-weaponry"=>1,
        "shielded-stride" or "dread-striker" or "guarded-movement" or "stand-still" or "scouts-warning" or "psi-strikes"=>4,
        "steady-spellcasting" or "reactive-strike" or "reflexive-shield" or "gang-up" or "sympathetic-vulnerabilities" or "combination-finisher" or "precise-finisher" or "eidolons-opportunity"=>6,
        "quick-shield-block" or "opportune-backstab" or "sly-striker" or "renewed-vigor" or "deadly-aim"=>8,
        "certain-strike"=>10, _=>2,
    };
    private static readonly Dictionary<string,string> Descriptions=new()
    {
        ["quick-shield-block"]="At the start of each turn, gain one extra reaction usable only to Shield Block.",
        ["healing-hands"]="Heal uses d10s instead of d8s, including variable-action casts.",
        ["steady-spellcasting"]="When a reaction would disrupt your spellcasting, a DC 15 flat check prevents disruption.",
        ["cantrip-expansion"]="Add two cantrips to this authored daily loadout.",
        ["reach-spell"]="One action: your next spell's range increases by 30 feet; touch becomes 30 feet. An intervening action loses this benefit.",
        ["basic-lesson"]="Lesson of Life grants Life Boost and increases your focus pool by 1 (maximum 3).",
        ["mental-buffer"]="Resist mental damage equal to half your level (minimum 1), or your level while Unleash Psyche is active.",
        ["poison-resistance"]="Poison resistance equal to half your level, and +1 status to saves against poison.",
        ["well-versed"]="+1 circumstance to saves against auditory, illusion, linguistic, sonic or visual effects.",
        ["stunning-blows"]="A Flurry that damages its single target forces a Fortitude save against class DC: failure Stunned 1, critical failure Stunned 3. Incapacitation applies.",
        ["guarded-movement"]="+4 circumstance AC against reactions triggered by your movement.",
        ["combination-finisher"]="Finishers use MAP -4/-8, or -3/-6 with an agile weapon.",
        ["precise-finisher"]="Confident Finisher failure deals full precision damage instead of half.",
        ["scouts-warning"]="Warn your allies before initiative, granting them +1 circumstance to initiative.",
        ["sympathetic-vulnerabilities"]="Personal antithesis also affects non-humanoid creatures of exactly the same kind as your exploited target.",
        ["esoteric-warden"]="Successful Exploit Vulnerability wards your AC against the next attack and your next save from that creature (+1 status, +2 on a critical success). Once per creature per day; exploiting again ends the previous ward.",
        ["advanced-weaponry"]="Earth eidolon's stone fist gains versatile slashing. Eidolon Slash uses this alternative damage type.",
    };
}
