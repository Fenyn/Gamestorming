using System.Linq;
using Delve.Rules;
using PF2e.Core;
using PF2e.Utilities;

namespace Delve.Combat;

internal static class AbilityBadges
{
    internal static string For(ICharacter actor, string id)
    {
        if (id == "inspiring-marshal-stance")
            return StanceRules.IsInStance(actor, id) ? "Active" : "";
        var feats=FeatEncounter.State(actor);
        if (id=="reach-spell" && SpellReach.Pending(actor)) return "Ready";
        if (id=="spell-parry" && feats.Parrying || id=="reinforce-eidolon" && feats.Reinforced) return "Active";
        if (id=="psi-strikes" && feats.PsiUsed) return "Spent";
        if (WayfarerFeature.Find(actor) == null) return "";
        var state = WayfarerFeature.State(actor);
        string status = id switch
        {
            "rage" when state.Raging => "Active",
            "spellstrike" => state.SpellstrikeReady ? "Ready" : "Spent",
            "recharge-spellstrike" when state.SpellstrikeReady => "Ready",
            "weapon-trance" when state.WeaponTrance => "Active",
            "arcane-cascade" when state.Cascade => "Active",
            "hunt-prey" when state.Prey != null => "Marked",
            "chalice" when state.ChaliceDrained => "Spent",
            "confident-finisher" => state.FinisherUsed ? "Spent" : state.Panache ? "Panache" : "No Panache",
            "unleash-psyche" => state.PsycheTurns > 0 ? "Active" : state.PsycheRecovery > 0 ? "Recovering" : "",
            "act-together" when state.ActTogetherUsed => "Spent",
            _ => "",
        };
        int focus = ClassActions.All.FirstOrDefault(a => a.Id == id)?.Focus ?? 0;
        return status.Length > 0 ? status : focus > 0 ? $"{focus} Focus" : "";
    }
}
