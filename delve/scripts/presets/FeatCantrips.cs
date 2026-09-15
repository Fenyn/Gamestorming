using System.Linq;
using Delve.Data;
using PF2e.Core;

namespace Delve.Presets;

/// <summary>Two fixed, tradition-legal additional cantrips for the authored Expansion selections.</summary>
internal static class FeatCantrips
{
    internal static void Apply(PF2eCharacter c)
    {
        if (!RosterFeats.Has(c,"cantrip-expansion") || c.Spellcasting==null) return;
        foreach(var id in ExtraIds(c))
        {
            var spell=id.StartsWith("feat-")?UtilityCantrips.Get(id):PresetSpells.Get(id);
            if (spell!=null && c.Spellcasting.Cantrips.All(s=>s.SpellId!=id)) c.Spellcasting.Cantrips.Add(spell);
        }
    }
    internal static void Remove(PF2eCharacter c) => c.Spellcasting.Cantrips.RemoveAll(s=>ExtraIds(c).Contains(s.SpellId));
    private static string[] ExtraIds(PF2eCharacter c) => c.Id switch
        {
            "fenwick"=>[PresetSpells.DazeId,"feat-caustic-blast"],
            "sera"=>[PresetSpells.IgnitionId,PresetSpells.TelekineticProjectileId],
            "oskar"=>["feat-void-warp","feat-haunting-hymn"],
            "flick"=>["feat-timber","feat-caustic-blast"],
            _=>[],
        };
}
