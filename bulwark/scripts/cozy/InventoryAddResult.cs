namespace Bulwark.Cozy;

/// <summary>
/// Outcome of a party-level <see cref="Inventory.AddItem"/>: how many units the auto-distribution
/// actually placed onto members versus how many were rejected because every member hit their PF2e
/// hard carry cap (10 + Str mod). Existing void-style callers ignore it; the encumbrance/hard-cap
/// spike inspects it.
/// </summary>
public readonly record struct InventoryAddResult(int Placed, int Rejected)
{
    /// <summary>True when the whole requested quantity found a home.</summary>
    public bool FullyPlaced => Rejected == 0;
}
