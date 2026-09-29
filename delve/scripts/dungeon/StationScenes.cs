using System.Collections.Generic;
using Delve.Run.Events;
using PF2e.Data;
using static Delve.Dungeon.SceneOptions;

namespace Delve.Dungeon;

/// <summary>
/// The PF2e exploration scene each quiet station room offers, by purpose and station history. DCs are
/// authored at level 1 (standard 15, hazards 17) and moved to the party level by
/// <see cref="DungeonEncounters.AtLevel"/>. Every scene also offers Leave, which refunds the crossing.
/// Outcome lines are functional placeholders until the user approves the prose.
/// </summary>
public static class StationScenes
{
    public const int StandardDc = 15;
    public const int HazardDc = 17;

    /// <summary>Ward a room returns when the party leaves it alone: one crossing.</summary>
    public const int LeaveWard = 5;

    /// <summary>Repair DC for a level 0 shield: the item's level sets it, not the party's (Player Core).</summary>
    public const int ShieldRepairDc = 14;

    /// <summary>Hazard damage as percent of maximum HP on a failure and a critical failure. A stand-in
    /// for the GM Core hazard damage table: a level-matched simple hazard takes about half an
    /// average member's HP (Spear Launcher at level 2).</summary>
    public const int HazardFailPercent = 25;
    public const int HazardCritFailPercent = 50;

    /// <summary>True for a scene whose only choice is one free, no-check option beside Leave. It is
    /// applied on arrival: banking a free rest always beats Leave's refund, so there is no decision.</summary>
    public static bool AppliesOnArrival(IReadOnlyList<EventOption> options)
        => options.Count == 2 && options[0].Check == null;

    public static IReadOnlyList<EventOption> For(RoomPurpose purpose, StationHistory history)
    {
        var options = new List<EventOption>();
        switch (purpose)
        {
            case RoomPurpose.Checkpoint:
                options.Add(Check("Read the duty log (Decipher Writing)", Skill.Society, StandardDc,
                    Do("The log names every room.", Effect(EventEffectKind.RevealKinds, 2)),
                    Do("The log names the rooms near where you have been.", Effect(EventEffectKind.RevealKinds, 1)),
                    Do("You make out only the nearest entries.", Effect(EventEffectKind.RevealKinds, 0))));
                break;
            case RoomPurpose.Barracks:
                options.Add(Free("Rest in the bunks", history == StationHistory.Evacuated
                    ? Do("The party rests and finds a remedy in the abandoned medical kit.", Effect(EventEffectKind.FreeRest), Effect(EventEffectKind.HealingPotion, 1))
                    : Do("The party rests ten minutes.", Effect(EventEffectKind.FreeRest))));
                break;
            case RoomPurpose.MessHall:
                options.Add(Check("Scavenge the pantry (Subsist)", Skill.Survival, StandardDc,
                    Do("Enough for a meal and a sealed remedy.", Effect(EventEffectKind.FreeRest), Effect(EventEffectKind.HealingPotion, 1)),
                    Do("Enough for a meal and a rest.", Effect(EventEffectKind.FreeRest)),
                    Nothing("Nothing here is fit to eat.")));
                break;
            case RoomPurpose.Kitchen:
                options.Add(Free("Light the stove", history == StationHistory.Flooded
                    ? Do("The party rests by the one dry stove and brews a remedy.", Effect(EventEffectKind.FreeRest), Effect(EventEffectKind.HealingPotion, 1))
                    : Do("The party rests by the stove.", Effect(EventEffectKind.FreeRest))));
                break;
            case RoomPurpose.Cistern:
                options.Add(history == StationHistory.Flooded
                    ? Check("Dive for what sank (Swim)", Skill.Athletics, HazardDc,
                        Do("You surface with two sealed remedies.", Effect(EventEffectKind.HealingPotion, 2)),
                        Do("You surface with a sealed remedy.", Effect(EventEffectKind.HealingPotion, 1)),
                        Nothing("The water is too dark to search."),
                        Do("The current slams you into the grate.", Effect(EventEffectKind.HazardDamage, HazardCritFailPercent)))
                    : Free("Wash and drink at the reservoir", Do("The party rests at the water.", Effect(EventEffectKind.FreeRest))));
                break;
            case RoomPurpose.Stores:
                options.Add(Check("Open the cache (Disable a Device)", Skill.Thievery, HazardDc,
                    Do("The lock opens clean. Coins and two remedies inside.", Effect(EventEffectKind.CacheGold), Effect(EventEffectKind.HealingPotion, 2)),
                    Do("The lock opens. Coins and a remedy inside.", Effect(EventEffectKind.CacheGold), Effect(EventEffectKind.HealingPotion, 1)),
                    Do("The poisoned needle finds a finger.", Effect(EventEffectKind.HazardDamage, HazardFailPercent)),
                    Do("The poison goes deep.", Effect(EventEffectKind.HazardDamage, HazardCritFailPercent), Effect(EventEffectKind.WoundedDelta, 1))));
                break;
            case RoomPurpose.Workshop:
                options.Add(Check("Repair shields at the bench (Repair)", Skill.Crafting, ShieldRepairDc,
                    Do("Every shield comes off the bench whole.", Effect(EventEffectKind.RepairShields, 2)),
                    Do("The shields are patched.", Effect(EventEffectKind.RepairShields, 1)),
                    Nothing("The tools are past use."),
                    Do("A slip gouges the shields.", Effect(EventEffectKind.RepairShields, -1)), fixedDc: true));
                if (history == StationHistory.WardFailure)
                    options.Add(Check("Cut the live conduit (Disable a Device)", Skill.Thievery, HazardDc,
                        Do("The trapped charge flows back into the Wardstone.", Effect(EventEffectKind.WardDelta, 20)),
                        Do("Some of the charge flows back.", Effect(EventEffectKind.WardDelta, 10)),
                        Nothing("The conduit stays live."),
                        Do("The conduit arcs through you.", Effect(EventEffectKind.HazardDamage, HazardCritFailPercent))));
                break;
            case RoomPurpose.Maintenance:
                options.Add(Check("Reconnect a ward conduit (Crafting)", Skill.Crafting,
                    history == StationHistory.WardFailure ? StandardDc - 2 : StandardDc,
                    Do("The conduit sings. The Wardstone drinks deep.", Effect(EventEffectKind.WardDelta, 30)),
                    Do("The conduit holds.", Effect(EventEffectKind.WardDelta, 15)),
                    Nothing("The conduit will not hold a charge."),
                    Do("The conduit drains the stone.", Effect(EventEffectKind.WardDelta, -5))));
                break;
            case RoomPurpose.Shrine:
                bool haunted = history == StationHistory.Evacuated;
                options.Add(Check(haunted ? "Quiet the restless shrine (Religion)" : "Pray at the statue (Refocus)", Skill.Religion,
                    haunted ? HazardDc : StandardDc,
                    Do("The shrine answers.", Effect(EventEffectKind.PartyRefocus, 1), Effect(EventEffectKind.HealFraction, 10)),
                    Do("The shrine steadies your focus.", Effect(EventEffectKind.PartyRefocus, 1)),
                    Nothing("The shrine is silent."),
                    haunted ? Do("The haunting lashes out.", Effect(EventEffectKind.HazardDamage, HazardCritFailPercent)) : Nothing("The shrine is silent.")));
                break;
        }
        options.Add(Leave());
        return options;
    }
}
