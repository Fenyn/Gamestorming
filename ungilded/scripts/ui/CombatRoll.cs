using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;

namespace Ungilded.UI;

/// <summary>A hit's damage as the engine rolled it: the weapon dice, the flat modifier on them, the
/// critical doubling, the damage added after the doubling (named bonus damage, fatal dice), then the
/// target's weakness and resistance. <see cref="Total"/> is the damage dealt; temporary Hit Points
/// that absorbed part of it are not taken off.</summary>
public sealed record DamageRoll(IReadOnlyList<int> Faces, int Sides, int Flat, bool Doubled,
    IReadOnlyList<(string Label, int Value)> Extras, int Weakness, int Resistance, int Total, PF2e.Data.DamageType Type)
{
    public int DiceSum => Faces.Sum();

    /// <summary>The roll behind one damage instance, or null for damage with no dice or with a label
    /// of its own (a persistent damage tick).</summary>
    public static DamageRoll? From(PF2e.Data.DamageResult result)
    {
        if (result.DiceRolls is not { Count: > 0 } faces || result.DamageLabel != null) return null;
        int flat = (result.Formula?.Modifier ?? 0) + result.AbilityModifier + result.ConditionModifier;
        int rolled = result.PreMitigationDamage > 0 ? result.PreMitigationDamage : result.TotalDamage;
        int total = rolled + result.WeaknessApplied - result.ResistanceApplied;
        int extra = rolled - (faces.Sum() + flat) * (result.WasCritical ? 2 : 1);
        var extras = new List<(string, int)>();
        foreach (var bonus in result.BonusDamageEntries ?? new())
            if (bonus.Total != 0) extras.Add((bonus.Source ?? "", bonus.Total));
        if (result.CritBonusRolls is { Count: > 0 } fatal) extras.Add(("", fatal.Sum()));
        if (extras.Sum(e => e.Item2) != extra)
        {
            extras.Clear();
            if (extra != 0) extras.Add(("", extra));
        }
        return new(faces.ToArray(), result.Formula?.DieSize ?? 0, flat, result.WasCritical, extras,
            result.WeaknessApplied, result.ResistanceApplied, total, result.DamageType);
    }
}

/// <summary>An already resolved roll, read from the engine's combat log: a Strike line
/// ("d20(19)+10=29 vs AC 17 → CriticalSuccess") or a skill check line
/// ("Athletics: 12 + 5 = 17 vs DC 18 → Success").</summary>
public sealed record CombatRoll(string Prefix, int Die, string Modifiers, int Total, string Defense, int DC, string Degree)
{
    /// <summary>True when an enemy made the roll, so its success is bad news for the party.</summary>
    public bool EnemyRoll { get; init; }

    /// <summary>True when the defence is not revealed yet: the line reads "vs AC ?" or "vs DC ?".</summary>
    public bool DcMasked { get; init; }

    public string DcText => DcMasked ? "?" : DC.ToString();

    /// <summary>The named modifiers that applied, from the engine's modifier stacks. Its roll side is
    /// already inside <see cref="Modifiers"/>' leading bonus unless <see cref="WithBreakdown"/> split it out.</summary>
    public Ungilded.Combat.RollBreakdown Breakdown { get; init; } = Ungilded.Combat.RollBreakdown.None;

    private static readonly Regex LeadingBonus = new(@"^\s*([+-]?\d+)");

    /// <summary>The roll with its named roll-side modifiers split out of the leading bonus, so the
    /// arithmetic reads "+7 MAP-4" then "Prone -2" and still sums to the total.</summary>
    public CombatRoll WithBreakdown(Ungilded.Combat.RollBreakdown breakdown)
    {
        var match = LeadingBonus.Match(Modifiers);
        if (breakdown.IsEmpty || !match.Success || !int.TryParse(match.Groups[1].Value, out int bonus)) return this;
        int named = 0;
        foreach (var modifier in breakdown.Roll) named += modifier.Value;
        string rest = Modifiers[match.Length..];
        return this with { Modifiers = $"{bonus - named:+0;-0;+0}{rest}", Breakdown = breakdown };
    }

    public bool IsAttack => Defense == "AC";

    public bool Critical => Degree is "CriticalSuccess" or "CriticalFailure";

    /// <summary>The degree as a zone index: 0 critical failure, 1 failure, 2 success, 3 critical success.</summary>
    public int DegreeIndex => DegreeZones.Index(Degree);

    private static readonly Regex Pattern = new(
        @"^(.*?)d20\((\d+)\)(.*?)=(\d+) vs (AC|DC) (\d+|\?) → (CriticalSuccess|CriticalFailure|Success|Failure)$");

    private static readonly Regex Check = new(
        @"^(.+?: )(\d+) \+ (-?\d+)(?: MAP(-\d+))? = (-?\d+) vs DC (\d+|\?) → (CriticalSuccess|CriticalFailure|Success|Failure)$");

    private static readonly Regex ArmorClass = new(@"vs AC \d+");
    private static readonly Regex CheckDc = new(@"vs DC \d+");

    /// <summary>The engine roll line with its AC replaced by "?".</summary>
    public static string MaskArmorClass(string message) => ArmorClass.Replace(message, "vs AC ?");

    /// <summary>A skill check line with its DC replaced by "?".</summary>
    public static string MaskCheckDc(string message) => IsCheckLine(message) ? CheckDc.Replace(message, "vs DC ?") : message;

    public static bool IsCheckLine(string message) => Check.IsMatch(message);

    public string Outcome => Degree switch {
        "CriticalSuccess" => Defense == "AC" ? "CRITICAL HIT" : "CRITICAL SUCCESS",
        "Success" => Defense == "AC" ? "HIT" : "SUCCESS",
        "CriticalFailure" => Defense == "AC" ? "CRITICAL MISS" : "CRITICAL FAILURE",
        _ => Defense == "AC" ? "MISS" : "FAILURE",
    };

    /// <summary>The outcome word of a compact log row.</summary>
    public string ShortOutcome => Degree switch {
        "CriticalSuccess" => Defense == "AC" ? "CRIT" : "CRIT SUCCESS",
        "Success" => Defense == "AC" ? "HIT" : "SUCCESS",
        "CriticalFailure" => Defense == "AC" ? "CRIT MISS" : "CRIT FAIL",
        _ => Defense == "AC" ? "MISS" : "FAILURE",
    };

    public static CombatRoll? Parse(string message)
    {
        var match = Pattern.Match(message);
        if (match.Success)
        {
            if (!int.TryParse(match.Groups[2].Value, out int die) || !int.TryParse(match.Groups[4].Value, out int total)
                || die is < 1 or > 20) return null;
            bool masked = match.Groups[6].Value == "?";
            int dc = 0;
            if (!masked && !int.TryParse(match.Groups[6].Value, out dc)) return null;
            return new(match.Groups[1].Value, die, match.Groups[3].Value, total,
                match.Groups[5].Value, dc, match.Groups[7].Value) { DcMasked = masked };
        }
        return ParseCheck(message);
    }

    /// <summary>The engine prints a check's bonus with the multiple attack penalty already in it and
    /// names the penalty after it; the modifiers split them so they still sum to the bonus.</summary>
    private static CombatRoll? ParseCheck(string message)
    {
        var match = Check.Match(message);
        if (!match.Success || !int.TryParse(match.Groups[2].Value, out int die) || die is < 1 or > 20
            || !int.TryParse(match.Groups[3].Value, out int bonus) || !int.TryParse(match.Groups[5].Value, out int total))
            return null;
        int map = match.Groups[4].Success && int.TryParse(match.Groups[4].Value, out int penalty) ? penalty : 0;
        string modifiers = map == 0 ? $"{bonus:+0;-0;+0}" : $"{bonus - map:+0;-0;+0} MAP{map}";
        bool masked = match.Groups[6].Value == "?";
        int dc = masked ? 0 : int.Parse(match.Groups[6].Value);
        return new(match.Groups[1].Value, die, modifiers, total, "DC", dc, match.Groups[7].Value) { DcMasked = masked };
    }
}
