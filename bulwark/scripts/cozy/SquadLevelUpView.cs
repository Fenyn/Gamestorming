namespace Bulwark.Cozy;

/// <summary>
/// One applied level-up, reported by <see cref="SquadRoster.ApplyBankedLevelUps"/> and re-emitted
/// through GameState's SquadLeveledUp event. View-model shaped (no engine types) per CLAUDE.md so
/// UI can announce it directly.
/// </summary>
public sealed record SquadLevelUpView(string MemberId, string MemberName, int FromLevel, int ToLevel);
