using System;

namespace Bulwark.Cozy;

/// <summary>
/// The party's gold purse — the combat-economy currency (loot + surplus sales → gear at the
/// Smithy). A dedicated wallet rather than an inventory stack because currency semantics differ
/// from stacking items: a single balance, no item-id, spent atomically with validation. Pure C#;
/// GameState owns the single instance, wraps mutations in intent-named commands (EarnGold via loot
/// and SellItem; TrySpendGold via the smithy), and re-exposes <see cref="GoldChanged"/> so the UI
/// renders passively. Persisted through the save (a single int).
/// </summary>
public sealed class Wallet
{
    /// <summary>Current gold balance (never negative).</summary>
    public int Gold { get; private set; }

    /// <summary>Raised after the balance changes, with the NEW balance (UI renders passively).</summary>
    public event Action<int>? GoldChanged;

    /// <summary>
    /// Add gold (loot coin, item sales). Non-positive amounts are a programmer error and throw —
    /// the command layer never earns nothing.
    /// </summary>
    public void EarnGold(int amount)
    {
        if (amount <= 0)
            throw new ArgumentOutOfRangeException(nameof(amount), amount, "Earned gold must be positive.");
        Gold += amount;
        GoldChanged?.Invoke(Gold);
    }

    /// <summary>
    /// Spend gold if the balance covers it. Returns false (no mutation) when the amount is
    /// non-positive or exceeds the balance — the validation path for smithy commands, so an
    /// insufficient-gold purchase consumes nothing.
    /// </summary>
    public bool TrySpendGold(int amount)
    {
        if (amount <= 0 || Gold < amount)
            return false;
        Gold -= amount;
        GoldChanged?.Invoke(Gold);
        return true;
    }

    /// <summary>Replace the balance (used by the save system). Negatives clamp to 0.</summary>
    public void LoadFrom(int gold)
    {
        Gold = Math.Max(0, gold);
        GoldChanged?.Invoke(Gold);
    }
}
