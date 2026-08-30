using System.Collections.Generic;
using System.Text;
using Delve.Run;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Data;

namespace Delve.Flow;

/// <summary>
/// One place that turns party state into the strings the run screens show. The map strip, the rest
/// panel and the short-rest panel all print the same "name HP/max (Wounded n)" shape, so the format
/// lives here instead of three times over.
/// </summary>
public static class PartyLines
{
    /// <summary>Wounded value of a member, 0 when the condition database is not loaded.</summary>
    public static int Wounded(PF2eCharacter member)
    {
        var wounded = ConditionDatabase.Instance?.Wounded;
        if (wounded == null || member.Conditions == null) return 0;
        return member.Conditions.GetConditionValue(wounded);
    }

    /// <summary>"Aldric 21/28 (Wounded 1)" - the single-member form every screen uses.</summary>
    public static string Describe(PF2eCharacter member)
    {
        var health = member.Health;
        var text = new StringBuilder(member.Name);
        if (health != null)
            text.Append(' ').Append(health.CurrentHP).Append('/').Append(health.MaxHP);

        int wounded = Wounded(member);
        if (wounded > 0)
            text.Append(" (Wounded ").Append(wounded).Append(')');
        if (health != null && health.IsDead)
            text.Append(" (down)");
        return text.ToString();
    }

    /// <summary>One line per member, in party order.</summary>
    public static IReadOnlyList<string> Lines(Party party)
    {
        var lines = new List<string>(party.Members.Count);
        foreach (var member in party.Members)
            lines.Add(Describe(member));
        return lines;
    }

    /// <summary>Every member on one line, for the map's top strip.</summary>
    public static string Summary(Party party)
    {
        var text = new StringBuilder();
        foreach (var member in party.Members)
        {
            if (text.Length > 0) text.Append("   ");
            text.Append(Describe(member));
        }
        return text.ToString();
    }
}
