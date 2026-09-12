namespace Delve.Combat;

/// <summary>Who may command party members. A null leader keeps standalone combat harnesses manual.</summary>
public sealed record PartyControlPolicy(string? LeaderId = null, bool ManualCompanions = false)
{
    public bool CanCommand(string characterId)
        => LeaderId == null || ManualCompanions || characterId == LeaderId;
}
