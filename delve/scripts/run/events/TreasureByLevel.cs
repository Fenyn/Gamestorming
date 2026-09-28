namespace Delve.Run.Events;

/// <summary>
/// GM Core "Party Treasure by Level", currency column for a party of four, levels 1-10 (gp). Room
/// rewards authored at level 1 scale along this curve, so a level 10 cache is worth what a level 10
/// cache should be. Values quoted from memory; check against the book before balancing.
/// </summary>
public static class TreasureByLevel
{
    private static readonly int[] Currency = { 40, 70, 120, 200, 320, 500, 720, 1000, 1400, 2000 };

    public static int Scale(int levelOneAmount, int partyLevel)
    {
        int index = System.Math.Clamp(partyLevel, 1, Currency.Length) - 1;
        return levelOneAmount * Currency[index] / Currency[0];
    }
}
