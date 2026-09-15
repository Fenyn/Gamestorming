using System;

namespace Delve.Run;

/// <summary>
/// Leveling tunables. XP per level is heavily accelerated against the book's 1000 so three small
/// floors carry the full 1-10 flow (design/core_concept.md "Run flow"). Awards themselves are RAW:
/// the encounter's XP total, relative to the party's level - which keeps the leveling pace roughly
/// constant per fight as the party grows.
/// </summary>
public sealed record LevelingRules
{
    public int XpPerLevel { get; init; } = 150;

    public int MaxLevel { get; init; } = 10;
}

/// <summary>
/// Run-scoped XP. Crossing a threshold raises the party's earned level and queues
/// member promotions. The character sheet applies each level after a player choice.
/// </summary>
public static class PartyLeveling
{
    /// <summary>
    /// Award XP and queue promotions for the whole party. Returns levels earned
    /// (0 at the cap or below the threshold).
    /// </summary>
    public static int Award(RunState state, int xp)
    {
        if (xp <= 0) return 0;
        var rules = state.Leveling;
        state.Xp += xp;

        int gained = 0;
        while (state.Xp >= rules.XpPerLevel && state.Party.Level + gained < rules.MaxLevel)
        {
            state.Xp -= rules.XpPerLevel;
            gained++;
        }
        // At the cap the pool stops mattering; hold it at the threshold so the UI reads "full".
        if (state.Party.Level + gained >= rules.MaxLevel)
            state.Xp = Math.Min(state.Xp, rules.XpPerLevel);
        if (gained == 0) return 0;

        int to = state.Party.Level + gained;
        foreach (var member in state.Party.Members)
            CharacterPromotion.Earn(member, to);
        state.Party.SetLevel(to);
        return gained;
    }
}
