namespace Delve.Combat;

/// <summary>How a set of targeting highlights should be rendered by the grid view. Ordinary movement
/// is not a kind here: it renders as the Idle bands (<see cref="MoveOption"/>).</summary>
public enum HighlightKind
{
    None,
    /// <summary>Shielded Stride destination tiles.</summary>
    Move,
    StrikeTarget,
    /// <summary>Enemy tiles targetable by an offensive spell.</summary>
    SpellEnemyTarget,
    /// <summary>Ally tiles targetable by a beneficial spell or skill (heal, Battle Medicine).</summary>
    AllyTarget,
    /// <summary>Candidate origin tiles the player can aim an area template at.</summary>
    AreaOrigin
}
