using System.Collections.Generic;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Combat;

/// <summary>
/// How a spell or skill action selects what it affects. Drives which player-turn mode the
/// controller enters after the intent is raised. Pure Delve data — no engine types.
/// </summary>
public enum TargetingKind
{
    /// <summary>Single living enemy within range (spell attacks, single-target saves).</summary>
    SingleEnemy,
    /// <summary>Single living ally within range, self included (Heal touch/ranged, Battle Medicine).</summary>
    SingleAlly,
    /// <summary>A primary enemy is chosen; the executor auto-fans to nearby enemies up to MaxTargets.</summary>
    MultiEnemy,
    /// <summary>Player aims an origin tile that orients a burst/cone template (Breathe Fire).</summary>
    AreaAim,
    /// <summary>Self-centered emanation — no target selection, cast fires immediately (Heal 3-action).</summary>
    SelfArea,
}

/// <summary>
/// UI-facing snapshot of one castable spell (or one cost-variant of a variable-cost spell).
/// Deliberately carries no PF2e engine types so passive Control scripts can render it.
/// </summary>
public sealed record SpellEntryView
{
    public required string SpellId { get; init; }
    /// <summary>Index into the spell's CostVariants, or -1 for a fixed-cost spell.</summary>
    public int VariantIndex { get; init; } = -1;
    public required string Name { get; init; }
    public int Rank { get; init; }
    public string CostText { get; init; } = "";
    public string SlotsText { get; init; } = "";
    public TargetingKind Targeting { get; init; }
    public bool Castable { get; init; }
    /// <summary>One-line rules text for the chip tooltip, straight from the spell data. Empty when
    /// the source has none — never invented by the UI.</summary>
    public string Description { get; init; } = "";
    /// <summary>Why the chip is greyed out ("Needs 2 actions (1 left)", "No spell slots left"),
    /// derived in the executor from the exact gate that failed. Empty when castable, or when the
    /// cause isn't determinable — the tooltip then adds nothing.</summary>
    public string UnavailableReason { get; init; } = "";
}

/// <summary>UI-facing snapshot of one carried consumable the actor may use this turn (Use Item action bar
/// entry). No engine types — a passive Control renders it; using it raises an intent with <see cref="ItemId"/>.</summary>
public sealed record ConsumableOptionView
{
    public required string ItemId { get; init; }
    public required string Name { get; init; }
    /// <summary>Short effect summary (e.g. "restore 8 HP", "+1 item to AC").</summary>
    public string EffectText { get; init; } = "";
    /// <summary>Action cost glyph text (potions = "1").</summary>
    public string CostText { get; init; } = "1";
    /// <summary>Units of this item the actor is carrying.</summary>
    public int Quantity { get; init; }
}

/// <summary>UI-facing snapshot of one castable skill action (Trip / Demoralize / Battle Medicine).</summary>
public sealed record SkillEntryView
{
    public required string ActionId { get; init; }
    public required string Name { get; init; }
    public string CostText { get; init; } = "1";
    public TargetingKind Targeting { get; init; }
    public bool Castable { get; init; }
    /// <summary>One-line rules text for the chip tooltip, straight from the action data. Empty when
    /// the source has none — never invented by the UI.</summary>
    public string Description { get; init; } = "";
    /// <summary>Why the chip is greyed out ("No adjacent foe", "Needs 2 actions (1 left)"), derived
    /// in the executor from the exact gate that failed. Empty when castable, or when the cause
    /// isn't determinable — the tooltip then adds nothing.</summary>
    public string UnavailableReason { get; init; } = "";
}

/// <summary>
/// Result of resolving a spell/skill's legal target set: the interaction kind plus the tiles the
/// player may click. For <see cref="TargetingKind.SelfArea"/> the tile set is empty (cast at once).
/// </summary>
public sealed class TargetingPlan
{
    public TargetingKind Kind { get; init; }
    public HashSet<PF2eVec> Tiles { get; init; } = new();
}
