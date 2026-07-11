using System.Collections.Generic;
using Bulwark.Autoload;
using Bulwark.Combat;
using Bulwark.Cozy;
using Bulwark.Presets;
using Godot;
using PF2e;
using PF2e.Core;
using PF2eVec = PF2e.Vector2Int;

namespace Bulwark.Dev;

/// <summary>
/// F5 target for the playable combat slice: the canonical party of four versus five Goblin Warriors
/// on a 14x12 grid, handed to the combat scene. The party comes from GameState's LIVE squad roster
/// (HP / conditions / spell slots carry in and out — attrition), with a fresh-preset fallback so the
/// scene still runs standalone (F6). The encounter result is reported back to GameState so downed
/// allies stabilize, encounter-scoped state clears, and XP banks on victory.
/// </summary>
public partial class CombatTestScene : Node
{
    public override void _Ready()
    {
        var data = GetNode<DataManager>("/root/DataManager");
        if (data == null || !data.IsLoaded)
        {
            GD.PushError("[CombatTest] DataManager not loaded — aborting.");
            return;
        }

        // Consume the live squad instances (built once per save); fall back to throwaway presets
        // when the squad is unavailable (standalone runs without a GameState-owned roster).
        var squad = GameState.Instance?.Squad;
        ICharacter? veteran = squad?.FindMember(SquadRoster.VeteranId);
        ICharacter? scout = squad?.FindMember(SquadRoster.ScoutId);
        ICharacter? medic = squad?.FindMember(SquadRoster.MedicId);
        ICharacter? scholar = squad?.FindMember(SquadRoster.ScholarId);
        veteran ??= PresetCharacters.BuildVeteran(level: 2, teamId: 1);
        scout ??= PresetCharacters.BuildScout(level: 2, teamId: 1);
        medic ??= PresetCharacters.BuildMedic(level: 2, teamId: 1);
        scholar ??= PresetCharacters.BuildScholar(level: 2, teamId: 1);

        var goblinDef = data.FindCreature("Goblin Warrior")
            ?? data.LoadCreatureFile("pathfinder-monster-core", "goblin-warrior");

        var enemies = new List<ICharacter>
        {
            CreatureFactory.Create(goblinDef, teamId: 2),
            CreatureFactory.Create(goblinDef, teamId: 2),
            CreatureFactory.Create(goblinDef, teamId: 2),
            CreatureFactory.Create(goblinDef, teamId: 2),
            CreatureFactory.Create(goblinDef, teamId: 2),
        };

        var setup = new CombatSetup
        {
            GridWidth = 14,
            GridHeight = 12,
            RngSeed = 1337,
            Enemies =
            {
                (enemies[0], new PF2eVec(12, 3)),
                (enemies[1], new PF2eVec(12, 5)),
                (enemies[2], new PF2eVec(11, 6)),
                (enemies[3], new PF2eVec(12, 7)),
                (enemies[4], new PF2eVec(11, 9)),
            },
        };

        // Dead squad members sit the fight out (they only return via a future revival mechanic).
        var partySlots = new (ICharacter Unit, PF2eVec Pos)[]
        {
            (veteran, new PF2eVec(1, 4)),
            (scout, new PF2eVec(2, 5)),
            (medic, new PF2eVec(1, 6)),
            (scholar, new PF2eVec(2, 7)),
        };
        foreach (var (unit, pos) in partySlots)
        {
            if (unit.Health == null || !unit.Health.IsDead)
                setup.Party.Add((unit, pos));
        }

        var scene = GD.Load<PackedScene>("res://scenes/combat/combat.tscn").Instantiate<CombatScene>();
        AddChild(scene);

        // Report the outcome to the state root: stabilization, cleanup and XP happen there.
        scene.EncounterFinished += result =>
            GameState.Instance?.CompleteEncounter(result, enemies);

        scene.StartEncounter(setup);
    }
}
