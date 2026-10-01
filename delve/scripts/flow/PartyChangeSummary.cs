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
    public int Focus { get; init; }
    public int ShieldHp { get; init; }

    public static PartyMemberSnapshot Read(PF2eCharacter member) => new(
        member.Health?.CurrentHP ?? 0, member.Health?.MaxHP ?? 0,
        member.Conditions?.GetConditionValue(Condition.Wounded) ?? 0,
        FeatureNames(HeroSheetBuilder.Read(member)),
        member.Spellcasting?.Cantrips.Concat(member.Spellcasting.LeveledSpells)
            .Select(s => s.ActionName).ToHashSet() ?? new(),
        Enumerable.Range(1, 10).ToDictionary(rank => rank, rank => member.Spellcasting?.GetMaxSlots(rank) ?? 0))
    {
        Focus = member.Spellcasting?.CurrentFocusPoints ?? 0,
        ShieldHp = member.Equipment?.Shield?.CurrentShieldHP ?? 0,
    };

    /// <summary>Every class feature and feat the sheet lists.</summary>
    private static HashSet<string> FeatureNames(HeroSheetData sheet) =>
        new[] { HeroSheetBuilder.FeaturesRow, HeroSheetBuilder.FeatsRow }
            .SelectMany(label => sheet.Row(label)?.Entries ?? (IEnumerable<SheetEntry>)System.Array.Empty<SheetEntry>())
            .Select(e => e.Label).ToHashSet();
}

public static class PartyChangeSummary
{
    public static Dictionary<string, PartyMemberSnapshot> Capture(Party party) =>
        party.Members.ToDictionary(m => m.Id, PartyMemberSnapshot.Read);

    public static IEnumerable<string> Recovery(Party party, IReadOnlyDictionary<string, PartyMemberSnapshot> before)
    {
        foreach (var member in party.Members)
        {
            var old = before[member.Id];
            if (old.Hp > 0) continue;
            int wounded = member.Conditions?.GetConditionValue(Condition.Wounded) ?? 0;
            yield return $"{member.Name}  HP {old.Hp} → {member.Health?.CurrentHP}"
                + (wounded != old.Wounded ? $"  Wounded {old.Wounded} → {wounded}" : "");
        }
    }

    public static IEnumerable<string> LevelGains(Party party, IReadOnlyDictionary<string, PartyMemberSnapshot> before)
    {
        foreach (var member in party.Members)
        {
            var old = before[member.Id];
            var now = PartyMemberSnapshot.Read(member);
            var gains = new List<string>();
            if (now.MaxHp > old.MaxHp) gains.Add($"HP {old.MaxHp} → {now.MaxHp}");
            foreach (var (rank, slots) in now.SpellSlots)
                if (slots > old.SpellSlots[rank]) gains.Add($"Rank {rank} slots {old.SpellSlots[rank]} → {slots}");
            gains.AddRange(now.Features.Except(old.Features));
            gains.AddRange(now.Spells.Except(old.Spells));
            if (gains.Count > 0) yield return $"{member.Name}  {string.Join("  ", gains)}";
        }
    }

    public static IEnumerable<string> Overnight(Party party, IReadOnlyDictionary<string, PartyMemberSnapshot> before)
    {
        foreach (var member in party.Living())
        {
            var old = before[member.Id];
            int hp = member.Health?.CurrentHP ?? 0;
            int wounded = member.Conditions?.GetConditionValue(Condition.Wounded) ?? 0;
            if (hp == old.Hp && wounded == old.Wounded) continue;
            yield return $"{member.Name}  {old.Hp} → {hp}"
                + (wounded != old.Wounded ? $"  Wounded {old.Wounded} → {wounded}" : "");
        }
    }
}
