using System;
using System.Collections.Generic;
using Bulwark.Data;
using PF2e.Core;

namespace Bulwark.Presets;

/// <summary>
/// One joinable PC preset: the code needed to build an additional squad member when a recruitable
/// villager joins the party. A <see cref="VillagerDefinition.JoinPresetKey"/> references this by
/// <see cref="Key"/>; the roster growth (SquadRoster.InsertMember) builds the member via
/// <see cref="Builder"/> and drives its scripted level-ups via <see cref="Combo"/> — exactly the
/// (builder, combo) pair the fixed four are assembled from.
/// </summary>
public sealed class PartyPresetSpec
{
    public required string Key { get; init; }
    public required Func<int, PF2eCharacter> Builder { get; init; }
    public required VariantComboDefinition Combo { get; init; }
}

/// <summary>
/// Registry of joinable PC presets (the code half of a recruitable villager). SHIPPED EMPTY, like
/// <see cref="Villagers"/>: authoring a new playable villager means authoring its PC preset the way
/// the existing four are authored, then <see cref="Register"/>-ing it here (typically at startup)
/// under the key its villager's <see cref="VillagerDefinition.JoinPresetKey"/> names. Because the
/// builder is executable code (it returns a PF2eCharacter), it can't live in the pure declarative
/// <see cref="VillagerDefinition"/> — the villager holds the string key, this holds the builder.
///
/// Mutable-registry (not the immutable DefinitionRegistry) precisely so no preset is baked into the
/// shipped binary: nothing is registered now, so <see cref="IsEmpty"/> is true and no villager can
/// actually join in shipped play. The VillagerSpike registers spike-local specs and clears them.
/// </summary>
public static class PartyPresets
{
    private static readonly Dictionary<string, PartyPresetSpec> Specs = new();

    /// <summary>True when no joinable preset has been registered (the shipped state).</summary>
    public static bool IsEmpty => Specs.Count == 0;

    /// <summary>Every registered joinable preset.</summary>
    public static IReadOnlyCollection<PartyPresetSpec> All => Specs.Values;

    /// <summary>Register (or replace) a joinable preset under its key. No-op on a null/keyless spec.</summary>
    public static void Register(PartyPresetSpec spec)
    {
        if (spec != null && !string.IsNullOrEmpty(spec.Key))
            Specs[spec.Key] = spec;
    }

    /// <summary>Non-throwing lookup by key.</summary>
    public static bool TryGet(string key, out PartyPresetSpec spec) => Specs.TryGetValue(key, out spec!);

    /// <summary>Drop every registration (test isolation).</summary>
    public static void Clear() => Specs.Clear();
}
