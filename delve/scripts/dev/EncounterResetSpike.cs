using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Combat;
using Delve.Data;
using Delve.Presets;
using Godot;
using PF2e.Actions;
using PF2e.Core;
using PF2e.Grid;
using PF2e.TurnManagement;
using PF2e.Utilities;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Dev;

/// <summary>
/// Headless verification of the roguelite loop's re-entrancy: one <see cref="CombatScene"/> must run
/// encounter after encounter without leaking nodes, stacking log subscriptions, or corrupting the
/// engine globals.
///
/// Two parts:
/// <list type="number">
/// <item>Stale-scope safety — an <see cref="EngineEncounterScope"/> disposed AFTER a newer scope
/// claimed the globals must leave the newer scope's wiring alone.</item>
/// <item>Scene reset — StartEncounter twice on one scene, checking the unit layer, the presenter's
/// unit registry, and that one log entry still reaches the log panel exactly once.</item>
/// </list>
/// </summary>
public partial class EncounterResetSpike : SpikeBase
{
    private const int FirstParty = 2;
    private const int FirstEnemies = 2;
    private const int SecondParty = 1;
    private const int SecondEnemies = 2;

    protected override string Banner => "==================== ENCOUNTER RESET SPIKE ====================";

    protected override async Task RunSpikeAsync(DataManager data)
    {
        PresetSpells.EnsureRegistered();

        CheckStaleScope();
        await CheckSceneReset(data);
    }

    // ───────────────────────── (1) stale scope disposal ─────────────────────────

    /// <summary>
    /// Claim the globals twice, then dispose the OLD scope. Everything must still point at the new
    /// one; disposing the new one afterwards must leave the process clean.
    /// </summary>
    private void CheckStaleScope()
    {
        var gridA = BattleGrid.CreateFlat(6, 6);
        var gridB = BattleGrid.CreateFlat(8, 8);

        var scopeA = NewScope(gridA);
        var scopeB = NewScope(gridB);

        scopeA.Dispose();

        Check("(1) stale dispose keeps TurnManager.Instance",
            ReferenceEquals(TurnManager.Instance, scopeB.Turns));
        Check("(1) stale dispose keeps CombatantRegistry.Instance",
            ReferenceEquals(CombatantRegistry.Instance, scopeB.Registry));
        Check("(1) stale dispose keeps ReactionManager.Instance",
            ReferenceEquals(ReactionManager.Instance, scopeB.Reactions));
        Check("(1) stale dispose keeps the spatial delegates",
            OffGuardHelper.IsFlankingAttacker != null
            && CoverHelper.GetPositionalCover != null
            && CoverHelper.IsAdjacentToTerrainCover != null
            && CoverHelper.HasLineOfSight != null
            && CoverHelper.HasLineOfEffect != null);
        Check("(1) stale dispose keeps the grid delegates",
            AreaCalculator.GetTileElevation != null && TileEffectRules.TileBlockedByZone != null);
        Check("(1) stale dispose keeps StepAction.ValidateDestination",
            StepAction.ValidateDestination != null);
        Check("(1) stale dispose keeps ForcedMovementExecutor on the live grid",
            ReferenceEquals(ForcedMovementExecutor.Grid, gridB));
        Check("(1) stale dispose keeps the reaction-strike bridge",
            ReactionStrikeBridge.Execute != null);

        scopeB.Dispose();

        Check("(1) owner dispose releases the singletons",
            TurnManager.Instance == null && CombatantRegistry.Instance == null);
        Check("(1) owner dispose releases the delegates",
            OffGuardHelper.IsFlankingAttacker == null
            && CoverHelper.HasLineOfSight == null
            && StepAction.ValidateDestination == null
            && AreaCalculator.GetTileElevation == null
            && ForcedMovementExecutor.Grid == null);
    }

    private static EngineEncounterScope NewScope(BattleGrid grid) => new(
        grid,
        _ => true,
        _ => Task.FromResult(true),
        (_, _) => null);

    // ───────────────────────── (2) scene reset ─────────────────────────

    private async Task CheckSceneReset(DataManager data)
    {
        var scene = GD.Load<PackedScene>("res://scenes/combat/combat.tscn")
            .Instantiate<Delve.Combat.CombatScene>();
        AddChild(scene);
        var unitLayer = scene.GetNode<Node3D>("%UnitLayer");
        var log = scene.GetNode<Control>("%CombatLog");

        scene.StartEncounter(BuildSetup(data, FirstParty, FirstEnemies, seed: 11));
        int firstUnits = FirstParty + FirstEnemies;
        Check($"(2) first encounter spawns {firstUnits} unit nodes",
            unitLayer.GetChildCount() == firstUnits);
        Check($"(2) first encounter registers {firstUnits} unit visuals",
            scene.RegisteredUnitCount == firstUnits);

        // Let the first encounter actually start and reach an await, so the reset happens on a LIVE
        // loop — the case that used to leak the session, the token source and the log subscription.
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);

        scene.StartEncounter(BuildSetup(data, SecondParty, SecondEnemies, seed: 22));
        int secondUnits = SecondParty + SecondEnemies;
        Check($"(2) second encounter leaves exactly {secondUnits} unit nodes",
            unitLayer.GetChildCount() == secondUnits);
        Check($"(2) second encounter registers {secondUnits} unit visuals",
            scene.RegisteredUnitCount == secondUnits);
        Check("(2) second encounter owns the engine singletons",
            TurnManager.Instance != null && CombatantRegistry.Instance != null
            && StepAction.ValidateDestination != null && CoverHelper.HasLineOfSight != null);

        // One entry in, one line out: a second subscription would write the entry twice.
        int before = LogLines(log);
        const int emitted = 3;
        for (int i = 0; i < emitted; i++)
            CombatLog.Emit($"reset spike probe {i}");
        int written = LogLines(log) - before;
        Check($"(2) {emitted} log entries reach the panel {emitted} times (one subscription)",
            written == emitted);

        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);

        // Leave the tree the way a host would: exit tears the encounter down and releases the globals.
        RemoveChild(scene);
        scene.QueueFree();
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);

        Check("(2) scene exit releases the engine singletons",
            TurnManager.Instance == null && CombatantRegistry.Instance == null);
        Check("(2) scene exit releases the delegates",
            StepAction.ValidateDestination == null && CoverHelper.HasLineOfSight == null
            && ForcedMovementExecutor.Grid == null);
    }

    /// <summary>Lines the log panel has written so far (its history label is the only record).</summary>
    private static int LogLines(Control log)
    {
        var history = log.GetNode<RichTextLabel>("%Log");
        string text = history.GetParsedText();
        int lines = 0;
        foreach (char c in text)
            if (c == '\n') lines++;
        return lines;
    }

    private static CombatSetup BuildSetup(DataManager data, int party, int enemies, int seed)
    {
        var goblinDef = data.ResolveCreature(EncounterTables.GoblinWarrior)!;
        var setup = new CombatSetup { GridWidth = 12, GridHeight = 10, RngSeed = seed };

        var heroes = new List<ICharacter>
        {
            PresetCharacters.BuildPlayer(level: 2, teamId: 1),
            PresetCharacters.BuildElara(level: 2, teamId: 1),
        };
        for (int i = 0; i < party; i++)
            setup.Party.Add((heroes[i % heroes.Count], new PF2eVec(1, 3 + i * 2)));
        for (int i = 0; i < enemies; i++)
            setup.Enemies.Add((CreatureFactory.Create(goblinDef, teamId: 2), new PF2eVec(8, 3 + i * 2)));

        return setup;
    }
}
