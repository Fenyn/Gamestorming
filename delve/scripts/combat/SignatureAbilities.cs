using System.Collections.Generic;

namespace Delve.Combat;

/// <summary>Stable authored priorities by ability identity. Zero keeps an action in overflow.</summary>
internal static class SignatureAbilities
{
    private static readonly Dictionary<string, int> Priorities = new()
    {
        ["lay-on-hands"] = 10, ["clinging-ice"] = 10, ["life-boost"] = 20,
        ["flurry-of-blows"] = 10, ["hunt-prey"] = 10, ["cornucopia"] = 10,
        ["spellstrike"] = 10, ["recharge-spellstrike"] = 20, ["dimensional-assault"] = 30,
        ["weapon-trance"] = 10, ["exploit-vulnerability"] = 10, ["chalice"] = 20,
        ["courageous-anthem"] = 10, ["lingering-composition"] = 20,
        ["amped-daze"] = 10, ["unleash-psyche"] = 20,
        ["braggarts-boast"] = 10, ["confident-finisher"] = 20,
        ["act-together"] = 10, ["eidolon-strike"] = 20, ["eidolon-advance"] = 30,
        ["elemental-toss"] = 10, ["preset-heal"] = 10, ["preset-force-bolt"] = 10,
    };

    internal static int Priority(string id)
    {
        return Priorities.GetValueOrDefault(BaseId(id));
    }

    internal static string BaseId(string id)
    {
        int rank = id.LastIndexOf("-rank-", System.StringComparison.Ordinal);
        if (rank >= 0) id = id[..rank];
        return id;
    }
}
