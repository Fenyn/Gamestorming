using System.Collections.Generic;
using System.Linq;

namespace Delve.Data;

/// <summary>What one step of a resident's loop does.</summary>
public enum StepKind
{
    /// <summary>Repeat one work clip a few times at the current spot.</summary>
    Work,
    /// <summary>Walk to the resident's next spot in its work area.</summary>
    Walk,
    /// <summary>Stand and look about for a while.</summary>
    Idle,
    /// <summary>Sit at a seated spot, breathing.</summary>
    Sit,
    /// <summary>Get up from a seat, stand a while, and sit back down.</summary>
    Stretch,
}

/// <summary>One step of an activity loop. Repeats and seconds are ranges; a step with Chance below 1 is sometimes skipped.</summary>
public sealed record ActivityStep
{
    public required StepKind Kind { get; init; }
    public WorkMotion Motion { get; init; }
    public int MinRepeats { get; init; } = 1;
    public int MaxRepeats { get; init; } = 1;
    public float MinSeconds { get; init; }
    public float MaxSeconds { get; init; }
    public float Chance { get; init; } = 1f;

    /// <summary>The spot use the step needs (see <see cref="VillageActivities.Block"/>); the resident walks to
    /// an owned spot of that use first. Empty: wherever the resident stands.</summary>
    public string At { get; init; } = "";
}

/// <summary>A job or a pastime: the page its work clips come from, and its loop of steps.</summary>
public sealed record VillageActivity(string Id, string Page, IReadOnlyList<ActivityStep> Steps)
{
    /// <summary>The spot uses the loop works at, in loop order.</summary>
    public IReadOnlyList<string> Uses { get; } = Steps.Select(s => s.At).Where(at => at != "").Distinct().ToList();

    /// <summary>Sitting activities take a seated spot; the rest take standing spots.</summary>
    public bool Seated { get; init; }

    /// <summary>How many spots of its area the activity likes to move between.</summary>
    public int Spots { get; init; } = 2;
}

/// <summary>
/// Every village activity as a loop of full Mana Seed clips and pauses, never a held work frame.
/// A resident starts its loop at a random step, and every range is rolled from its own seed, so
/// neighbours never move in step.
/// </summary>
public static class VillageActivities
{
    public const string Chop = "chop";
    public const string Smith = "smith";
    public const string Garden = "garden";
    public const string Harvest = "harvest";
    public const string Train = "train";
    public const string Cook = "cook";
    public const string Watch = "watch";
    public const string Chat = "chat";
    public const string Sit = "sit";
    public const string Haul = "haul";
    public const string Wander = "wander";

    // Spot uses: what a work step acts on. A ResidentSpot of the same use stands at that prop, facing it.
    public const string Block = "block";
    public const string Pile = "pile";
    public const string Anvil = "anvil";
    public const string Bench = "bench";
    public const string Bed = "bed";
    public const string Pot = "pot";
    public const string Goods = "goods";
    public const string Hens = "hens";
    public const string Dummy = "dummy";

    private static ActivityStep Work(WorkMotion motion, int min, int max, string at, float chance = 1f) =>
        new() { Kind = StepKind.Work, Motion = motion, MinRepeats = min, MaxRepeats = max, At = at, Chance = chance };

    private static ActivityStep Idle(float min, float max, float chance = 1f) =>
        new() { Kind = StepKind.Idle, MinSeconds = min, MaxSeconds = max, Chance = chance };

    private static ActivityStep Walk(float chance = 1f) => new() { Kind = StepKind.Walk, Chance = chance };

    private static readonly Dictionary<string, VillageActivity> ById = new()
    {
        // Split a few rounds at the block, look up, sometimes stack the split logs on the pile.
        [Chop] = new(Chop, ManaSeedSheet.AxePage, new[]
        {
            Work(WorkMotion.Swing, 3, 6, Block), Idle(1f, 2.5f), Work(WorkMotion.Lift, 1, 2, Pile, 0.5f),
        }),
        // Hammer bursts at the anvil with breathers; now and then fetch stock from the bench.
        [Smith] = new(Smith, ManaSeedSheet.PickPage, new[]
        {
            Work(WorkMotion.Swing, 2, 5, Anvil), Idle(0.8f, 2f), Work(WorkMotion.Swing, 1, 3, Anvil, 0.6f),
            Work(WorkMotion.Lift, 1, 1, Bench, 0.4f), Idle(1f, 3f, 0.5f),
        }),
        // Hoe, sow, move along the beds, water, wipe the brow.
        [Garden] = new(Garden, ManaSeedSheet.HoePage, new[]
        {
            Work(WorkMotion.Swing, 2, 4, Bed), Work(WorkMotion.Seed, 1, 3, Bed), Walk(), Work(WorkMotion.Water, 2, 3, Bed),
            Idle(1f, 3f, 0.5f),
        }),
        // Lift the stored goods, then now and then scatter feed for the hens.
        [Harvest] = new(Harvest, ManaSeedSheet.HoePage, new[]
        {
            Work(WorkMotion.Lift, 1, 3, Goods), Idle(0.8f, 2f), Work(WorkMotion.Seed, 1, 2, Hens, 0.4f),
        }),
        // Shift crates and sacks about.
        [Haul] = new(Haul, ManaSeedSheet.HoePage, new[]
        {
            Work(WorkMotion.Lift, 1, 2, Goods), Idle(1f, 3f), Walk(0.5f),
        }),
        // Axe drills at the straw dummy.
        [Train] = new(Train, ManaSeedSheet.AxePage, new[]
        {
            Work(WorkMotion.Swing, 2, 4, Dummy), Idle(1f, 2f), Walk(0.4f),
        }),
        // Stir and season the pot, ladle now and then.
        [Cook] = new(Cook, ManaSeedSheet.HoePage, new[]
        {
            Work(WorkMotion.Seed, 2, 4, Pot), Idle(1f, 2.5f), Work(WorkMotion.Water, 1, 1, Pot, 0.4f),
        }),
        [Watch] = new(Watch, ManaSeedSheet.HoePage, new[] { Idle(3f, 7f), Walk(0.4f), Idle(2f, 5f) }),
        [Chat] = new(Chat, ManaSeedSheet.HoePage, new[] { Idle(2f, 6f), Idle(2f, 4f), Walk(0.15f) }) { Spots = 1 },
        [Sit] = new(Sit, ManaSeedSheet.HoePage, new[]
        {
            new ActivityStep { Kind = StepKind.Sit, MinSeconds = 8f, MaxSeconds = 18f },
            new ActivityStep { Kind = StepKind.Stretch, MinSeconds = 2f, MaxSeconds = 5f, Chance = 0.5f },
        }) { Seated = true, Spots = 1 },
        [Wander] = new(Wander, ManaSeedSheet.HoePage, new[] { Walk(), Idle(4f, 10f), Walk(), Idle(4f, 10f) }),
    };

    /// <summary>The activity for an id; unknown ids wander.</summary>
    public static VillageActivity For(string id) => ById.TryGetValue(id, out var activity) ? activity : ById[Wander];
}
