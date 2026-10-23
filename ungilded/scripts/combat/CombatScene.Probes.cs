using Ungilded.Terrain;
using Godot;

namespace Ungilded.Combat;

/// <summary>Capture and spike hooks: hovers that stand in for the mouse, the presenter's unit count
/// and the running session.</summary>
public partial class CombatScene
{
    /// <summary>Capture/dev use: how many tiles the movement bands currently cover.</summary>
    public int MoveBandTileCount => _lastBands.Count;

    /// <summary>
    /// Capture/dev use — the combat shot spike photographs the route preview with it. Hovers the
    /// farthest tile in the band that costs <paramref name="actions"/>, as if the mouse were there.
    /// False when no such tile is showing. Pass through <see cref="ClearHover"/> afterwards.
    /// </summary>
    public bool HoverBandTile(int actions) => HoverBandTile(actions, out _);

    /// <summary>Capture/dev use: <see cref="HoverBandTile(int)"/> that also returns the tile's world centre.</summary>
    public bool HoverBandTile(int actions, out Vector3 world)
    {
        world = Vector3.Zero;
        var from = _session?.CurrentActor?.GridPosition;
        if (from == null) return false;
        PF2e.Vector2Int? best = null;
        int bestDistance = -1;
        foreach (var (tile, option) in _lastBands)
        {
            if (option.Kind == MoveKind.Step || option.Actions != actions) continue;
            int distance = System.Math.Abs(tile.x - from.Value.x) + System.Math.Abs(tile.y - from.Value.y);
            if (distance > bestDistance) { bestDistance = distance; best = tile; }
        }
        if (best == null) return false;
        OnTileHovered(best);
        world = GridSpace.GridToWorld(best.Value, SurfaceHeights);
        return true;
    }

    /// <summary>
    /// Capture/dev use — photographs the markers on a slope. Hovers the band tile whose corners
    /// differ most in height and returns its world centre; false on a flat board or flat bands.
    /// </summary>
    public bool HoverSteepestBandTile(out Vector3 world)
    {
        world = Vector3.Zero;
        var heights = SurfaceHeights;
        if (!heights.HasTerrain) return false;
        PF2e.Vector2Int? best = null;
        int bestSpan = 0;
        foreach (var (tile, _) in _lastBands)
        {
            int span = heights.Corners(tile).HeightSpan;
            if (span > bestSpan) { bestSpan = span; best = tile; }
        }
        if (best == null) return false;
        OnTileHovered(best);
        world = GridSpace.GridToWorld(best.Value, heights);
        return true;
    }

    /// <summary>Capture/dev use: end a <see cref="HoverBandTile"/> hover.</summary>
    public void ClearHover() => OnTileHovered(null);

    /// <summary>
    /// How many unit visuals the presenter holds. Equals the encounter's unit count while an
    /// encounter runs, and 0 between encounters — the reset spike asserts on it.
    /// </summary>
    public int RegisteredUnitCount => _presenter?.UnitCount ?? 0;

    /// <summary>The running encounter's session, or null between encounters. Spikes drive player
    /// turns through its <see cref="CombatSession.PlayerActions"/>.</summary>
    public CombatSession? Session => _session;

    /// <summary>Dev use: the running encounter's player-turn controller, as the menu drives it.</summary>
    public PlayerTurnController? Controller => _controller;

    /// <summary>Dev use: the command menu.</summary>
    public Ungilded.UI.ActionBar CommandBar => _actionBar;

    /// <summary>Dev use: a board click on a tile, through the same gate as the mouse.</summary>
    public void ClickTile(PF2e.Vector2Int tile) => HandleTacticalClick(tile);

    /// <summary>Dev use: hover a tile as if the mouse were there; null ends the hover.</summary>
    public void HoverTile(PF2e.Vector2Int? tile) => OnTileHovered(tile);

    /// <summary>Dev use: a tile's centre on screen, in HUD pixels, or null behind the camera.</summary>
    public Vector2? TileScreenPoint(PF2e.Vector2Int tile)
    {
        var world = GridSpace.GridToWorld(tile, SurfaceHeights);
        return _cameraRig.Camera.IsPositionBehind(world) ? null : _cameraRig.Camera.UnprojectPosition(world);
    }

    /// <summary>Dev use: the card that shows the hovered or targeted unit.</summary>
    public Ungilded.UI.UnitInspectPanel TargetCard => _targetCard;

    /// <summary>Dev use: the hero card, with the action squares and the reaction diamond.</summary>
    public Ungilded.UI.UnitInspectPanel InspectPanel => _inspectPanel;

    /// <summary>Dev use: the timeline.</summary>
    public Ungilded.UI.TurnOrderBar TurnBar => _turnBar;

    /// <summary>Dev use: how many gold tutorial tiles the board shows.</summary>
    public int GuideTileCount => _moveBands.GuideTileCount;

    /// <summary>Dev use: the combat log as plain text, one line per row.</summary>
    public string LogText => _log.HistoryText;
}
