using System.Text.RegularExpressions;

namespace Delve.UI;

/// <summary>An already resolved roll, read from the engine's combat log.</summary>
public sealed record CombatRoll(string Prefix, int Die, string Modifiers, int Total, string Defense, int DC, string Degree)
{
    private static readonly Regex Pattern = new(
        @"^(.*?)d20\((\d+)\)(.*?)=(\d+) vs (AC|DC) (\d+) → (CriticalSuccess|CriticalFailure|Success|Failure)$");

    public string Outcome => Degree switch {
        "CriticalSuccess" => Defense == "AC" ? "CRITICAL HIT" : "CRITICAL SUCCESS",
        "Success" => Defense == "AC" ? "HIT" : "SUCCESS",
        "CriticalFailure" => Defense == "AC" ? "CRITICAL MISS" : "CRITICAL FAILURE",
        _ => Defense == "AC" ? "MISS" : "FAILURE",
    };

    public static CombatRoll? Parse(string message)
    {
        var match = Pattern.Match(message);
        if (!match.Success || !int.TryParse(match.Groups[2].Value, out int die)
            || !int.TryParse(match.Groups[4].Value, out int total)
            || !int.TryParse(match.Groups[6].Value, out int dc) || die is < 1 or > 20) return null;
        return new(match.Groups[1].Value, die, match.Groups[3].Value, total,
            match.Groups[5].Value, dc, match.Groups[7].Value);
    }
}
