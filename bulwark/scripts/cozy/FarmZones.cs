namespace Bulwark.Cozy;

/// <summary>
/// Refinement 2 — the farm's TILLABLE-AREA expansion gate. Farm upgrades do not add a plot COUNT; they
/// expand the AREA of legal tilling cells. Each farm cell carries a ZONE tier (0 = base area, then one
/// tier per ring outward — see <c>OutpostScene.FarmZoneOf</c>); the outpost's current tillable-area
/// LEVEL (summed FarmPlots-effect magnitude, <see cref="OutpostEffects.TillableAreaLevel"/>) unlocks
/// zones ≤ level. The tillable area starts small (level 0 → only the base zone-0 rectangle) and grows
/// as the farmhouse tiers raise the level.
///
/// Pure rule so both the world scene (<c>OutpostScene.IsTillable</c>) and the headless spike share one
/// definition of "within the unlocked area" — the zone→cell mapping is the 3D scene's business, this
/// is only the level gate.
/// </summary>
public static class FarmZones
{
    /// <summary>The base zone every farm cell defaults to (tillable from level 0).</summary>
    public const int BaseZone = 0;

    /// <summary>True when a tile's <paramref name="tileZone"/> is within the currently unlocked tillable
    /// area (its zone ≤ the outpost's <paramref name="tillableAreaLevel"/>). Base zone (0) is always in.</summary>
    public static bool IsWithinTillableArea(int tileZone, int tillableAreaLevel) => tileZone <= tillableAreaLevel;
}
