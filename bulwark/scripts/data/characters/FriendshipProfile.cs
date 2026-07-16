using System;
using System.Collections.Generic;

namespace Bulwark.Data.Characters;

/// <summary>How much a character enjoys receiving a particular gift item.</summary>
public enum GiftTier
{
    Loved,
    Liked,
    Neutral,
    Disliked,
    Hated,
}

/// <summary>
/// One heart-threshold unlock entry: when the character's friendship first reaches
/// <see cref="Heart"/>, the entry's payload applies (each fires exactly ONCE — no decay, so
/// once-earned stays earned). All payload fields are optional and composable:
///  - <see cref="EventId"/> is the PHASE-4 HOOK the future dialogue/cutscene system consumes —
///    the framework fires <c>HeartThresholdReached</c> and carries this id; no event content ships.
///  - <see cref="Effect"/> is an optional domain perk, expressed as a declarative
///    <see cref="BuildingEffect"/> that a friendship effect source feeds into
///    <see cref="Bulwark.Cozy.OutpostEffects"/> (additive with building effects — e.g. a
///    StorePriceDiscount or InfirmaryHealing bonus granted by hearts).
///  - <see cref="UnlockCategoryId"/> is an optional recipe/item unlock, flowing through the
///    existing CategoryUnlock membership seam (crafting recipes gate on it already).
/// </summary>
public sealed class HeartUnlock
{
    /// <summary>Heart level (1..10) at which this entry fires.</summary>
    public required int Heart { get; init; }

    /// <summary>Dialogue/heart-event id for the future dialogue system (Phase-4 hook; no content ships).</summary>
    public string? EventId { get; init; }

    /// <summary>Optional domain-perk effect fed into the OutpostEffects aggregator once earned.</summary>
    public BuildingEffect? Effect { get; init; }

    /// <summary>Optional category id unlocked via the existing CategoryUnlock seam once earned.</summary>
    public string? UnlockCategoryId { get; init; }
}

/// <summary>
/// Per-character FRIENDSHIP data, keyed by character id and authored alongside the
/// <see cref="CharacterProfile"/>s (design/friendship.md). Data-only per CLAUDE.md: gift
/// preferences (by item id AND/OR item category; anything unlisted is neutral), birthday,
/// the romanceable flag, and the heart-threshold unlock table. The player avatar's profile
/// sets <see cref="Befriendable"/> = false; townsfolk without an authored profile default to
/// a befriendable all-neutral profile (see <see cref="Friendships"/>).
/// </summary>
public sealed class FriendshipProfile
{
    public required string CharacterId { get; init; }

    /// <summary>Whether this character can be befriended at all (false for the player avatar).</summary>
    public bool Befriendable { get; init; } = true;

    // --- Gift preferences (item ids and/or categories; unlisted = neutral) ---
    public IReadOnlyList<string> LovedItems { get; init; } = Array.Empty<string>();
    public IReadOnlyList<string> LikedItems { get; init; } = Array.Empty<string>();
    public IReadOnlyList<string> DislikedItems { get; init; } = Array.Empty<string>();
    public IReadOnlyList<string> HatedItems { get; init; } = Array.Empty<string>();
    public IReadOnlyList<ItemCategory> LovedCategories { get; init; } = Array.Empty<ItemCategory>();
    public IReadOnlyList<ItemCategory> LikedCategories { get; init; } = Array.Empty<ItemCategory>();
    public IReadOnlyList<ItemCategory> DislikedCategories { get; init; } = Array.Empty<ItemCategory>();
    public IReadOnlyList<ItemCategory> HatedCategories { get; init; } = Array.Empty<ItemCategory>();

    /// <summary>Birthday season, or null when no birthday is authored (no multiplier ever applies).</summary>
    public Season? BirthdaySeason { get; init; }

    /// <summary>Birthday day-of-season (1..28); meaningful only when <see cref="BirthdaySeason"/> is set.</summary>
    public int BirthdayDay { get; init; }

    /// <summary>Whether a romance track can open for this character (authored content; Phase-4+).</summary>
    public bool Romanceable { get; init; }

    /// <summary>Heart-threshold unlock table (each entry fires once; see <see cref="HeartUnlock"/>).</summary>
    public IReadOnlyList<HeartUnlock> Unlocks { get; init; } = Array.Empty<HeartUnlock>();

    /// <summary>
    /// Preference lookup for a gift: explicit item ids take precedence over category listings;
    /// anything unlisted is <see cref="GiftTier.Neutral"/>. Pure data helper (no system rules —
    /// the point values per tier live in <see cref="Bulwark.Cozy.FriendshipSystem"/>).
    /// </summary>
    public GiftTier TierOf(string itemId)
    {
        if (Contains(LovedItems, itemId)) return GiftTier.Loved;
        if (Contains(LikedItems, itemId)) return GiftTier.Liked;
        if (Contains(DislikedItems, itemId)) return GiftTier.Disliked;
        if (Contains(HatedItems, itemId)) return GiftTier.Hated;

        if (Items.TryGet(itemId, out var def))
        {
            if (ContainsCategory(LovedCategories, def.Category)) return GiftTier.Loved;
            if (ContainsCategory(LikedCategories, def.Category)) return GiftTier.Liked;
            if (ContainsCategory(DislikedCategories, def.Category)) return GiftTier.Disliked;
            if (ContainsCategory(HatedCategories, def.Category)) return GiftTier.Hated;
        }
        return GiftTier.Neutral;
    }

    /// <summary>True when the given calendar date is this character's birthday.</summary>
    public bool IsBirthday(Season season, int day)
        => BirthdaySeason.HasValue && BirthdaySeason.Value == season && BirthdayDay == day;

    private static bool Contains(IReadOnlyList<string> list, string id)
    {
        for (int i = 0; i < list.Count; i++)
            if (list[i] == id)
                return true;
        return false;
    }

    private static bool ContainsCategory(IReadOnlyList<ItemCategory> list, ItemCategory cat)
    {
        for (int i = 0; i < list.Count; i++)
            if (list[i] == cat)
                return true;
        return false;
    }
}
