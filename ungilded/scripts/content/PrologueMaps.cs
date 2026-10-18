using System.Collections.Generic;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Content;

/// <summary>
/// The four authored Prologue battle maps (spec sections 3 and 8), biome "sewer". The combat
/// camera opens from the high-x, high-y corner, so the party stands on the east side (high x,
/// near the camera) and the enemies face it from the west (low x, far side). Every call builds a
/// fresh layout.
///
///   E1  6x6   walkway, water channel on row 0. One Sewer Rat 3 tiles from the Player.
///   E2  8x8   walkway, water channel on row 0. Two Sewer Rats 3 and 4 tiles away.
///   E3 10x10  open chamber, two 2x2 pillars. Rats 1 and 2 forward, Rats 3 and 4 beside the north
///             pillar (Rat 4 is the Vicious Sewer Rat), Rat 5 at the back.
///   E4 12x12  chamber, sludge band on columns 5 to 7, two 2x2 pillars, a Dire Sewer Rat before
///             each pillar, the Sewer Tyrant centred behind them in front of the far wall.
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

    /// <summary>"rat_1" .. "rat_5".</summary>
    public static string RatAnchorN(int n) => $"rat_{n}";

    /// <summary>The Encounter 1 rat's max HP: two Player hits (spec section 3).</summary>
    public const int Encounter1RatHp = 18;

    public static PrologueBattle Encounter(int number) => number switch
    {
        1 => Encounter1(),
        2 => Encounter2(),
        3 => Encounter3(),
        4 => Encounter4(),
        _ => throw new System.ArgumentOutOfRangeException(nameof(number), number, "The Prologue has encounters 1 to 4."),
    };

    public static PrologueBattle Encounter1() => new()
    {
        Id = "prologue_e1",
        Layout = new SewerBoard("Sewer_prologue_e1", 6, 6, seed: 61001).Channel(0, 0, 5, 0).Finish(),
        Anchors = new Dictionary<string, PF2eVec>
        {
            [PrologueBattle.PlayerAnchor] = new(4, 3),
            [PrologueBattle.FriendAnchor] = new(5, 3),
            [RatAnchor] = new(1, 3),
            // One tile further from the Player once the Player stands next to the rat.
            [RatFleeMark] = new(0, 3),
        },
        Enemies = new[] { new PrologueSpawn(RatAnchor, PrologueBestiary.SewerRatId, Encounter1RatHp) },
    };

    public static PrologueBattle Encounter2() => new()
    {
        Id = "prologue_e2",
        Layout = new SewerBoard("Sewer_prologue_e2", 8, 8, seed: 61002).Channel(0, 0, 7, 0).Finish(),
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

    /// <summary>Rat 3 has a clear line from the Friend. Rat 4 is adjacent to Rat 3 and to no other
    /// rat, so an acid flask on Rat 3 splashes Rat 4 only.</summary>
    public static PrologueBattle Encounter3() => new()
    {
        Id = "prologue_e3",
        Layout = new SewerBoard("Sewer_prologue_e3", 10, 10, seed: 61003)
            .Pillar(3, 1, 4, 2)
            .Pillar(3, 7, 4, 8)
            .Finish(),
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
            new PrologueSpawn(RatAnchorN(1), PrologueBestiary.SewerRatId),
            new PrologueSpawn(RatAnchorN(2), PrologueBestiary.SewerRatId),
            new PrologueSpawn(RatAnchorN(3), PrologueBestiary.SewerRatId),
            new PrologueSpawn(RatAnchorN(4), PrologueBestiary.ViciousSewerRatId),
            new PrologueSpawn(RatAnchorN(5), PrologueBestiary.SewerRatId),
        },
    };

    public static PrologueBattle Encounter4() => new()
    {
        Id = "prologue_e4",
        Layout = new SewerBoard("Sewer_prologue_e4", 12, 12, seed: 61004)
            .Sludge(5, 0, 7, 11)
            .Pillar(2, 2, 3, 3)
            .Pillar(2, 8, 3, 9)
            .Finish(),
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
