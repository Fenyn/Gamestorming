using System.Collections.Generic;
using System.Linq;
using Delve.Combat;
using PF2e.Core;
using PF2e.Data;
using PF2e.Utilities;

namespace Delve.Flow;

/// <summary>
/// What confirming a promotion changes, as labelled before → after pairs ("HP 32 → 42"). The change
/// is what the level alone adds: the same preset built fresh at the current and at the target level.
/// It is applied to the live member's numbers, so their feats, gear and conditions stay in the
/// "before" and do not skew the step. Only the numbers that change are listed. Godot-free.
/// </summary>
public static class PromotionGains
{
    public static IReadOnlyList<FigureView> Between(PF2eCharacter live, PF2eCharacter now, PF2eCharacter next)
    {
        var figures = new List<FigureView>();
        int Hp(PF2eCharacter c) => c.Health?.MaxHP ?? 0;
        int Save(PF2eCharacter c, SavingThrow save) => StatsCalculator.CalculateSave(c, save);
        Add(figures, "HP", Hp(live), Hp(now), Hp(next));
        Add(figures, "AC", StatsCalculator.CalculateAC(live), StatsCalculator.CalculateAC(now), StatsCalculator.CalculateAC(next));
        Add(figures, "Fort", Save(live, SavingThrow.Fortitude), Save(now, SavingThrow.Fortitude), Save(next, SavingThrow.Fortitude), signed: true);
        Add(figures, "Ref", Save(live, SavingThrow.Reflex), Save(now, SavingThrow.Reflex), Save(next, SavingThrow.Reflex), signed: true);
        Add(figures, "Will", Save(live, SavingThrow.Will), Save(now, SavingThrow.Will), Save(next, SavingThrow.Will), signed: true);
        Add(figures, "Perception", StatsCalculator.CalculatePerception(live), StatsCalculator.CalculatePerception(now),
            StatsCalculator.CalculatePerception(next), signed: true);
        if (live.Spellcasting != null)
            Add(figures, "Spell DC", StatsCalculator.CalculateSpellDC(live), StatsCalculator.CalculateSpellDC(now), StatsCalculator.CalculateSpellDC(next));
        else
        {
            Add(figures, "Class DC", StatsCalculator.CalculateClassDC(live), StatsCalculator.CalculateClassDC(now), StatsCalculator.CalculateClassDC(next));
            if (Strike(live) is { } strike && Strike(now) is { } before && Strike(next) is { } after && strike.Label == after.Label)
                Add(figures, Title(strike.Label), strike.Bonus, before.Bonus, after.Bonus, signed: true);
        }
        return figures;
    }

    /// <summary>The sheet's signature strike ("LONGSWORD", +10), or null for a caster's spell DC.</summary>
    private static (string Label, int Bonus)? Strike(PF2eCharacter character)
    {
        var headline = HeroSheetBuilder.Read(character).Headlines.LastOrDefault();
        if (headline == null || headline.Label is "HP" or "AC" or "KEY ABILITY") return null;
        return int.TryParse(headline.Value.TrimStart('+'), out int bonus) ? (headline.Label, bonus) : null;
    }

    private static string Title(string label) => label.Length == 0 ? label : label[0] + label[1..].ToLowerInvariant();

    private static void Add(List<FigureView> figures, string caption, int live, int now, int next, bool signed = false)
    {
        int step = next - now;
        if (step == 0) return;
        string Text(int value) => signed ? HeroSheetBuilder.Signed(value) : value.ToString();
        figures.Add(new FigureView(caption, Text(live + step)) { Before = Text(live) });
    }
}
