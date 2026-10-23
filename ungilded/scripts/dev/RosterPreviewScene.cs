using Ungilded.Autoload;
using Godot;

namespace Ungilded.Dev;

/// <summary>
/// F6 target: the <see cref="RosterEncounter"/> fight, the two heroes against one of every
/// creature with its own sprite on a forest clearing. The heroes act first, so every creature
/// holds its rest pose until the player ends a turn.
/// </summary>
public partial class RosterPreviewScene : Node
{
    /// <summary>Map seed. The UNGILDED_MAP_SEED environment variable overrides it.</summary>
    [Export] public int MapSeed { get; set; } = RosterEncounter.DefaultMapSeed;

    /// <summary>Dice seed.</summary>
    [Export] public int CombatSeed { get; set; } = 1337;

    /// <summary>Tiles between the rows and between the slots of a row.</summary>
    [Export(PropertyHint.Range, "2,4,1")] public int Spacing { get; set; } = RosterEncounter.DefaultSpacing;

    /// <summary>The combat scene to instance. Assigned in roster_preview.tscn.</summary>
    [Export] public PackedScene? CombatScene { get; set; }

    public override void _Ready()
    {
        if (int.TryParse(OS.GetEnvironment("UNGILDED_MAP_SEED"), out int envSeed))
        {
            MapSeed = envSeed;
            GD.Print($"[RosterPreview] map seed overridden by UNGILDED_MAP_SEED: {envSeed}");
        }

        var data = DataManager.Instance;
        if (data == null || !data.IsLoaded)
        {
            GD.PushError("[RosterPreview] DataManager not loaded, aborting.");
            return;
        }
        if (CombatScene == null)
        {
            GD.PushError("[RosterPreview] CombatScene is not assigned, aborting.");
            return;
        }

        var setup = RosterEncounter.Build(data, MapSeed, CombatSeed, Spacing);
        if (setup == null) return;

        var scene = CombatScene.Instantiate<Combat.CombatScene>();
        AddChild(scene);
        scene.SetVictoryRestartVisible(true);
        scene.StartEncounter(setup);
    }
}
