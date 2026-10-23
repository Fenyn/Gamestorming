using System;
using System.Collections.Generic;
using System.Linq;
using Godot;
using PF2e.Core;
using PF2e.MapGen;
using PF2e.MapGen.Biomes;
using Ungilded.Autoload;
using Ungilded.Combat;
using Ungilded.Content;
using Ungilded.Data;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Dev;

/// <summary>
/// The roster fight: the two Prologue heroes against one of every creature with its own sprite,
/// stood in rows on a generated forest clearing. Shared by <see cref="RosterPreviewScene"/> (F6)
/// and the roster shot spike. Initiative is fixed with the heroes first, so the creatures stand
/// still while they are looked at.
/// </summary>
public static class RosterEncounter
{
    public const string ForestBiome = "forest";
    /// <summary>An open clearing: no river, and every row on level ground.</summary>
    public const int DefaultMapSeed = 16;
    public const int DefaultSpacing = 3;

    /// <summary>Pack creatures with their own sprite, smallest first.</summary>
    public static readonly CreatureRef[] PackCreatures =
    {
        EncounterTables.GiantRat, EncounterTables.Viper, EncounterTables.GoblinWarrior,
        EncounterTables.KoboldWarrior, EncounterTables.Wolf, EncounterTables.HuntingSpider,
        EncounterTables.Boar, EncounterTables.GiantMonitorLizard, EncounterTables.GiantViper,
        EncounterTables.DireWolf, EncounterTables.GrizzlyBear, EncounterTables.GiantStagBeetle,
    };

    /// <summary>Prologue sewer creatures whose sprite no pack creature shares.</summary>
    public static readonly string[] PrologueCreatures =
    {
        PrologueBestiary.DireSewerRatId, PrologueBestiary.SewerTyrantId,
    };

    /// <summary>Build the encounter, or null (with an error pushed) when a creature or the map is missing.</summary>
    public static CombatSetup? Build(DataManager data, int mapSeed, int combatSeed, int spacing = DefaultSpacing)
    {
        var layout = MapGenerator.GenerateValidated(ForestBiome, mapSeed, ClearingParams());
        if (layout == null)
        {
            GD.PushError($"[Roster] Could not generate a '{ForestBiome}' map for seed {mapSeed}.");
            return null;
        }

        var enemies = new List<ICharacter>();
        foreach (var @ref in PackCreatures)
        {
            var def = data.ResolveCreature(@ref);
            if (def == null)
            {
                GD.PushError($"[Roster] Could not resolve the {@ref.DisplayName}.");
                return null;
            }
            enemies.Add(CreatureFactory.Create(def, teamId: 2));
        }
        foreach (string id in PrologueCreatures)
            enemies.Add(PrologueBestiary.Create(id, teamId: 2));

        var heroes = new ICharacter[] { PrologueCast.BuildPlayer(), PrologueCast.BuildFriend() };
        var setup = new CombatSetup
        {
            Layout = layout, BiomeId = ForestBiome, RngSeed = combatSeed, FixedInitiative = true,
        };
        Place(setup, layout, heroes, enemies, spacing);
        GD.Print($"[Roster] generated '{ForestBiome}' map {layout.Width}x{layout.Height} seed {layout.Seed}, "
            + $"{heroes.Length} heroes and {enemies.Count} creatures.");
        return setup;
    }

    /// <summary>The forest's own tuning with the scatter thinned, so the rows stand in a clearing.</summary>
    private static MapGenerationParams ClearingParams()
    {
        var forest = MapGenRegistry.GetBiome(ForestBiome).DefaultParams;
        return new MapGenerationParams
        {
            Id = "forest_roster",
            Width = forest.Width,
            Height = forest.Height,
            HasBorder = forest.HasBorder,
            CoverDensity = 0.03f,
            WaterDensity = 0f,
            DifficultTerrainDensity = 0.02f,
            WallDensity = 0.03f,
            SymmetricLayout = forest.SymmetricLayout,
            DeploymentDepth = forest.DeploymentDepth,
        };
    }

    /// <summary>
    /// Rows of slots <paramref name="spacing"/> tiles apart. The heroes take the two middle slots
    /// of the first row; the creatures fill the rows from the third on, left to right, on flat
    /// open ground first and on any open ground second, so an empty row parts the heroes from the
    /// creatures. A creature with no slot left is anchored at the board's centre for
    /// <see cref="CombatSetup.Normalize"/> to move to the nearest free footprint.
    /// </summary>
    private static void Place(CombatSetup setup, MapLayout layout, ICharacter[] heroes,
        List<ICharacter> enemies, int spacing)
    {
        const int margin = 2;
        var taken = new HashSet<PF2eVec>();
        var rows = new List<List<PF2eVec>>();
        for (int y = margin; y < layout.Height - margin; y += spacing)
        {
            var row = new List<PF2eVec>();
            for (int x = margin; x < layout.Width - margin; x += spacing) row.Add(new PF2eVec(x, y));
            rows.Add(row);
        }

        var front = rows[0].OrderBy(s => Math.Abs(s.x - layout.Width / 2))
            .Where(s => Fits(layout, s, 1, taken, flat: true)).Take(heroes.Length).ToList();
        var centre = new PF2eVec(layout.Width / 2, layout.Height / 2);
        for (int i = 0; i < heroes.Length; i++)
        {
            var slot = i < front.Count ? front[i] : centre;
            Reserve(taken, slot, heroes[i].TileWidth);
            setup.Party.Add((heroes[i], slot));
        }

        var queue = new Queue<ICharacter>(enemies);
        foreach (bool flat in new[] { true, false })
            foreach (var row in rows.Skip(2))
                foreach (var slot in row)
                {
                    if (queue.Count == 0) return;
                    var unit = queue.Peek();
                    if (!Fits(layout, slot, unit.TileWidth, taken, flat)) continue;
                    Reserve(taken, slot, unit.TileWidth);
                    setup.Enemies.Add((queue.Dequeue(), slot));
                }
        while (queue.Count > 0) setup.Enemies.Add((queue.Dequeue(), centre));
    }

    /// <summary>Every tile of the footprint is open ground, free, and (when <paramref name="flat"/>)
    /// level with the rest.</summary>
    private static bool Fits(MapLayout layout, PF2eVec anchor, int width, HashSet<PF2eVec> taken, bool flat)
    {
        int? level = null;
        for (int dy = 0; dy < width; dy++)
            for (int dx = 0; dx < width; dx++)
            {
                int x = anchor.x + dx, y = anchor.y + dy;
                if (!layout.IsInBounds(x, y) || layout.GetTile(x, y) != TileRole.Ground
                    || taken.Contains(new PF2eVec(x, y))) return false;
                if (!flat) continue;
                var corners = layout.GetCornerHeights(x, y);
                if (corners.MinHeight != corners.MaxHeight) return false;
                level ??= corners.MinHeight;
                if (corners.MinHeight != level) return false;
            }
        return true;
    }

    private static void Reserve(HashSet<PF2eVec> taken, PF2eVec anchor, int width)
    {
        for (int dy = 0; dy < width; dy++)
            for (int dx = 0; dx < width; dx++)
                taken.Add(new PF2eVec(anchor.x + dx, anchor.y + dy));
    }
}
