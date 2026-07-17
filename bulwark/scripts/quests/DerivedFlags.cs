using System;
using System.Collections.Generic;
using Bulwark.Data;

namespace Bulwark.Quests;

/// <summary>
/// Resolves the DERIVED (virtual) story flags — flag ids whose truth is a LIVE read of game system
/// state rather than a persisted latch. Extracted from GameState.HasFlagForConditions so the growing
/// family set lives in one testable place; GameState now just asks this class first and falls back to
/// its real <c>StoryFlags</c> store.
///
/// Derived flags are never persisted and never settable via SetStoryFlag: their value is recomputed
/// from the systems on every lookup. The building/villager/quest catalogs are STATIC, so the exact
/// flag name for every building/villager/quest family is precomputed once at construction into
/// exact-match dictionaries (no per-lookup string interpolation, no substring scanning).
///
/// FALL-THROUGH SEMANTICS (uniform across all families): a family resolver reports TRUE ⇒ the flag is
/// true (derived state wins); a family resolver reports FALSE ⇒ <see cref="Resolve"/> returns false and
/// the caller falls through to the real flag store. This makes every family behave identically. The
/// fall-through is load-bearing for <c>&lt;villager&gt;_arrived</c>: several dev spikes (EffectsSpike,
/// EconomySpike, IntroSpike) SetStoryFlag("arkus_arrived")/("josen_arrived") as a REAL flag to open a
/// character-gated building without driving the villager's arrival trigger, and rely on that real flag
/// reading true when the villager has not actually arrived. No shipped content sets a real flag of the
/// other families' names, so uniform fall-through is byte-identical to the pre-extraction behaviour for
/// those too.
///
/// Families (flag id → semantics):
///  • "building_under_construction"        — LIVE: any building is currently under construction (a DYNAMIC
///                                            state a one-way StoryFlag latch cannot represent).
///  • "&lt;building_id&gt;_commissioned"    — building's tier ≥ 1 (true from commission through every later
///                                            construction/upgrade window).
///  • "&lt;building_id&gt;_built"           — building has ≥ 1 COMPLETED tier: tier ≥ 1 AND NOT (tier == 1
///                                            while still under construction). False during the tier-1
///                                            commission window; true once it closes and thereafter.
///  • "&lt;villager_id&gt;_arrived"         — villager has ARRIVED at the outpost (the character-first
///                                            commissionability gate: arkus_arrived → Smithy, etc).
///  • "quest_&lt;id&gt;_complete"           — quest is in the completed set (chain-start conditions as data).
///  • "quest_&lt;id&gt;_active"             — quest is currently active/started (gate dialogue on "quest
///                                            underway", e.g. the wolf-arc talk entries).
/// </summary>
public sealed class DerivedFlags
{
    /// <summary>The one flag whose name is fixed (not a per-entity family).</summary>
    public const string UnderConstructionFlag = "building_under_construction";

    // Exact flag-name → entity-id maps, precomputed from the static catalogs (buildings/villagers/quests
    // never change at runtime). A lookup is one dictionary probe; the resolver delegate is then called
    // with the entity id. No per-lookup interpolation, no EndsWith substring matching.
    private readonly Dictionary<string, string> _commissioned;   // "<id>_commissioned" → building id
    private readonly Dictionary<string, string> _built;          // "<id>_built"        → building id
    private readonly Dictionary<string, string> _arrived;        // "<id>_arrived"      → villager id
    private readonly Dictionary<string, string> _questComplete;  // "quest_<id>_complete" → quest id
    private readonly Dictionary<string, string> _questActive;    // "quest_<id>_active"   → quest id

    private readonly Func<bool> _anyUnderConstruction;
    private readonly Func<string, int> _buildingTier;
    private readonly Func<string, bool> _buildingUnderConstruction;
    private readonly Func<string, bool> _villagerArrived;
    private readonly Func<string, bool> _questCompleted;
    private readonly Func<string, bool> _questIsActive;

    /// <param name="anyUnderConstruction">Live "is any building under construction" query.</param>
    /// <param name="buildingTier">A building's current tier (0 = not commissioned).</param>
    /// <param name="buildingUnderConstruction">Whether a specific building is under construction (for _built).</param>
    /// <param name="villagerArrived">Whether a villager has arrived.</param>
    /// <param name="questCompleted">Whether a quest is in the completed set.</param>
    /// <param name="questActive">Whether a quest is currently active/started.</param>
    /// <param name="buildingIds">Building ids to precompute _commissioned/_built names for. Null → the
    /// shipped <see cref="Buildings.All"/> registry (the production catalog).</param>
    /// <param name="villagerIds">Villager ids to precompute _arrived names for. Null → <see cref="Villagers.All"/>.</param>
    /// <param name="questIds">Quest ids to precompute quest_*_complete / quest_*_active names for. Null →
    /// <see cref="Bulwark.Data.Quests.All"/>.</param>
    public DerivedFlags(
        Func<bool> anyUnderConstruction,
        Func<string, int> buildingTier,
        Func<string, bool> buildingUnderConstruction,
        Func<string, bool> villagerArrived,
        Func<string, bool> questCompleted,
        Func<string, bool> questActive,
        IEnumerable<string>? buildingIds = null,
        IEnumerable<string>? villagerIds = null,
        IEnumerable<string>? questIds = null)
    {
        _anyUnderConstruction = anyUnderConstruction ?? throw new ArgumentNullException(nameof(anyUnderConstruction));
        _buildingTier = buildingTier ?? throw new ArgumentNullException(nameof(buildingTier));
        _buildingUnderConstruction = buildingUnderConstruction ?? throw new ArgumentNullException(nameof(buildingUnderConstruction));
        _villagerArrived = villagerArrived ?? throw new ArgumentNullException(nameof(villagerArrived));
        _questCompleted = questCompleted ?? throw new ArgumentNullException(nameof(questCompleted));
        _questIsActive = questActive ?? throw new ArgumentNullException(nameof(questActive));

        _commissioned = new Dictionary<string, string>();
        _built = new Dictionary<string, string>();
        foreach (var id in buildingIds ?? IdsOfBuildings())
        {
            _commissioned[$"{id}_commissioned"] = id;
            _built[$"{id}_built"] = id;
        }

        _arrived = new Dictionary<string, string>();
        foreach (var id in villagerIds ?? IdsOfVillagers())
            _arrived[$"{id}_arrived"] = id;

        _questComplete = new Dictionary<string, string>();
        _questActive = new Dictionary<string, string>();
        foreach (var id in questIds ?? IdsOfQuests())
        {
            _questComplete[$"quest_{id}_complete"] = id;
            _questActive[$"quest_{id}_active"] = id;
        }
    }

    /// <summary>
    /// Resolve a derived flag: returns true when <paramref name="flagId"/> names a derived family AND
    /// that family's live condition currently holds. Returns false when the flag is not a derived family
    /// OR the condition does not hold — in both cases the caller falls through to the real flag store.
    /// </summary>
    public bool Resolve(string flagId)
    {
        if (flagId == UnderConstructionFlag)
            return _anyUnderConstruction();

        if (_commissioned.TryGetValue(flagId, out var cid))
            return _buildingTier(cid) >= 1;

        if (_built.TryGetValue(flagId, out var bid))
        {
            int tier = _buildingTier(bid);
            return tier >= 1 && !(tier == 1 && _buildingUnderConstruction(bid));
        }

        if (_arrived.TryGetValue(flagId, out var vid))
            return _villagerArrived(vid);

        if (_questComplete.TryGetValue(flagId, out var qcid))
            return _questCompleted(qcid);

        if (_questActive.TryGetValue(flagId, out var qaid))
            return _questIsActive(qaid);

        return false;
    }

    /// <summary>
    /// Whether <paramref name="flagId"/> belongs to any derived family (regardless of its current truth).
    /// A data-validation seam: an authored flag id that <c>CanResolve</c> reports false for is either a
    /// real story flag or a typo. Not used by the hot flag-lookup path (which calls <see cref="Resolve"/>).
    /// </summary>
    public bool CanResolve(string flagId)
        => flagId == UnderConstructionFlag
           || _commissioned.ContainsKey(flagId)
           || _built.ContainsKey(flagId)
           || _arrived.ContainsKey(flagId)
           || _questComplete.ContainsKey(flagId)
           || _questActive.ContainsKey(flagId);

    private static IEnumerable<string> IdsOfBuildings()
    {
        foreach (var d in Buildings.All)
            yield return d.Id;
    }

    private static IEnumerable<string> IdsOfVillagers()
    {
        foreach (var d in Villagers.All)
            yield return d.Id;
    }

    private static IEnumerable<string> IdsOfQuests()
    {
        foreach (var d in Bulwark.Data.Quests.All)
            yield return d.Id;
    }
}
