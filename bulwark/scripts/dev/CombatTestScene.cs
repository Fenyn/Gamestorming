using Bulwark.Autoload;
using Bulwark.Combat;
using Bulwark.Presets;
using Godot;
using PF2e;
using PF2e.Core;
using PF2eVec = PF2e.Vector2Int;

namespace Bulwark.Dev;

/// <summary>
/// F5 target for M1: assembles the playable combat slice — the Veteran + the Recruit (team 1)
/// versus three Goblin Warriors (team 2) on a 12x10 grid — and hands it to the combat scene.
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

        var goblinDef = data.FindCreature("Goblin Warrior")
            ?? data.LoadCreatureFile("pathfinder-monster-core", "goblin-warrior");

        var g1 = CreatureFactory.Create(goblinDef, teamId: 2);
        var g2 = CreatureFactory.Create(goblinDef, teamId: 2);
        var g3 = CreatureFactory.Create(goblinDef, teamId: 2);

        var setup = new CombatSetup
        {
            GridWidth = 12,
            GridHeight = 10,
            RngSeed = 1337,
            Party =
            {
                (veteran, new PF2eVec(1, 4)),
                (recruit, new PF2eVec(2, 5)),
            },
            Enemies =
            {
                (g1, new PF2eVec(10, 3)),
                (g2, new PF2eVec(10, 5)),
                (g3, new PF2eVec(9, 6)),
            },
        };

        var scene = GD.Load<PackedScene>("res://scenes/combat/combat.tscn").Instantiate<CombatScene>();
        AddChild(scene);
        scene.StartEncounter(setup);
    }
}
