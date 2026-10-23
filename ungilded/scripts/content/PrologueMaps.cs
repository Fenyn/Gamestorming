using System.Collections.Generic;
using Ungilded.Terrain;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Content;

/// <summary>
/// The four authored Prologue battle maps (spec sections 3 and 8), biome "sewer". Each is a board
/// plus an authored halo (<see cref="SewerBoard.Halo"/>): every halo tile is wall unless the map
/// opens it. The combat camera opens from the high-x, high-y corner, so the party stands on the
/// east side (high x, near the camera) and the enemies face it from the west (low x, far side).
/// Channels sit a quarter metre below the floor. Every call builds a fresh layout.
///
///   E1  8x5   a stretch of ribbed barrel tunnel: walkway beside a channel, a ledge and wall beyond
///             it. Every third tile a pier stands on the ledge, with niches in the north wall
///             between the ribs. The tunnel runs on west (ahead) and east (the way in). One Sewer
///             Rat 3 tiles from the Player.
///   E2  8x8   a junction further along: the same ribbed tunnel, the chamber widened north with a
///             niche, side passages north and south, a footbridge in the west tunnel, outfall
///             pipes. Two Sewer Rats 3 and 4 tiles away.
///   E3 10x10  an octagonal junction cistern with two 2x2 pillars and a passage in the middle of
///             each side. A drain sump on the south edge empties through an arched culvert. The
///             narrow east passage behind the party is the way in and holds the skeleton. Rats 1
///             and 2 forward, Rats 3 and 4
///             beside the pillar on rows 1 and 2 (Rat 4 is the Vicious Sewer Rat), Rat 5 at the back.
///   E4 12x12  a vaulted hall running east to west: buttress piers along both long walls with a bay
///             between them on the east side only, solid wall behind the pillars, the sludge band
///             on columns 5 to 7 leaving through arched culverts north and south, a neck where the climbing entry passage comes in from the east, and a
///             stepped apse at the west end whose back wall carries the sigil. Two 2x2 pillars, a
///             Dire Sewer Rat before each, the Sewer Tyrant centred behind them before the apse.
/// </summary>
public static class PrologueMaps
{
    public const string RatAnchor = "rat";
    public const string RatFleeMark = "rat_flee";
    public const string PlayerFlankRat1Mark = "player_flank_rat_1";
    public const string FriendFlankRat1Mark = "friend_flank_rat_1";
    public const string TyrantAnchor = "tyrant";
    public const string DireRatNorthAnchor = "dire_rat_north";
    public const string DireRatSouthAnchor = "dire_rat_south";

    private const string OutfallMark = SewerBoard.OutfallMark;
    private const string SkeletonMark = SewerBoard.SkeletonMark;

    /// <summary>"rat_1" .. "rat_5".</summary>
    public static string RatAnchorN(int n) => $"rat_{n}";

    /// <summary>The Encounter 1 rat's max HP: two Player hits (spec section 3).</summary>
    public const int Encounter1RatHp = 18;

    /// <summary>Encounter 3 Rat 1's max HP: the Player's two round 1 hits (1d8+4, dice forced to 6
    /// and 1) leave it at 50% and then 25%, as the PDF roll table has it.</summary>
    public const int Encounter3Rat1Hp = 20;

    /// <summary>Halo coordinate past the rim, for runs painted along a whole side.</summary>
    private const int Rim = HaloPlan.Reach;

    public static PrologueBattle Encounter(int number) => number switch
    {
        1 => Encounter1(),
        2 => Encounter2(),
        3 => Encounter3(),
        4 => Encounter4(),
        _ => throw new System.ArgumentOutOfRangeException(nameof(number), number, "The Prologue has encounters 1 to 4."),
    };

    /// <summary>Tunnel rhythm: a rib every <see cref="RibPeriod"/> tiles along x, at the columns
    /// <see cref="RibPhase"/> apart from a multiple of the period.</summary>
    private const int RibPeriod = 3;
    private const int RibPhase = 1;

    private static bool IsRib(int x) => ((x - RibPhase) % RibPeriod + RibPeriod) % RibPeriod == 0;

    /// <summary>Ribs the tunnel walls between <paramref name="from"/> and <paramref name="to"/>
    /// (where <paramref name="here"/> allows): a pier on the ledge row at each rib, a niche in the
    /// facing wall row between ribs.</summary>
    private static SewerBoard Ribbed(SewerBoard board, int ledgeY, int nicheY, int from, int to, System.Func<int, bool> here)
    {
        for (int x = from; x <= to; x++)
        {
            if (!here(x)) continue;
            if (IsRib(x)) board.HaloWall(x, ledgeY, x, ledgeY);
            else board.HaloFloor(x, nicheY, x, nicheY);
        }
        return board;
    }

    public static PrologueBattle Encounter1()
    {
        var board = new SewerBoard("Sewer_prologue_e1", 8, 5, seed: 61001)
            .Flow(BoardSide.West)
            .Channel(0, 0, 7, 0)
            .HaloFloor(-Rim, -1, 7 + Rim, -1)
            .Run(BoardSide.West, 0, 4)
            .Run(BoardSide.East, 0, 4)
            .Mark(OutfallMark, 3, -2);
        Ribbed(board, ledgeY: -1, nicheY: 5, -Rim, 7 + Rim, _ => true);
        return new()
        {
            Id = "prologue_e1",
            Layout = board.Finish(),
            Halo = board.Halo,
            Anchors = new Dictionary<string, PF2eVec>
            {
                [PrologueBattle.PlayerAnchor] = new(5, 2),
                [PrologueBattle.FriendAnchor] = new(6, 2),
                [RatAnchor] = new(2, 2),
                // One tile further from the Player once the Player stands next to the rat.
                [RatFleeMark] = new(1, 2),
            },
            Enemies = new[] { new PrologueSpawn(RatAnchor, PrologueBestiary.SewerRatId, Encounter1RatHp) },
        };
    }

    public static PrologueBattle Encounter2()
    {
        var board = new SewerBoard("Sewer_prologue_e2", 8, 8, seed: 61002)
            .Flow(BoardSide.West)
            .Channel(0, 1, 7, 1)
            .Wall(0, 7, 0, 7)
            .Wall(7, 7, 7, 7)
            .Run(BoardSide.West, 0, 5)
            .Run(BoardSide.East, 0, 5)
            .Run(BoardSide.North, 2, 3)
            .Run(BoardSide.South, 5, 6)
            .HaloFloor(5, 8, 6, 8)
            .HaloBridge(-1, 1, -1, 1)
            .Mark(OutfallMark, 2, -1)
            .Mark(OutfallMark, 9, -1);
        Ribbed(board, ledgeY: 0, nicheY: 6, -Rim, 7 + Rim, x => x < 0 || x > 7);
        return new()
        {
            Id = "prologue_e2",
            Layout = board.Finish(),
            Halo = board.Halo,
            Anchors = new Dictionary<string, PF2eVec>
            {
                [PrologueBattle.PlayerAnchor] = new(6, 4),
                [PrologueBattle.FriendAnchor] = new(7, 4),
                [RatAnchorN(1)] = new(3, 4),
                [RatAnchorN(2)] = new(2, 5),
            },
            Enemies = new[]
            {
                new PrologueSpawn(RatAnchorN(1), PrologueBestiary.SewerRatId),
                new PrologueSpawn(RatAnchorN(2), PrologueBestiary.SewerRatId),
            },
        };
    }

    /// <summary>Rat 3 has a clear line from the Friend. Rat 4 is adjacent to Rat 3 and to no other
    /// rat, so an acid flask on Rat 3 splashes Rat 4 only.</summary>
    public static PrologueBattle Encounter3()
    {
        var board = new SewerBoard("Sewer_prologue_e3", 10, 10, seed: 61003)
            .Flow(BoardSide.South)
            .Pillar(3, 1, 4, 2)
            .Pillar(3, 7, 4, 8)
            .Chamfer(3)
            .Channel(5, 0, 6, 1)
            .Run(BoardSide.East, 4, 5)
            .Run(BoardSide.West, 4, 5)
            .Run(BoardSide.North, 5, 6)
            .Run(BoardSide.South, 5, 6)
            .Mark(SkeletonMark, 11, 5);
        return new()
        {
            Id = "prologue_e3",
            Layout = board.Finish(),
            Halo = board.Halo,
            Anchors = new Dictionary<string, PF2eVec>
            {
                [PrologueBattle.PlayerAnchor] = new(8, 4),
                [PrologueBattle.FriendAnchor] = new(8, 5),
                [RatAnchorN(1)] = new(5, 4),
                [RatAnchorN(2)] = new(4, 5),
                [RatAnchorN(3)] = new(2, 3),
                [RatAnchorN(4)] = new(2, 2),
                [RatAnchorN(5)] = new(0, 6),
                [PlayerFlankRat1Mark] = new(6, 4),
                [FriendFlankRat1Mark] = new(4, 4),
            },
            Enemies = new[]
            {
                new PrologueSpawn(RatAnchorN(1), PrologueBestiary.SewerRatId, Encounter3Rat1Hp),
                new PrologueSpawn(RatAnchorN(2), PrologueBestiary.SewerRatId),
                new PrologueSpawn(RatAnchorN(3), PrologueBestiary.SewerRatId),
                new PrologueSpawn(RatAnchorN(4), PrologueBestiary.ViciousSewerRatId),
                new PrologueSpawn(RatAnchorN(5), PrologueBestiary.SewerRatId),
            },
        };
    }

    public static PrologueBattle Encounter4()
    {
        var board = new SewerBoard("Sewer_prologue_e4", 12, 12, seed: 61004)
            .Flow(BoardSide.South)
            .Sludge(5, 0, 7, 11)
            .Pillar(2, 2, 3, 3)
            .Pillar(2, 8, 3, 9)
            .Wall(0, 0, 4, 1).Wall(8, 0, 8, 1).Wall(11, 0, 11, 1)
            .Wall(0, 10, 4, 11).Wall(8, 10, 8, 11).Wall(11, 10, 11, 11)
            .Wall(0, 2, 0, 2).Wall(0, 9, 0, 9)
            .Wall(11, 2, 11, 3).Wall(11, 7, 11, 9)
            .HaloFloor(-1, 3, -1, 7, floor: 2)
            .HaloFloor(-2, 3, -2, 7, floor: 4)
            .Run(BoardSide.South, 5, 7)
            .Run(BoardSide.North, 5, 7)
            .Run(BoardSide.East, 4, 6, rise: 1)
            .Mark(OutfallMark, 10, -1)
            .Mark(OutfallMark, 9, 12);
        return new()
        {
            Id = "prologue_e4",
            Layout = board.Finish(),
            Halo = board.Halo,
            Anchors = new Dictionary<string, PF2eVec>
            {
                [PrologueBattle.PlayerAnchor] = new(10, 5),
                [PrologueBattle.FriendAnchor] = new(11, 5),
                [DireRatNorthAnchor] = new(4, 3),
                [DireRatSouthAnchor] = new(4, 8),
                [TyrantAnchor] = new(1, 5),
            },
            Enemies = new[]
            {
                new PrologueSpawn(TyrantAnchor, PrologueBestiary.SewerTyrantId),
                new PrologueSpawn(DireRatNorthAnchor, PrologueBestiary.DireSewerRatId),
                new PrologueSpawn(DireRatSouthAnchor, PrologueBestiary.DireSewerRatId),
            },
        };
    }
}
