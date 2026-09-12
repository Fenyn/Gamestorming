using System.Collections.Generic;
using PF2e.Core;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Combat;

/// <summary>All clickable cells of an already-validated creature target, regardless of its size.</summary>
internal static class CreatureTargetTiles
{
    internal static IEnumerable<PF2eVec> For(ICharacter target)
    {
        for (int y = 0; y < target.TileWidth; y++)
            for (int x = 0; x < target.TileWidth; x++)
                yield return new PF2eVec(target.GridPosition.x + x, target.GridPosition.y + y);
    }
}
