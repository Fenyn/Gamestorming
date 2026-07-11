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
    /// <summary>Save schema version, bumped when the shape changes. v2 added the squad snapshot.</summary>
    public int Version { get; set; } = 2;

    public ClockDto Clock { get; set; } = new();

    /// <summary>Inventory stacks: item id → quantity.</summary>
    public Dictionary<string, int> Inventory { get; set; } = new();

    public List<PlotDto> Plots { get; set; } = new();

    public FlagsDto Flags { get; set; } = new();

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

/// <summary>Persistent game flags.</summary>
public sealed class FlagsDto
{
    /// <summary>Set when the player collapsed at 2 AM instead of sleeping voluntarily.</summary>
    public bool CollapsedLastNight { get; set; }
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
