using PF2e.Core;

namespace Ungilded.Combat;

/// <summary>The kinds of player order a host tells apart as it is committed.</summary>
public enum PlayerOrderKind
{
    Other,
    Strike,
    Bomb,
    Reaction,
    EndTurn,
}

/// <summary>An order the player commits: its kind and the creature it aims at, or null.</summary>
public readonly record struct PlayerOrder(PlayerOrderKind Kind, ICharacter? Target = null);
