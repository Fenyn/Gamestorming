using System.Collections.Generic;
using System.Linq;

namespace Bulwark.Data;

/// <summary>
/// The smithy PROGRESSION GATE seam: pure tier-comparison helpers shared by the shop command path
/// (GameState) and the tests, so the "unlock ceiling opens higher-tier gear" rule lives in exactly
/// one place. The ceiling itself comes from <see cref="Bulwark.Cozy.OutpostEffects.SmithyTier"/>
/// (baseline <see cref="SmithyTier.Base"/>); nothing here commits specific catalog content.
///
/// Fundamental runes (Potency/Striking) are BASE tier — always available (ungated baseline). Higher
/// tiers exist as data seams: property/elemental runes will map to Improved/Advanced here once
/// property-rune execution lands in the engine (FLAGGED — no rune content committed yet).
/// </summary>
public static class SmithyAccess
{
    /// <summary>Smithy tier a rune requires. Fundamental runes are Base (baseline, always unlocked).</summary>
    public static SmithyTier RequiredTier(RuneKind kind) => SmithyTier.Base;

    /// <summary>True when the outpost's smithy ceiling reaches a rune's required tier.</summary>
    public static bool RuneUnlocked(RuneKind kind, SmithyTier maxTier) => maxTier >= RequiredTier(kind);

    /// <summary>True when a weapon entry's tier is at or below the outpost's smithy ceiling.</summary>
    public static bool WeaponUnlocked(WeaponCatalogEntry entry, SmithyTier maxTier) => entry.Tier <= maxTier;

    /// <summary>Filter arbitrary catalog entries by the smithy ceiling — the shared gate the shop uses.</summary>
    public static IEnumerable<WeaponCatalogEntry> UnlockedWeapons(
        IEnumerable<WeaponCatalogEntry> entries, SmithyTier maxTier)
        => entries.Where(e => WeaponUnlocked(e, maxTier));
}
