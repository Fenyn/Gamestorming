using System.Collections.Generic;
using PF2e.Data;

namespace Delve.Run.Events;

/// <summary>
/// The event table. One placeholder for the skeleton - enough to walk a Happenstance node end to
/// end. Content lands later, and the definitions are pure data, so they can move to files.
/// </summary>
public static class EventCatalog
{
    public const string CollapsedPassageId = "collapsed-passage";

    public static readonly EventDefinition CollapsedPassage = new()
    {
        Id = CollapsedPassageId,
        Title = "Collapsed passage",
        Body = "The tunnel ahead has fallen in. Loose rubble slopes up to a gap near the ceiling, "
               + "and a longer side gallery curves away into the dark.",
        Options = new List<EventOption>
        {
            new()
            {
                Label = "Climb the rubble",
                Check = new EventCheck(Skill.Athletics, Dc: 15, AllowPickActor: true),
                CriticalSuccess = new EventOutcome(
                    "The climb goes clean, and the shortcut saves the party an hour of walking.",
                    new List<EventEffect> { new(EventEffectKind.HealFraction, 10) }),
                Success = EventOutcome.Nothing("The party scrambles through without incident."),
                Failure = new EventOutcome(
                    "A slab shifts underfoot and the climber slides back down the scree.",
                    new List<EventEffect> { new(EventEffectKind.Damage, 4) }),
                CriticalFailure = new EventOutcome(
                    "The whole slope gives way and buries the climber to the waist.",
                    new List<EventEffect>
                    {
                        new(EventEffectKind.Damage, 8),
                        new(EventEffectKind.WoundedDelta, 1),
                    }),
            },
            new()
            {
                Label = "Go around",
                Success = EventOutcome.Nothing("The side gallery is long, but it comes out where you need it."),
            },
        },
    };

    /// <summary>Every event that can be rolled for a Happenstance node.</summary>
    public static readonly IReadOnlyList<EventDefinition> All = new List<EventDefinition> { CollapsedPassage };

    /// <summary>Pick an event deterministically for a node.</summary>
    public static EventDefinition ForNode(int runSeed, int nodeId)
    {
        int index = RunRng.StableSeed(runSeed, nodeId, "event") % All.Count;
        return All[index];
    }
}
