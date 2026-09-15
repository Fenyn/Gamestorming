using System;
using System.Linq;
using Delve.Presets;
using Delve.Run;

namespace Delve.Dev;

/// <summary>Explicit choices for integration fixtures without a human driving their sheets.</summary>
internal static class PromotionTestDriver
{
    internal static void Complete(Party party)
    {
        foreach (var member in party.Living())
        {
            var state = CharacterPromotion.For(member);
            while (state.PendingLevels(member) > 0)
            {
                var feat = PromotionFeats.For(member).FirstOrDefault(f => PromotionFeats.LockReason(member, f, state.ChoiceLevel(member)) == null);
                string error;
                bool done = feat == null ? state.SaveChoiceAndPromote(member, state.Revision, out error)
                    : state.Confirm(member, feat.Id, state.Revision, out error);
                if (!done) throw new InvalidOperationException(error);
            }
        }
    }
}
