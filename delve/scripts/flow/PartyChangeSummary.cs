using System.Collections.Generic;
using System.Linq;
using Delve.Run;
using PF2e.Conditions;
using PF2e.Core;

namespace Delve.Flow;

/// <summary>Read before and after rules run, so presentation reports applied changes.</summary>
public sealed record PartyMemberSnapshot(int Hp, int MaxHp, int Wounded, HashSet<string> Features, HashSet<string> Spells,
    Dictionary<int, int> SpellSlots)
{
    public static PartyMemberSnapshot Read(PF2eCharacter member) => new(
        member.Health?.CurrentHP ?? 0, member.Health?.MaxHP ?? 0,
        member.Conditions?.GetConditionValue(Condition.Wounded) ?? 0,
        HeroSheetBuilder.Read(member).Row(HeroSheetBuilder.FeaturesRow)?.Entries.Select(e => e.Label).ToHashSet() ?? new(),
        member.Spellcasting?.Cantrips.Concat(member.Spellcasting.LeveledSpells)
            .Select(s => s.ActionName).ToHashSet() ?? new(),
        Enumerable.Range(1, 10).ToDictionary(rank => rank, rank => member.Spellcasting?.GetMaxSlots(rank) ?? 0));
}

public static class PartyChangeSummary
{
    public static Dictionary<string, PartyMemberSnapshot> Capture(Party party) =>
        party.Members.ToDictionary(m => m.Id, PartyMemberSnapshot.Read);

    public static IEnumerable<string> Recovery(Party party, IReadOnlyDictionary<string, PartyMemberSnapshot> before)
    {
        foreach (var member in party.Members)
        {
            if (before[member.Id].Hp > 0) continue;
            int wounded = member.Conditions?.GetConditionValue(Condition.Wounded) ?? 0;
            yield return $"{member.Name} recovered at {member.Health?.CurrentHP} HP"
                + (wounded > 0 ? $"; Wounded {wounded} remains." : ".");
        }
    }

    public static IEnumerable<string> LevelGains(Party party, IReadOnlyDictionary<string, PartyMemberSnapshot> before)
    {
        foreach (var member in party.Members)
        {
            var old = before[member.Id];
            var now = PartyMemberSnapshot.Read(member);
            var gains = new List<string>();
            if (now.MaxHp > old.MaxHp) gains.Add($"+{now.MaxHp - old.MaxHp} maximum HP");
            gains.AddRange(now.Features.Except(old.Features));
            gains.AddRange(now.Spells.Except(old.Spells).Select(s => $"new spell: {s}"));
            foreach (var (rank, slots) in now.SpellSlots)
                if (slots > old.SpellSlots[rank]) gains.Add($"+{slots - old.SpellSlots[rank]} rank {rank} spell slots");
            if (gains.Count > 0) yield return $"{member.Name}: {string.Join(", ", gains)}.";
        }
    }

    public static IEnumerable<string> Overnight(Party party, IReadOnlyDictionary<string, PartyMemberSnapshot> before)
    {
        foreach (var member in party.Living())
        {
            var old = before[member.Id];
            int hp = member.Health?.CurrentHP ?? 0;
            yield return $"{member.Name}: {hp}/{member.Health?.MaxHP} HP (+{hp - old.Hp})"
                + (old.Wounded > 0 ? "; Wounded cleared" : "")
                + (member.Spellcasting != null ? "; spell slots and focus restored" : "") + ".";
        }
    }
}
