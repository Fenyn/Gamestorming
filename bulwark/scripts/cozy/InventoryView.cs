using System.Collections.Generic;

namespace Bulwark.Cozy;

/// <summary>
/// View-model for a future inventory/warehouse screen (no UI built this phase): every member's
/// carried stacks with their Bulk/limit/encumbered state, the shared warehouse stacks, and the
/// gold balance. View-model shaped per CLAUDE.md — no engine types leak (Bulk/limits are plain
/// numbers, member ids/names are strings). Built by GameState.GetInventoryView from live state.
/// </summary>
public sealed class InventoryView
{
    public required IReadOnlyList<MemberInventoryView> Members { get; init; }

    /// <summary>Warehouse contents (item id → quantity); unlimited, no Bulk limit.</summary>
    public required IReadOnlyDictionary<string, int> Warehouse { get; init; }

    public required int Gold { get; init; }
}

/// <summary>One member's carried stacks plus their PF2e Bulk carry state.</summary>
public sealed class MemberInventoryView
{
    public required string MemberId { get; init; }
    public required string Name { get; init; }

    /// <summary>Items this member personally carries (item id → quantity).</summary>
    public required IReadOnlyDictionary<string, int> Stacks { get; init; }

    /// <summary>Carried Bulk (fractional; PF2e Light = 0.1 Bulk).</summary>
    public required double CarriedBulk { get; init; }

    /// <summary>Bulk above which the member is Encumbered (5 + Str mod).</summary>
    public required double EncumberedThreshold { get; init; }

    /// <summary>Hard carry cap the member cannot exceed (10 + Str mod).</summary>
    public required double MaxBulk { get; init; }

    /// <summary>True when <see cref="CarriedBulk"/> exceeds <see cref="EncumberedThreshold"/>.</summary>
    public required bool Encumbered { get; init; }
}
