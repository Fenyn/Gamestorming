using System.Collections.Generic;
using System.Linq;
using CharacterRegistry = Bulwark.Data.Characters.Characters;

namespace Bulwark.Data;

/// <summary>
/// Static registry of the villager cast (Phase 3 keystone) — same DefinitionRegistry pattern as
/// <see cref="Buildings"/>, <see cref="Crops"/>, etc. Populated from two sources:
///   1. Character profiles (non-starting PCs emit VillagerDefinitions via <see cref="Characters"/>).
///   2. Standalone hand-authored VillagerDefinitions (for NPCs without a CharacterProfile).
/// With only StartingPC profiles registered, the catalog is empty in shipped play; villagers
/// auto-populate as recruitable/townsfolk profiles are added.
/// </summary>
public static class Villagers
{
    private static readonly DefinitionRegistry<VillagerDefinition> Registry = new(d => d.Id,
        CharacterRegistry.AllVillagerDefinitions().ToArray());

    /// <summary>Every defined villager (empty in the shipped build).</summary>
    public static IReadOnlyCollection<VillagerDefinition> All => Registry.All;

    /// <summary>True when <paramref name="id"/> names a defined villager.</summary>
    public static bool IsDefined(string id) => Registry.IsDefined(id);

    /// <summary>Look up a villager by id. Throws if unknown — call <see cref="IsDefined"/> to probe.</summary>
    public static VillagerDefinition Get(string id) => Registry.Get(id);

    /// <summary>Non-throwing lookup.</summary>
    public static bool TryGet(string id, out VillagerDefinition def) => Registry.TryGet(id, out def);
}
