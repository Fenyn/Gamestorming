using Bulwark.Data;
using Bulwark.Presets;
using PF2e.Core;

namespace Bulwark.Cozy;

/// <summary>
/// The roster-join gate (Phase 3): the single validated path that turns an arrived, recruitable
/// villager into a new ROSTER-POOL member. It grows the roster pool — NOT a live combat party. The
/// adventuring/combat party is always a selection of ≤4 from the pool (see
/// TerritorySystem.BuildPartySelectView / Travel), which nothing here touches. Extracted from
/// GameState so the command and the spike exercise the identical rules. Joining is a SPECIFIC
/// arrived-preset insertion — no generator, no recruit UI, no roster management.
/// </summary>
public static class RosterJoin
{
    /// <summary>
    /// Add the villager's referenced PC preset to the roster pool, if allowed. Returns the new
    /// member (pool grown by one) or null when any rule fails: the villager isn't recruitable / has
    /// no join preset, hasn't arrived yet, its preset key isn't registered in <see cref="PartyPresets"/>,
    /// or it's already in the pool (idempotent). No shipped preset is registered, so this never
    /// succeeds in shipped play.
    /// </summary>
    public static PF2eCharacter? TryAdd(SquadRoster roster, VillagerSystem villagers, VillagerDefinition def, int level)
    {
        if (roster == null || villagers == null || def == null)
            return null;
        if (!def.Recruitable || string.IsNullOrEmpty(def.JoinPresetKey))
            return null;
        if (!villagers.HasArrived(def.Id))
            return null;
        if (!PartyPresets.TryGet(def.JoinPresetKey!, out var spec))
            return null;

        return roster.InsertMember(def.JoinPresetKey!, spec.Builder, spec.Combo, level);
    }
}
