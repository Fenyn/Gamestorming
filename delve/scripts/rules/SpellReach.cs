using System;
using PF2e.Actions;
using PF2e.Core;

namespace Delve.Rules;

/// <summary>Reach is valid for the immediately following action, not for the whole turn.</summary>
internal static class SpellReach
{
    internal static int ClassRange(ICharacter c,ClassActionSpec spec) => spec.Id is "lay-on-hands" or "clinging-ice" or "life-boost" or "amped-daze" or "elemental-toss" ? Feet(c,spec.Range*5)/5 : spec.Range;
    internal static bool Pending(ICharacter c)=>FeatEncounter.State(c).ReachSequence>=0 && FeatEncounter.State(c).ReachSequence==c.Combat.ActionSequence && FeatEncounter.State(c).ReachActions==c.Actions.TotalActionsRemaining;
    internal static int Feet(ICharacter c,int original)=>Pending(c)?(original<=5?30:original+30):original;
    internal static IDisposable Apply(ICharacter c,SpellCastAction spell)
    {
        int? before=spell.RuntimeRangeOverride;
        if (Pending(c) && (spell.Area?.HasArea!=true || spell.Area.RangeInFeet>0))
            spell.RuntimeRangeOverride=Feet(c,before??spell.Area?.RangeInFeet??0);
        return new Scope(()=>spell.RuntimeRangeOverride=before);
    }
    private sealed class Scope(Action restore):IDisposable { public void Dispose()=>restore(); }
}
