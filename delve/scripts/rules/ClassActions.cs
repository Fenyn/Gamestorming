using System.Collections.Generic;
using System.Linq;

namespace Delve.Rules;

public sealed record ClassActionSpec(string Id, string Name, string Class, int Cost, int Range,
    bool Ally, int Focus, string Description);

public static class ClassActions
{
    public static readonly IReadOnlyList<ClassActionSpec> All = new ClassActionSpec[]
    {
        new("rage","Rage","Barbarian",1,0,false,0,"Gain level + Constitution temporary HP and +3 melee damage (+7 at level 7). Quick-Tempered enters Rage free on your first turn."),
        new("lay-on-hands","Lay on Hands","Champion",1,1,true,1,"Heal a living ally 6 HP per spell rank and grant +2 status AC until your next turn. Costs 1 Focus Point."),
        new("clinging-ice","Clinging Ice","Witch",1,6,false,0,"Grandmother Mulch's winter hex: 1d4 cold per spell rank, basic Reflex save. One hex each turn."),
        new("life-boost","Life Boost","Witch",1,6,true,1,"Grant an ally fast healing equal to twice your spell rank for four turns. Costs 1 Focus Point."),
        new("flurry-of-blows","Flurry of Blows","Monk",1,1,false,0,"Make two unarmed Strikes with normal multiple attack penalties. One flourish per turn."),
        new("hunt-prey","Hunt Prey","Ranger",1,24,false,0,"Designate prey. Your first hit against your prey each round adds 1d8 precision damage."),
        new("cornucopia","Cornucopia","Druid",3,1,true,1,"Grow and feed a nourishing fruit to an ally: heal 1d6+4, heightened by 1d6+4 each spell rank. Costs 1 Focus Point."),
        new("spellstrike","Spellstrike: Ignition","Magus",2,1,false,0,"Deliver Ignition with a melee Strike using its attack roll. Counts as two attacks for MAP. Discharges Spellstrike."),
        new("dimensional-assault","Dimensional Assault","Magus",1,4,false,1,"Teleport up to half your Speed to a foe and Strike. This conflux spell recharges Spellstrike. Costs 1 Focus Point."),
        new("recharge-spellstrike","Recharge Spellstrike","Magus",1,0,false,0,"Concentrate to recharge Spellstrike."),
        new("arcane-cascade","Arcane Cascade","Magus",1,0,false,0,"After casting or Spellstriking this turn, enter your stance: add fire damage to melee Strikes."),
        new("weapon-trance","Weapon Trance","Oracle",1,0,false,1,"Enter your battle revelation: martial weapon proficiency equals simple weapon proficiency. Lasts one minute. Costs 1 Focus Point."),
        
        new("exploit-vulnerability","Exploit Vulnerability","Thaumaturge",1,6,false,0,"Check Esoteric Lore against level DC. On failure or better identify personal antithesis: your Strikes trigger weakness 2 + half your level."),
        new("chalice","Drink from Chalice","Thaumaturge",1,1,true,0,"Drain your chalice to heal an ally 3 HP per level. It refreshes after ten minutes."),
        new("lingering-composition","Lingering Composition","Bard",0,0,false,1,"Before your anthem, check Performance against a level DC. On success it lasts 3 rounds, or 4 on a critical success. On failure your Focus Point is refunded. Once per turn."),
        new("courageous-anthem","Courageous Anthem","Bard",1,0,false,0,"A composition cantrip: allies within 60 feet gain +1 status to attacks, damage and saves against fear until your next turn."),
        new("unleash-psyche","Unleash Psyche","Psychic",0,0,false,0,"After casting a spell on your previous turn, unleash for two turns. Psychic spells gain twice their rank in damage; afterward become Stupefied 2 for two turns."),
        new("amped-daze","Amped Daze","Psychic",2,24,false,1,"Silent Whisper psi cantrip: mental damage, basic Will save. Your amp increases its damage. Costs 1 Focus Point."),
        new("braggarts-boast","Braggart's Boast","Swashbuckler",1,6,false,0,"Demoralize a foe. A successful Intimidation check grants Panache, enabling finishers."),
        new("confident-finisher","Confident Finisher","Swashbuckler",1,1,false,0,"Spend Panache on a finesse Strike with 2d6 precision damage (3d6 at level 5, 4d6 at 9). Failure deals half the precision damage. No more attacks this turn."),
        new("act-together","Act Together","Summoner",2,6,false,0,"Cast Electric Arc on one foe while your eidolon Strikes that foe in its reach. This two-action activity combines three actions. Once per turn."),
        new("eidolon-strike","Eidolon Strike","Summoner",1,24,false,0,"Your manifested earth eidolon Strikes a foe in its reach, spending your shared action budget and MAP."),
        new("eidolon-advance","Eidolon Advance","Summoner",1,24,false,0,"Your earth eidolon Strides toward the chosen foe using your shared action budget."),
        new("evolution-surge","Evolution Surge","Summoner",2,0,false,1,"Your earth eidolon gains a +20-foot status bonus to Speed for one minute. Costs 1 Focus Point."),
        new("boost-eidolon","Boost Eidolon","Summoner",1,0,false,0,"A link cantrip: your eidolon's Strikes gain +2 status damage per weapon damage die until your next turn."),
        new("elemental-toss","Elemental Toss","Sorcerer",1,6,false,1,"Hurl elemental fire with a spell attack: 1d8 per spell rank. Costs 1 Focus Point."),
    };
    public static IEnumerable<ClassActionSpec> For(string name) => All.Where(a => a.Class == name);
    public static string Description(string name) => string.Join("\n", For(name).Select(a => $"{a.Name}: {a.Description}"));
}
