namespace Bulwark.Data.Characters;

public static class Fenwick
{
    public const string CharacterId = "fenwick";

    public static readonly CharacterProfile Profile = new()
    {
        Id = CharacterId,
        DefaultName = "Fenwick",
        PlayerNamed = false,
        Pronouns = "he/him",
        ClassName = "Wizard",
        AncestryName = "Halfling",
        Kind = CharacterKind.StartingPC,
        Bio = "A halfling wizard-turned-cook who trained at the academy alongside the player. "
            + "Calls himself the world's first gastronomancer. Volunteered for the frontier posting "
            + "to build a kitchen from scratch.",
        Personality = "Academic warmth. Talks to everyone, remembers what they like to eat, and "
            + "believes morale starts at the table. Chipper without being grating — genuine, not performed.",
        RoleDescription = "Runs the Kitchen and Tavern. Source of day-long meal buffs and the outpost's "
            + "social anchor. The party's second spellcaster.",
        AssociatedBuildingId = "tavern",
        Arrival = null,
        PortraitId = "fenwick",
        SpriteId = "wizard",
        Build = null,
    };
}
