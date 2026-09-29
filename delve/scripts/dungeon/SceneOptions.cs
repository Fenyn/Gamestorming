using Delve.Run.Events;
using PF2e.Data;

namespace Delve.Dungeon;

/// <summary>Builders for crawl scene options, shared by the station and glade scene tables.</summary>
public static class SceneOptions
{
    public static EventOption Check(string label, Skill skill, int dc, EventOutcome critical, EventOutcome success,
        EventOutcome failure, EventOutcome? criticalFailure = null, bool fixedDc = false) => new()
    {
        Label = label,
        Check = new EventCheck(skill, dc, true, fixedDc),
        CriticalSuccess = critical,
        Success = success,
        Failure = failure,
        CriticalFailure = criticalFailure ?? failure,
    };

    public static EventOption Free(string label, EventOutcome outcome) => new() { Label = label, Success = outcome };
    public static EventOutcome Do(string text, params EventEffect[] effects) => new(text, effects);
    public static EventOutcome Nothing(string text) => EventOutcome.Nothing(text);
    public static EventEffect Effect(EventEffectKind kind, int value = 0) => new(kind, value);

    /// <summary>The option every scene ends with: move on and get one crossing's ward back.</summary>
    public static EventOption Leave() =>
        Free("Leave it undisturbed", Do("You move on and save your strength.", Effect(EventEffectKind.WardDelta, StationScenes.LeaveWard)));
}
