using System.Collections.Generic;
using PF2e.Core;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Tutorial;

/// <summary>One step of a scripted enemy turn.</summary>
public abstract record ScriptedStep;

/// <summary>Stride to a tile. <see cref="Provokes"/> false moves without movement reactions.</summary>
public sealed record StrideToStep(PF2eVec Tile, bool Provokes) : ScriptedStep;

/// <summary>Stride to the reachable tile farthest from <see cref="From"/>, at most
/// <see cref="MaxTiles"/> tiles of path away.</summary>
public sealed record StrideAwayStep(ICharacter From, int MaxTiles, bool Provokes) : ScriptedStep;

/// <summary>Strike the target with the actor's first melee strike.</summary>
public sealed record StrikeStep(ICharacter Target) : ScriptedStep;

/// <summary>End the turn here; later steps do not run.</summary>
public sealed record EndTurnStep : ScriptedStep;

/// <summary>
/// An ordered list of steps that replaces the AI for one enemy for one round. Steps run through
/// the same executor and event path the AI uses, so they animate and log the same way. A step the
/// rules refuse (out of reach, no actions) is skipped.
/// </summary>
public sealed class ScriptedTurn
{
    private readonly List<ScriptedStep> _steps = new();

    public IReadOnlyList<ScriptedStep> Steps => _steps;

    public ScriptedTurn StrideTo(PF2eVec tile, bool provokes = true)
    {
        _steps.Add(new StrideToStep(tile, provokes));
        return this;
    }

    public ScriptedTurn StrideAwayFrom(ICharacter from, int maxTiles, bool provokes = true)
    {
        _steps.Add(new StrideAwayStep(from, maxTiles, provokes));
        return this;
    }

    public ScriptedTurn Strike(ICharacter target)
    {
        _steps.Add(new StrikeStep(target));
        return this;
    }

    public ScriptedTurn EndTurn()
    {
        _steps.Add(new EndTurnStep());
        return this;
    }
}
