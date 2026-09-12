namespace Delve.Combat;

/// <summary>Current interaction mode of the player turn controller. Idle shows the movement bands
/// and takes smart-move clicks; SelectingMove is the Shielded Stride tile pick.</summary>
public enum PlayerTurnMode
{
    Idle,
    SelectingMove,
    SelectingStrike,
    SelectingSpellTarget,
    SelectingAreaOrigin,
    SelectingSkillTarget
}
