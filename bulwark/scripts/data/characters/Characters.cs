using System.Collections.Generic;

namespace Bulwark.Data.Characters;

public static class Characters
{
    private static readonly DefinitionRegistry<CharacterProfile> Registry = new(p => p.Id,
        PlayerCharacter.Profile,
        Tharr.Profile
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
}
