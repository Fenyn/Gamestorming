using System.Collections.Generic;

namespace Bulwark.Data;

/// <summary>
/// The kind of benefit one consumable EFFECT confers. Bulwark-local (no engine type leaks into data,
/// like <see cref="MealBuffKind"/>) — the plain-C# <see cref="Bulwark.Cozy.ConsumableSystem"/> translates
/// each kind into a CALL-only engine effect on the drinker (Health.Heal / Health.GrantTempHP, or an ITEM
/// ConditionModifier on a save / AC / attack roll). Extensible: add a kind here + a case in ConsumableSystem.
///
/// SCOPE: these are PER-FIGHT / INSTANT consumables used IN COMBAT as an action (or out of combat),
/// distinct from the day-long <see cref="MealBuffKind"/> meal buffs. PF2e grounding (GM Core pack JSON):
/// potions/elixirs are "Activate ◆ (manipulate)" — 1 action, manipulate-tagged, consumed on use; a
/// healing potion regains HP by tier; an elixir/antidote grants an ITEM bonus for a duration.
/// </summary>
public enum ConsumableEffectType
{
    /// <summary>Regain Hit Points immediately (healing potion). <see cref="ConsumableEffect.Magnitude"/> HP.</summary>
    Heal,

    /// <summary>Grant <see cref="ConsumableEffect.Magnitude"/> temporary HP for <see cref="ConsumableEffect.DurationRounds"/>.</summary>
    TempHp,

    /// <summary>+<see cref="ConsumableEffect.Magnitude"/> ITEM bonus to Fortitude saves for the duration
    /// (antidote / elixir of life vs poisons &amp; disease; the poison-resistance framework — content deferred).</summary>
    FortitudeSave,

    /// <summary>+<see cref="ConsumableEffect.Magnitude"/> ITEM bonus to Armor Class for the duration (a defensive combat elixir).</summary>
    ArmorClass,

    /// <summary>+<see cref="ConsumableEffect.Magnitude"/> ITEM bonus to attack rolls for the duration (an offensive combat elixir).</summary>
    AttackRoll,
}

/// <summary>One declared effect of a consumable. A consumable may carry several (an elixir of life heals
/// AND buffs saves). Duration is in combat ROUNDS: -1 = encounter-length (outlasts a fight, like the real
/// 10-min / 6-hr elixir durations — cleared at the encounter boundary); a positive value expires after that
/// many rounds mid-fight. Ignored for <see cref="ConsumableEffectType.Heal"/> (instantaneous).</summary>
public readonly struct ConsumableEffect
{
    public ConsumableEffect(ConsumableEffectType type, int magnitude, int durationRounds = -1)
    {
        Type = type;
        Magnitude = magnitude;
        DurationRounds = durationRounds;
    }

    public ConsumableEffectType Type { get; }
    public int Magnitude { get; }
    public int DurationRounds { get; }
}

/// <summary>
/// Declarative definition of a per-fight/instant consumable: the item eaten (<see cref="Id"/> is the item
/// id) and the effect(s) drinking it applies. Data-only per CLAUDE.md; magnitudes are PLACEHOLDER/modest
/// (tune later) — the user authors the full catalog. Adding a consumable touches <see cref="Consumables"/>
/// (and its <see cref="Items"/> entry) only.
/// </summary>
public sealed class ConsumableDefinition
{
    /// <summary>The consumable <see cref="ItemDefinition.Id"/> consumed on use.</summary>
    public required string Id { get; init; }
    public required string DisplayName { get; init; }

    /// <summary>Actions to activate in combat (PF2e: drinking a potion = 1 action).</summary>
    public int ActionCost { get; init; } = 1;

    /// <summary>The effects applied on use, in order.</summary>
    public required IReadOnlyList<ConsumableEffect> Effects { get; init; }

    /// <summary>Short effect summary for a future consumable UI / action bar.</summary>
    public string EffectText
    {
        get
        {
            var parts = new List<string>(Effects.Count);
            foreach (var e in Effects)
            {
                parts.Add(e.Type switch
                {
                    ConsumableEffectType.Heal => $"restore {e.Magnitude} HP",
                    ConsumableEffectType.TempHp => $"+{e.Magnitude} temp HP",
                    ConsumableEffectType.FortitudeSave => $"+{e.Magnitude} item to Fortitude",
                    ConsumableEffectType.ArmorClass => $"+{e.Magnitude} item to AC",
                    ConsumableEffectType.AttackRoll => $"+{e.Magnitude} item to attack rolls",
                    _ => e.Type.ToString(),
                });
            }
            return string.Join(", ", parts);
        }
    }
}

/// <summary>
/// Static registry of every per-fight consumable. PROVING SET only — a healing potion, a combat buff
/// elixir, and an antidote — proving the data-driven framework; the user extends the menu here. Each id
/// matches a <see cref="ItemCategory.Consumable"/> item in <see cref="Items"/>. Poisons are DEFERRED
/// (design decision) — the framework (duration, item-bonus effects, the Fortitude-resistance kind) is in
/// place so poisons slot in later as data + a resolver kind, but NO poison content ships here.
/// </summary>
public static class Consumables
{
    /// <summary>Minor healing potion — "Activate ◆ (manipulate) ... regain Hit Points" (pack: 1d8;
    /// modeled flat/placeholder like meal magnitudes for deterministic play). Instantaneous.</summary>
    public static readonly ConsumableDefinition MinorHealingPotion = new()
    {
        Id = "minor_healing_potion", DisplayName = "Minor Healing Potion",
        Effects = new[] { new ConsumableEffect(ConsumableEffectType.Heal, 8) },
    };

    /// <summary>Guardian Elixir — a defensive COMBAT elixir: +1 item bonus to AC for 3 rounds (a short,
    /// per-fight buff that visibly expires mid-combat). PLACEHOLDER magnitude/duration.</summary>
    public static readonly ConsumableDefinition GuardianElixir = new()
    {
        Id = "guardian_elixir", DisplayName = "Guardian Elixir",
        Effects = new[] { new ConsumableEffect(ConsumableEffectType.ArmorClass, 1, durationRounds: 3) },
    };

    /// <summary>Antidote — "+item bonus to Fortitude saves vs poisons" (pack: 6 hours → encounter-length
    /// here, -1). The poison-defense framework with no poison content yet (deferred).</summary>
    public static readonly ConsumableDefinition Antidote = new()
    {
        Id = "antidote", DisplayName = "Antidote",
        Effects = new[] { new ConsumableEffect(ConsumableEffectType.FortitudeSave, 2, durationRounds: -1) },
    };

    private static readonly DefinitionRegistry<ConsumableDefinition> Registry = new(d => d.Id,
        MinorHealingPotion, GuardianElixir, Antidote);

    /// <summary>Every defined consumable.</summary>
    public static IReadOnlyCollection<ConsumableDefinition> All => Registry.All;

    /// <summary>True when <paramref name="id"/> names a defined consumable.</summary>
    public static bool IsDefined(string id) => Registry.IsDefined(id);

    /// <summary>Look up a consumable by id. Throws if unknown — call <see cref="IsDefined"/> to probe.</summary>
    public static ConsumableDefinition Get(string id) => Registry.Get(id);

    /// <summary>Non-throwing lookup.</summary>
    public static bool TryGet(string id, out ConsumableDefinition def) => Registry.TryGet(id, out def);
}
