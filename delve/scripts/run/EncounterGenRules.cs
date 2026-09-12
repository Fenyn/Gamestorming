namespace Delve.Run;

/// <summary>
/// Every generated-encounter tunable in one record. XP budgets always come from the real party
/// (level and member count); the floor's roster and the depth ramp constrain which creature LEVELS
/// may fill them, and the floor's <see cref="Delve.Data.TierWeights"/> plus the Wardstone upshift
/// set the tier.
/// </summary>
public sealed record EncounterGenRules
{
    // ------------------------------------------------ Depth -> creature level band

    /// <summary>Lowest creature level offset from party level, at any depth.</summary>
    public int MinOffset { get; init; } = -4;

    /// <summary>Highest offset on the entrance rows of a floor, before the depth ramp.</summary>
    public int EntranceMaxOffset { get; init; } = 0;

    /// <summary>Map rows per +1 on the highest offset.</summary>
    public int FloorsPerOffsetStep { get; init; } = 2;

    /// <summary>The highest offset never exceeds this.</summary>
    public int MaxOffsetCap { get; init; } = 2;

    // ------------------------------------------------ Tier

    /// <summary>Tiers a Lair (Elite node) adds on top of its rolled tier, before the ward upshift.
    /// Lairs are the meaty elite fights (design/core_concept.md "Wardstone").</summary>
    public int LairTierBonus { get; init; } = 1;

    /// <summary>Party size at or below which a generated fight drops a tier. Reserved for small
    /// combat harnesses and a separate tutorial; normal expeditions always start with four.</summary>
    public int UnderstrengthPartySize { get; init; } = 1;

    /// <summary>Tiers taken off for an understrength party.</summary>
    public int UnderstrengthTierRelief { get; init; } = 1;

    /// <summary>Tiers off a generated fight at this party size. 0 once the party is up to strength.</summary>
    public int TierRelief(int partySize)
        => partySize > 0 && partySize <= UnderstrengthPartySize ? UnderstrengthTierRelief : 0;

    // ------------------------------------------------ Composition

    /// <summary>Hard cap on spawned enemies - the deployment zone's capacity.</summary>
    public int MaxEnemies { get; init; } = 8;

    /// <summary>Generated encounter names remembered for the generator's anti-repeat.</summary>
    public int RecentTemplateMemory { get; init; } = 3;

    // ------------------------------------------------ Board

    /// <summary>How big the battle map is for the party that walks onto it.</summary>
    public BattleMapRules Map { get; init; } = new();
}
