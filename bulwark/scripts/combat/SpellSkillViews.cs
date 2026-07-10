using System.Collections.Generic;
using PF2eVec = PF2e.Vector2Int;

namespace Bulwark.Combat;

/// <summary>
/// How a spell or skill action selects what it affects. Drives which player-turn mode the
/// controller enters after the intent is raised. Pure Bulwark data — no engine types.
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
}

/// <summary>UI-facing snapshot of one castable skill action (Trip / Demoralize / Battle Medicine).</summary>
public sealed record SkillEntryView
{
    public required string ActionId { get; init; }
    public required string Name { get; init; }
    public string CostText { get; init; } = "1";
    public TargetingKind Targeting { get; init; }
    public bool Castable { get; init; }
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
