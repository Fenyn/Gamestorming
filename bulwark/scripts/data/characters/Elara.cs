namespace Bulwark.Data.Characters;

public static class Elara
{
    public const string CharacterId = "elara";

    public static readonly CharacterProfile Profile = new()
    {
        Id = CharacterId,
        DefaultName = "Elara",
        PlayerNamed = false,
        Pronouns = "she/her",
        ClassName = "Rogue",
        AncestryName = "Elf",
        Kind = CharacterKind.StartingPC,
        Bio = "A silver-tongued elven merchant who joined the company on the road to the outpost, "
            + "drawn by the crown's frontier trade concessions and reasons of her own.",
        Personality = "Warm charm over cool calculation. Reads a room like a jeweler reads a gem. "
            + "Never flustered, and understands that the truth has many angles — some more profitable.",
        RoleDescription = "Runs the Trading Post. Handles buying, selling, and the flow of goods. "
            + "The economic engine and social fulcrum of the outpost.",
        AssociatedBuildingId = "trading_post",
        Arrival = null,
        PortraitId = "elara",
        SpriteId = "rogue",
        Build = null,
    };
}
