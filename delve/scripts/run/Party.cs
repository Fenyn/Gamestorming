using System;
using System.Collections.Generic;
using PF2e.Core;

namespace Delve.Run;

/// <summary>
/// The live characters of a run. A run starts with the leader alone; companions join along the way
/// through <see cref="AddMember"/>, up to <see cref="MaxSize"/>. The instances are built once - in
/// <see cref="Build"/> or on the join - and kept for the whole run, so damage, Wounded and spent
/// slots carry across nodes.
/// </summary>
public sealed class Party
{
    private readonly List<string> _memberIds;
    private readonly List<PF2eCharacter> _members;

    private Party(string leaderId, List<string> memberIds, List<PF2eCharacter> members, int level)
    {
        LeaderId = leaderId;
        _memberIds = memberIds;
        _members = members;
        Level = level;
    }

    /// <summary>Characters a party may hold, leader included.</summary>
    public const int MaxSize = 4;

    /// <summary>Level a run builds its party at. Hero select previews stats at this level, so the
    /// numbers on the sheet are the numbers the first fight uses.</summary>
    public const int DefaultLevel = 2;

    /// <summary>Catalog id of the leader.</summary>
    public string LeaderId { get; }

    /// <summary>Catalog ids of the non-leader members, in join order.</summary>
    public IReadOnlyList<string> MemberIds => _memberIds;

    /// <summary>Every live character, leader first.</summary>
    public IReadOnlyList<PF2eCharacter> Members => _members;

    /// <summary>The party's current level. Members are built at it; newcomers join at it.</summary>
    public int Level { get; private set; }

    /// <summary>Record the new level after an in-place level-up. <see cref="PartyLeveling"/> owns
    /// the flow (XP threshold, per-member LevelUpInPlace); this only moves the number the next
    /// <see cref="AddMember"/> builds at.</summary>
    public void SetLevel(int level) => Level = level;

    /// <summary>True when no more companions fit.</summary>
    public bool IsFull => _members.Count >= MaxSize;

    /// <summary>True when no member can keep fighting - the only thing that ends a run in defeat.</summary>
    public bool IsWiped
    {
        get
        {
            foreach (var member in _members)
            {
                var health = member.Health;
                if (health != null && !health.IsDead && health.CurrentHP > 0)
                    return false;
            }
            return true;
        }
    }

    /// <summary>Members that can still take the field.</summary>
    public IReadOnlyList<PF2eCharacter> Living()
    {
        var living = new List<PF2eCharacter>(_members.Count);
        foreach (var member in _members)
        {
            if (member.Health == null || !member.Health.IsDead)
                living.Add(member);
        }
        return living;
    }

    /// <summary>The live character with this catalog id, or null.</summary>
    public PF2eCharacter? Find(string id)
    {
        foreach (var member in _members)
        {
            if (member.Id == id) return member;
        }
        return null;
    }

    /// <summary>
    /// Take a companion into the party at the party's own level. Returns false - and changes
    /// nothing - when the id is unknown, locked, already in the party, or the party is full. This
    /// is the seam a recruitment source plugs into; who offers the companion is not decided yet.
    /// </summary>
    public bool AddMember(string id, UnlockState unlocks)
    {
        if (IsFull) return false;
        if (CharacterCatalog.Find(id) is not { } def) return false;
        if (!unlocks.IsUnlocked(id)) return false;
        if (id == LeaderId || _memberIds.Contains(id)) return false;

        _memberIds.Add(id);
        _members.Add(def.Builder(Level));
        return true;
    }

    /// <summary>
    /// Build the starting party. <paramref name="memberIds"/> may be empty - a run normally opens
    /// with the leader alone. Throws when the picks are illegal: at most <see cref="MaxSize"/>
    /// characters in all, every id known to <see cref="CharacterCatalog"/>, unlocked and named
    /// once, and the leader flagged <see cref="CharacterDef.CanLead"/>.
    /// </summary>
    public static Party Build(string leaderId, IReadOnlyList<string> memberIds, UnlockState unlocks, int level)
    {
        if (memberIds.Count > MaxSize - 1)
            throw new ArgumentException($"A party holds at most {MaxSize} characters.", nameof(memberIds));

        var ids = new List<string> { leaderId };
        ids.AddRange(memberIds);

        var seen = new HashSet<string>();
        var defs = new List<CharacterDef>(ids.Count);
        foreach (string id in ids)
        {
            if (!seen.Add(id))
                throw new ArgumentException($"Character '{id}' is picked twice.", nameof(memberIds));

            var def = CharacterCatalog.Find(id)
                ?? throw new ArgumentException($"Unknown character '{id}'.", nameof(memberIds));
            if (!unlocks.IsUnlocked(id))
                throw new ArgumentException($"Character '{id}' is not unlocked.", nameof(unlocks));
            defs.Add(def);
        }

        if (!defs[0].CanLead)
            throw new ArgumentException($"Character '{leaderId}' cannot lead.", nameof(leaderId));

        int built = level < 1 ? 1 : level;
        var members = new List<PF2eCharacter>(defs.Count);
        foreach (var def in defs)
            members.Add(def.Builder(built));

        return new Party(leaderId, new List<string>(memberIds), members, built);
    }
}
