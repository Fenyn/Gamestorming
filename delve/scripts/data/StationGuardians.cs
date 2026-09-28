using PF2e.Data;

namespace Delve.Data;

/// <summary>
/// The ward chamber guardians of the dungeon run, one per floor. The keepers left constructs to hold
/// the ward engine, so floors 1 and 2 fight animated guardians; the last floor keeps the Depths Warden
/// from <see cref="BossEncounters"/>, the run's final boss. Budgets use the same yardstick as the
/// wilderness bosses (4 members at the pinned level), PF2e XP by creature level against party level.
/// The node-map run keeps <see cref="BossEncounters"/> unchanged.
/// </summary>
public static class StationGuardians
{
    private const string MonsterCore = "pathfinder-monster-core";

    private static CreatureRef Ref(string name, string slug) => new() { DisplayName = name, Pack = MonsterCore, Slug = slug };

    /// <summary>Floor 1. At 4@3: Elite Animated Statue (L4, 60) + two Animated Armors (L2, 30 each)
    /// = 120 XP, Severe. Same budget as the Dire Wolf pack it replaces.</summary>
    private static readonly BossSpec HallOfArms = new()
    {
        Id = "station-hall-of-arms",
        PinnedLevel = 3,
        Spawns = new BossSpawn[]
        {
            new(Ref("Animated Statue", "animated-statue"), Count: 1, CreatureAdjustment.Elite),
            new(Ref("Animated Armor", "animated-armor"), Count: 2),
        },
    };

    /// <summary>Floor 2. At 4@6: Elite Giant Animated Statue (L8, 80) + two Elite Animated Statues
    /// (L4, 20 each) = 120 XP, Severe.</summary>
    private static readonly BossSpec StoneWatch = new()
    {
        Id = "station-stone-watch",
        PinnedLevel = 6,
        Spawns = new BossSpawn[]
        {
            new(Ref("Giant Animated Statue", "giant-animated-statue"), Count: 1, CreatureAdjustment.Elite),
            new(Ref("Animated Statue", "animated-statue"), Count: 2, CreatureAdjustment.Elite),
        },
    };

    private static readonly BossSpec[] ByStratum = { HallOfArms, StoneWatch };

    /// <summary>Guardian for a floor. Past the authored station rows it is the wilderness table's
    /// boss for that floor, so the last floor stays the Depths Warden.</summary>
    public static BossSpec ForStratum(int stratum)
        => stratum >= 0 && stratum < ByStratum.Length ? ByStratum[stratum] : BossEncounters.ForStratum(stratum);
}
