using System;
using System.Collections.Generic;

namespace Bulwark.Cozy;

/// <summary>
/// The bulwark-side story-flag set (Phase 3): a simple named-boolean store for story beats. Kept
/// deliberately minimal (a string set) rather than leaning on the engine's StoryFlagDatabase — it
/// feeds villager <see cref="Bulwark.Data.ArrivalTrigger"/>s and future quests, and persists in the
/// save. Plain C#; GameState owns the single instance, wraps it in the SetStoryFlag command +
/// HasStoryFlag query, and re-exposes <see cref="FlagSet"/> as StoryFlagChanged.
/// </summary>
public sealed class StoryFlags
{
    private readonly HashSet<string> _flags = new();

    /// <summary>Raised when a flag is newly set (never on a redundant re-set), with the flag id.</summary>
    public event Action<string>? FlagSet;

    /// <summary>True once <paramref name="flagId"/> has been set.</summary>
    public bool Has(string flagId) => _flags.Contains(flagId);

    /// <summary>Every set flag (save capture reads this).</summary>
    public IReadOnlyCollection<string> All => _flags;

    /// <summary>
    /// Set a flag. Returns true (and raises <see cref="FlagSet"/>) only when it was newly added —
    /// idempotent, so re-setting an already-set flag is a clean no-op with no event.
    /// </summary>
    public bool Set(string flagId)
    {
        if (string.IsNullOrEmpty(flagId) || !_flags.Add(flagId))
            return false;
        FlagSet?.Invoke(flagId);
        return true;
    }

    /// <summary>Snapshot the set flags for the save file.</summary>
    public List<string> Capture() => new(_flags);

    /// <summary>
    /// Overwrite the set from a save. Version-tolerant: null (pre-v5 save) clears to "no flags".
    /// Silent — no <see cref="FlagSet"/> events on restore.
    /// </summary>
    public void Restore(IEnumerable<string>? flags)
    {
        _flags.Clear();
        if (flags == null)
            return;
        foreach (var f in flags)
            if (!string.IsNullOrEmpty(f))
                _flags.Add(f);
    }
}
