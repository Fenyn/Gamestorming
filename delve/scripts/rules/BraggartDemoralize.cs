using PF2e.Actions.SkillActions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Utilities;

namespace Delve.Rules;

/// <summary>The normal Demoralize action also triggers Braggart panache. Do not require players
/// to choose a differently named duplicate of the same skill check to receive their class benefit.</summary>
public sealed class BraggartDemoralize : DemoralizeAction
{
    protected override void ApplyOutcome(ICharacter actor,ICharacter target,DegreeOfSuccess degree,SkillCheckResult result)
    {
        base.ApplyOutcome(actor,target,degree,result);
        if (WayfarerFeature.Find(actor)?.Class=="Swashbuckler" && degree>=DegreeOfSuccess.Success)
            WayfarerFeature.SetPanache(actor,true);
    }
}
