using System.Collections.Generic;
using PF2e.MapGen;
using Ungilded.Content;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Props;

/// <summary>
/// The named tiles of an authored board (spawn anchors and script marks), found by layout name in
/// <see cref="PrologueMaps"/>. Dressing keeps props off these tiles and hangs anchor-bound props
/// (the Encounter 4 sigil) from them. A generated board has none.
/// </summary>
public static class BoardAnchors
{
    private static readonly IReadOnlyDictionary<string, PF2eVec> None = new Dictionary<string, PF2eVec>();
    private static Dictionary<string, IReadOnlyDictionary<string, PF2eVec>>? _byName;

    public static IReadOnlyDictionary<string, PF2eVec> For(MapLayout board)
    {
        if (_byName == null)
        {
            _byName = new Dictionary<string, IReadOnlyDictionary<string, PF2eVec>>();
            for (int n = 1; n <= 4; n++)
            {
                var battle = PrologueMaps.Encounter(n);
                if (battle.Layout.Name != null) _byName[battle.Layout.Name] = battle.Anchors;
            }
        }
        return board.Name != null && _byName.TryGetValue(board.Name, out var anchors) ? anchors : None;
    }
}
