using Bulwark.Autoload;
using Bulwark.Combat;
using Bulwark.Presets;
using Godot;
using PF2e;
using PF2e.Core;
using PF2eVec = PF2e.Vector2Int;

namespace Bulwark.Dev;

/// <summary>
/// F5 target for M1 phase 2: assembles the playable combat slice — a party of four (the Veteran,
/// the Recruit, the Medic, the Scholar) on team 1 versus five Goblin Warriors on team 2, on a 14x12
/// grid — and hands it to the combat scene. The Medic/Scholar exercise the spell + skill layer.
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

        var veteran = PresetCharacters.BuildVeteran(level: 2, teamId: 1);
        var recruit = PresetCharacters.BuildRecruit(level: 2, teamId: 1);
        var medic = PresetCharacters.BuildMedic(level: 2, teamId: 1);
        var scholar = PresetCharacters.BuildScholar(level: 2, teamId: 1);

        var goblinDef = data.FindCreature("Goblin Warrior")
            ?? data.LoadCreatureFile("pathfinder-monster-core", "goblin-warrior");

        var setup = new CombatSetup
        {
            GridWidth = 14,
            GridHeight = 12,
            RngSeed = 1337,
            Party =
            {
                (veteran, new PF2eVec(1, 4)),
                (recruit, new PF2eVec(2, 5)),
                (medic, new PF2eVec(1, 6)),
                (scholar, new PF2eVec(2, 7)),
            },
            Enemies =
            {
                (CreatureFactory.Create(goblinDef, teamId: 2), new PF2eVec(12, 3)),
                (CreatureFactory.Create(goblinDef, teamId: 2), new PF2eVec(12, 5)),
                (CreatureFactory.Create(goblinDef, teamId: 2), new PF2eVec(11, 6)),
                (CreatureFactory.Create(goblinDef, teamId: 2), new PF2eVec(12, 7)),
                (CreatureFactory.Create(goblinDef, teamId: 2), new PF2eVec(11, 9)),
            },
        };

        var scene = GD.Load<PackedScene>("res://scenes/combat/combat.tscn").Instantiate<CombatScene>();
        AddChild(scene);
        scene.StartEncounter(setup);
    }
}
