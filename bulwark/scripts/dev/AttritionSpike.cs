using System;
using System.Collections.Generic;
using System.Text.Json;
using System.Threading.Tasks;
using Bulwark.Autoload;
using Bulwark.Combat;
using Bulwark.Cozy;
using Bulwark.Data;
using Godot;
using PF2e;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Events;
using PF2e.TurnManagement;
using PF2e.Utilities;
using PF2eVec = PF2e.Vector2Int;

namespace Bulwark.Dev;

/// <summary>
/// Headless regression for squad ownership, attrition persistence, XP, save/load and rest (WP:
/// squad attrition). Drives a REAL GameState node (fresh, on a clean save slot — the user's
/// slot0.json is backed up first and restored at the end) through:
///  (1) squad built once by GameState;
///  (2) a scripted encounter — veteran wounded, scout downed to Dying, medic spends a Heal
///      preparation — then victory: stabilization to 1 HP + Wounded, encounter-scoped state
///      (Frightened, MAP) cleared, attrition (HP, slots) kept, XP banked;
///  (3) save → reload into a second fresh GameState → exact squad round-trip;
///  (4) a second encounter with the SAME live instances — MAP is fresh, slot usage persisted,
///      Wounded raises the initial Dying value, and the DyingSystem's turn-start recovery check
///      still fires on the re-subscribed TurnManager (the risky re-entry wiring);
///  (5) sleep — full HP, slots re-prepared, Wounded cleared, day advanced, XP retained unapplied.
/// Prints [PASS]/[FAIL] per check and a final SPIKE RESULT line.
/// </summary>
public partial class AttritionSpike : Node
{
    private const string SavePath = "user://save/slot0.json";

    private int _failures;
    private bool _slot0Existed;
    private string? _slot0Backup;

    public override void _Ready() => _ = RunAsync();

    private async Task RunAsync()
    {
        GD.Print("==================== ATTRITION SPIKE ====================");

        var data = GetNode<DataManager>("/root/DataManager");
        if (data == null || !data.IsLoaded)
        {
            GD.PushError("[AttritionSpike] DataManager not loaded — aborting.");
            GD.Print("SPIKE RESULT: FAIL");
            GetTree().Quit(1);
            return;
        }

        // Protect the player's save: this spike exercises GameState's real save path (slot0).
        BackupSlot0();
        try
        {
            await RunScenario(data);
        }
        catch (Exception e)
        {
            GD.PushError($"[AttritionSpike] Unhandled exception: {e}");
            _failures++;
        }
        finally
        {
            RestoreSlot0();
        }

        GD.Print("---------------------------------------------------------");
        bool pass = _failures == 0;
        GD.Print($"[AttritionSpike] failures: {_failures}");
        GD.Print($"SPIKE RESULT: {(pass ? "PASS" : "FAIL")}");
        GetTree().Quit(pass ? 0 : 1);
    }

    private async Task RunScenario(DataManager data)
    {
        // Fresh GameState on the now-clean slot (the autoload instance may have loaded the user's
        // save before backup; this one builds a pristine squad).
        var gs1 = new GameState();
        AddChild(gs1);

        // ── (1) GameState owns the squad, built once ──
        GD.Print("-------------------- (1) Squad ownership --------------------");
        var squad = gs1.Squad;
        Check("(1) GameState built a squad of 4", squad != null && squad.Members.Count == 4);
        if (squad == null) return;

        Check("(1) all four canonical members present",
            squad.FindMember(SquadRoster.VeteranId) != null
            && squad.FindMember(SquadRoster.ScoutId) != null
            && squad.FindMember(SquadRoster.MedicId) != null
            && squad.FindMember(SquadRoster.ScholarId) != null);
        var vet = squad.FindMember(SquadRoster.VeteranId)!;
        var scout = squad.FindMember(SquadRoster.ScoutId)!;
        var medic = squad.FindMember(SquadRoster.MedicId)!;
        var scholar = squad.FindMember(SquadRoster.ScholarId)!;
        Check("(1) squad starts at full HP",
            vet.Health.IsFullHealth && scout.Health.IsFullHealth
            && medic.Health.IsFullHealth && scholar.Health.IsFullHealth);
        Check("(1) medic starts with 3 rank-1 preparations", PreparedCount(medic, 1) == 3);
        Check("(1) medic starts with a full divine font (4 heal slots)",
            medic.Spellcasting?.DivineFont?.CurrentSlots == 4);
        Check("(1) squad starts with 0 XP", squad.GetXp(SquadRoster.VeteranId) == 0);

        // ── (2) Encounter 1: attrition + stabilization + XP ──
        GD.Print("-------------------- (2) Encounter 1 --------------------");
        var goblin = MakeGoblin(data);
        int vetMax = vet.Health.MaxHP;
        var (session, exec) = StartSession(data,
            party: new()
            {
                (vet, new PF2eVec(5, 5)), (medic, new PF2eVec(5, 6)),
                (scout, new PF2eVec(6, 6)), (scholar, new PF2eVec(4, 6)),
            },
            enemies: new() { (goblin, new PF2eVec(12, 10)) }, seed: 42);
        try
        {
            // Veteran takes a solid hit (shield down → unmitigated).
            await ReactionEvents.DeliverDamage(goblin, vet, Physical(20));
            Check("(2) veteran took 20 damage", vet.Health.CurrentHP == vetMax - 20);

            // Medic spends a real cast (1-action touch Heal, max 1d8 — cannot top the veteran off).
            // Warpriest divine font: the cast is paid from the font pool, not the preparations.
            medic.Actions.RefillActions();
            await exec.ExecuteCast(medic, PresetSpells.HealId, variantIndex: 0, vet.GridPosition);
            Check("(2) Heal consumed one divine-font slot (font-first)",
                medic.Spellcasting?.DivineFont?.CurrentSlots == 3);
            Check("(2) rank-1 preparations untouched while the font holds", PreparedCount(medic, 1) == 3);
            Check("(2) Heal raised the veteran below max",
                vet.Health.CurrentHP > vetMax - 20 && vet.Health.CurrentHP < vetMax);

            // Encounter-scoped leakage candidates: a fear effect and multiple-attack penalty.
            vet.Conditions.AddCondition(ConditionDatabase.Instance!.Frightened, value: 2, duration: 0);
            vet.Combat.IncrementAttackCount();
            Check("(2) veteran has MAP mid-encounter", vet.Combat.GetCurrentMAP() != 0);

            // Scout goes down: Dying 1 + Unconscious, not dead.
            await ReactionEvents.DeliverDamage(goblin, scout, Physical(scout.Health.MaxHP));
            Check("(2) scout is Dying 1 + Unconscious at 0 HP",
                scout.Health.CurrentHP == 0
                && scout.Conditions.GetConditionValue(Condition.Dying) == 1
                && scout.Conditions.HasCondition(Condition.Unconscious)
                && !scout.Health.IsDead);

            // Victory.
            await ReactionEvents.DeliverDamage(vet, goblin, Physical(999));
            Check("(2) goblin slain", goblin.Health.IsDead);
        }
        finally { session.Teardown(); }

        int vetHpAfterFight = vet.Health.CurrentHP;
        gs1.CompleteEncounter(BattleResult.Team1Wins, new List<ICharacter> { goblin });

        int xpPerGoblin = EncounterXPCalculator.GetCreatureXP(
            goblin.CreatureStats!.Data.CreatureLevel, squad.Level);
        Check("(2) scout stabilized to 1 HP", scout.Health.CurrentHP == 1);
        Check("(2) scout gained Wounded 1",
            scout.Conditions.GetConditionValue(Condition.Wounded) == 1);
        Check("(2) scout no longer Dying/Unconscious",
            !scout.Conditions.HasCondition(Condition.Dying)
            && !scout.Conditions.HasCondition(Condition.Unconscious));
        Check("(2) veteran HP persists after combat (attrition)",
            vet.Health.CurrentHP == vetHpAfterFight && vet.Health.CurrentHP < vetMax);
        Check("(2) encounter-scoped Frightened cleared",
            !vet.Conditions.HasCondition(Condition.Frightened));
        Check("(2) MAP cleared post-combat", vet.Combat.GetCurrentMAP() == 0);
        Check("(2) medic font usage persists (3 of 4 left)",
            medic.Spellcasting?.DivineFont?.CurrentSlots == 3);
        Check($"(2) squad banked {xpPerGoblin} XP each",
            squad.GetXp(SquadRoster.VeteranId) == xpPerGoblin
            && squad.GetXp(SquadRoster.ScholarId) == xpPerGoblin);

        // ── (3) Save → reload into a fresh GameState → exact round-trip ──
        GD.Print("-------------------- (3) Save / load round-trip --------------------");
        gs1.SaveGame();

        var gs2 = new GameState();
        AddChild(gs2); // _Ready: builds fresh presets, then LoadGame re-applies the snapshot
        var squad2 = gs2.Squad;
        Check("(3) reloaded GameState built a squad", squad2 != null && squad2.Members.Count == 4);
        if (squad2 != null)
        {
            string snapLive = JsonSerializer.Serialize(squad.CaptureMembers());
            string snapLoaded = JsonSerializer.Serialize(squad2.CaptureMembers());
            Check("(3) EXACT squad round-trip (serialized snapshots identical)", snapLive == snapLoaded);

            var scout2 = squad2.FindMember(SquadRoster.ScoutId)!;
            var medic2 = squad2.FindMember(SquadRoster.MedicId)!;
            Check("(3) reloaded scout at 1 HP with Wounded 1",
                scout2.Health.CurrentHP == 1
                && scout2.Conditions.GetConditionValue(Condition.Wounded) == 1);
            Check("(3) reloaded medic font at 3 of 4 (additive save field round-trips)",
                medic2.Spellcasting?.DivineFont?.CurrentSlots == 3);
            Check("(3) reloaded medic has 3 rank-1 preparations", PreparedCount(medic2, 1) == 3);
            Check("(3) reloaded XP matches", squad2.GetXp(SquadRoster.VeteranId) == xpPerGoblin);
        }

        // ── (4) Encounter 2 with the SAME live instances (re-entry wiring) ──
        GD.Print("-------------------- (4) Encounter 2 (re-entry) --------------------");
        var goblin2 = MakeGoblin(data);
        var (session2, _) = StartSession(data,
            party: new()
            {
                (vet, new PF2eVec(5, 5)), (medic, new PF2eVec(5, 6)),
                (scout, new PF2eVec(6, 6)), (scholar, new PF2eVec(4, 6)),
            },
            enemies: new() { (goblin2, new PF2eVec(12, 10)) }, seed: 7, registerNow: false);
        try
        {
            Check("(4) MAP is fresh entering encounter 2", vet.Combat.GetCurrentMAP() == 0);
            Check("(4) medic font usage carried INTO encounter 2",
                medic.Spellcasting?.DivineFont?.CurrentSlots == 3);

            // Wounded 1 raises the initial dying value: DyingSystem still fires on the live scout.
            await ReactionEvents.DeliverDamage(goblin2, scout, Physical(scout.Health.MaxHP));
            Check("(4) scout drops at Dying 2 (Wounded 1 raised it) — DyingSystem survives re-entry",
                scout.Conditions.GetConditionValue(Condition.Dying) == 2);

            // Medic (no Wounded) goes down at Dying 1 for the recovery-check test — its dying value
            // can never reach the death threshold from one check, keeping the test deterministic.
            await ReactionEvents.DeliverDamage(goblin2, medic, Physical(medic.Health.MaxHP));
            Check("(4) medic drops at Dying 1", medic.Conditions.GetConditionValue(Condition.Dying) == 1);

            // Turn wiring: fixed order (veteran first, medic second) — ending the veteran's turn
            // starts the dying medic's turn, whose recovery check must fire via the NEW TurnManager.
            bool recoveryFired = false;
            Action<RecoveryCheckEvent> onRecovery = _ => recoveryFired = true;
            medic.Health.DyingSystem!.OnRecoveryCheck += onRecovery;
            try
            {
                TurnManager.Instance!.StartEncounterWithFixedOrder(
                    new List<ICharacter> { vet, medic, scout, scholar, goblin2 });
                TurnManager.Instance.EndTurn(); // veteran → medic: recovery check at turn start
            }
            finally { medic.Health.DyingSystem.OnRecoveryCheck -= onRecovery; }

            Check("(4) dying recovery check fired on the re-subscribed TurnManager", recoveryFired);
            Check("(4) dying medic's turn auto-ends (RequestEndTurn)",
                TurnManager.Instance.EndTurnRequested);

            await ReactionEvents.DeliverDamage(vet, goblin2, Physical(999));
            Check("(4) second goblin slain", goblin2.Health.IsDead);
        }
        finally { session2.Teardown(); }

        gs1.CompleteEncounter(BattleResult.Team1Wins, new List<ICharacter> { goblin2 });
        Check("(4) scout re-stabilized at 1 HP with Wounded 2",
            scout.Health.CurrentHP == 1
            && scout.Conditions.GetConditionValue(Condition.Wounded) == 2);
        Check("(4) medic stabilized at 1 HP with Wounded 1 (exactly once — no double-apply)",
            medic.Health.CurrentHP == 1
            && medic.Conditions.GetConditionValue(Condition.Wounded) == 1
            && !medic.Conditions.HasCondition(Condition.Unconscious));
        Check("(4) XP accumulated across encounters",
            squad.GetXp(SquadRoster.VeteranId) == 2 * xpPerGoblin);

        // ── (5) Sleep = full rest ──
        GD.Print("-------------------- (5) Sleep --------------------");
        int dayBefore = gs1.Clock.Day;
        int xpBefore = squad.GetXp(SquadRoster.VeteranId);
        gs1.Sleep();

        Check("(5) day advanced", gs1.Clock.Day == dayBefore + 1);
        Check("(5) squad at full HP after rest",
            vet.Health.IsFullHealth && scout.Health.IsFullHealth
            && medic.Health.IsFullHealth && scholar.Health.IsFullHealth);
        Check("(5) Wounded cleared by rest",
            !scout.Conditions.HasCondition(Condition.Wounded)
            && !medic.Conditions.HasCondition(Condition.Wounded));
        Check("(5) Fatigued absent after rest", !vet.Conditions.HasCondition(Condition.Fatigued));
        Check("(5) medic re-prepared to 3 rank-1 spells", PreparedCount(medic, 1) == 3);
        Check("(5) medic divine font refilled to 4", medic.Spellcasting?.DivineFont?.CurrentSlots == 4);
        // Scholar (Battle Magic): 3 base rank-1 slots + 1 curriculum school slot = 4 preparations.
        Check("(5) scholar re-prepared to 4 rank-1 spells (incl. school slot)",
            PreparedCount(scholar, 1) == 4);
        Check("(5) XP retained through sleep, level-up NOT applied",
            squad.GetXp(SquadRoster.VeteranId) == xpBefore && vet.Stats!.Level == 2);
    }

    // ─────────────────────────── Harness helpers ───────────────────────────

    private (CombatSession session, PlayerActionExecutor exec) StartSession(
        DataManager data,
        List<(ICharacter, PF2eVec)> party,
        List<(ICharacter, PF2eVec)> enemies,
        int seed,
        bool registerNow = true)
    {
        var setup = new CombatSetup { GridWidth = 16, GridHeight = 14, RngSeed = seed };
        setup.Party.AddRange(party);
        setup.Enemies.AddRange(enemies);

        var session = new CombatSession();
        session.Setup(setup);
        session.SetPresenter(_ => Task.CompletedTask);

        // Scenarios that don't run the turn loop must register combatants themselves; scenarios
        // that drive the TurnManager directly pass registerNow:false (StartEncounter registers).
        if (registerNow)
        {
            foreach (var (c, _) in party) CombatantRegistry.Instance.Register(c);
            foreach (var (c, _) in enemies) CombatantRegistry.Instance.Register(c);
        }

        return (session, session.PlayerActions);
    }

    private ICharacter MakeGoblin(DataManager data)
    {
        var def = data.FindCreature("Goblin Warrior")
            ?? data.LoadCreatureFile("pathfinder-monster-core", "goblin-warrior");
        return CreatureFactory.Create(def, teamId: 2);
    }

    private static int PreparedCount(ICharacter caster, int rank)
    {
        var spellcasting = caster.Spellcasting;
        if (spellcasting == null) return 0;
        int count = 0;
        foreach (var spell in spellcasting.LeveledSpells)
            // Focus spells (Force Bolt) live in LeveledSpells but are not slot preparations.
            if (spell?.Spell != null && spell.Spell.SpellLevel == rank && !spell.Spell.IsFocusSpell)
                count++;
        return count;
    }

    private static DamageResult Physical(int amount) =>
        new() { TotalDamage = amount, DamageType = DamageType.Slashing };

    private void Check(string label, bool ok)
    {
        if (!ok) _failures++;
        GD.Print($"  [{(ok ? "PASS" : "FAIL")}] {label}");
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
        GD.Print("[AttritionSpike] slot0.json backed up and cleared for the test run.");
    }

    private void RestoreSlot0()
    {
        if (_slot0Existed && _slot0Backup != null)
        {
            using var file = Godot.FileAccess.Open(SavePath, Godot.FileAccess.ModeFlags.Write);
            file?.StoreString(_slot0Backup);
            GD.Print("[AttritionSpike] slot0.json restored.");
        }
        else if (!_slot0Existed && Godot.FileAccess.FileExists(SavePath))
        {
            DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(SavePath));
            GD.Print("[AttritionSpike] test slot0.json removed (no prior save existed).");
        }
    }
}
