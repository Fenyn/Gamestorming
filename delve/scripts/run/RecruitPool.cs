using System.Collections.Generic;
using PF2e.Core;

namespace Delve.Run;

/// <summary>
/// The characters a run can still meet, in the order it meets them: <see cref="CharacterCatalog"/>
/// order minus the leader and anyone already in the party - today, the three the player did not
/// lead with, one per Wayfarer node. A meeting that was lost is not consumed, so the character
/// comes up again at the next one.
/// </summary>
public sealed class RecruitPool
{
    private readonly List<string> _order = new();
    private readonly UnlockState _unlocks;

    /// <summary>Locked characters are left out for the whole run.</summary>
    public RecruitPool(Party party, UnlockState unlocks)
    {
        _unlocks = unlocks;
        foreach (var def in CharacterCatalog.All)
        {
            if (def.Id == party.LeaderId) continue;
            if (!unlocks.IsUnlocked(def.Id)) continue;
            _order.Add(def.Id);
        }
    }

    /// <summary>Meetable ids in meeting order. Party members are skipped on draw.</summary>
    public IReadOnlyList<string> Order => _order;

    /// <summary>Next character to meet, or null when the party is full or the pool is spent.</summary>
    public string? Next(Party party)
    {
        if (party.IsFull) return null;
        foreach (string id in _order)
        {
            if (id == party.LeaderId) continue;
            if (party.Find(id) != null) continue;
            return id;
        }
        return null;
    }

    /// <summary>
    /// Build the next character to meet, at the party's level. The instance fights the meeting and,
    /// if it survives a won fight, joins - never rebuilt, so it joins with the wounds it took.
    /// </summary>
    public (string Id, PF2eCharacter Character)? Draw(Party party)
    {
        if (Next(party) is not { } id) return null;
        if (CharacterCatalog.Find(id) is not { } def) return null;
        return (id, def.Builder(party.Level));
    }

    /// <summary>The unlock set this pool was built against, for the join after a draw.</summary>
    public UnlockState Unlocks => _unlocks;
}
