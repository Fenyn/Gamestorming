using System.Collections.Generic;
using Ungilded.Autoload;
using Ungilded.Combat;
using Ungilded.Data;
using Ungilded.Presets;
using Godot;
using PF2e.Core;
using PF2e.MapGen;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Dev;

/// <summary>
/// The dev harness fight: two preset heroes against two Giant Rats, on a generated biome map or
/// the flat board. Shared by <see cref="CombatTestScene"/> and the combat smoke spike.
/// The heroes are Delve's Veteran and Elara presets, a stand-in until Ungilded's own pregens exist.
/// </summary>
public static class HarnessEncounter
{
    public const string SewerBiome = "sewer";

    /// <summary>Build the encounter, or null (with an error pushed) when content or the map is missing.</summary>
    public static CombatSetup? Build(DataManager data, int level, bool generatedMap, string biome,
        int mapSeed, int combatSeed)
    {
        var ratDef = data.ResolveCreature(EncounterTables.GiantRat);
        if (ratDef == null)
        {
            GD.PushError("[Harness] Could not resolve the Giant Rat.");
            return null;
        }

        var party = new ICharacter[]
        {
            PresetCharacters.BuildPlayer(level: level, teamId: 1),
            PresetCharacters.BuildElara(level: level, teamId: 1),
        };
        var enemies = new List<ICharacter>
        {
            CreatureFactory.Create(ratDef, teamId: 2),
            CreatureFactory.Create(ratDef, teamId: 2),
        };
        return generatedMap
            ? BuildGenerated(party, enemies, biome, mapSeed, combatSeed)
            : BuildFlat(party, enemies, combatSeed);
    }

    private static CombatSetup BuildFlat(ICharacter[] party, List<ICharacter> enemies, int combatSeed)
    {
        var setup = new CombatSetup
        {
            GridWidth = CombatBoards.StandardWidth,
            GridHeight = CombatBoards.StandardHeight,
            RngSeed = combatSeed,
        };
        var enemyAnchors = CombatBoards.Anchors(teamId: 2, enemies.Count);
        for (int i = 0; i < enemies.Count; i++)
            setup.Enemies.Add((enemies[i], enemyAnchors[i]));
        var partyAnchors = CombatBoards.Anchors(teamId: 1, party.Length);
        for (int i = 0; i < party.Length; i++)
            setup.Party.Add((party[i], partyAnchors[i]));
        return setup;
    }

    /// <summary>
    /// Both sides deploy on the layout's own deployment zones (team 0 is the player side, team 1 the
    /// enemy side in map-generation terms).
    /// </summary>
    private static CombatSetup? BuildGenerated(ICharacter[] party, List<ICharacter> enemies, string biome,
        int mapSeed, int combatSeed)
    {
        var layout = MapGenerator.GenerateValidated(biome, mapSeed);
        if (layout == null)
        {
            GD.PushError($"[Harness] Could not generate a '{biome}' map for seed {mapSeed}.");
            return null;
        }

        var setup = new CombatSetup { Layout = layout, BiomeId = biome, RngSeed = combatSeed };
        var partyAnchors = DeploymentPlanner.GetAnchors(layout, teamId: 0, count: party.Length);
        for (int i = 0; i < party.Length; i++)
            setup.Party.Add((party[i], AnchorAt(partyAnchors, i)));
        var enemyAnchors = DeploymentPlanner.GetAnchors(layout, teamId: 1, count: enemies.Count);
        for (int i = 0; i < enemies.Count; i++)
            setup.Enemies.Add((enemies[i], AnchorAt(enemyAnchors, i)));

        GD.Print($"[Harness] generated '{biome}' map {layout.Width}x{layout.Height} seed {layout.Seed}.");
        return setup;
    }

    /// <summary>
    /// The i-th anchor, or the last one when the zone held fewer walkable tiles than the team has
    /// members. <c>CombatSetup.Normalize</c> spreads a stacked anchor onto the nearest free tiles.
    /// </summary>
    private static PF2eVec AnchorAt(List<PF2eVec> anchors, int index) =>
        anchors.Count == 0 ? default : anchors[System.Math.Min(index, anchors.Count - 1)];
}
