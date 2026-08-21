using System.Collections.Generic;
using PF2e.Core;
using PF2e.Data;
using PF2e.Grid;
using PF2e.Utilities;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Combat;

/// <summary>
/// Terrain-driven cover, line of sight and line of effect over a populated <see cref="BattleGrid"/>.
/// Port of the Unity Tactics <c>CoverCalculator</c> (Assets/Scripts/Controllers/CoverCalculator.cs),
/// with its Unity dependencies replaced one-for-one:
/// <c>GameTileTracker.GameTileDictionary</c> → <see cref="BattleGrid.GetTile"/>,
/// <c>GameTile.OccupyingCharacter</c> → <see cref="BattleGrid.GetGroundOccupant"/>,
/// <c>CharacterGameData.AnchorTile/TileWidth/AltitudeInFeet</c> → <see cref="ICharacter"/>.
/// Plain C# — no Godot types — so the whole thing is exercisable headlessly.
///
/// <para><b>The model.</b> Everything is a height-interpolated 3D line between two grid centres,
/// walked tile by tile with Bresenham. Heights are FFT corner units (4 per elevation, 5 ft per
/// elevation). A creature's line height is its tile's surface height (<see cref="TileData.EffectiveHeight"/>,
/// the rounded centre of the four corners — Unity's <c>CellPositionZ</c> is computed exactly this way in
/// RuntimeMapBuilder) plus <see cref="CreatureEyeHeight"/>, plus its flight altitude converted to corner
/// units. An intervening tile only matters if its TALLEST corner reaches the interpolated line: terrain
/// more than one corner unit below the line is simply shot over, which is what lets a creature on a
/// plateau see and shoot past a low wall.</para>
///
/// <para><b>Two deliberate adaptations from the Unity source.</b></para>
/// <list type="number">
/// <item><description><b>Walls are real here.</b> Unity's <c>RuntimeMapBuilder</c> skipped
/// <c>TileRole.Wall</c> entirely (<c>if (role == Empty || role == Wall) continue;</c>), so generated
/// walls were absent from the tile dictionary and every trace walked straight through them — LOS, LOE
/// and cover alike. <see cref="PF2e.MapGen.MapLayoutGridBuilder"/> puts walls in the grid, which is the
/// whole point of this milestone; nothing else about the trace changes.</description></item>
/// <item><description><b>The solid-barrier predicate is <c>Inaccessible</c> alone</b>, not Unity's
/// <c>Inaccessible &amp;&amp; !ProvidesCover</c>. On Unity's own data the two are identical — no shipped
/// GameTileType asset sets both flags (Inaccesible.asset is Inaccessible/no cover; Cover.asset is
/// standable/cover). In this engine the grid builder marks a Wall <c>Inaccessible + ProvidesCover</c>
/// (a wall you cannot enter also shields what is behind it), so Unity's phrasing would have made every
/// wall transparent. <c>ProvidesCover</c> without <c>Inaccessible</c> is a standable Cover pillar: it
/// grants cover but you can see and shoot past it.</description></item>
/// </list>
///
/// <para>Unity's <c>CalculateCoverFromTile</c> — the same trace run from a prospective tile rather than
/// a real attacker — is deliberately NOT ported: it existed for GOAP cover-seeking sensors, and this
/// project's AI has none. It is a near-duplicate of <see cref="GetPositionalCover"/> with the attacker's
/// character swapped for an anchor + width, so it can be added when something asks for it.</para>
///
/// PF2e reference: https://2e.aonprd.com/Rules.aspx?ID=2372
/// </summary>
public sealed class TerrainSpatial
{
    /// <summary>
    /// Corner units above a tile's surface for a Medium creature's eye level. 3 corner units ≈ 3.75 ft
    /// — Unity's <c>CoverCalculator.CreatureEyeHeight</c>, carried over unchanged.
    /// </summary>
    public const int CreatureEyeHeight = 3;

    /// <summary>
    /// How far a walkable tile's top must rise ABOVE the line before it counts as natural cover (a ridge
    /// or cliff lip the shot grazes). Unity's literal 2f.
    /// </summary>
    private const float NaturalCoverMargin = 2f;

    /// <summary>
    /// Slack below the line within which terrain still counts as intervening. Unity's literal 1f: a tile
    /// whose top is more than one corner unit under the line is shot clean over.
    /// </summary>
    private const float BelowLineSlack = 1f;

    private readonly BattleGrid _grid;

    public TerrainSpatial(BattleGrid grid) => _grid = grid;

    /// <summary>
    /// Whether a grid has anything for a spatial trace to find: a blocking or cover-granting tile, or any
    /// variation in corner heights. False for <see cref="BattleGrid.CreateFlat"/> boards, on which every
    /// terrain branch below is unreachable — see <see cref="SpatialDelegates.Wire"/> for why that matters.
    /// </summary>
    public static bool HasSpatialFeatures(BattleGrid grid)
    {
        if (grid == null) return false;

        bool haveReference = false;
        int reference = 0;

        foreach (var tile in grid.AllTiles)
        {
            if (tile == null) continue;
            if (tile.Inaccessible || tile.ProvidesCover) return true;

            var c = tile.CornerHeights;
            if (!haveReference)
            {
                reference = c.NW;
                haveReference = true;
            }
            if (c.NW != reference || c.NE != reference || c.SE != reference || c.SW != reference)
                return true;
        }

        return false;
    }

    // ─────────────────────────────── Cover ───────────────────────────────

    /// <summary>
    /// Positional cover between attacker and defender. Geometry alone yields at most
    /// <see cref="CoverLevel.Standard"/> — matching Unity, and PF2e, where Greater cover comes from Take
    /// Cover behind an obstacle, which <see cref="CoverHelper.GetConditionCoverLevel"/> reads off the
    /// defender's conditions and combines with this result.
    /// </summary>
    public CoverLevel GetPositionalCover(ICharacter attacker, ICharacter defender)
    {
        if (_grid == null || attacker == null || defender == null)
            return CoverLevel.None;

        var attackerAnchor = attacker.GridPosition;
        var defenderAnchor = defender.GridPosition;

        var (startX, startY) = CentreTile(attackerAnchor, attacker.TileWidth);
        var (endX, endY) = CentreTile(defenderAnchor, defender.TileWidth);

        int sourceHeight = CharacterLineHeight(attacker);
        int targetHeight = CharacterLineHeight(defender);

        CreatureSize attackerSize = attacker.StatProvider?.Size ?? CreatureSize.Medium;
        CreatureSize defenderSize = defender.StatProvider?.Size ?? CreatureSize.Medium;

        var attackerTiles = OccupiedSet(attackerAnchor, attacker.TileWidth);
        var defenderTiles = OccupiedSet(defenderAnchor, defender.TileWidth);

        var result = CoverLevel.None;

        foreach (var pos in GetInterveningTiles(startX, startY, endX, endY))
        {
            if (attackerTiles.Contains(pos) || defenderTiles.Contains(pos))
                continue;

            var tile = _grid.GetTile(pos);
            if (tile == null) continue; // a hole in the board — nothing to hide behind

            int tileMaxH = tile.CornerHeights.MaxHeight;
            float lineH = InterpolateLineHeight(sourceHeight, targetHeight, startX, startY, endX, endY, pos.x, pos.y);

            if (tileMaxH < lineH - BelowLineSlack)
            {
                // The shot passes over this tile, but a creature standing on it may still be tall
                // enough to get in the way.
                if (tileMaxH + CreatureEyeHeight >= lineH)
                {
                    var blocker = LivingBlocker(pos, attacker, defender);
                    if (blocker != null)
                        result = Higher(result, CreatureCover(blocker, attackerSize, defenderSize));
                }
                continue;
            }

            // Wall or cover pillar at/above the line: standard cover, the most geometry can grant.
            if (tile.Inaccessible || tile.ProvidesCover || tile.DynamicBlocked)
                return CoverLevel.Standard;

            // Walkable ground that rises well above the line — a ridge or cliff lip.
            if (tileMaxH > lineH + NaturalCoverMargin)
            {
                result = Higher(result, CoverLevel.Standard);
                continue;
            }

            var occupant = LivingBlocker(pos, attacker, defender);
            if (occupant != null)
                result = Higher(result, CreatureCover(occupant, attackerSize, defenderSize));
        }

        return result;
    }

    /// <summary>
    /// Whether the character stands next to a tile that provides cover, which is what lets Take Cover
    /// upgrade to Greater cover (<see cref="PF2e.Actions.TakeCoverAction"/>). Cardinal neighbours of every
    /// tile in the creature's footprint, exactly as Unity checked them.
    /// </summary>
    public bool IsAdjacentToTerrainCover(ICharacter character)
    {
        if (_grid == null || character == null) return false;

        var occupied = CreatureSizeHelper.GetOccupiedTiles(character.GridPosition, character.TileWidth);
        var occupiedSet = new HashSet<PF2eVec>(occupied);

        foreach (var from in occupied)
        {
            foreach (var offset in Cardinals)
            {
                var neighbour = from + offset;
                if (occupiedSet.Contains(neighbour)) continue;

                var tile = _grid.GetTile(neighbour);
                if (tile != null && (tile.ProvidesCover || tile.Inaccessible))
                    return true;
            }
        }

        return false;
    }

    // ──────────────────────── Line of sight / effect ────────────────────────

    /// <summary>
    /// Whether the attacker can see the defender. Blocked by a solid barrier at or above the sight line,
    /// or by walkable ground standing a full elevation over it (a cliff shoulder). A standable
    /// cover-granting tile does NOT block sight — you can see past a pillar, you just take a penalty.
    /// </summary>
    public bool HasLineOfSight(ICharacter attacker, ICharacter defender)
    {
        if (_grid == null || attacker == null || defender == null)
            return true; // no data — default to visible, as Unity did

        var attackerAnchor = attacker.GridPosition;
        var defenderAnchor = defender.GridPosition;

        var (startX, startY) = CentreTile(attackerAnchor, attacker.TileWidth);
        var (endX, endY) = CentreTile(defenderAnchor, defender.TileWidth);

        return Trace(
            startX, startY, endX, endY,
            CharacterLineHeight(attacker), CharacterLineHeight(defender),
            OccupiedSet(attackerAnchor, attacker.TileWidth),
            OccupiedSet(defenderAnchor, defender.TileWidth),
            terrainMargin: TileCornerHeights.UnitsPerElevation);
    }

    /// <summary>
    /// Whether an effect can reach from one tile to another — the PF2e rule behind
    /// "an area effect doesn't affect targets behind a solid barrier". Stricter than sight: any terrain
    /// standing more than <see cref="NaturalCoverMargin"/> over the line stops the effect, not just a
    /// full elevation of it. Heights are tile surfaces plus the standard eye offset (Unity's
    /// <c>CheckLineOfEffect</c>), so an area traced across a board behaves like a shot from a standing
    /// creature rather than one fired along the dirt.
    /// </summary>
    public bool HasLineOfEffect(PF2eVec from, PF2eVec to)
    {
        if (_grid == null) return true;

        return Trace(
            from.x, from.y, to.x, to.y,
            TileSurfaceHeight(from) + CreatureEyeHeight,
            TileSurfaceHeight(to) + CreatureEyeHeight,
            excludeStart: null, excludeEnd: null,
            terrainMargin: NaturalCoverMargin);
    }

    /// <summary>
    /// The shared trace behind both LOS and LOE; they differ only in how far walkable terrain must rise
    /// above the line before it stops the trace (<paramref name="terrainMargin"/>).
    /// </summary>
    private bool Trace(
        int x0, int y0, int x1, int y1,
        int sourceHeight, int targetHeight,
        HashSet<PF2eVec>? excludeStart, HashSet<PF2eVec>? excludeEnd,
        float terrainMargin)
    {
        foreach (var pos in GetInterveningTiles(x0, y0, x1, y1))
        {
            if (excludeStart != null && excludeStart.Contains(pos)) continue;
            if (excludeEnd != null && excludeEnd.Contains(pos)) continue;

            var tile = _grid.GetTile(pos);
            if (tile == null) continue; // hole in the board: nothing to block against

            // Zone blocking (Wall of Force and friends). Read off the tile rather than through
            // TileEffectRules so the trace can't be answered by a stale global from another encounter —
            // BattleGrid.WireDelegates points that delegate straight back at this same field.
            if (tile.DynamicBlocked) return false;

            int tileMaxH = tile.CornerHeights.MaxHeight;
            float lineH = InterpolateLineHeight(sourceHeight, targetHeight, x0, y0, x1, y1, pos.x, pos.y);

            if (tileMaxH < lineH - BelowLineSlack)
                continue;

            if (tile.Inaccessible) return false;

            if (tileMaxH > lineH + terrainMargin) return false;
        }

        return true;
    }

    // ─────────────────────────────── Heights ───────────────────────────────

    /// <summary>
    /// A tile's walking surface in corner units — the rounded centre of its four corners. Identical to
    /// Unity's <c>GameTile.CellPositionZ</c>, which RuntimeMapBuilder set from
    /// <c>RoundToInt(corners.CenterHeight)</c>. Missing tiles read 0.
    /// </summary>
    private int TileSurfaceHeight(PF2eVec pos) => _grid.GetTile(pos)?.EffectiveHeight ?? 0;

    /// <summary>
    /// A creature's eye height for the trace: its tile's surface, plus flight altitude converted from
    /// feet to corner units, plus the Medium eye offset.
    /// </summary>
    private int CharacterLineHeight(ICharacter character)
    {
        int altitudeUnits = character.AltitudeFeet
            * TileCornerHeights.UnitsPerElevation / TileCornerHeights.FeetPerElevation;
        return TileSurfaceHeight(character.GridPosition) + altitudeUnits + CreatureEyeHeight;
    }

    /// <summary>
    /// Expected line height over a tile, interpolated on Chebyshev distance (max of dx, dy) so the
    /// parameter advances one step per Bresenham tile.
    /// </summary>
    private static float InterpolateLineHeight(
        int sourceHeight, int targetHeight,
        int startX, int startY, int endX, int endY, int tileX, int tileY)
    {
        float totalDist = System.Math.Max(System.Math.Abs(endX - startX), System.Math.Abs(endY - startY));
        if (totalDist < 1f) return sourceHeight;

        float tileDist = System.Math.Max(System.Math.Abs(tileX - startX), System.Math.Abs(tileY - startY));
        float t = tileDist / totalDist;
        return sourceHeight + (targetHeight - sourceHeight) * t;
    }

    // ─────────────────────────────── Helpers ───────────────────────────────

    private static readonly PF2eVec[] Cardinals =
    {
        PF2eVec.up, PF2eVec.down, PF2eVec.left, PF2eVec.right,
    };

    /// <summary>The tile a creature's footprint centre rounds to — the trace endpoint.</summary>
    private static (int x, int y) CentreTile(PF2eVec anchor, int tileWidth)
    {
        var centre = CreatureSizeHelper.GetSpaceCenter(anchor, tileWidth);
        return ((int)System.Math.Floor(centre.x + 0.5f), (int)System.Math.Floor(centre.y + 0.5f));
    }

    private static HashSet<PF2eVec> OccupiedSet(PF2eVec anchor, int tileWidth)
        => new(CreatureSizeHelper.GetOccupiedTiles(anchor, tileWidth));

    /// <summary>
    /// The living creature standing on a tile, if it is someone other than the two combatants.
    /// Ground occupancy only: a flyer is registered by (tile, altitude) and its altitude is not knowable
    /// from a tile alone, so airborne creatures do not grant cover to those beneath them.
    /// </summary>
    private ICharacter? LivingBlocker(PF2eVec pos, ICharacter attacker, ICharacter defender)
    {
        var occupant = _grid.GetGroundOccupant(pos);
        if (occupant == null || occupant == attacker || occupant == defender) return null;
        if (occupant.Health != null && !occupant.Health.IsAlive) return null;
        return occupant;
    }

    /// <summary>
    /// PF2e: an intervening creature grants lesser cover, unless it is two or more sizes larger than
    /// both the attacker and the target, in which case it grants standard cover.
    /// </summary>
    private static CoverLevel CreatureCover(ICharacter blocker, CreatureSize attackerSize, CreatureSize defenderSize)
    {
        CreatureSize blockerSize = blocker.StatProvider?.Size ?? CreatureSize.Medium;
        return (int)blockerSize - (int)attackerSize >= 2 && (int)blockerSize - (int)defenderSize >= 2
            ? CoverLevel.Standard
            : CoverLevel.Lesser;
    }

    private static CoverLevel Higher(CoverLevel a, CoverLevel b) => b > a ? b : a;

    /// <summary>
    /// Bresenham walk between two tiles, EXCLUDING both endpoints. Same tile or adjacent tiles (Chebyshev
    /// distance ≤ 1) have nothing in between, so nothing can block them — which is what makes
    /// "adjacent tiles always have line of effect" true by construction.
    /// </summary>
    internal static List<PF2eVec> GetInterveningTiles(int x0, int y0, int x1, int y1)
    {
        var result = new List<PF2eVec>();

        int dx = System.Math.Abs(x1 - x0);
        int dy = System.Math.Abs(y1 - y0);
        if (dx <= 1 && dy <= 1) return result;

        int sx = x0 < x1 ? 1 : -1;
        int sy = y0 < y1 ? 1 : -1;
        int err = dx - dy;

        int x = x0;
        int y = y0;

        while (x != x1 || y != y1)
        {
            int e2 = 2 * err;
            if (e2 > -dy)
            {
                err -= dy;
                x += sx;
            }
            if (e2 < dx)
            {
                err += dx;
                y += sy;
            }

            if (x != x1 || y != y1)
                result.Add(new PF2eVec(x, y));
        }

        return result;
    }
}
