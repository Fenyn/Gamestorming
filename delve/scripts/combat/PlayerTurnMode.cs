namespace Delve.Combat;

/// <summary>Current interaction mode of the player turn controller. Idle shows the movement bands
/// and takes smart-move clicks; SelectingMove is the Shielded Stride tile pick; SelectingDelaySlot
/// picks a turn order chip to Delay until after.</summary>
public enum PlayerTurnMode
{
    Idle,
    /// <summary>Move was picked from the command menu: the smart-move bands are up.</summary>
    Moving,
    SelectingMove,
    SelectingStrike,
    SelectingSpellTarget,
    SelectingSpellTargets,
    SelectingAreaOrigin,
    SelectingSkillTarget,
    SelectingDelaySlot
}
