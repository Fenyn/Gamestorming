using System.Collections.Generic;
using Bulwark.Autoload;
using Bulwark.Combat;
using Bulwark.Cozy;
using Bulwark.Data;
using Bulwark.Presets;
using Godot;
using PF2e;
using PF2e.Core;

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
        ICharacter? veteran = squad?.FindMember(SquadRoster.PlayerId);
        ICharacter? scout = squad?.FindMember(SquadRoster.ElaraId);
        ICharacter? medic = squad?.FindMember(SquadRoster.TharrId);
        ICharacter? scholar = squad?.FindMember(SquadRoster.FenwickId);
        veteran ??= PresetCharacters.BuildPlayer(level: GameState.SquadStartLevel, teamId: 1);
        scout ??= PresetCharacters.BuildScout(level: GameState.SquadStartLevel, teamId: 1);
        medic ??= PresetCharacters.BuildTharr(level: GameState.SquadStartLevel, teamId: 1);
        scholar ??= PresetCharacters.BuildScholar(level: GameState.SquadStartLevel, teamId: 1);

        var goblinDef = data.ResolveCreature(EncounterTables.GoblinWarrior);
        if (goblinDef == null)
        {
            GD.PushError("[CombatTest] Could not resolve the Goblin Warrior — aborting.");
            return;
        }

        var enemies = new List<ICharacter>();
        for (int i = 0; i < CombatBoards.EnemyAnchors.Length; i++)
            enemies.Add(CreatureFactory.Create(goblinDef, teamId: 2));

        var setup = new CombatSetup
        {
            GridWidth = CombatBoards.StandardWidth,
            GridHeight = CombatBoards.StandardHeight,
            RngSeed = 1337,
        };
        for (int i = 0; i < enemies.Count; i++)
            setup.Enemies.Add((enemies[i], CombatBoards.EnemyAnchors[i]));

        // Dead squad members sit the fight out (they only return via a future revival mechanic);
        // each survivor keeps their marching-order anchor.
        var partySlots = new[] { veteran, scout, medic, scholar };
        for (int i = 0; i < partySlots.Length; i++)
        {
            if (partySlots[i].Health == null || !partySlots[i].Health!.IsDead)
                setup.Party.Add((partySlots[i], CombatBoards.PartyAnchors[i]));
        }

        var scene = GD.Load<PackedScene>("res://scenes/combat/combat.tscn").Instantiate<CombatScene>();
        AddChild(scene);

        // Report the outcome to the state root: stabilization, cleanup and XP happen there.
        scene.EncounterFinished += result =>
            GameState.Instance?.CompleteEncounter(result, enemies);

        scene.StartEncounter(setup);
    }
}
