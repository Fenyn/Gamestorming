using System;
using System.Collections.Generic;
using System.Linq;
using Godot;
using PF2e.Grid;
using PF2e.MapGen;
using Ungilded.Combat;
using Ungilded.Content;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Dev;

/// <summary>The four authored maps: size, walls, pillars, channels, sludge, anchors, reach, and the
/// tiles the encounter scripts depend on.</summary>
public partial class PrologueContentSpike
{
    private static readonly (int W, int H, int Pillars, int Outline, int Sludge)[] Expected =
    {
        (8, 5, 0, 0, 0), (8, 8, 0, 2, 0), (10, 10, 8, 24, 0), (12, 12, 8, 35, 36),
    };

    private void CheckMap(int number)
    {
        var battle = PrologueMaps.Encounter(number);
        var layout = battle.Layout;
        var grid = MapLayoutGridBuilder.Build(layout);
        var expect = Expected[number - 1];
        string tag = $"E{number}";

        Check($"{tag} is {expect.W}x{expect.H} sewer", layout.Width == expect.W && layout.Height == expect.H && battle.BiomeId == "sewer");

        var walls = Tiles(layout, TileRole.Wall);
        int pillarTop = SewerBoard.PillarHeightUnits;
        int wallTop = PF2e.MapGen.Biomes.MapGenRegistry.GetBiome("sewer").WallHeight;
        var pillars = walls.Where(p => layout.GetCornerHeights(p.x, p.y).MaxHeight == pillarTop).ToList();
        var outline = walls.Where(p => layout.GetCornerHeights(p.x, p.y).MaxHeight == wallTop).ToList();
        Check($"{tag} has {expect.Pillars} pillar tiles and {expect.Outline} outline wall tiles ({outline.Count}), each blocking movement",
            pillars.Count == expect.Pillars && outline.Count == expect.Outline && pillars.Count + outline.Count == walls.Count
            && walls.All(p => grid.GetTile(p)?.IsBlocked == true));
        // Low enough to see a rat over from the camera, above a creature's eye line.
        Check($"{tag} pillars are {pillarTop} units tall, above eye height, and still give cover",
            pillars.All(p => grid.GetTile(p) is { ProvidesCover: true } t && t.CornerHeights.MaxHeight == pillarTop
                && pillarTop > TerrainSpatial.CreatureEyeHeight + 1));
        var water = Tiles(layout, TileRole.Water);
        Check($"{tag} channels sit {SewerBoard.ChannelRecessUnits} units below the floor and stay one step from it",
            water.All(p => layout.GetCornerHeights(p.x, p.y).MaxHeight == -SewerBoard.ChannelRecessUnits)
            && water.All(p => !NeighbourBlocked(grid, p)));
        Check($"{tag} halo is authored and leaves the board alone",
            battle.Halo != null && battle.Halo.Cells.Keys.All(c => !layout.IsInBounds(c.X, c.Y)));

        var sludge = Tiles(layout, TileRole.DifficultTerrain);
        Check($"{tag} has {expect.Sludge} sludge tiles and each costs 2", sludge.Count == expect.Sludge
            && sludge.All(p => grid.GetTile(p)?.EffectiveMovementCost == 2 && layout.GetSurface(p.x, p.y) == SurfaceType.Mud));

        bool standable = battle.Anchors.Values.All(p => layout.GetTile(p.x, p.y) is TileRole.Ground or TileRole.DifficultTerrain
            && grid.GetTile(p) is { IsBlocked: false, Water: false });
        Check($"{tag} anchors are standable ({battle.Anchors.Count})", standable);
        Check($"{tag} enemy anchors are distinct and named",
            battle.Enemies.Select(e => battle.Anchor(e.Anchor)).Distinct().Count() == battle.Enemies.Count);

        var from = battle.Anchor(PrologueBattle.PlayerAnchor);
        var reach = Pathfinder.FindReachableTiles(grid, new PathfindingRequest
        {
            Origin = from, MaxDistance = 400, TileWidth = 1, OriginTeamId = 1, BypassOpposingUnits = true,
        });
        Check($"{tag} every enemy is reachable from the Player",
            battle.Enemies.All(e => reach.ContainsKey(battle.Anchor(e.Anchor))));
        Check($"{tag} the Friend is reachable from the Player", reach.ContainsKey(battle.Anchor(PrologueBattle.FriendAnchor)));

        if (number == 4)
        {
            var tyrant = battle.Anchor(PrologueMaps.TyrantAnchor);
            int straight = Math.Max(Math.Abs(tyrant.x - from.x), Math.Abs(tyrant.y - from.y));
            int cost = reach[tyrant].Cost;
            Check($"E4 crossing the sludge costs extra movement (cost {cost}, distance {straight})", cost >= straight + 3);
            int width = PrologueBestiary.Create(PrologueBestiary.SewerTyrantId).TileWidth;
            var space = PF2e.Utilities.CreatureSizeHelper.GetOccupiedTiles(tyrant, width);
            Check($"E4 the Tyrant's {width}x{width} space at ({tyrant.x},{tyrant.y}) is walkable floor",
                width == 2 && space.All(p => layout.GetTile(p.x, p.y) == TileRole.Ground
                    && grid.GetTile(p) is { IsBlocked: false, Water: false }) && grid.CanCreatureFit(tyrant, width));
            Check("E4 no other anchor lies in the Tyrant's space", battle.Anchors
                .Where(a => a.Key != PrologueMaps.TyrantAnchor).All(a => !space.Contains(a.Value)));
        }
        if (number == 1)
        {
            var rat = battle.Anchor(PrologueMaps.RatAnchor);
            Check("E1 rat stands 3 tiles from the Player", Math.Abs(rat.x - from.x) == 3 && rat.y == from.y);
        }
        if (number == 3) CheckEncounter3Tiles(battle, grid);

        var setup = battle.BuildSetup();
        var corrections = setup.Normalize();
        Check($"{tag} setup needs no placement corrections", corrections.Count == 0);
        foreach (var line in corrections) GD.Print($"[Prologue]   {line}");
    }

    /// <summary>The pillar on rows 1 and 2 blocks a line and gives cover, the flask splash and the
    /// flank marks hold, and every tile the Encounter 3 script moves a unit to is open floor.</summary>
    private void CheckEncounter3Tiles(PrologueBattle battle, BattleGrid grid)
    {
        var spatial = new TerrainSpatial(grid);
        var beside = PrologueBestiary.Create(PrologueBestiary.SewerRatId);
        beside.GridPosition = new PF2eVec(2, 2);
        Check("E3 a low pillar still blocks line of effect and gives cover",
            !spatial.HasLineOfEffect(new PF2eVec(6, 2), new PF2eVec(1, 2))
            && spatial.HasLineOfEffect(new PF2eVec(6, 4), new PF2eVec(1, 4))
            && spatial.IsAdjacentToTerrainCover(beside));
        var rat3 = battle.Anchor(PrologueMaps.RatAnchorN(3));
        var nextToRat3 = Enumerable.Range(1, 5).Where(n => n != 3)
            .Where(n => Chebyshev(battle.Anchor(PrologueMaps.RatAnchorN(n)), rat3) == 1).ToList();
        Check("E3 an acid flask on Rat 3 splashes Rat 4 only", nextToRat3.SequenceEqual(new[] { 4 }));
        var rat1 = battle.Anchor(PrologueMaps.RatAnchorN(1));
        var p = battle.Anchor(PrologueMaps.PlayerFlankRat1Mark);
        var f = battle.Anchor(PrologueMaps.FriendFlankRat1Mark);
        Check("E3 the two flank marks sit on opposite sides of Rat 1",
            p.x + f.x == 2 * rat1.x && p.y + f.y == 2 * rat1.y && Chebyshev(p, rat1) == 1);
        // Rat 3's step, Rat 4's approach, Rat 5's two strides, Rat 2's approach and the Friend's
        // flank behind it, and the flank tiles around Rat 5 in round 3.
        var scripted = new[] { (2, 4), (3, 3), (1, 6), (2, 5), (5, 5), (4, 6), (3, 5), (1, 5), (2, 6) };
        Check("E3 every scripted tile is open floor",
            scripted.All(t => grid.GetTile(new PF2eVec(t.Item1, t.Item2)) is { IsBlocked: false, Water: false }));
    }

    private static int Chebyshev(PF2eVec a, PF2eVec b) => Math.Max(Math.Abs(a.x - b.x), Math.Abs(a.y - b.y));

    /// <summary>True when an open neighbour of a channel tile is more than a stride's step away.</summary>
    private static bool NeighbourBlocked(BattleGrid grid, PF2eVec p) =>
        new[] { new PF2eVec(p.x + 1, p.y), new PF2eVec(p.x - 1, p.y), new PF2eVec(p.x, p.y + 1), new PF2eVec(p.x, p.y - 1) }
            .Any(n => grid.GetTile(n) is { IsBlocked: false } && (!grid.CanTraverseEdge(p, n, 1) || !grid.CanTraverseEdge(n, p, 1)));

    private static List<PF2eVec> Tiles(MapLayout layout, TileRole role)
    {
        var tiles = new List<PF2eVec>();
        for (int y = 0; y < layout.Height; y++)
            for (int x = 0; x < layout.Width; x++)
                if (layout.GetTile(x, y) == role) tiles.Add(new PF2eVec(x, y));
        return tiles;
    }
}
