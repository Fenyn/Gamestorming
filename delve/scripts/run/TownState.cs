namespace Delve.Run;

/// <summary>How far the camp has grown. Later unlocks raise it; it never drops.</summary>
public enum TownTier
{
    Camp = 1,
    Outpost = 2,
    Hamlet = 3,
}

/// <summary>The camp's time of day. It advances one step each time a run ends.</summary>
public enum CampTimeOfDay
{
    Morning,
    Afternoon,
    Evening,
}

/// <summary>Outpost milestone ids that record each town upgrade.</summary>
public static class TownMilestones
{
    public const string Outpost = "town-outpost";
    public const string Hamlet = "town-hamlet";

    public static string For(TownTier tier) => tier switch
    {
        TownTier.Outpost => Outpost,
        TownTier.Hamlet => Hamlet,
        _ => "",
    };

    public static CampTimeOfDay Next(CampTimeOfDay time) => time switch
    {
        CampTimeOfDay.Morning => CampTimeOfDay.Afternoon,
        CampTimeOfDay.Afternoon => CampTimeOfDay.Evening,
        _ => CampTimeOfDay.Morning,
    };
}
