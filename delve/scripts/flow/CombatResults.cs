using System.Collections.Generic;
using System.Linq;
using Delve.Combat;
using Delve.Run;
using PF2e.Core;

namespace Delve.Flow;

/// <summary>One hero on the results screen: the values that changed, and the member for "Choose feat".</summary>
public sealed record ResultMemberRow(PF2eCharacter Member, IReadOnlyList<FigureView> Figures);

/// <summary>The victory screen as rows: party figures, one row per changed hero, then notes.</summary>
public sealed record CombatResultsView
{
    public IReadOnlyList<FigureView> Figures { get; init; } = System.Array.Empty<FigureView>();
    public IReadOnlyList<ResultMemberRow> Members { get; init; } = System.Array.Empty<ResultMemberRow>();
    public IReadOnlyList<string> Notes { get; init; } = System.Array.Empty<string>();

    /// <summary>Progress toward the next level, 0-100, or null when the bar does not apply.</summary>
    public double? Progress { get; init; }

    /// <summary>Everyone the promotion view can step through with "Next".</summary>
    public IReadOnlyList<PF2eCharacter> Party { get; init; } = System.Array.Empty<PF2eCharacter>();
}

/// <summary>Builds <see cref="CombatResultsView"/> content from before/after reads. Godot-free.</summary>
public static class CombatResults
{
    /// <summary>"XP 40 → 80", or "Level 2 → 3" alone when a level was earned: the reset XP changes no decision.</summary>
    public static List<FigureView> Progress(int xpBefore, int xpAfter, int levelBefore, int levelAfter, bool atCap)
    {
        var figures = new List<FigureView>();
        if (levelAfter != levelBefore)
            figures.Add(new FigureView("Level", levelAfter.ToString()) { Before = levelBefore.ToString() });
        else if (!atCap && xpAfter != xpBefore)
            figures.Add(new FigureView("XP", xpAfter.ToString()) { Before = xpBefore.ToString() });
        return figures;
    }

    public static FigureView? Ward(int before, int after)
        => before == after ? null : new FigureView("Ward", after.ToString()) { Before = before.ToString() };

    /// <summary>HP and Wounded pairs for the values that changed since <paramref name="before"/>.</summary>
    public static List<FigureView> MemberFigures(PartyMemberSnapshot before, PF2eCharacter member)
    {
        var now = PartyMemberSnapshot.Read(member);
        var figures = new List<FigureView>();
        if (now.Hp != before.Hp)
            figures.Add(new FigureView("HP", now.Hp.ToString()) { Before = before.Hp.ToString(), Max = now.MaxHp.ToString() });
        if (now.Wounded != before.Wounded)
            figures.Add(new FigureView("Wounded", now.Wounded.ToString()) { Before = before.Wounded.ToString() });
        return figures;
    }

    /// <summary>Rest and morning rows: HP, Wounded, Focus and Shield pairs, only for members that changed.</summary>
    public static List<ResultMemberRow> RestMembers(IEnumerable<PF2eCharacter> members,
        IReadOnlyDictionary<string, PartyMemberSnapshot> before)
    {
        var rows = new List<ResultMemberRow>();
        foreach (var member in members)
        {
            if (!before.TryGetValue(member.Id, out var old)) continue;
            var figures = MemberFigures(old, member);
            var now = PartyMemberSnapshot.Read(member);
            if (now.Focus != old.Focus)
                figures.Add(new FigureView("Focus", now.Focus.ToString()) { Before = old.Focus.ToString() });
            if (now.ShieldHp != old.ShieldHp)
                figures.Add(new FigureView("Shield", now.ShieldHp.ToString()) { Before = old.ShieldHp.ToString() });
            if (figures.Count > 0) rows.Add(new ResultMemberRow(member, figures));
        }
        return rows;
    }

    /// <summary>A row for every member whose values changed or who has a feat to choose.</summary>
    public static List<ResultMemberRow> Members(IEnumerable<PF2eCharacter> members,
        IReadOnlyDictionary<string, PartyMemberSnapshot> before)
    {
        var rows = new List<ResultMemberRow>();
        foreach (var member in members)
        {
            var figures = before.TryGetValue(member.Id, out var old) ? MemberFigures(old, member) : new List<FigureView>();
            if (figures.Count > 0 || HasFeatChoice(member)) rows.Add(new ResultMemberRow(member, figures));
        }
        return rows;
    }

    public static bool HasFeatChoice(PF2eCharacter member)
        => member.Health?.IsDead != true && CharacterPromotion.For(member).HasChoice(member);

    /// <summary>The next member after <paramref name="current"/> in party order with a feat to choose.</summary>
    public static PF2eCharacter? NextWithChoice(IReadOnlyList<PF2eCharacter> party, PF2eCharacter current)
    {
        int start = party.ToList().IndexOf(current);
        for (int step = 1; step <= party.Count; step++)
        {
            var member = party[((start + step) % party.Count + party.Count) % party.Count];
            if (!ReferenceEquals(member, current) && HasFeatChoice(member)) return member;
        }
        return null;
    }
}
