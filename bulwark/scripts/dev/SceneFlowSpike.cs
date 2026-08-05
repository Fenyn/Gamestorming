using System;
using System.Linq;
using System.Threading.Tasks;
using Bulwark.Autoload;
using Bulwark.Combat;
using Bulwark.Cozy;
using Bulwark.Data;
using Bulwark.Territory;
using Godot;
using PF2e.Core;
using PF2e.Data;
using PF2e.Events;
using PF2e.TurnManagement;

namespace Bulwark.Dev;

/// <summary>
/// Headless integration proof of the FULL game loop through REAL SceneRouter transitions — unlike
/// the command-level spikes, this one actually swaps scenes and inspects the tree:
///  (1) Boot init → GoToOutpost: outpost is the current scene, player spawned, gate sign affordance
///      present, day clock unpaused.
///  (2) Gate travel (the same all-hands command the gate interact handler runs) → GoToTerritory:
///      forest is current, 30-minute cost, party = full living roster, player + roamer bodies +
///      resource-node views + exit sign spawned, clock still running.
///  (3) Roamer contact seam (BeginTerritoryEncounter + GoToCombat, exactly what OnRoamerContact
///      does) → encounter assembler is current, real combat scene built, session's turn loop live,
///      clock paused, team-1 roster = ALL living members.
///  (4) Deterministic resolution: enemies slain through the engine damage pipeline
///      (ReactionEvents.DeliverDamage — the session's mid-turn death latch detects victory), then
///      the assembler's victory route runs for real.
///  (5) Victory return: forest is current again, player at the stored return position, the beaten
///      roamer's body absent for the day, clock unpaused.
///  (6) Exit travel (TravelToOutpost + GoToOutpost, the exit-trigger seam) → outpost current, clock
///      unpaused; GameState.Sleep advances the day.
/// Runs on a fresh deterministic GameState over a clean save slot (the user's slot0.json is backed
/// up and restored). The spike scene is the initial scene; since the first transition frees it, a
/// driver copy re-homes itself under /root to survive every ChangeSceneToFile.
/// Prints [PASS]/[FAIL] per check and a final SPIKE RESULT line.
/// </summary>
public partial class SceneFlowSpike : SpikeBase
{
    private const string SavePath = "user://save/slot0.json";
    private const string ForestId = "verdant_fringe";

    private bool _isDriver;
    private bool _slot0Existed;
    private string? _slot0Backup;

    public override void _Ready()
    {
        if (_isDriver)
        {
            _ = RunAsync();
            return;
        }

        // This node is the initial CurrentScene and the first SceneRouter transition frees it.
        // Re-launch as a plain /root child (outside the current-scene slot) that survives every
        // scene swap the flow drives.
        var driver = new SceneFlowSpike { _isDriver = true, Name = "SceneFlowDriver" };
        GetTree().Root.CallDeferred(Node.MethodName.AddChild, driver);
    }

    private async Task RunAsync()
    {
        GD.Print("==================== SCENE FLOW SPIKE ====================");

        var data = GetNodeOrNull<DataManager>("/root/DataManager");
        if (data == null || !data.IsLoaded)
        {
            AbortFail("[SceneFlowSpike] DataManager not loaded — aborting.");
            return;
        }

        // Retire the autoload GameState FIRST (it already loaded whatever save existed and its
        // clock ticks in real time), then snapshot/clear the slot so nothing stale is reloaded.
        GetNodeOrNull<Node>("/root/GameState")?.QueueFree();
        await Frames(1);
        BackupSlot0();

        try
        {
            await RunScenario();
        }
        catch (Exception e)
        {
            GD.PushError($"[SceneFlowSpike] Unhandled exception: {e}");
            Fail();
        }
        finally
        {
            RestoreSlot0();
        }

        FinishAndQuit("SceneFlowSpike");
    }

    private async Task RunScenario()
    {
        var tree = GetTree();

        // Fresh deterministic GameState on the clean slot (real-time ticking off — commands spend
        // time via SpendTime). Everything reads GameState.Instance, so the swap is transparent to
        // the scenes the flow visits; the node just needs to live under /root to _Process.
        var gs = new GameState { RealSecondsPerGameMinute = 0, Name = "GameStateFlow" };
        tree.Root.AddChild(gs);
        await Frames(1);

        var squad = gs.Squad;
        Check("(0) fresh GameState built a squad of 4", squad != null && squad.Members.Count == 4);
        if (squad == null)
            return;

        // ── (1) Boot init → outpost ──
        GD.Print("-------------------- (1) Boot -> outpost --------------------");
        SceneRouter.Instance.GoToOutpost();
        Check("(1) GoToOutpost → current scene is the outpost",
            await WaitUntil(() => tree.CurrentScene is OutpostScene, 10));
        Check("(1) router mode is Outpost", SceneRouter.Instance.CurrentMode == SceneRouter.Mode.Outpost);
        Check("(1) day clock unpaused", !gs.Clock.IsPaused);
        Check("(1) outpost spawned the player",
            tree.CurrentScene?.GetNodeOrNull<PlayerController>("Player") != null);
        Check("(1) gate sign affordance present (programmatic, at %GateTrigger)",
            tree.CurrentScene?.GetNodeOrNull<TransitionSign>("GateSign") != null);

        // ── (2) Gate travel → forest ──
        GD.Print("-------------------- (2) Gate travel -> forest --------------------");
        int minuteBefore = gs.Clock.MinuteOfDay;
        Check("(2) all-hands TravelToTerritory (the gate command) accepted", gs.TravelToTerritory(ForestId));
        Check("(2) travel spent exactly 30 game-minutes", gs.Clock.MinuteOfDay == minuteBefore + 30);
        Check("(2) party = full living roster (3 companions + the Veteran)",
            gs.Territory.SelectedCompanionIds.SequenceEqual(
                new[] { SquadRoster.TharrId, SquadRoster.FenwickId, SquadRoster.ElaraId }));

        SceneRouter.Instance.GoToTerritory(ForestId);
        Check("(2) GoToTerritory → current scene is the forest",
            await WaitUntil(() => tree.CurrentScene is TerritoryScene, 10));
        Check("(2) clock still unpaused in territory", !gs.Clock.IsPaused);

        var forest = tree.CurrentScene as TerritoryScene;
        var player = forest?.GetNodeOrNull<PlayerController>("Player");
        Check("(2) forest spawned the player", player != null);
        if (forest == null || player == null)
            return;

        var territory = Territories.Forest;
        // Only NON-boss roamers spawn as wandering bodies; boss sites (IsBoss, e.g. the wolf lair) are
        // placed by their own quest-conditional scene path, not the roaming pass.
        int wanderers = territory.Roamers.Count(r => !r.IsBoss);
        int roamers = CountChildren<RoamingEnemy>(forest);
        Check($"(2) roamer bodies spawned ({roamers}/{wanderers}, none defeated yet)",
            roamers == wanderers);
        // Marker views plus the scene-placed tree prefabs and any live forage spawns
        // (design/forage.md) — the marker contract is a floor now, not an exact count.
        int nodes = CountChildren<ResourceNodeView>(forest);
        Check($"(2) resource node views spawned ({nodes} >= {territory.Nodes.Count} marker nodes)",
            nodes >= territory.Nodes.Count);
        Check("(2) exit sign affordance present (at %ExitTrigger)",
            forest.GetNodeOrNull<TransitionSign>("ExitSign") != null);

        // ── (3) Roamer contact → combat ──
        GD.Print("-------------------- (3) Roamer contact -> combat --------------------");
        // The exact seam OnRoamerContact drives: the command stages the encounter with the return
        // position, then the router swaps to the assembler (deterministic gob_1 = goblin_pair).
        Vector2 contactPos = player.GlobalPosition + new Vector2(7f, 3f);
        Check("(3) BeginTerritoryEncounter (gob_1) accepted", gs.BeginTerritoryEncounter("gob_1", contactPos));

        var pending = gs.Territory.PendingEncounter;
        Check("(3) pending encounter staged", pending != null);
        if (pending == null)
            return;
        Check("(3) combat team-1 roster = ALL living members (4, marching order)",
            pending.Setup.Party.Select(p => p.Unit.Id).SequenceEqual(new[]
            {
                SquadRoster.PlayerId, SquadRoster.TharrId, SquadRoster.FenwickId, SquadRoster.ElaraId,
            }));
        var enemies = pending.Enemies;
        Check($"(3) enemies staged from gob_1's table ({enemies.Count}x)", enemies.Count == 2);

        SceneRouter.Instance.GoToCombat();
        Check("(3) GoToCombat → current scene is the encounter assembler",
            await WaitUntil(() => tree.CurrentScene is EncounterScene, 10));
        Check("(3) day clock paused for combat", gs.Clock.IsPaused);
        Check("(3) assembler built the real combat scene",
            await WaitUntil(
                () => tree.CurrentScene != null
                      && tree.CurrentScene.GetChildren().OfType<CombatScene>().Any(), 10));
        Check("(3) combat session running (initiative rolled, turn loop live)",
            await WaitUntil(() => TurnManager.Instance?.CurrentTurn?.Character != null, 15));

        // ── (4) Deterministic resolution → victory ──
        GD.Print("-------------------- (4) Scripted victory --------------------");
        // Let the session settle on a party member's turn (it idles awaiting player input there);
        // the kill below works mid-AI-turn too — the session latches mid-turn deaths — but this
        // keeps the resolution point stable.
        bool partyTurn = await WaitUntil(
            () => TurnManager.Instance?.CurrentTurn?.Character?.TeamId == 1, 30);
        Check("(4) session reached a party member's turn (idling on player input)", partyTurn);

        var veteran = squad.FindMember(SquadRoster.PlayerId)!;
        foreach (var enemy in enemies)
        {
            if (enemy.Health != null && !enemy.Health.IsDead)
                await ReactionEvents.DeliverDamage(veteran, enemy, Physical(999));
        }
        Check("(4) all enemies slain through the engine damage pipeline",
            enemies.All(e => e.Health != null && e.Health.IsDead));

        // The raw damage seam bypasses the session's battle-event stream, so the mid-turn victory
        // latch hasn't seen the deaths — end the current player turn through the REAL HUD path
        // (End Turn button → controller → session), which drives the turn loop to its single
        // victory gate. Pressed on a short poll: a press that lands before the session arms the
        // player-turn seam is a harmless no-op, so repeat until the assembler routes us out
        // (victory → banner linger → GoToTerritory).
        var combatScene = tree.CurrentScene?.GetChildren().OfType<CombatScene>().FirstOrDefault();
        var actionBar = combatScene?.GetNodeOrNull<Bulwark.UI.ActionBar>("%ActionBar");
        var endButton = actionBar?.GetNodeOrNull<Button>("%EndButton");
        Check("(4) End Turn button reachable on the combat HUD", endButton != null);

        bool routedBack = false;
        for (int i = 0; i < 40 && !routedBack; i++)
        {
            if (endButton != null && IsInstanceValid(endButton))
                endButton.EmitSignal(BaseButton.SignalName.Pressed);
            routedBack = await WaitUntil(() => tree.CurrentScene is TerritoryScene, 0.5);
        }
        Check("(4) victory detected → assembler routed back to the forest", routedBack);

        // ── (5) Victory return state ──
        GD.Print("-------------------- (5) Return to the forest --------------------");
        Check("(5) day clock unpaused again", !gs.Clock.IsPaused);
        Check("(5) still in the territory", gs.Territory.CurrentTerritoryId == ForestId);

        forest = tree.CurrentScene as TerritoryScene;
        player = forest?.GetNodeOrNull<PlayerController>("Player");
        Check("(5) player respawned at the stored return position",
            player != null && player.GlobalPosition.DistanceTo(contactPos) < 1f);
        Check("(5) gob_1 marked defeated for the day", gs.Territory.IsRoamerDefeated(ForestId, "gob_1"));
        int roamersAfter = forest != null ? CountChildren<RoamingEnemy>(forest) : -1;
        Check($"(5) defeated roamer's body absent ({roamersAfter}/{wanderers - 1})",
            roamersAfter == wanderers - 1);
        Check("(5) pending encounter cleared", gs.Territory.PendingEncounter == null);

        // ── (6) Exit travel → outpost, sleep → next day ──
        GD.Print("-------------------- (6) Exit -> outpost -> sleep --------------------");
        int dayBefore = gs.Clock.Day;
        Check("(6) TravelToOutpost (the exit-trigger command) accepted", gs.TravelToOutpost());
        SceneRouter.Instance.GoToOutpost();
        Check("(6) GoToOutpost → current scene is the outpost again",
            await WaitUntil(() => tree.CurrentScene is OutpostScene, 10));
        Check("(6) day clock unpaused at the outpost", !gs.Clock.IsPaused);
        Check("(6) location cleared (back at the outpost)", gs.Territory.CurrentTerritoryId == null);

        gs.Sleep();
        Check("(6) sleep advanced the day", gs.Clock.Day == dayBefore + 1);
        Check("(6) wake at the day-start minute", gs.Clock.MinuteOfDay == DayClock.DayStartMinute);
    }

    // ─────────────────────────── Harness helpers ───────────────────────────

    private static DamageResult Physical(int amount) =>
        new() { TotalDamage = amount, DamageType = DamageType.Slashing };

    private static int CountChildren<T>(Node parent) where T : Node
    {
        int count = 0;
        foreach (var child in parent.GetChildren())
            if (child is T)
                count++;
        return count;
    }

    /// <summary>Poll a condition once per process frame until it holds or the timeout elapses.</summary>
    private async Task<bool> WaitUntil(Func<bool> condition, double timeoutSeconds)
    {
        ulong deadline = Time.GetTicksMsec() + (ulong)(timeoutSeconds * 1000.0);
        while (!condition())
        {
            if (Time.GetTicksMsec() >= deadline)
                return condition();
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        }
        return true;
    }

    private async Task Frames(int count)
    {
        for (int i = 0; i < count; i++)
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }

    // ─────────────────────────── Save-slot protection ───────────────────────────

    private void BackupSlot0()
    {
        _slot0Existed = Godot.FileAccess.FileExists(SavePath);
        if (!_slot0Existed)
            return;

        using (var file = Godot.FileAccess.Open(SavePath, Godot.FileAccess.ModeFlags.Read))
            _slot0Backup = file?.GetAsText();

        DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(SavePath));
        GD.Print("[SceneFlowSpike] slot0.json backed up and cleared for the test run.");
    }

    private void RestoreSlot0()
    {
        if (_slot0Existed && _slot0Backup != null)
        {
            using var file = Godot.FileAccess.Open(SavePath, Godot.FileAccess.ModeFlags.Write);
            file?.StoreString(_slot0Backup);
            GD.Print("[SceneFlowSpike] slot0.json restored.");
        }
        else if (!_slot0Existed && Godot.FileAccess.FileExists(SavePath))
        {
            DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(SavePath));
            GD.Print("[SceneFlowSpike] test slot0.json removed (no prior save existed).");
        }
    }
}
