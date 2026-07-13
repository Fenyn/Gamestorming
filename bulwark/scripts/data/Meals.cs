using System.Collections.Generic;

namespace Bulwark.Data;

/// <summary>
/// The kind of day-long buff a meal grants. Bulwark-local (no engine type leaks into data) — the
/// plain-C# <see cref="Bulwark.Cozy.MealSystem"/> translates each kind into a CALL-only engine buff
/// (temp HP via Health.GrantTempHP, or a status ConditionModifier on a save / attack roll / AC / speed).
/// Extensible: add a kind here + a case in MealSystem (and classify it in <see cref="Meals.IsPerCombat"/>).
///
/// PERSISTENCE MODEL (Refinement 1): a meal is a DAY-LONG benefit (well-fed all day), cleared only on
/// the next day rollover. Its components split two ways:
///  - PERSISTENT ALL-DAY (stat/save/attack/AC status modifiers): applied once when eaten and left on
///    the roster's live ModifierStack all day — post-combat cleanup never strips them.
///  - PER-COMBAT REFRESHED (temp HP): post-combat cleanup wipes temp HP, so the active meal RE-GRANTS
///    it at the START of every encounter (see <see cref="Bulwark.Cozy.MealSystem.RefreshPerCombat"/>) —
///    well-fed means a fresh cushion of temp HP each fight, all day long.
/// (Per-FIGHT-only consumables — potions eaten mid-combat — are a SEPARATE future system, not this.)
/// </summary>
public enum MealBuffKind
{
    /// <summary>PER-COMBAT: grants <see cref="MealDefinition.Magnitude"/> temporary HP to each roster
    /// member, refreshed at the start of every encounter within the day.</summary>
    TempHp,

    /// <summary>ALL-DAY: +<see cref="MealDefinition.Magnitude"/> status bonus to Fortitude saves.</summary>
    FortitudeSave,

    /// <summary>ALL-DAY: +<see cref="MealDefinition.Magnitude"/> feet Speed (status).</summary>
    Speed,

    /// <summary>ALL-DAY: +<see cref="MealDefinition.Magnitude"/> status bonus to ATTACK rolls (feeds the
    /// engine's melee/ranged/spell attack umbrellas via a status ConditionModifier on AttackRoll).</summary>
    AttackRoll,

    /// <summary>ALL-DAY: +<see cref="MealDefinition.Magnitude"/> status bonus to Armor Class (the optional
    /// generic defensive kind — a status ConditionModifier on AC).</summary>
    ArmorClass,
}

/// <summary>
/// Declarative definition of a meal: the Food item eaten (<see cref="Id"/> is the item id) and the
/// day-long buff it applies to the roster. Data-only per CLAUDE.md. Magnitudes are PLACEHOLDER and
/// deliberately modest (see the phase report) — tune later. Adding a meal touches <see cref="Meals"/>
/// (and its Food item + kitchen recipe) only.
/// </summary>
public sealed class MealDefinition
{
    /// <summary>The Food <see cref="ItemDefinition.Id"/> consumed when this meal is eaten.</summary>
    public required string Id { get; init; }
    public required string DisplayName { get; init; }
    public required MealBuffKind Buff { get; init; }
    public required int Magnitude { get; init; }

    /// <summary>True when this meal's buff is PER-COMBAT refreshed (temp HP) rather than persistent
    /// all-day (stat/attack/AC/save modifiers). Drives the encounter-start re-grant.</summary>
    public bool IsPerCombatRefreshed => Meals.IsPerCombat(Buff);

    /// <summary>Short buff description for a future meal UI.</summary>
    public string BuffText => Buff switch
    {
        MealBuffKind.TempHp => $"+{Magnitude} temporary HP (refreshed each fight)",
        MealBuffKind.FortitudeSave => $"+{Magnitude} status to Fortitude saves",
        MealBuffKind.Speed => $"+{Magnitude} ft Speed",
        MealBuffKind.AttackRoll => $"+{Magnitude} status to attack rolls",
        MealBuffKind.ArmorClass => $"+{Magnitude} status to AC",
        _ => Buff.ToString(),
    };
}

/// <summary>
/// Static registry of every meal. Phase-5 PROVING SET only (one per buff kind); the framework is
/// data-driven so the user extends the menu here. Each id matches a Food item produced by a
/// kitchen-gated recipe in <see cref="Recipes"/>.
/// </summary>
public static class Meals
{
    public static readonly MealDefinition HeartyStew = new()
    {
        Id = "hearty_stew", DisplayName = "Hearty Stew", Buff = MealBuffKind.TempHp, Magnitude = 5,
    };
    public static readonly MealDefinition HerbTonic = new()
    {
        Id = "herb_tonic", DisplayName = "Herb Tonic", Buff = MealBuffKind.FortitudeSave, Magnitude = 1,
    };
    public static readonly MealDefinition TravelRation = new()
    {
        Id = "travel_ration", DisplayName = "Travel Ration", Buff = MealBuffKind.Speed, Magnitude = 5,
    };
    // Refinement 1: the "combat well-fed" meals — an ALL-DAY attack-roll status buff and an ALL-DAY AC
    // status buff. Magnitudes are PLACEHOLDER/modest (+1 status, PF2e status-bonus scale) — tune later.
    public static readonly MealDefinition BattleDraught = new()
    {
        Id = "battle_draught", DisplayName = "Battle Draught", Buff = MealBuffKind.AttackRoll, Magnitude = 1,
    };
    public static readonly MealDefinition GuardRation = new()
    {
        Id = "guard_ration", DisplayName = "Guard Ration", Buff = MealBuffKind.ArmorClass, Magnitude = 1,
    };

    private static readonly DefinitionRegistry<MealDefinition> Registry = new(d => d.Id,
        HeartyStew, HerbTonic, TravelRation, BattleDraught, GuardRation);

    /// <summary>
    /// Classify a buff kind: true = PER-COMBAT refreshed (re-granted at each encounter start), false =
    /// PERSISTENT all-day (applied once on eat, survives combat, cleared on day rollover). Only temp HP
    /// is per-combat today; every stat/save/attack/AC modifier is a persistent all-day benefit.
    /// </summary>
    public static bool IsPerCombat(MealBuffKind kind) => kind == MealBuffKind.TempHp;

    /// <summary>Every defined meal.</summary>
    public static IReadOnlyCollection<MealDefinition> All => Registry.All;

    /// <summary>True when <paramref name="id"/> names a defined meal.</summary>
    public static bool IsDefined(string id) => Registry.IsDefined(id);

    /// <summary>Look up a meal by id. Throws if unknown — call <see cref="IsDefined"/> to probe.</summary>
    public static MealDefinition Get(string id) => Registry.Get(id);

    /// <summary>Non-throwing lookup.</summary>
    public static bool TryGet(string id, out MealDefinition def) => Registry.TryGet(id, out def);
}
