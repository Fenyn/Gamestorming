using System.Collections.Generic;
using PF2e.Data;

namespace Delve.Run.Events;

/// <summary>What an event outcome does. Data only - no delegates, so events move to data files later.</summary>
public enum EventEffectKind
{
    Nothing,

    /// <summary>Heal the acting member for <c>Value</c> percent of its maximum HP.</summary>
    HealFraction,

    /// <summary>Damage the acting member for <c>Value</c>, floored at 1 HP.</summary>
    Damage,

    /// <summary>Raise (or, negative, lower) the acting member's Wounded value by <c>Value</c>.</summary>
    WoundedDelta,

    /// <summary>Add <c>Value</c> to the run's gold.</summary>
    GoldDelta,

    /// <summary>Change the Wardstone by <c>Value</c>. A loss never puts the ward out.</summary>
    WardDelta,

    /// <summary>Banks one ten-minute rest that costs no ward (<see cref="RunState.FreeRests"/>);
    /// the next short rest spends it.</summary>
    FreeRest,

    /// <summary>Banks <c>Value</c> healing potions (<see cref="RunState.Potions"/>); the party drinks
    /// them later at the party's grade (<see cref="HealingPotions"/>).</summary>
    HealingPotion,

    /// <summary>Hazard damage to the acting member: <c>Value</c> percent of maximum HP, floored at
    /// 1 HP. A stand-in until the GM Core hazard damage table is pulled.</summary>
    HazardDamage,

    /// <summary>Reveal room kinds on the floor plan. <c>Value</c> 0: rooms next to this one;
    /// 1: rooms next to any visited room; 2: the whole floor. Applied by the dungeon.</summary>
    RevealKinds,

    /// <summary>Every member with a focus pool regains <c>Value</c> Focus Points.</summary>
    PartyRefocus,

    /// <summary>The actor Repairs every damaged shield: 5 HP plus 5 per Crafting rank, times
    /// <c>Value</c> (2 on a critical success). A negative <c>Value</c> is the critical failure:
    /// 2d6 damage, less Hardness, to the most damaged shield.</summary>
    RepairShields,

    /// <summary>A cache's coins: <see cref="CacheGoldAtLevelOne"/> scaled by
    /// <see cref="TreasureByLevel"/> to the party's level.</summary>
    CacheGold,
}

public static class EventRewards
{
    /// <summary>Gold a level 1 cache holds.</summary>
    public const int CacheGoldAtLevelOne = 25;
}

/// <summary>One data-only effect of an outcome.</summary>
public sealed record EventEffect(EventEffectKind Kind, int Value = 0);

/// <summary>What one degree of success does, plus the line to show for it.</summary>
public sealed record EventOutcome(string Text, IReadOnlyList<EventEffect> Effects)
{
    /// <summary>An outcome that only prints.</summary>
    public static EventOutcome Nothing(string text) =>
        new(text, new List<EventEffect> { new(EventEffectKind.Nothing) });
}

/// <summary>The skill check an option rolls, if it rolls one.</summary>
/// <param name="FixedDc">True when the DC comes from an item's own level (Repair on a level 0
/// shield is DC 14 at any party level), so level scaling leaves it alone.</param>
public sealed record EventCheck(Skill Skill, int Dc, bool AllowPickActor, bool FixedDc = false);

/// <summary>One choice on an event, with its outcome per degree of success.</summary>
public sealed record EventOption
{
    public required string Label { get; init; }

    /// <summary>Null for an option that resolves straight to <see cref="Success"/>.</summary>
    public EventCheck? Check { get; init; }

    public required EventOutcome Success { get; init; }

    /// <summary>Falls back to <see cref="Success"/> when unset.</summary>
    public EventOutcome? CriticalSuccess { get; init; }

    /// <summary>Falls back to <see cref="Success"/> when unset.</summary>
    public EventOutcome? Failure { get; init; }

    /// <summary>Falls back to <see cref="Failure"/>, then to <see cref="Success"/>, when unset.</summary>
    public EventOutcome? CriticalFailure { get; init; }
}

/// <summary>A text encounter: what the party sees and what it may do about it.</summary>
public sealed record EventDefinition
{
    public required string Id { get; init; }
    public required string Title { get; init; }
    public required string Body { get; init; }
    public required IReadOnlyList<EventOption> Options { get; init; }
}
