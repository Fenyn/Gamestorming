namespace Delve.Combat;

/// <summary>How a set of highlighted tiles should be rendered by the grid view.</summary>
public enum HighlightKind
{
    None,
    Move,
    Step,
    StrikeTarget,
    /// <summary>Enemy tiles targetable by an offensive spell.</summary>
    SpellEnemyTarget,
    /// <summary>Ally tiles targetable by a beneficial spell or skill (heal, Battle Medicine).</summary>
    AllyTarget,
    /// <summary>Candidate origin tiles the player can aim an area template at.</summary>
    AreaOrigin
}
