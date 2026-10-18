using System.Reflection;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Combat;
using Delve.Data;
using Delve.Presets;
using Delve.UI;
using Godot;
using PF2e.Core;
using PF2e.Utilities;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Dev;

/// <summary>
/// Headless regression for HP pacing: the engine applies a Strike's damage before the presenter shows
/// the attack roll, so every HP readout must wait for the roll's outcome. A hero strikes a goblin on a
/// fixed natural 20; each frame the spike reads the goblin's live HP, its board bar, its timeline tile
/// and the dice panel, and checks the bar and tile hold the old HP until the roll's outcome shows.
/// </summary>
public partial class HpPacingSpike : SpikeBase
{
    [Export] public PackedScene? CombatScene { get; set; }

    /// <summary>Seconds to wait for the hero's turn (the goblin may win initiative).</summary>
    private const float TurnWaitSeconds = 20f;

    /// <summary>Seconds the Strike may take to present.</summary>
    private const float StrikeWaitSeconds = 10f;

    protected override string Banner => "==================== HP PACING SPIKE ====================";

    protected override async Task RunSpikeAsync(DataManager data)
    {
        if (CombatScene == null) { AbortFail("[HpPacing] CombatScene not assigned."); return; }
        var scene = CombatScene.Instantiate<CombatScene>();
        AddChild(scene);
        var hero = PresetCharacters.BuildPlayer(level: 2);
        var goblin = CreatureFactory.Create(data.ResolveCreature(EncounterTables.GoblinWarrior)!, teamId: 2);
        scene.StartEncounter(new CombatSetup
        {
            GridWidth = 12, GridHeight = 10, RngSeed = 7,
            Party = { (hero, new PF2eVec(4, 5)) }, Enemies = { (goblin, new PF2eVec(5, 5)) },
        });
        for (float waited = 0; !scene.IsPlayerTurn && waited < TurnWaitSeconds; waited += 0.25f) await WaitSeconds(0.25f);
        Check("the hero's turn arrived", scene.IsPlayerTurn);
        if (!scene.IsPlayerTurn || goblin.Health.IsDead) return;
        await WaitSeconds(0.5f);

        var token = FindUnit(scene, goblin);
        var dice = scene.GetNode<DiceRollPanel>("%DiceRoll");
        var turnBar = scene.GetNode<TurnOrderBar>("%TurnOrderBar");
        Check("the goblin has a board token", token != null);
        if (token == null) return;
        int before = goblin.Health.CurrentHP;
        Check($"the bar starts at the live HP ({token.ShownHp}/{before})", token.ShownHp == before);

        DiceRoller.EnqueueD20(20);
        var session = (CombatSession)typeof(CombatScene).GetField("_session", BindingFlags.Instance | BindingFlags.NonPublic)!.GetValue(scene)!;
        var strike = session.PlayerActions.ExecuteStrike(hero, goblin);
        bool appliedEarly = false, barHeld = true, tileHeld = true;
        string leak = "";
        ulong rollStart = 0, rollGate = 0;
        float gateSeconds = 0;
        for (float waited = 0; !strike.IsCompleted && waited < StrikeWaitSeconds; waited += (float)GetProcessDeltaTime())
        {
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            if (rollStart == 0 && dice.Beat is { } beat) { rollStart = Time.GetTicksMsec(); gateSeconds = dice.GateSeconds(beat); }
            if (rollStart != 0 && rollGate == 0 && dice.ResultShowing) rollGate = Time.GetTicksMsec();
            bool rolling = dice.Showing != null && !dice.ResultShowing;
            if (!rolling || goblin.Health.CurrentHP == before) continue;
            appliedEarly = true;
            int tile = turnBar.HpShown.TryGetValue(goblin.UniqueId, out int shown) ? shown : before;
            if (token.ShownHp != before && barHeld) { barHeld = false; leak += $" bar {token.ShownHp}"; }
            if (tile != before && tileHeld) { tileHeld = false; leak += $" tile {tile}"; }
        }
        DiceRoller.ClearAllOverrides();
        Check("the Strike finished presenting", strike.IsCompleted);
        Check("the engine applied the damage while the attack roll still played (the case under test)", appliedEarly);
        Check($"the board bar and the timeline tile held {before} HP until the roll's outcome showed{leak}", barHeld && tileHeld);
        float beatSeconds = (rollGate - rollStart) / 1000f;
        Check($"the roll plays at the scene's pace ×{scene.PresentationPace}: its outcome lands after {beatSeconds:0.00} s of a paced {gateSeconds:0.00} s",
            dice.Pace == scene.PresentationPace && rollGate > 0 && beatSeconds >= gateSeconds * 0.9f);
        var speedBefore = Delve.Settings.UserSettings.CombatSpeed;
        Delve.Settings.UserSettings.CombatSpeed = Delve.Settings.CombatSpeed.Fast;
        Check($"the Fast option reaches the dice mid-fight (pace {dice.Pace}, Fast {scene.FastPace})", dice.Pace == scene.FastPace);
        Delve.Settings.UserSettings.CombatSpeed = Delve.Settings.CombatSpeed.Slow;
        Check($"and Slow too (pace {dice.Pace}, Slow {scene.SlowPace})", dice.Pace == scene.SlowPace);
        Delve.Settings.UserSettings.CombatSpeed = speedBefore;
        await WaitSeconds(0.5f);
        Check($"after the hit the bar shows the live HP ({token.ShownHp}/{goblin.Health.CurrentHP})",
            token.ShownHp == goblin.Health.CurrentHP && goblin.Health.CurrentHP < before);
    }

    private static UnitVisual3D? FindUnit(Node scene, ICharacter character)
    {
        foreach (var node in scene.FindChildren("*", "", recursive: true, owned: false))
            if (node is UnitVisual3D unit && ReferenceEquals(unit.Character, character)) return unit;
        return null;
    }

    private async Task WaitSeconds(float seconds)
    {
        await ToSignal(GetTree().CreateTimer(seconds), SceneTreeTimer.SignalName.Timeout);
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }
}
