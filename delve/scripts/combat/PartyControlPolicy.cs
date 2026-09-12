namespace Delve.Combat;

/// <summary>Every party member may be commanded. Guests remain AI through their ally status.</summary>
public sealed record PartyControlPolicy
{
    public bool CanCommand(string characterId) => true;
}
