using System.Collections.Generic;

namespace Bulwark.Data.Characters;

public static class Characters
{
    private static readonly DefinitionRegistry<CharacterProfile> Registry = new(p => p.Id,
        PlayerCharacter.Profile,
        Tharr.Profile,
        Elara.Profile,
        Fenwick.Profile,
        Arkus.Profile
    );

    public static IReadOnlyCollection<CharacterProfile> All => Registry.All;

    public static bool IsDefined(string id) => Registry.IsDefined(id);

    public static CharacterProfile Get(string id) => Registry.Get(id);

    public static bool TryGet(string id, out CharacterProfile p) => Registry.TryGet(id, out p);

    public static IEnumerable<VillagerDefinition> AllVillagerDefinitions()
    {
        foreach (var p in Registry.All)
            if (p.Kind != CharacterKind.StartingPC)
                yield return p.ToVillagerDefinition();
    }

    /// <summary>
    /// The non-player starting party members (Tharr, Elara, Fenwick) as villager definitions —
    /// the tutorial's teacher NPCs. Unlike the arrival-gated cast (<see cref="AllVillagerDefinitions"/>,
    /// which excludes StartingPCs), these are present at the outpost from day one and never "arrive",
    /// so they sit OUTSIDE the arrival system: the VillagerLoader places them unconditionally as
    /// always-present residents. The player avatar itself is excluded — it is
    /// controlled, not talked to.
    /// </summary>
    public static IEnumerable<VillagerDefinition> StartingResidents()
    {
        foreach (var p in Registry.All)
            if (p.Kind == CharacterKind.StartingPC && p.Id != PlayerCharacter.CharacterId)
                yield return p.ToVillagerDefinition();
    }
}
