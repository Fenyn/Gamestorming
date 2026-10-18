using Ungilded.Autoload;
using Godot;

namespace Ungilded.Dev;

/// <summary>
/// F5 target: the <see cref="HarnessEncounter"/> fight, built fresh from presets each run and
/// handed to the combat scene. With <see cref="UseGeneratedMap"/> on, the fight runs on a
/// generated <see cref="Biome"/> map with that biome's look; off, on the flat board.
/// </summary>
public partial class CombatTestScene : Node
{
    /// <summary>Level the preset party is built at.</summary>
    [Export(PropertyHint.Range, "1,10,1")] public int StartLevel { get; set; } = 2;

    /// <summary>Fight on a generated battle map instead of the flat board.</summary>
    [Export] public bool UseGeneratedMap { get; set; } = true;

    /// <summary>Biome id to generate from ("sewer", "forest").</summary>
    [Export] public string Biome { get; set; } = HarnessEncounter.SewerBiome;

    /// <summary>Map seed. The same seed and biome give the same terrain. The UNGILDED_MAP_SEED
    /// environment variable overrides it.</summary>
    [Export] public int MapSeed { get; set; } = 20260804;

    /// <summary>Initiative and dice seed.</summary>
    [Export] public int CombatSeed { get; set; } = 1337;

    /// <summary>The combat scene to instance. Assigned in combat_test.tscn.</summary>
    [Export] public PackedScene? CombatScene { get; set; }

    public override void _Ready()
    {
        if (int.TryParse(OS.GetEnvironment("UNGILDED_MAP_SEED"), out int envSeed))
        {
            MapSeed = envSeed;
            GD.Print($"[CombatTest] map seed overridden by UNGILDED_MAP_SEED: {envSeed}");
        }

        var data = DataManager.Instance;
        if (data == null || !data.IsLoaded)
        {
            GD.PushError("[CombatTest] DataManager not loaded, aborting.");
            return;
        }
        if (CombatScene == null)
        {
            GD.PushError("[CombatTest] CombatScene is not assigned, aborting.");
            return;
        }

        var setup = HarnessEncounter.Build(data, StartLevel, UseGeneratedMap, Biome, MapSeed, CombatSeed);
        if (setup == null) return;

        var scene = CombatScene.Instantiate<Combat.CombatScene>();
        AddChild(scene);
        // Reloading this scene on Restart is safe: each run rebuilds a fresh preset encounter.
        scene.SetVictoryRestartVisible(true);
        scene.StartEncounter(setup);
    }
}
