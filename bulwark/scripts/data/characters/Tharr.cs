using Bulwark.Presets;

namespace Bulwark.Data.Characters;

public static class Tharr
{
    public const string CharacterId = PresetCharacters.TharrId;

    public static readonly CharacterProfile Profile = new()
    {
        Id = CharacterId,
        DefaultName = "Tharr",
        PlayerNamed = false,
        Pronouns = "he/him",
        ClassName = "Cleric",
        AncestryName = "Dwarf",
        Kind = CharacterKind.StartingPC,
        Bio = "A dwarven stonemason and cleric, stationed alone at this crumbling outpost. "
            + "Has been struggling to hold it together on his own.",
        Personality = "Gruff but dependable. Takes pride in solid craftsmanship. "
            + "Quietly relieved to finally have help, though he won't say it outright.",
        RoleDescription = "Construction-master. Leads building repair, restoration, and new construction. "
            + "Operates the planning table at the Command Post.",
        AssociatedBuildingId = "command_post",
        Arrival = null,
        PortraitId = "tharr",
        SpriteId = "cleric",
        Build = null,
    };

    /// <summary>
    /// Minimal proving friendship content (design/friendship.md Phase 1): a stonemason's tastes —
    /// fine worked materials loved, raw building stock liked, vermin trophies hated. The unlock
    /// table ships EVENT HOOKS only (the future dialogue system consumes the ids); perk/recipe
    /// unlock entries are authored later per character.
    /// </summary>
    public static readonly FriendshipProfile Friendship = new()
    {
        CharacterId = CharacterId,
        Befriendable = true,
        LovedItems = new[] { "cut_stone", "copper_ingot" },
        LikedItems = new[] { "stone", "plank", "hearty_stew" },
        LikedCategories = new[] { ItemCategory.Refined },
        DislikedCategories = new[] { ItemCategory.Seed },
        HatedItems = new[] { "rat_pelt" },
        BirthdaySeason = Season.Summer,
        BirthdayDay = 11,
        Romanceable = false,
        Unlocks = new HeartUnlock[]
        {
            new() { Heart = 2, EventId = "tharr_heart_2" },
            new() { Heart = 4, EventId = "tharr_heart_4" },
            new() { Heart = 6, EventId = "tharr_heart_6" },
            new() { Heart = 8, EventId = "tharr_heart_8" },
            new() { Heart = 10, EventId = "tharr_heart_10" },
        },
    };
}
