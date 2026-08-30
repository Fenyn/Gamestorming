using System.Collections.Generic;
using PF2e.Data;

namespace Delve.Data;

/// <summary>One creature line of a boss encounter.</summary>
public sealed record BossSpawn(
    CreatureRef Creature, int Count, CreatureAdjustment Adjustment = CreatureAdjustment.Normal);

/// <summary>
/// An authored boss fight. A floor boss is a STATIC encounter: a fixed creature list, tuned once
/// against a yardstick of 4 members at <see cref="PinnedLevel"/>. The book difficulty rating is a
/// design-time check only; the runtime applies no scaling and ignores the Wardstone
/// (design/core_concept.md "Bosses"). The actual party faces the list as-is.
/// </summary>
public sealed record BossSpec
{
    public required string Id { get; init; }

    /// <summary>Party level the creature list was authored against.</summary>
    public required int PinnedLevel { get; init; }

    /// <summary>Party size the creature list was authored against. Always 4 per the design doc.</summary>
    public int PinnedPartySize { get; init; } = 4;

    public required IReadOnlyList<BossSpawn> Spawns { get; init; }
}

/// <summary>
/// The boss table, one row per stratum, paired 1:1 with <see cref="FloorThemes"/> (CLAUDE.md:
/// per-kind behaviour in one data table). Beating a row's boss advances the run to the next floor;
/// the last row is the Depths Warden and ends the run in victory. The encounter spike re-derives
/// each row's XP through EncounterXPCalculator at the pinned values, so a new row that misses its
/// authored budget fails the spike instead of shipping quietly.
/// </summary>
public static class BossEncounters
{
    private const string MonsterCore = "pathfinder-monster-core";

    /// <summary>Floor 1. At 4@3: Elite Dire Wolf (60) + three Wolves (20 each) = 120 XP, Severe.
    /// The alpha the tutorial death sold, grown, with its pack.</summary>
    private static readonly BossSpec DireWolfLair = new()
    {
        Id = "dire-wolf-lair",
        PinnedLevel = 3,
        Spawns = new BossSpawn[]
        {
            new(new CreatureRef
            {
                DisplayName = "Dire Wolf", Pack = MonsterCore, Slug = "dire-wolf",
            }, Count: 1, CreatureAdjustment.Elite),
            new(new CreatureRef
            {
                DisplayName = "Wolf", Pack = MonsterCore, Slug = "wolf",
            }, Count: 3),
        },
    };

    /// <summary>Floor 2. At 4@6: Arboreal Regent (80) + Forest Troll (30) = 110 XP, strong
    /// Moderate. A treant lord the fog turned, with a wood troll at its roots. Add a second troll
    /// (140) if playtests read it as easy.</summary>
    private static readonly BossSpec RegentsGrove = new()
    {
        Id = "regents-grove",
        PinnedLevel = 6,
        Spawns = new BossSpawn[]
        {
            new(new CreatureRef
            {
                DisplayName = "Arboreal Regent", Pack = MonsterCore, Slug = "arboreal-regent",
            }, Count: 1),
            new(new CreatureRef
            {
                DisplayName = "Forest Troll", Pack = MonsterCore, Slug = "forest-troll",
            }, Count: 1),
        },
    };

    /// <summary>Floor 3, the Depths Warden. At 4@10: Adult Horned Dragon (80) + two Marsh Giants
    /// (20 each) = 120 XP, Severe. An unnamed dragon risen from the swamp heart with giant thralls
    /// (the Ungilded firewall permits an unnamed dragon; see "Ungilded link").</summary>
    private static readonly BossSpec DepthsWarden = new()
    {
        Id = "depths-warden",
        PinnedLevel = 10,
        Spawns = new BossSpawn[]
        {
            new(new CreatureRef
            {
                DisplayName = "Adult Horned Dragon", Pack = MonsterCore, Slug = "horned-dragon-adult",
            }, Count: 1),
            new(new CreatureRef
            {
                DisplayName = "Marsh Giant", Pack = MonsterCore, Slug = "marsh-giant",
            }, Count: 2),
        },
    };

    private static readonly BossSpec[] ByStratum = { DireWolfLair, RegentsGrove, DepthsWarden };

    /// <summary>Boss for a stratum index. Clamps to the last authored row, so a deeper stratum
    /// without its own boss repeats the deepest one instead of crashing.</summary>
    public static BossSpec ForStratum(int stratum)
    {
        if (stratum < 0) stratum = 0;
        if (stratum >= ByStratum.Length) stratum = ByStratum.Length - 1;
        return ByStratum[stratum];
    }
}
