using System.Collections.Generic;
using Delve.Run.Events;
using PF2e.Data;
using static Delve.Dungeon.SceneOptions;
using static Delve.Dungeon.StationScenes;

namespace Delve.Dungeon;

/// <summary>
/// The exploration scene each quiet forest glade offers, by purpose and floor history. Same outcome
/// types and level 1 DCs as <see cref="StationScenes"/>, so both floors pay out alike.
/// </summary>
public static class GladeScenes
{
    public static IReadOnlyList<EventOption> For(RoomPurpose purpose, StationHistory history)
    {
        var options = new List<EventOption>();
        switch (purpose)
        {
            case RoomPurpose.Checkpoint:
                options.Add(Check("Read the trail blazes (Decipher Writing)", Skill.Society, StandardDc, Scouted(2), Scouted(1), Scouted(0)));
                options.Add(Check("Survey from up high (Sense Direction)", Skill.Survival, StandardDc, Scouted(2), Scouted(1), Scouted(0)));
                break;
            case RoomPurpose.Barracks:
                options.Add(Free("Rest in the camp", history == StationHistory.Evacuated
                    ? Do("The party rests and finds a remedy in a pack left behind.", Effect(EventEffectKind.FreeRest), Effect(EventEffectKind.HealingPotion, 1))
                    : Do("The party rests ten minutes.", Effect(EventEffectKind.FreeRest))));
                break;
            case RoomPurpose.MessHall:
                options.Add(Check("Forage for food (Subsist)", Skill.Survival, StandardDc,
                    Do("The party eats well and brews a remedy from what it finds.", Effect(EventEffectKind.FreeRest), Effect(EventEffectKind.HealingPotion, 1)),
                    Do("The party eats and rests.", Effect(EventEffectKind.FreeRest)),
                    Nothing("Nothing here is safe to eat.")));
                break;
            case RoomPurpose.Kitchen:
                options.Add(Free("Warm up by the fire", history == StationHistory.Flooded
                    ? Do("The party dries out by the fire and brews a remedy.", Effect(EventEffectKind.FreeRest), Effect(EventEffectKind.HealingPotion, 1))
                    : Do("The party rests by the fire.", Effect(EventEffectKind.FreeRest))));
                break;
            case RoomPurpose.Cistern:
                options.Add(history == StationHistory.Flooded
                    ? Check("Dive for what sank (Swim)", Skill.Athletics, HazardDc,
                        Do("You surface with two sealed remedies.", Effect(EventEffectKind.HealingPotion, 2)),
                        Do("You surface with a sealed remedy.", Effect(EventEffectKind.HealingPotion, 1)),
                        Nothing("The water is too dark to search."),
                        Do("Roots snag you under the surface.", Effect(EventEffectKind.HazardDamage, HazardCritFailPercent)))
                    : Free("Drink and wash at the water", Do("The party rests at the water.", Effect(EventEffectKind.FreeRest))));
                break;
            case RoomPurpose.Stores:
                options.Add(Check("Disarm the snare on the chest (Disable a Device)", Skill.Thievery, HazardDc,
                    Do("The snare comes apart clean. Coins and two remedies are inside.", Effect(EventEffectKind.CacheGold), Effect(EventEffectKind.HealingPotion, 2)),
                    Do("The snare comes apart. Coins and a remedy are inside.", Effect(EventEffectKind.CacheGold), Effect(EventEffectKind.HealingPotion, 1)),
                    Do("The wire snaps back across a hand.", Effect(EventEffectKind.HazardDamage, HazardFailPercent)),
                    Do("The snare springs and bites deep.", Effect(EventEffectKind.HazardDamage, HazardCritFailPercent), Effect(EventEffectKind.WoundedDelta, 1))));
                break;
            case RoomPurpose.Workshop:
                options.Add(Check("Repair shields at the bench (Repair)", Skill.Crafting, ShieldRepairDc,
                    Do("Every shield comes off the bench whole.", Effect(EventEffectKind.RepairShields, 2)),
                    Do("The shields are patched.", Effect(EventEffectKind.RepairShields, 1)),
                    Nothing("The tools are past use."),
                    Do("A slip gouges the shields.", Effect(EventEffectKind.RepairShields, -1)), fixedDc: true));
                if (history == StationHistory.WardFailure)
                    options.Add(Check("Bleed the cracked lantern (Disable a Device)", Skill.Thievery, HazardDc,
                        Do("The lantern's light flows back into the Wardstone.", Effect(EventEffectKind.WardDelta, 20)),
                        Do("Some of the light flows back.", Effect(EventEffectKind.WardDelta, 10)),
                        Nothing("The lantern stays dark."),
                        Do("The lantern bursts in your hands.", Effect(EventEffectKind.HazardDamage, HazardCritFailPercent))));
                break;
            case RoomPurpose.Maintenance:
                int dc = history == StationHistory.WardFailure ? StandardDc - 2 : StandardDc;
                options.Add(Check("Rekindle the lantern (Crafting)", Skill.Crafting, dc, Kindled(30), Kindled(15), Cold(), Smothered()));
                options.Add(Check("Say the lamp rite (Religion)", Skill.Religion, dc, Kindled(30), Kindled(15), Cold(), Smothered()));
                break;
            case RoomPurpose.Shrine:
                bool restless = history == StationHistory.Evacuated;
                options.Add(Check(restless ? "Lay the dead to rest (Religion)" : "Pray for focus (Refocus)", Skill.Religion,
                    restless ? HazardDc : StandardDc,
                    Do("Your prayer is answered.", Effect(EventEffectKind.PartyRefocus, 1), Effect(EventEffectKind.HealFraction, 10)),
                    Do("Your focus steadies.", Effect(EventEffectKind.PartyRefocus, 1)),
                    Nothing("Nothing answers."),
                    restless ? Do("The dead lash out.", Effect(EventEffectKind.HazardDamage, HazardCritFailPercent)) : Nothing("Nothing answers.")));
                break;
        }
        options.Add(Leave());
        return options;
    }

    private static EventOutcome Scouted(int reach) => reach switch
    {
        2 => Do("The blazes mark every glade on this floor.", Effect(EventEffectKind.RevealKinds, 2)),
        1 => Do("The blazes mark the glades near where you have been.", Effect(EventEffectKind.RevealKinds, 1)),
        _ => Do("You make out only the nearest blazes.", Effect(EventEffectKind.RevealKinds, 0))
    };

    private static EventOutcome Kindled(int ward) => ward >= 30
        ? Do("The lantern blazes up. The Wardstone drinks the light.", Effect(EventEffectKind.WardDelta, ward))
        : Do("The lantern holds a small flame.", Effect(EventEffectKind.WardDelta, ward));

    private static EventOutcome Cold() => Nothing("The lantern will not take a flame.");

    private static EventOutcome Smothered() => Do("The lantern gutters and drains the stone.", Effect(EventEffectKind.WardDelta, -5));
}
