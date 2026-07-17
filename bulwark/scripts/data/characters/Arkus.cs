namespace Bulwark.Data.Characters;

public static class Arkus
{
    public const string CharacterId = "arkus";

    public static readonly CharacterProfile Profile = new()
    {
        Id = CharacterId,
        DefaultName = "Arkus",
        PlayerNamed = false,
        Pronouns = "they/them",
        ClassName = "Barbarian",
        AncestryName = "Orc",
        Kind = CharacterKind.RecruitablePC,
        Bio = "A young orc barbarian, rootborn and raised by their tribe, who went into the deep forest "
            + "to prove themselves and did not come back the same. Found wounded on the road after the "
            + "dire wolf, dragged to the outpost, and patched up.",
        Personality = "Blunt orc honesty — says exactly what they think, no softening and no cruelty "
            + "intended. States problems as facts and expects the same in return. Cares more than they "
            + "know how to show.",
        RoleDescription = "Runs the Smithy — the outpost's blacksmith, forging weapons, armor, and tools. "
            + "Also a frontline combatant bringing raw physical power to the squad.",
        AssociatedBuildingId = "smithy",
        // Placed as an unconscious resident the moment the Arkus-found cutscene latches this flag on the
        // first return after the wolf kill (OutpostScene.TryPlayArkusFound). This profile's emitted
        // VillagerDefinition is Arkus's ONLY definition — he is deliberately absent from
        // Villagers.HandAuthored.
        Arrival = ArrivalTrigger.StoryFlag("arkus_found"),
        PortraitId = "arkus",
        SpriteId = null,
        Build = null,
    };
}
