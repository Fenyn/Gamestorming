using System.Collections.Generic;
using System.Linq;
using PF2e.Core;

namespace Delve.Rules;

public static class ClassStatus
{
    public static IEnumerable<string> Active(ICharacter c)
    {
        var s=WayfarerFeature.State(c);
        foreach (var buff in s.ActiveBuffs.Values.Distinct()) yield return buff;
        var feats=FeatEncounter.State(c);
        if (SpellReach.Pending(c)) yield return "Reach Spell ready";
        if (feats.Parrying) yield return "Spell Parry";
        if (feats.Reinforced) yield return "Eidolon reinforced";
        if (feats.PsiStrikes && (feats.PsiTurns==feats.Turn || feats.PsiUnleashed && s.PsycheTurns>0)) yield return "Psi Strikes";
        if (WayfarerFeature.Find(c)==null) yield break;
        if (s.Raging) yield return "Raging";
        if (s.Panache) yield return "Panache";
        if (s.Prey!=null) yield return $"Marked: {s.Prey.Name}";
        if (s.Cascade) yield return "Arcane Cascade";
        if (s.WeaponTrance) yield return "Weapon Trance";
        if (s.PsycheTurns>0) yield return "Psyche unleashed";
        if (s.Cursebound>0) yield return $"Cursebound {s.Cursebound}";
    }
    public static string Resources(ICharacter c)
    {
        var parts=new List<string>();
        if (c.Spellcasting?.MaxFocusPoints>0) parts.Add($"Focus {c.Spellcasting.CurrentFocusPoints}/{c.Spellcasting.MaxFocusPoints}");
        var feature=WayfarerFeature.Find(c);
        if (feature!=null)
        {
            var s=WayfarerFeature.State(c);
            if (feature.Class=="Magus") parts.Add(s.SpellstrikeReady?"Spellstrike ready":"Spellstrike spent");
            if (feature.Class=="Thaumaturge") parts.Add(s.ChaliceDrained?"Chalice drained":"Chalice full");
            if (feature.Class=="Swashbuckler") parts.Add(s.FinisherUsed?"Finisher used":s.Panache?"Panache":"No Panache");
        }
        return string.Join("  ",parts);
    }

    /// <summary>Spendable resources as (name, current, max) for pip rows. Binary states count as 1 of 1.</summary>
    public static IEnumerable<(string Name, int Current, int Max)> ResourcePips(ICharacter c)
    {
        if (c.Spellcasting?.MaxFocusPoints>0) yield return ("Focus", c.Spellcasting.CurrentFocusPoints, c.Spellcasting.MaxFocusPoints);
        var feature=WayfarerFeature.Find(c);
        if (feature==null) yield break;
        var s=WayfarerFeature.State(c);
        if (feature.Class=="Magus") yield return ("Spellstrike", s.SpellstrikeReady?1:0, 1);
        if (feature.Class=="Thaumaturge") yield return ("Chalice", s.ChaliceDrained?0:1, 1);
        if (feature.Class=="Swashbuckler") yield return ("Panache", s.Panache?1:0, 1);
    }
}
