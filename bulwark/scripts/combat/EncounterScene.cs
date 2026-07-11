using Bulwark.Autoload;
using Godot;

namespace Bulwark.Combat;

/// <summary>
/// Assembler for a GameState-driven combat: consumes the pending territory encounter staged by the
/// BeginTerritoryEncounter command (party = the live gate-selected squad members, enemies from the
/// roamer's encounter table), runs the REAL combat scene with it, reports the result through
/// GameState.CompleteTerritoryEncounter, and routes back — to the territory (victory, at the stored
/// return position) or to the outpost (defeat wake). SceneRouter.GoToCombat targets this scene;
/// scenes/dev/combat_test.tscn remains the standalone F5/F6 dev entry with its fresh-preset fallback.
/// </summary>
public partial class EncounterScene : Node
{
    /// <summary>Seconds the victory/defeat banner stays up before the scene routes onward.</summary>
    [Export] public double ResultLingerSeconds { get; set; } = 2.0;

    public override void _Ready()
    {
        var pending = GameState.Instance?.Territory?.PendingEncounter;
        if (pending == null)
        {
            // Standalone run (F6) or a routing bug — nothing staged to fight. Fall back gently.
            GD.PushWarning("[EncounterScene] No pending territory encounter — returning to outpost.");
            Callable.From(() => SceneRouter.Instance?.GoToOutpost()).CallDeferred();
            return;
        }

        var scene = GD.Load<PackedScene>("res://scenes/combat/combat.tscn").Instantiate<CombatScene>();
        AddChild(scene);
        scene.EncounterFinished += OnEncounterFinished;
        scene.StartEncounter(pending.Setup);
    }

    private void OnEncounterFinished(PF2e.Core.BattleResult result)
    {
        // State settles immediately (stabilization, XP, save, defeat penalty/day advance);
        // only the scene transition lingers so the banner is readable.
        var outcome = GameState.Instance?.CompleteTerritoryEncounter(result);

        var timer = GetTree().CreateTimer(ResultLingerSeconds);
        timer.Timeout += () =>
        {
            var router = SceneRouter.Instance;
            if (router == null)
                return;
            if (outcome is { Victory: true })
                router.GoToTerritory(outcome.TerritoryId);
            else
                router.GoToOutpost();
        };
    }
}
