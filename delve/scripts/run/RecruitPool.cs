using System.Collections.Generic;
using PF2e.Core;

namespace Delve.Run;

/// <summary>Run-local guest availability. Locked characters can be met; joining never unlocks
/// them. Starting members, declined guests and dismissed companions cannot be drawn again.</summary>
public sealed class RecruitPool
{
    private readonly List<string> _order = new();
    private readonly HashSet<string> _unavailable = new();

    public RecruitPool(Party party, UnlockState unlocks)
    {
        Unlocks = unlocks;
        _unavailable.Add(party.LeaderId);
        foreach (string id in party.MemberIds) _unavailable.Add(id);
        foreach (var def in CharacterCatalog.All)
            if (def.CanMeet && !_unavailable.Contains(def.Id)) _order.Add(def.Id);
    }

    public IReadOnlyList<string> Order => _order;
    public UnlockState Unlocks { get; }

    public string? Next(Party party)
    {
        foreach (string id in _order)
            if (!_unavailable.Contains(id) && party.Find(id) == null) return id;
        return null;
    }

    /// <summary>Build once at encounter start. Resolve the meeting when combat ends, even if
    /// the guest dies or is declined, to prevent repeat offers with fresh resources.</summary>
    public (string Id, PF2eCharacter Character)? Draw(Party party)
    {
        if (Next(party) is not { } id || CharacterCatalog.Find(id) is not { } def) return null;
        return (id, def.Builder(party.Level));
    }

    public void Resolve(string id) => _unavailable.Add(id);
}
