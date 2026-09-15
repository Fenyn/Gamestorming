namespace Delve.Combat;

/// <summary>Party-card presentation, independent of engine character objects.</summary>
public sealed record SquadMemberView(int Id, string HeroId, string Name, int Hp, int MaxHp,
    bool Acting, bool Focused, string State, string Conditions);
