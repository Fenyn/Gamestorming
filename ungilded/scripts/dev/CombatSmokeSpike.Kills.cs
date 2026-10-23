using System.Collections.Generic;
using System.Linq;
using Godot;
using PF2e.Core;

namespace Ungilded.Dev;

public partial class CombatSmokeSpike
{
    /// <summary>Each death plays once, right after the damage that caused it, and no damage plays on
    /// the corpse afterwards.</summary>
    private void CheckKills(List<BattleEvent> presented)
    {
        var deaths = presented.Select((e, i) => (e, i)).Where(p => p.e.Type == BattleEventType.CreatureDied).ToList();
        Check($"the fight had a kill ({deaths.Count})", deaths.Count > 0);
        foreach (var (death, at) in deaths)
        {
            var dead = death.Source!;
            int died = deaths.Count(d => ReferenceEquals(d.e.Source, dead));
            int before = presented.Take(at).Count(e => e.Type == BattleEventType.DamageDealt && ReferenceEquals(e.Target, dead));
            int after = presented.Skip(at + 1).Count(e => e.Type == BattleEventType.DamageDealt && ReferenceEquals(e.Target, dead));
            bool followsDamage = at > 0 && presented[at - 1].Type == BattleEventType.DamageDealt
                && ReferenceEquals(presented[at - 1].Target, dead);
            GD.Print($"[CombatSmoke] {dead.Name}: {before} DamageDealt before its death, {died} CreatureDied, {after} DamageDealt after");
            Check($"{dead.Name}: one CreatureDied, right after the DamageDealt that killed it, none after",
                died == 1 && before > 0 && followsDamage && after == 0);
        }
    }
}
