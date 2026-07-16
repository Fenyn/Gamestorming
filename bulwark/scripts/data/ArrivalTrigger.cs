using System;

namespace Bulwark.Data;

/// <summary>
/// A villager's arrival condition (Phase 3 keystone): a small declarative model, evaluated purely
/// against an <see cref="IArrivalContext"/>, that decides WHEN a hand-authored named character shows
/// up at the outpost. Triggers are decoupled from buildings — building-restore is just ONE variant
/// among several (story flags, calendar dates, AND-composites). Construct via the static factories:
///
///   ArrivalTrigger.BuildingReached("smithy", minTier: 1)   // a building restored to a tier
///   ArrivalTrigger.StoryFlag("met_the_smith")              // a story beat happened
///   ArrivalTrigger.DateReached(Season.Summer, day: 5)      // the calendar reached a date
///   ArrivalTrigger.ItemCountReached("beast_hide", 8)       // the party has stockpiled N of an item
///   ArrivalTrigger.FriendshipReached("tharr", 4)           // a character reached a heart level
///   ArrivalTrigger.All(triggerA, triggerB, ...)            // every sub-trigger satisfied
///
/// Pure and immutable: the definition holds the trigger, the live <see cref="IArrivalContext"/> is
/// supplied at evaluation time, so nothing about a trigger is persisted (only the resulting arrival
/// state is). Concrete variants are private nested types — content authors only ever see the
/// factories.
/// </summary>
public abstract class ArrivalTrigger
{
    /// <summary>True when this trigger's condition holds against the current game state.</summary>
    public abstract bool IsSatisfied(IArrivalContext context);

    // ===================== Factories (the authoring surface) =====================

    /// <summary>Fires once a building reaches (≥) the given tier — the domain-gate arrival path.</summary>
    public static ArrivalTrigger BuildingReached(string buildingId, int minTier)
        => new BuildingReachedTrigger(buildingId, minTier);

    /// <summary>Fires once a bulwark story flag is set — story-beat arrivals and future quests.</summary>
    public static ArrivalTrigger StoryFlag(string flagId)
        => new StoryFlagTrigger(flagId);

    /// <summary>Fires once the calendar reaches (≥) the given date. Year defaults to 1 (first year).</summary>
    public static ArrivalTrigger DateReached(Season season, int day, int year = 1)
        => new DateReachedTrigger(season, day, year);

    /// <summary>AND-composite: satisfied only when EVERY sub-trigger is (and at least one is given).</summary>
    public static ArrivalTrigger All(params ArrivalTrigger[] triggers)
        => new AllTrigger(triggers);

    /// <summary>OR-composite: satisfied once ANY sub-trigger is (false when none are given). The
    /// primary-trigger-or-fallback-date shape (e.g. Josen: a wounded/downed party member, OR a
    /// mid-Spring calendar fallback so a cautious/lucky player can't lock him out forever).</summary>
    public static ArrivalTrigger Any(params ArrivalTrigger[] triggers)
        => new AnyTrigger(triggers);

    /// <summary>
    /// Fires once the party's total CURRENT count of an item (every member's carry plus the outpost
    /// warehouse — <see cref="IArrivalContext.CountItem"/>) reaches (≥) <paramref name="minCount"/>.
    /// E.g. a curator character who shows up once the party has stockpiled enough monster trophies
    /// (see design/economy/characters.md — Hazel/Reliquary). NOTE: this reads CURRENT holdings, not a
    /// lifetime/cumulative total — spending or selling counted items lowers it back below the
    /// threshold. A future lifetime-counter seam would be a separate trigger variant if that
    /// distinction turns out to matter for an authored character.
    /// </summary>
    public static ArrivalTrigger ItemCountReached(string itemId, int minCount)
        => new ItemCountReachedTrigger(itemId, minCount);

    /// <summary>
    /// Fires once a character's friendship reaches (≥) <paramref name="minHearts"/> hearts
    /// (<see cref="IArrivalContext.HeartsOf"/> — the FriendshipSystem heart model, see
    /// design/friendship.md). The arrival gate for social/missable characters: someone who only
    /// shows up once the party is close with someone else. Friendship never decays, so once
    /// satisfied the condition stays satisfied.
    /// </summary>
    public static ArrivalTrigger FriendshipReached(string characterId, int minHearts)
        => new FriendshipReachedTrigger(characterId, minHearts);

    /// <summary>
    /// Absolute day index for calendar comparisons: 28 days per season, 4 seasons per year, year
    /// 1-based. Shared by <see cref="DateReachedTrigger"/> and GameState's context so both order
    /// dates identically.
    /// </summary>
    public static int Ordinal(int year, Season season, int day)
        => ((Math.Max(1, year) - 1) * 4 + (int)season) * DaysPerSeason + day;

    private const int DaysPerSeason = 28;

    // ===================== Variants =====================

    private sealed class BuildingReachedTrigger : ArrivalTrigger
    {
        private readonly string _buildingId;
        private readonly int _minTier;

        public BuildingReachedTrigger(string buildingId, int minTier)
        {
            _buildingId = buildingId;
            _minTier = minTier;
        }

        public override bool IsSatisfied(IArrivalContext context)
            => context.GetBuildingTier(_buildingId) >= _minTier;
    }

    private sealed class StoryFlagTrigger : ArrivalTrigger
    {
        private readonly string _flagId;

        public StoryFlagTrigger(string flagId) => _flagId = flagId;

        public override bool IsSatisfied(IArrivalContext context)
            => context.HasStoryFlag(_flagId);
    }

    private sealed class DateReachedTrigger : ArrivalTrigger
    {
        private readonly int _targetOrdinal;

        public DateReachedTrigger(Season season, int day, int year)
            => _targetOrdinal = Ordinal(year, season, day);

        public override bool IsSatisfied(IArrivalContext context)
            => context.CurrentDayOrdinal >= _targetOrdinal;
    }

    private sealed class AllTrigger : ArrivalTrigger
    {
        private readonly ArrivalTrigger[] _triggers;

        public AllTrigger(ArrivalTrigger[] triggers)
            => _triggers = triggers ?? Array.Empty<ArrivalTrigger>();

        public override bool IsSatisfied(IArrivalContext context)
        {
            // Empty composite never fires (avoids an accidental instant arrival).
            if (_triggers.Length == 0)
                return false;
            foreach (var t in _triggers)
                if (t == null || !t.IsSatisfied(context))
                    return false;
            return true;
        }
    }

    private sealed class AnyTrigger : ArrivalTrigger
    {
        private readonly ArrivalTrigger[] _triggers;

        public AnyTrigger(ArrivalTrigger[] triggers)
            => _triggers = triggers ?? Array.Empty<ArrivalTrigger>();

        public override bool IsSatisfied(IArrivalContext context)
        {
            // Empty composite never fires (mirrors AllTrigger's empty-set convention).
            if (_triggers.Length == 0)
                return false;
            foreach (var t in _triggers)
                if (t != null && t.IsSatisfied(context))
                    return true;
            return false;
        }
    }

    private sealed class ItemCountReachedTrigger : ArrivalTrigger
    {
        private readonly string _itemId;
        private readonly int _minCount;

        public ItemCountReachedTrigger(string itemId, int minCount)
        {
            _itemId = itemId;
            _minCount = minCount;
        }

        public override bool IsSatisfied(IArrivalContext context)
            => context.CountItem(_itemId) >= _minCount;
    }

    private sealed class FriendshipReachedTrigger : ArrivalTrigger
    {
        private readonly string _characterId;
        private readonly int _minHearts;

        public FriendshipReachedTrigger(string characterId, int minHearts)
        {
            _characterId = characterId;
            _minHearts = minHearts;
        }

        public override bool IsSatisfied(IArrivalContext context)
            => context.HeartsOf(_characterId) >= _minHearts;
    }
}
