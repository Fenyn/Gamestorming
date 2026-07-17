namespace Bulwark.Data.Characters;

public enum CharacterKind { StartingPC, RecruitablePC, Townsfolk }

public sealed class CharacterProfile
{
    public required string Id { get; init; }
    public required string DefaultName { get; init; }
    public bool PlayerNamed { get; init; }
    public string? Pronouns { get; init; }
    public string? Bio { get; init; }
    public string? Personality { get; init; }

    public required string ClassName { get; init; }
    public required string AncestryName { get; init; }

    public required CharacterKind Kind { get; init; }
    public string? RoleDescription { get; init; }
    public string? AssociatedBuildingId { get; init; }

    public ArrivalTrigger? Arrival { get; init; }

    public string? PortraitId { get; init; }
    public string? SpriteId { get; init; }
    public string MarkerName => $"Villager_{Id}";

    // TODO: FA build layer — populated when full PC builds are authored.
    public BuildSpec? Build { get; init; }

    public VillagerDefinition ToVillagerDefinition() => new()
    {
        Id = Id,
        DisplayName = DefaultName,
        AssociatedBuildingId = AssociatedBuildingId,
        Arrival = Arrival!,
        Recruitable = Kind == CharacterKind.RecruitablePC,
        JoinPresetKey = Kind == CharacterKind.RecruitablePC ? Id : null,
        SpriteId = SpriteId,
    };
}
