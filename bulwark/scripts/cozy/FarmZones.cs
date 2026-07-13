namespace Bulwark.Cozy;

/// <summary>
/// Refinement 2 — the farm's TILLABLE-AREA expansion gate. Farm upgrades do not add a plot COUNT; they
/// expand the AREA of legal tilling tiles. Each farmable Ground tile carries a ZONE tier (a tile
/// custom-data field, <see cref="CustomDataKey"/>, default 0 = base area); the outpost's current
/// tillable-area LEVEL (summed FarmPlots-effect magnitude, <see cref="OutpostEffects.TillableAreaLevel"/>)
/// unlocks zones ≤ level. The tillable area starts small (level 0 → only base zone-0 tiles) and grows
/// as the farmhouse tiers raise the level.
///
/// Pure rule so both the world scene (<c>OutpostScene.IsTillable</c>) and the headless spike share one
/// definition of "within the unlocked area".
///
/// BASELINE SAFETY: a tile with no authored zone data reads as zone 0, tillable at level 0 — so until
/// the user authors <see cref="CustomDataKey"/> tiers on the farmable tiles, behaviour is byte-identical
/// to the pre-refinement "all farmable soil is tillable" rule.
///
/// CONTENT HAND-OFF: the user authors the <c>farm_zone</c> integer custom-data layer on the Ground
/// TileSet and stamps higher tiers (1, 2, …) on the tiles that later farm upgrades should unlock — the
/// small→expand progression. Base soil stays zone 0 (or simply unauthored).
/// </summary>
public static class FarmZones
{
    /// <summary>Tile custom-data layer holding a farmable tile's zone tier (int; absent/0 = base zone).</summary>
    public const string CustomDataKey = "farm_zone";

    /// <summary>The base zone every farmable tile defaults to (tillable from level 0).</summary>
    public const int BaseZone = 0;

    /// <summary>True when a tile's <paramref name="tileZone"/> is within the currently unlocked tillable
    /// area (its zone ≤ the outpost's <paramref name="tillableAreaLevel"/>). Base zone (0) is always in.</summary>
    public static bool IsWithinTillableArea(int tileZone, int tillableAreaLevel) => tileZone <= tillableAreaLevel;
}
