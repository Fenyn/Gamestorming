using System;
using System.Collections.Generic;

namespace Bulwark.Data;

/// <summary>
/// Id-keyed index behind the static definition registries (Items, Crops, Territories,
/// ResourceNodes, EncounterTables). Each registry keeps its declarative definitions plus a thin
/// static façade (All / IsDefined / Get / TryGet) and delegates the lookup semantics here — one
/// home for "last definition wins on duplicate id" and throwing Get vs non-throwing TryGet.
/// </summary>
public sealed class DefinitionRegistry<T> where T : class
{
    private readonly Dictionary<string, T> _byId;

    public DefinitionRegistry(Func<T, string> idOf, params T[] defs)
    {
        _byId = new Dictionary<string, T>(defs.Length);
        foreach (var def in defs)
            _byId[idOf(def)] = def;
    }

    /// <summary>Every registered definition.</summary>
    public IReadOnlyCollection<T> All => _byId.Values;

    /// <summary>True when <paramref name="id"/> names a registered definition.</summary>
    public bool IsDefined(string id) => _byId.ContainsKey(id);

    /// <summary>Look up by id. Throws if unknown — call <see cref="IsDefined"/> to probe.</summary>
    public T Get(string id) => _byId[id];

    /// <summary>Non-throwing lookup.</summary>
    public bool TryGet(string id, out T def) => _byId.TryGetValue(id, out def!);
}
