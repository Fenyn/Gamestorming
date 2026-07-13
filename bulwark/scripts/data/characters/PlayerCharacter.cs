using Bulwark.Presets;

namespace Bulwark.Data.Characters;

public static class PlayerCharacter
{
    public const string CharacterId = PresetCharacters.PlayerId;

    public static readonly CharacterProfile Profile = new()
    {
        Id = CharacterId,
        DefaultName = "Warden",
        PlayerNamed = true,
        Pronouns = "he/him",
        ClassName = "Fighter",
        AncestryName = "Human",
        Kind = CharacterKind.StartingPC,
        Bio = "A farmhand who joined the army, sent to reinforce a neglected frontier outpost.",
        Personality = "Practical and steady. Knows the land — grew up working it. "
            + "More comfortable with a hoe than a salute, but carries a soldier's discipline.",
        RoleDescription = "The player's avatar. Drives farming, outpost expansion, and upgrades. "
            + "Not tied to any one building — the generalist who keeps the outpost moving.",
        AssociatedBuildingId = null,
        Arrival = null,
        PortraitId = "player",
        SpriteId = "veteran",
        Build = null,
    };
}
