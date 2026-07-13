using System.Collections.Generic;
using Bulwark.Data;

namespace Bulwark.Cozy;

/// <summary>
/// Plain serializable snapshot of all persisted cozy-layer state. Flat DTO — no Godot types, no
/// behaviour — so <see cref="SaveSerializer"/> can round-trip it with System.Text.Json and only the
/// GameState adapter ever touches file paths.
/// </summary>
public sealed class SaveData
{
    /// <summary>Save schema version, bumped when the shape changes. v2 added the squad snapshot;
    /// v3 split the flat inventory into per-member carry + warehouse; v4 added building states;
    /// v5 added story flags, villager arrival state, and grown-roster preset keys; v6 added the
    /// active meal buff id; v7 added the player-chosen character name.</summary>
    public int Version { get; set; } = 7;

    /// <summary>
    /// Player-chosen name for the main character. Additive field: null in pre-v7 saves, where
    /// restore falls back to the profile's DefaultName.
    /// </summary>
    public string? PlayerName { get; set; }

    public ClockDto Clock { get; set; } = new();

    /// <summary>
    /// LEGACY flat inventory (item id → quantity) from pre-v3 saves. New saves leave this empty and
    /// persist <see cref="MemberInventories"/> + <see cref="Warehouse"/> instead; restore falls back
    /// to distributing this pool only when the new fields are absent.
    /// </summary>
    public Dictionary<string, int> Inventory { get; set; } = new();

    /// <summary>
    /// Per-member carried stacks (the PF2e Bulk carry system). Null in pre-v3 saves — restore then
    /// migrates the legacy flat <see cref="Inventory"/> instead.
    /// </summary>
    public List<MemberInventoryDto>? MemberInventories { get; set; }

    /// <summary>Shared outpost warehouse stacks (item id → quantity). Null in pre-v3 saves.</summary>
    public Dictionary<string, int>? Warehouse { get; set; }

    /// <summary>Gold balance (Phase-1 combat-economy currency). Additive field: 0 in pre-economy saves.</summary>
    public int Gold { get; set; }

    public List<PlotDto> Plots { get; set; } = new();

    // NOTE: older saves carry a "Flags" object (the retired CollapsedLastNight collapse flag).
    // System.Text.Json ignores unknown JSON members by default, so those saves still load.

    /// <summary>
    /// Squad delta snapshot (see <see cref="SquadRoster.CaptureMembers"/>). Null in v1 saves —
    /// loading one keeps the freshly built presets.
    /// </summary>
    public List<SquadMemberDto>? Squad { get; set; }

    /// <summary>
    /// Active Treat Wounds immunity windows (see <see cref="TreatWoundsSystem"/>). Additive field
    /// (FontSlotsRemaining precedent): absent in older saves, where null means no one is immune.
    /// </summary>
    public List<TreatWoundsImmunityDto>? TreatWoundsImmunities { get; set; }

    /// <summary>
    /// Territory-loop state (M3). Additive field: absent in older saves, where null means fresh
    /// territory state. The player's LOCATION is never persisted — loads always start at the
    /// outpost; only the gate selection and the day-scoped depleted/defeated sets round-trip.
    /// </summary>
    public TerritoryDto? Territory { get; set; }

    /// <summary>
    /// Phase-2 building states (commissioned + tier + accumulated upgrade contributions). Additive
    /// field: null in pre-v4 saves, where restore resets every building to not-commissioned.
    /// </summary>
    public List<BuildingStateDto>? Buildings { get; set; }

    /// <summary>
    /// Phase-3 bulwark story flags that have been set. Additive field: null in pre-v5 saves, where
    /// restore clears to "no flags".
    /// </summary>
    public List<string>? StoryFlags { get; set; }

    /// <summary>
    /// Phase-3 ids of villagers that have arrived at the outpost. Additive field: null in pre-v5
    /// saves, where restore clears to "none arrived" (GameState re-evaluates triggers on load).
    /// Empty in shipped play — the villager catalog ships empty.
    /// </summary>
    public List<string>? ArrivedVillagers { get; set; }

    /// <summary>
    /// Phase-5 active meal buff id (the day-long provision buff). Additive field: null in pre-v6
    /// saves and whenever no meal is active — restore then clears to "no buff". Re-applied to the
    /// roster on load (the buff itself lives only on the live instances, never serialized).
    /// </summary>
    public string? ActiveMeal { get; set; }
}

/// <summary>
/// One building's persisted state: its current tier (0 = not commissioned) and the items
/// accumulated toward the next tier's upgrade bundle. See Bulwark.Cozy.BuildingSystem.
/// </summary>
public sealed class BuildingStateDto
{
    public string Id { get; set; } = "";
    public int Tier { get; set; }
    public Dictionary<string, int> Contributions { get; set; } = new();
}

/// <summary>One member's carried stacks (item id → quantity) for the PF2e Bulk carry system.
/// Encumbrance is NOT persisted here — it is recomputed from these weights on load.</summary>
public sealed class MemberInventoryDto
{
    public string MemberId { get; set; } = "";
    public Dictionary<string, int> Stacks { get; set; } = new();
}

/// <summary>Persisted territory-loop state (see Bulwark.Territory.TerritorySystem).</summary>
public sealed class TerritoryDto
{
    /// <summary>Companion member ids picked at the gate (the Veteran is implicit).</summary>
    public List<string> SelectedCompanionIds { get; set; } = new();

    /// <summary>Depleted resource nodes, as "territoryId:nodeId" keys.</summary>
    public List<string> DepletedNodeIds { get; set; } = new();

    /// <summary>Roamers beaten today, as "territoryId:roamerId" keys.</summary>
    public List<string> DefeatedRoamerIds { get; set; } = new();
}

/// <summary>
/// One member's Treat Wounds immunity window: the absolute game-clock minute (see
/// <see cref="TreatWoundsSystem.AbsoluteMinute(DayClock)"/>) at which the RAW 1-hour immunity ends.
/// </summary>
public sealed class TreatWoundsImmunityDto
{
    public string MemberId { get; set; } = "";
    public long ExpiresAtMinute { get; set; }
}

/// <summary>Calendar + time-of-day snapshot.</summary>
public sealed class ClockDto
{
    public int MinuteOfDay { get; set; } = DayClock.DayStartMinute;
    public int Day { get; set; } = 1;
    public Season Season { get; set; } = Season.Spring;
    public int Year { get; set; } = 1;
}

/// <summary>One farm plot. Vector2I is flattened to X/Y so JSON stays engine-agnostic.</summary>
public sealed class PlotDto
{
    public int X { get; set; }
    public int Y { get; set; }
    public PlotStage Stage { get; set; }
    public string? CropId { get; set; }
    public int DaysGrown { get; set; }
    public bool WateredToday { get; set; }
}

/// <summary>
/// One squad member's live delta from the deterministic preset build: HP, death, persistent
/// conditions, spell-slot usage, focus, shield HP, banked XP. The full build (class, feats,
/// equipment, prepared loadout) is NOT serialized — presets rebuild it identically on load.
/// </summary>
public sealed class SquadMemberDto
{
    public string Id { get; set; } = "";

    /// <summary>
    /// The member's current level — presets rebuild AT this level on load, so applied level-ups
    /// persist. Additive field (FontSlotsRemaining precedent): 0 = absent in older saves, where
    /// SquadRoster falls back to its build level (GameState's SquadStartLevel).
    /// </summary>
    public int Level { get; set; }

    /// <summary>Banked XP; 1000 = a pending level-up (the sleep command applies it, cap
    /// SquadRoster.MaxAppliedLevel; XP above the cap stays banked).</summary>
    public int Xp { get; set; }

    public int CurrentHp { get; set; }
    public bool IsDead { get; set; }

    /// <summary>Current shield HP, or -1 when the member has no shield equipped.</summary>
    public int ShieldHp { get; set; } = -1;

    /// <summary>Persistent conditions (Wounded, Drained, Doomed, Fatigued) with values.</summary>
    public List<SquadConditionDto> Conditions { get; set; } = new();

    public int FocusPoints { get; set; }

    /// <summary>Per-rank spell state; null for non-casters.</summary>
    public List<SpellRankDto>? SpellRanks { get; set; }

    /// <summary>
    /// Remaining divine font slots (Warpriest Medic's heal font); -1 when the member has no
    /// font. Additive v2 field — absent in older snapshots, where the default keeps the freshly
    /// rebuilt font untouched (version-tolerant, mirroring how v2 added Squad itself).
    /// </summary>
    public int FontSlotsRemaining { get; set; } = -1;

    /// <summary>
    /// Smithy: pack slug of a bought replacement weapon; null keeps the deterministic preset weapon.
    /// Additive field — absent in pre-economy saves.
    /// </summary>
    public string? WeaponSlug { get; set; }

    /// <summary>Smithy: potency-rune bonus on the main-hand weapon (0 = none). Additive field.</summary>
    public int WeaponPotency { get; set; }

    /// <summary>
    /// Smithy: striking-rune level on the main-hand weapon as the engine enum's int
    /// (None = 1, Striking = 2). 0 = absent in older saves (restore leaves the weapon as built).
    /// </summary>
    public int WeaponStriking { get; set; }

    /// <summary>
    /// Phase-3 party-join: for a GROWN member (inserted beyond the fixed four), the Bulwark.Presets
    /// PartyPresets key its preset is rebuilt from on load. Null for the fixed four — an additive
    /// field (WeaponSlug precedent) that keeps the default-squad snapshot byte-identical.
    /// </summary>
    public string? PresetKey { get; set; }
}

/// <summary>A persistent condition on a squad member (enum name + value; 0 for binary).</summary>
public sealed class SquadConditionDto
{
    public string Condition { get; set; } = "";
    public int Value { get; set; }
}

/// <summary>
/// Spell state for one rank: remaining count, plus the uncast prepared spell ids for prepared
/// casters (spontaneous casters persist only the counter).
/// </summary>
public sealed class SpellRankDto
{
    public int Rank { get; set; }
    public int Remaining { get; set; }
    public List<string>? PreparedSpellIds { get; set; }
}
