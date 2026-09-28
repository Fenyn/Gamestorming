using System.Collections.Generic;
using System.Linq;

namespace Delve.Run.Events;

/// <summary>One grade of the Player Core healing potion: item level and the dice it heals.</summary>
public sealed record HealingPotion(string Name, int Level, int Dice, int Die, int Bonus)
{
    public string Formula => Bonus > 0 ? $"{Dice}d{Die}+{Bonus}" : $"{Dice}d{Die}";
}

/// <summary>Healing potion grades by item level (Player Core). A room hands out the best grade at or
/// below the party's level, drunk on the spot, so no run inventory is needed.</summary>
public static class HealingPotions
{
    public static readonly IReadOnlyList<HealingPotion> Grades = new[]
    {
        new HealingPotion("minor healing potion", 1, 1, 8, 0),
        new HealingPotion("lesser healing potion", 3, 2, 8, 5),
        new HealingPotion("moderate healing potion", 6, 3, 8, 10),
        new HealingPotion("greater healing potion", 12, 6, 8, 20),
    };

    public static HealingPotion ForLevel(int partyLevel)
        => Grades.Where(p => p.Level <= partyLevel).DefaultIfEmpty(Grades[0]).Last();

    /// <summary>The most wounded living member drinks one banked potion of the party's grade.
    /// Returns the line to show, or null when nobody is hurt or no potion is left.</summary>
    public static string? Drink(RunState state)
    {
        var drinker = state.Party.Living().Where(m => m.Health.CurrentHP < m.Health.MaxHP)
            .OrderByDescending(m => m.Health.MaxHP - m.Health.CurrentHP).FirstOrDefault();
        if (state.Potions <= 0 || drinker == null) return null;
        var potion = ForLevel(state.Party.Level);
        var rng = new System.Random(RunRng.StableSeed(state.StratumSeed, state.Clock.Day * 100 + state.Potions, "potion-drink"));
        int healed = potion.Bonus + Enumerable.Range(0, potion.Dice).Sum(_ => rng.Next(1, potion.Die + 1));
        int before = drinker.Health.CurrentHP;
        drinker.Health.Heal(healed);
        state.Potions--;
        return $"{drinker.Name} drinks a {potion.Name}. HP {before} → {drinker.Health.CurrentHP}.";
    }
}
