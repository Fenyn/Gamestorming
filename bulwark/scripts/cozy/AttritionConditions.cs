using PF2e.Conditions;

namespace Bulwark.Cozy;

/// <summary>
/// The long-term attrition conditions the cozy layer keys on: Wounded, Drained, Doomed, Fatigued.
/// Single named home for the whitelist (squad-panel display AND save capture consume it).
/// Deliberately NOT the engine's duration classification — encounter cleanup uses
/// <c>ConditionTracker.RemoveNonPersistingConditions</c>; this list answers "what does the squad
/// carry between fights", not "what ends when combat ends".
/// </summary>
public static class AttritionConditions
{
    public static readonly Condition[] LongTerm =
    {
        Condition.Wounded, Condition.Drained, Condition.Doomed, Condition.Fatigued,
    };
}
