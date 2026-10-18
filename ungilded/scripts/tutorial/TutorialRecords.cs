using System.Collections.Generic;
using PF2e.Core;
using PF2e.Data;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Tutorial;

/// <summary>One resolved Strike as the tutorial sees it: who, at whom, the roll and what it did.
/// Raised after the strike's damage and death events have played.</summary>
public sealed record StrikeInfo(
    ICharacter Attacker,
    ICharacter Target,
    DegreeOfSuccess Degree,
    int D20,
    int Total,
    int TargetAc,
    int Damage,
    bool Killed,
    bool IsReaction);

/// <summary>An enemy about to leave its first tile of a Stride. <see cref="Path"/> is the whole
/// route when a scripted turn planned it; an AI Stride only reports its first step.</summary>
public sealed record EnemyStride(
    ICharacter Unit,
    PF2eVec From,
    PF2eVec NextTile,
    IReadOnlyList<PF2eVec> Path);
