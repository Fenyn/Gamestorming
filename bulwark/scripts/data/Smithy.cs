using System.Collections.Generic;
using System.Linq;

namespace Bulwark.Data;

/// <summary>Fundamental weapon runes the smithy applies (Phase 1: gold-only, no material cost).</summary>
public enum RuneKind
{
    /// <summary>Potency rune: +1 to attack per step (up to +3).</summary>
    Potency,

    /// <summary>Striking rune: a second weapon damage die (None → Striking).</summary>
    Striking,
}

/// <summary>
/// Unlock tier for a smithy catalog entry. Phase 1 populates <see cref="Base"/> only; Phase 2's
/// building-upgrade system unlocks higher tiers by raising the available-tier ceiling.
/// </summary>
public enum SmithyTier
{
    Base = 0,
    Improved = 1,
    Advanced = 2,
}

/// <summary>
/// Rune application costs. Refinement 3: runes are a MAGICAL enchantment layer on equipment, so
/// applying one costs gold + a MAGICAL (non-metal) reagent — the abstracted <see cref="ReagentItemId"/>
/// (arcane_essence). Kept abstracted: a single magical reagent drives runes generally (no per-rune
/// materials). Metal is NOT a rune input — it drives higher-tier EQUIPMENT instead (see
/// <see cref="WeaponCatalogEntry.MetalCost"/>). Gold + reagent counts are PLACEHOLDER/modest; tunable.
/// </summary>
public static class RunePrices
{
    public const int Potency = 150;
    public const int Striking = 400;

    /// <summary>Highest potency step the smithy sells (PF2e fundamental cap).</summary>
    public const int MaxPotency = 3;

    /// <summary>The abstracted MAGICAL rune reagent consumed (in addition to gold) on every rune apply.
    /// CONTENT FLAG: arcane_essence has no gather source authored yet (see <see cref="Bulwark.Data.Items.ArcaneEssence"/>).</summary>
    public const string ReagentItemId = "arcane_essence";

    public static int CostOf(RuneKind kind) => kind switch
    {
        RuneKind.Potency => Potency,
        RuneKind.Striking => Striking,
        _ => int.MaxValue,
    };

    /// <summary>Units of the magical reagent a rune consumes alongside its gold cost (placeholder/modest).</summary>
    public static int ReagentCostOf(RuneKind kind) => kind switch
    {
        RuneKind.Potency => 1,
        RuneKind.Striking => 2,
        _ => 0,
    };
}

/// <summary>One weapon the smithy sells: a real pack weapon slug (resolved through the engine's
/// GameDataLoader — stats are never invented here) plus a gold price, unlock tier, and (Refinement 3)
/// an optional METAL-material cost. Metal (ingots) drives higher-tier EQUIPMENT: base-tier entries stay
/// gold-only (<see cref="MetalCost"/> 0), while higher-tier entries (SmithyTier &gt; Base) require metal
/// ingots consumed on purchase. Roughly abstracted — a broad metal category (copper_ingot) maps to the
/// upgrade, not a hyper-specific per-item material. Costs are PLACEHOLDER/modest; tunable.</summary>
public sealed class WeaponCatalogEntry
{
    /// <summary>Pack equipment slug (e.g. "longsword") — the id GameDataLoader.FindEquipment takes.</summary>
    public required string WeaponSlug { get; init; }
    public required string DisplayName { get; init; }
    public required int Price { get; init; }
    public SmithyTier Tier { get; init; } = SmithyTier.Base;

    /// <summary>Metal ingot item consumed on purchase (Refinement 3). Default copper_ingot; only charged
    /// when <see cref="MetalCost"/> &gt; 0. CONTENT FLAG: copper_ingot needs copper_ore→smelter authored.</summary>
    public string MetalItemId { get; init; } = "copper_ingot";

    /// <summary>Units of <see cref="MetalItemId"/> consumed on purchase (0 = gold-only, for base entries).</summary>
    public int MetalCost { get; init; }
}

/// <summary>
/// The smithy weapon shop's curated core set. Every entry references an existing PF2e pack weapon
/// by slug (verified present in the equipment pack); the smithy builds the WeaponInstance from the
/// engine WeaponDefinition when purchased. Phase 1 = <see cref="SmithyTier.Base"/> only; higher
/// tiers are authored ahead for Phase 2 building unlocks. Data-only per CLAUDE.md.
/// </summary>
public static class WeaponCatalog
{
    private static readonly WeaponCatalogEntry[] Entries =
    {
        // --- Base tier: simple + martial, L1-5 appropriate melee/ranged ---
        new() { WeaponSlug = "dagger", DisplayName = "Dagger", Price = 20 },
        new() { WeaponSlug = "club", DisplayName = "Club", Price = 15 },
        new() { WeaponSlug = "mace", DisplayName = "Mace", Price = 60 },
        new() { WeaponSlug = "spear", DisplayName = "Spear", Price = 40 },
        new() { WeaponSlug = "shortsword", DisplayName = "Shortsword", Price = 90 },
        new() { WeaponSlug = "rapier", DisplayName = "Rapier", Price = 200 },
        new() { WeaponSlug = "longsword", DisplayName = "Longsword", Price = 100 },
        new() { WeaponSlug = "scimitar", DisplayName = "Scimitar", Price = 100 },
        new() { WeaponSlug = "warhammer", DisplayName = "Warhammer", Price = 130 },
        new() { WeaponSlug = "battle-axe", DisplayName = "Battle Axe", Price = 100 },
        new() { WeaponSlug = "greatsword", DisplayName = "Greatsword", Price = 220 },
        new() { WeaponSlug = "greataxe", DisplayName = "Greataxe", Price = 200 },
        new() { WeaponSlug = "shortbow", DisplayName = "Shortbow", Price = 90 },
        new() { WeaponSlug = "longbow", DisplayName = "Longbow", Price = 120 },

        // --- Higher-tier gear (Refinement 3): unlocked by smithy upgrades AND paid partly in METAL.
        //     Metal ingots drive the better/new weapon types; gold + copper_ingot. Placeholder costs. ---
        new() { WeaponSlug = "falchion", DisplayName = "Falchion", Price = 300, Tier = SmithyTier.Improved, MetalCost = 2 },
        new() { WeaponSlug = "maul", DisplayName = "Maul", Price = 320, Tier = SmithyTier.Improved, MetalCost = 2 },
        new() { WeaponSlug = "glaive", DisplayName = "Glaive", Price = 360, Tier = SmithyTier.Advanced, MetalCost = 3 },
        new() { WeaponSlug = "halberd", DisplayName = "Halberd", Price = 380, Tier = SmithyTier.Advanced, MetalCost = 3 },
    };

    /// <summary>Every catalog entry (all tiers).</summary>
    public static IReadOnlyList<WeaponCatalogEntry> All => Entries;

    /// <summary>Entries unlocked at or below <paramref name="maxTier"/> (the available shelf).</summary>
    public static IEnumerable<WeaponCatalogEntry> Available(SmithyTier maxTier = SmithyTier.Base)
        => Entries.Where(e => e.Tier <= maxTier);

    /// <summary>Look up an available entry by slug. False when the slug is unknown or its tier is
    /// still locked at <paramref name="maxTier"/>.</summary>
    public static bool TryGetAvailable(string weaponSlug, out WeaponCatalogEntry entry,
        SmithyTier maxTier = SmithyTier.Base)
    {
        entry = Entries.FirstOrDefault(e => e.Tier <= maxTier && e.WeaponSlug == weaponSlug)!;
        return entry != null;
    }
}
