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
}
