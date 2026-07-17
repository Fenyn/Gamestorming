using System.Collections.Generic;
using Bulwark.Data;

using Bulwark.Cozy;
namespace Bulwark.Save;

/// <summary>
/// Plain serializable snapshot of all persisted cozy-layer state. Flat DTO — no Godot types, no
/// behaviour — so <see cref="SaveSerializer"/> can round-trip it with System.Text.Json and only the
/// GameState adapter ever touches file paths.
/// </summary>
public sealed class SaveData
{
    /// <summary>The highest schema version this build knows how to write/restore. GameState.LoadGame
    /// refuses (treats as unparseable) any save whose <see cref="Version"/> is greater than this —
    /// that save came from a newer build, and loading it here would silently drop fields this build
    /// doesn't know about and corrupt it on the next write.</summary>
    public const int CurrentVersion = 13;

    /// <summary>Save schema version, bumped when the shape changes. v2 added the squad snapshot;
    /// v3 split the flat inventory into per-member carry + warehouse; v4 added building states;
    /// v5 added story flags, villager arrival state, and grown-roster preset keys; v6 added the
    /// active meal buff id; v7 added the player-chosen character name; v8 added friendship state;
    /// v9 added seen dialogue ids; v10 added building construction days remaining; v11 added quest
    /// log state; v12 added the world seed, per-territory forage state, and day-stamped depleted
    /// nodes (RespawnDays); v13 added the tutorial-arc quest fabric — its new state (event counters,
    /// one-shot latches) rides the EXISTING <see cref="QuestDto.ObjectiveProgress"/> array, and its new
    /// real flags (first_commission, first_combat_victory, command_post_tier2_built) ride the existing
    /// <see cref="StoryFlags"/> list, so no new DTO field is required and pre-v13 saves load unchanged
    /// (missing state = quests re-evaluate fresh from the restored flags/buildings on load).</summary>
    public int Version { get; set; } = CurrentVersion;

    /// <summary>
    /// Per-save world seed anchoring deterministic rolls (forage daily passes). Additive field:
    /// 0 in pre-v12 saves, where GameState keeps its freshly generated seed and persists it on the
    /// next save.
    /// </summary>
    public int WorldSeed { get; set; }

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

    /// <summary>
    /// Friendship / heart-system state (v8). Additive field: null in pre-v8 saves, where restore
    /// clears to zero friendship (points, counters, fired thresholds all empty).
    /// </summary>
    public FriendshipDto? Friendship { get; set; }

    /// <summary>
    /// Dialogue ids that have been seen (v9). Additive field: null in pre-v9 saves, where restore
    /// clears to "nothing seen". Used by once-only dialogue sequences.
    /// </summary>
    public List<string>? SeenDialogueIds { get; set; }

    /// <summary>
    /// Quest log state (v11). Additive field: null in pre-v11 saves, where restore clears to
    /// "no quests started". Each entry carries the quest id, completed flag, and per-objective
    /// progress array.
    /// </summary>
    public List<QuestDto>? Quests { get; set; }

    /// <summary>
    /// Per-territory forage spawn state (v12, design/forage.md). Additive field: null in pre-v12
    /// saves, where restore clears to "no forage yet" and the first territory visit catches up
    /// deterministically from day 1.
    /// </summary>
    public List<TerritoryForageDto>? Forage { get; set; }
}

/// <summary>One territory's persisted forage state: the last day the daily pass processed plus
/// every live/harvested-today spawn (see Bulwark.Territory.ForageSystem).</summary>
public sealed class TerritoryForageDto
{
    public string TerritoryId { get; set; } = "";

    /// <summary>Absolute day ordinal of the last processed daily pass (0 = never).</summary>
    public int LastPassDay { get; set; }

    public List<ForageSpawnDto> Spawns { get; set; } = new();

    /// <summary>Debris clutter pieces (design/forage.md third category — the non-swept second
    /// pass). Additive field: empty in pre-debris saves.</summary>
    public List<ForageSpawnDto> Debris { get; set; } = new();

    /// <summary>True once the one-time initial debris sprinkle ran here. Additive field: false in
    /// pre-debris saves, so their next pass runs the 8–12 piece sprinkle exactly once.</summary>
    public bool DebrisSeeded { get; set; }
}

/// <summary>One forage spawn: node id, resource id, cell, spawn day, harvested flag.</summary>
public sealed class ForageSpawnDto
{
    public string NodeId { get; set; } = "";
    public string ResourceId { get; set; } = "";
    public int X { get; set; }
    public int Y { get; set; }
    public int SpawnDay { get; set; }
    public bool Harvested { get; set; }
}

/// <summary>
/// Persisted friendship state (see Bulwark.Cozy.FriendshipSystem): per-character points, the
/// weekly gift counters + their week index, the talked-today set + its day ordinal (so counters
/// only restore within the same day/week window), the once-only fired heart thresholds, and the
/// Phase-4 romance-state placeholder.
/// </summary>
public sealed class FriendshipDto
{
    /// <summary>Character id → friendship points (hearts are derived, never stored).</summary>
    public Dictionary<string, int> Points { get; set; } = new();

    /// <summary>Character id → gifts accepted in the current week.</summary>
    public Dictionary<string, int> GiftsThisWeek { get; set; } = new();

    /// <summary>Week index (7-day windows from day 1) the gift counters belong to.</summary>
    public int GiftWeekIndex { get; set; }

    /// <summary>Characters already talked to today.</summary>
    public List<string> TalkedToday { get; set; } = new();

    /// <summary>Absolute day ordinal the talked-today set belongs to.</summary>
    public int TalkedDayOrdinal { get; set; }

    /// <summary>Character id → highest heart threshold that has fired (fires once, stays earned).</summary>
    public Dictionary<string, int> FiredHearts { get; set; } = new();

    /// <summary>Phase-4 romance-track placeholder (character ids courted). No commands write it yet.</summary>
    public List<string> Romanced { get; set; } = new();
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

    /// <summary>Days remaining under construction (0 = complete or not started). Additive field:
    /// 0 in pre-v10 saves (buildings complete instantly in those).</summary>
    public int ConstructionDaysRemaining { get; set; }
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

    /// <summary>LEGACY (pre-v12) depleted resource nodes, as "territoryId:nodeId" keys. Still
    /// written for shape stability; restore uses it only when <see cref="DepletedNodes"/> is
    /// absent (migrated with the depletion day = the loaded day).</summary>
    public List<string> DepletedNodeIds { get; set; } = new();

    /// <summary>Depleted resource nodes with their rolled respawn day (v12, RespawnDays window —
    /// the roll happens at harvest time and is never repeated on load).</summary>
    public List<DepletedNodeDto>? DepletedNodes { get; set; }

    /// <summary>Roamers beaten today, as "territoryId:roamerId" keys.</summary>
    public List<string> DefeatedRoamerIds { get; set; } = new();
}

/// <summary>One depleted node: its "territoryId:nodeId" key and the absolute day ordinal it
/// respawns on (0 = never — one-shot nodes).</summary>
public sealed class DepletedNodeDto
{
    public string Key { get; set; } = "";
    public int RespawnDay { get; set; }
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

public sealed class QuestDto
{
    public string QuestId { get; set; } = "";
    public bool Completed { get; set; }
    public int[] ObjectiveProgress { get; set; } = System.Array.Empty<int>();
}
