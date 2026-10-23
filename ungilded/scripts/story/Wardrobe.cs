using System.Collections.Generic;

namespace Ungilded.Story;

/// <summary>Who carries or wears each accessory. <see cref="AccessoryCue"/>s on dialogue lines change it.</summary>
public sealed class Wardrobe
{
    private readonly Dictionary<string, (string Speaker, AccessoryState State)> _holders = new();

    public void Apply(AccessoryCue cue) => Set(cue.Speaker, cue.Accessory, cue.State);

    /// <summary>Give <paramref name="accessory"/> to <paramref name="speaker"/> in <paramref name="state"/>.
    /// Hidden puts it away, whoever had it.</summary>
    public void Set(string speaker, string accessory, AccessoryState state)
    {
        if (state == AccessoryState.Hidden) _holders.Remove(accessory);
        else _holders[accessory] = (speaker, state);
    }

    /// <summary>How <paramref name="speaker"/> has <paramref name="accessory"/>: Hidden when someone else has it.</summary>
    public AccessoryState StateOf(string speaker, string accessory) =>
        _holders.TryGetValue(accessory, out var holder) && holder.Speaker == speaker ? holder.State : AccessoryState.Hidden;

    public bool IsWearing(string speaker, string accessory) => StateOf(speaker, accessory) == AccessoryState.Worn;

    /// <summary>The highest state of any accessory <paramref name="speaker"/> has: Worn over Carried over Hidden.</summary>
    public AccessoryState ShownOn(string speaker)
    {
        var shown = AccessoryState.Hidden;
        foreach (var (holder, state) in _holders.Values)
            if (holder == speaker && state > shown) shown = state;
        return shown;
    }

    public void Clear() => _holders.Clear();
}
