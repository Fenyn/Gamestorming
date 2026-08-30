using System;

namespace Delve.Run;

/// <summary>
/// Wardstone tunables. All in one record so the future outpost upgrade layer can hand a run a
/// modified rule set (larger <see cref="MaxWard"/>, smaller <see cref="ShortRestBurn"/>) without
/// touching the Wardstone itself.
/// </summary>
public sealed record WardstoneRules
{
    /// <summary>Ward the stone holds at the start of a run.</summary>
    public int MaxWard { get; init; } = 100;

    /// <summary>Ward one short rest consumes.</summary>
    public int ShortRestBurn { get; init; } = 15;

    /// <summary>Ward each node advance consumes. Passive-burn seam; 0 keeps it off.</summary>
    public int NodeBurn { get; init; } = 0;

    /// <summary>Ward a Campsite night's rest restores.</summary>
    public int CampsiteRefill { get; init; } = 25;

    /// <summary>Ward at or above this applies no upshift to rolled threat tiers.</summary>
    public int SteadyAbove { get; init; } = 70;

    /// <summary>Ward at or above this (and below <see cref="SteadyAbove"/>) upshifts by 1 tier.</summary>
    public int FirstShiftAbove { get; init; } = 40;

    /// <summary>Ward at or above this (and below <see cref="FirstShiftAbove"/>) upshifts by 2
    /// tiers. Below it the upshift is 3.</summary>
    public int SecondShiftAbove { get; init; } = 15;

    /// <summary>Lethal XP budget for a party of 4. Extends the book ladder (40/60/80/120/160).</summary>
    public int LethalBudgetBase { get; init; } = 200;

    /// <summary>Lethal budget change per party member away from 4. Extends the book
    /// per-character adjustments (10/20/20/30/40).</summary>
    public int LethalPerCharacterAdjust { get; init; } = 50;
}

/// <summary>
/// Encounter danger band. The first five values map 1:1 onto
/// <see cref="PF2e.Data.EncounterDifficulty"/>; Lethal is a delve-only tier above the book budgets.
/// </summary>
public enum ThreatTier
{
    Trivial,
    Low,
    Moderate,
    Severe,
    Extreme,
    Lethal,
}

/// <summary>
/// The device the party carries into the delve, and the run's health meter. Each floor sets the
/// base threat distribution; as the ward burns down, <see cref="Upshift"/> raises every rolled
/// tier toward Lethal. Pure state - the flow layer decides when to burn and refill, the encounter
/// generator reads the upshift. Bosses ignore it (design/core_concept.md, "Wardstone").
/// </summary>
public sealed class Wardstone
{
    public Wardstone(WardstoneRules? rules = null)
    {
        Rules = rules ?? new WardstoneRules();
        Ward = Rules.MaxWard;
    }

    public WardstoneRules Rules { get; }

    /// <summary>Ward remaining, <see cref="WardstoneRules.MaxWard"/> down to 0.</summary>
    public int Ward { get; private set; }

    /// <summary>Tiers added to every rolled threat tier at the current ward: 0 while the ward
    /// holds, up to 3 when it is nearly spent.</summary>
    public int Upshift =>
        Ward >= Rules.SteadyAbove ? 0
        : Ward >= Rules.FirstShiftAbove ? 1
        : Ward >= Rules.SecondShiftAbove ? 2
        : 3;

    /// <summary>Consume the ward one short rest costs.</summary>
    public void BurnShortRest() => Burn(Rules.ShortRestBurn);

    /// <summary>Consume the ward one node advance costs. No-op while <see cref="WardstoneRules.NodeBurn"/> is 0.</summary>
    public void BurnNode() => Burn(Rules.NodeBurn);

    /// <summary>Restore the ward a Campsite night's rest grants, up to the maximum.</summary>
    public void RefillCampsite() => Ward = Math.Min(Rules.MaxWard, Ward + Rules.CampsiteRefill);

    /// <summary>Restore the ward completely. Beating a floor's Depths Warden recharges the stone.</summary>
    public void RefillFull() => Ward = Rules.MaxWard;

    /// <summary>Lethal XP budget for a party size, extending the book's per-character scaling.</summary>
    public int LethalBudget(int partySize) =>
        Rules.LethalBudgetBase + (partySize - 4) * Rules.LethalPerCharacterAdjust;

    private void Burn(int amount) => Ward = Math.Max(0, Ward - amount);
}
