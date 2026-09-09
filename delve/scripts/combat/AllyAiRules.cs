using PF2e.Data;

namespace Delve.Combat;

/// <summary>
/// How a companion the player does not command fights. Applied on top of the profile the engine
/// resolves. An ally still closes and strikes; what it will not do is end a turn somewhere a round
/// of attacks could kill it, and it falls back on the defensive plans while it can still walk.
/// </summary>
public sealed record AllyAiRules
{
    /// <summary>Weight on avoiding a lethal end position. 0 fights like a monster.</summary>
    public float Caution { get; init; } = 0.8f;

    /// <summary>Share of its remaining HP it will risk in one round. At 0.6 a healthy ally takes on
    /// a pack; the same ally at a third HP backs out of the same pack.</summary>
    public float SurvivalMargin { get; init; } = 0.6f;

    /// <summary>HP fraction below which it kites, shields and retreats. Engine default is 0.25.</summary>
    public float DefensiveThreshold { get; init; } = 0.5f;

    /// <summary>How much it avoids provoking reactive strikes. Engine default is 0.5.</summary>
    public float ReactiveStrikeFear { get; init; } = 0.9f;

    public static readonly AllyAiRules Default = new();

    /// <summary>A copy of <paramref name="source"/> carrying these values. Never edits the source:
    /// a creature definition shares one profile across every instance of that creature.</summary>
    public AIProfile Apply(AIProfile source)
    {
        var profile = source.Copy();
        profile.Caution = Caution;
        profile.SurvivalMargin = SurvivalMargin;
        profile.DefensiveThreshold = DefensiveThreshold;
        profile.ReactiveStrikeFear = ReactiveStrikeFear;
        return profile;
    }
}
