using System;
using System.Collections.Generic;
using PF2e.Core;
using PF2e.MapGen;
using Ungilded.Combat;
using Ungilded.Terrain;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Content;

/// <summary>One enemy of an authored battle: the anchor it stands on, its bestiary id, and an
/// optional max HP that replaces the stat block's.</summary>
public sealed record PrologueSpawn(string Anchor, string CreatureId, int? MaxHp = null);

/// <summary>
/// One authored Prologue battle map: the layout, every named tile (party anchors, enemy anchors,
/// script marks such as flank tiles) and the enemy list. <see cref="ToSetup"/> turns it into a
/// <see cref="CombatSetup"/>. Plain data, no Godot types.
/// </summary>
public sealed record PrologueBattle
{
    public const string PlayerAnchor = "player";
    public const string FriendAnchor = "friend";

    public required string Id { get; init; }
    public required MapLayout Layout { get; init; }

    /// <summary>The authored halo around <see cref="Layout"/>, or null for a synthesized one.</summary>
    public HaloPlan? Halo { get; init; }

    public string BiomeId { get; init; } = SewerBoard.BiomeId;
    public required IReadOnlyDictionary<string, PF2eVec> Anchors { get; init; }
    public required IReadOnlyList<PrologueSpawn> Enemies { get; init; }

    public int Width => Layout.Width;
    public int Height => Layout.Height;

    public PF2eVec Anchor(string name) => Anchors.TryGetValue(name, out var tile) ? tile
        : throw new KeyNotFoundException($"[PrologueBattle] {Id} has no anchor '{name}'.");

    /// <summary>Fresh enemies in <see cref="Enemies"/> order.</summary>
    public List<PF2eCharacter> CreateEnemies(int teamId = 2)
    {
        var enemies = new List<PF2eCharacter>(Enemies.Count);
        foreach (var spawn in Enemies)
            enemies.Add(PrologueBestiary.Create(spawn.CreatureId, teamId, spawn.MaxHp));
        return enemies;
    }

    /// <summary>A combat setup with the two heroes on their anchors and <paramref name="enemies"/>
    /// (in <see cref="Enemies"/> order) on theirs.</summary>
    public CombatSetup ToSetup(ICharacter player, ICharacter friend, IReadOnlyList<ICharacter> enemies, int? rngSeed = null)
    {
        if (enemies.Count != Enemies.Count)
            throw new ArgumentException($"[PrologueBattle] {Id} expects {Enemies.Count} enemies, got {enemies.Count}.");
        var setup = new CombatSetup { Layout = Layout, Halo = Halo, BiomeId = BiomeId, RngSeed = rngSeed };
        setup.Party.Add((player, Anchor(PlayerAnchor)));
        setup.Party.Add((friend, Anchor(FriendAnchor)));
        for (int i = 0; i < enemies.Count; i++)
            setup.Enemies.Add((enemies[i], Anchor(Enemies[i].Anchor)));
        return setup;
    }

    /// <summary>Build both pregens and the enemies, then the setup. Requires GameDataLoader.</summary>
    public CombatSetup BuildSetup(int? rngSeed = null)
        => ToSetup(PrologueCast.BuildPlayer(), PrologueCast.BuildFriend(), CreateEnemies(), rngSeed);
}
