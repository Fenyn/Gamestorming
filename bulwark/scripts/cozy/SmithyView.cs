using System.Collections.Generic;
using Bulwark.Data;

namespace Bulwark.Cozy;

/// <summary>
/// View-model for a future smithy screen (no UI built this phase): current gold, the per-member
/// rune-upgrade options with costs, and the weapons available to buy. View-model shaped per
/// CLAUDE.md — no engine types leak (weapon names are plain strings, <see cref="RuneKind"/> is a
/// bulwark enum). Built by GameState.GetSmithyView from live state.
/// </summary>
public sealed class SmithyView
{
    public required int Gold { get; init; }
    public required IReadOnlyList<SmithyMemberView> Members { get; init; }
    public required IReadOnlyList<SmithyWeaponOption> Weapons { get; init; }
}

/// <summary>One squad member's weapon + the fundamental-rune upgrades offered for it.</summary>
public sealed class SmithyMemberView
{
    public required string MemberId { get; init; }
    public required string Name { get; init; }

    /// <summary>Current main-hand weapon name (or "Unarmed" when nothing is equipped).</summary>
    public required string WeaponName { get; init; }

    public required int PotencyBonus { get; init; }
    public required bool HasStriking { get; init; }

    public required IReadOnlyList<SmithyRuneOption> RuneUpgrades { get; init; }
}

/// <summary>A purchasable rune upgrade for a member's weapon (gold + magical reagent — Refinement 3).</summary>
public sealed class SmithyRuneOption
{
    public required RuneKind Kind { get; init; }
    public required string Label { get; init; }
    public required int Cost { get; init; }

    /// <summary>Magical reagent (arcane_essence) and quantity consumed alongside the gold cost.</summary>
    public string ReagentItemId { get; init; } = RunePrices.ReagentItemId;
    public int ReagentCost { get; init; }

    /// <summary>True when the rune can still be applied (not already maxed on this weapon).</summary>
    public required bool Available { get; init; }

    /// <summary>True when gold covers <see cref="Cost"/> AND the inventory holds the reagent.</summary>
    public required bool CanAfford { get; init; }
}

/// <summary>A weapon on the smithy shelf (gold + optional metal ingots for higher tiers — Refinement 3).</summary>
public sealed class SmithyWeaponOption
{
    public required string WeaponSlug { get; init; }
    public required string DisplayName { get; init; }
    public required int Price { get; init; }

    /// <summary>Metal material (copper_ingot) and quantity consumed on purchase (0 = gold-only base entry).</summary>
    public string MetalItemId { get; init; } = "copper_ingot";
    public int MetalCost { get; init; }

    /// <summary>True when gold covers <see cref="Price"/> AND the inventory holds any required metal.</summary>
    public required bool CanAfford { get; init; }
}
