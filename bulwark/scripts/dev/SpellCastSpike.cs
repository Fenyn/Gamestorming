using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Bulwark.Autoload;
using Bulwark.Combat;
using Bulwark.Data;
using Bulwark.Presets;
using Godot;
using PF2e;
using PF2e.Actions;
using PF2e.Actions.SkillActions;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Utilities;
using PF2eVec = PF2e.Vector2Int;

namespace Bulwark.Dev;

/// <summary>
/// Headless regression for the spell + skill-action layer. Each scenario builds a fresh
/// <see cref="CombatSession"/> (real wiring: grid, registry, spatial + reaction delegates), runs a
/// player-side cast/skill through <see cref="PlayerActionExecutor"/>, asserts the observable outcome,
/// and tears the session down (so pass-through reaction handlers never stack). Prints
/// "SPIKE RESULT: PASS/FAIL" and quits with the matching exit code.
/// </summary>
public partial class SpellCastSpike : Node
{
    private int _failures;

    public override void _Ready() => _ = RunAsync();

    private async Task RunAsync()
    {
        GD.Print("==================== SPELL CAST SPIKE ====================");

        var data = GetNode<DataManager>("/root/DataManager");
        if (data == null || !data.IsLoaded)
        {
            GD.PushError("[SpellSpike] DataManager not loaded — aborting.");
            GD.Print("SPIKE RESULT: FAIL");
            GetTree().Quit(1);
            return;
        }
        PresetSpells.EnsureRegistered();

        await Scenario_A_HealTouch(data);
        await Scenario_B_ElectricArcMulti(data);
        await Scenario_C_Fear(data);
        await Scenario_D_BreatheFireCone(data);
        await Scenario_E_Trip(data);
        await Scenario_F_BattleMedicine(data);
        await Scenario_G_SlotExhaustion(data);

        GD.Print("---------------------------------------------------------");
        bool pass = _failures == 0;
        GD.Print($"[SpellSpike] failures: {_failures}");
        GD.Print($"SPIKE RESULT: {(pass ? "PASS" : "FAIL")}");
        GetTree().Quit(pass ? 0 : 1);
    }

    // ─────────────────────────── (a) Heal (1-action touch) ───────────────────────────

    private async Task Scenario_A_HealTouch(DataManager data)
    {
        var medic = PresetCharacters.BuildMedic(level: 2, teamId: 1);
        var veteran = PresetCharacters.BuildVeteran(level: 2, teamId: 1);

        var (session, exec) = StartSession(data,
            party: new() { (medic, new PF2eVec(5, 5)), (veteran, new PF2eVec(5, 6)) },
            enemies: new(), seed: 1);
        try
        {
            veteran.Health.TakeDamage(new DamageResult { TotalDamage = 12, DamageType = DamageType.Slashing });
            medic.Actions.RefillActions();

            int hpBefore = veteran.Health.CurrentHP;
            int actionsBefore = medic.Actions.TotalActionsRemaining;
            int preparedBefore = PreparedCount(medic, PresetSpells.HealId);

            await exec.ExecuteCast(medic, PresetSpells.HealId, variantIndex: 0, veteran.GridPosition);

            Check("(a) Heal raises HP", veteran.Health.CurrentHP > hpBefore);
            Check("(a) 1-action variant consumes 1 action",
                actionsBefore - medic.Actions.TotalActionsRemaining == 1);
            Check("(a) one rank-1 prepared entry consumed",
                preparedBefore - PreparedCount(medic, PresetSpells.HealId) == 1);
        }
        finally { session.Teardown(); }
    }

    // ─────────────────────────── (b) Electric Arc (2 targets) ───────────────────────────

    private async Task Scenario_B_ElectricArcMulti(DataManager data)
    {
        var scholar = PresetCharacters.BuildScholar(level: 2, teamId: 1);
        var g1 = MakeGoblin(data);
        var g2 = MakeGoblin(data);

        var (session, exec) = StartSession(data,
            party: new() { (scholar, new PF2eVec(5, 5)) },
            enemies: new() { (g1, new PF2eVec(6, 5)), (g2, new PF2eVec(7, 5)) },
            seed: 5);
        try
        {
            int leveledBefore = scholar.Spellcasting.LeveledSpells.Count;

            var first = await CaptureCast(() =>
                exec.ExecuteCast(scholar, PresetSpells.ElectricArcId, -1, g1.GridPosition));
            Check("(b) Electric Arc resolves against 2 targets",
                first != null && first.TargetResults != null && first.TargetResults.Count == 2);
            Check("(b) per-target damage is save-degree consistent", first != null && DamageConsistent(first));
            Check("(b) cantrip consumes no leveled slot",
                scholar.Spellcasting.LeveledSpells.Count == leveledBefore);

            // Repeatable.
            scholar.Actions.RefillActions();
            var second = await CaptureCast(() =>
                exec.ExecuteCast(scholar, PresetSpells.ElectricArcId, -1, g1.GridPosition));
            Check("(b) Electric Arc is repeatable (still 2 targets)",
                second != null && second.TargetResults != null && second.TargetResults.Count == 2);
        }
        finally { session.Teardown(); }
    }

    // ─────────────────────────── (c) Fear (Frightened by degree) ───────────────────────────

    private async Task Scenario_C_Fear(DataManager data)
    {
        bool applied = false;
        foreach (int seed in new[] { 1, 2, 3, 7, 11, 42 })
        {
            var medic = PresetCharacters.BuildMedic(level: 2, teamId: 1);
            var goblin = MakeGoblin(data);
            var (session, exec) = StartSession(data,
                party: new() { (medic, new PF2eVec(5, 5)) },
                enemies: new() { (goblin, new PF2eVec(6, 5)) }, seed: seed);
            try
            {
                medic.Actions.RefillActions();
                await exec.ExecuteCast(medic, PresetSpells.FearId, -1, goblin.GridPosition);
                if (goblin.Conditions.GetConditionValue(Condition.Frightened) > 0) { applied = true; break; }
            }
            finally { session.Teardown(); }
        }
        Check("(c) Fear applies Frightened on a failed Will save", applied);
    }

    // ─────────────────────────── (d) Breathe Fire (cone) ───────────────────────────

    private async Task Scenario_D_BreatheFireCone(DataManager data)
    {
        var scholar = PresetCharacters.BuildScholar(level: 2, teamId: 1);
        var g1 = MakeGoblin(data);
        var g2 = MakeGoblin(data);
        var g3 = MakeGoblin(data);

        var (session, exec) = StartSession(data,
            party: new() { (scholar, new PF2eVec(5, 5)) },
            enemies: new()
            {
                (g1, new PF2eVec(6, 5)), (g2, new PF2eVec(7, 5)), (g3, new PF2eVec(6, 6)),
            }, seed: 9);
        try
        {
            scholar.Actions.RefillActions();
            var ctx = await CaptureCast(() =>
                exec.ExecuteCast(scholar, PresetSpells.BreatheFireId, -1, new PF2eVec(7, 5)));
            Check("(d) Breathe Fire cone hits multiple goblins",
                ctx != null && ctx.TargetResults != null && ctx.TargetResults.Count >= 2);
        }
        finally { session.Teardown(); }
    }

    // ─────────────────────────── (e) Trip (Prone) ───────────────────────────

    private async Task Scenario_E_Trip(DataManager data)
    {
        bool prone = false;
        foreach (int seed in new[] { 1, 2, 3, 7, 11, 42, 100 })
        {
            var veteran = PresetCharacters.BuildVeteran(level: 2, teamId: 1);
            var goblin = MakeGoblin(data);
            var (session, exec) = StartSession(data,
                party: new() { (veteran, new PF2eVec(5, 5)) },
                enemies: new() { (goblin, new PF2eVec(6, 5)) }, seed: seed);
            try
            {
                veteran.Actions.RefillActions();
                await exec.ExecuteSkillAction(veteran, "trip", goblin.GridPosition);
                if (goblin.Conditions.HasCondition(Condition.Prone)) { prone = true; break; }
            }
            finally { session.Teardown(); }
        }
        Check("(e) Trip applies Prone on success", prone);
    }

    // ─────────────────────────── (f) Battle Medicine (heal + immunity) ───────────────────────────

    private async Task Scenario_F_BattleMedicine(DataManager data)
    {
        bool ok = false;
        foreach (int seed in new[] { 1, 2, 3, 7, 11, 42, 100 })
        {
            var medic = PresetCharacters.BuildMedic(level: 2, teamId: 1);
            var veteran = PresetCharacters.BuildVeteran(level: 2, teamId: 1);
            var (session, exec) = StartSession(data,
                party: new() { (medic, new PF2eVec(5, 5)), (veteran, new PF2eVec(5, 6)) },
                enemies: new(), seed: seed);
            try
            {
                veteran.Health.TakeDamage(new DamageResult { TotalDamage = 20, DamageType = DamageType.Slashing });
                medic.Actions.RefillActions();

                int hpBefore = veteran.Health.CurrentHP;
                await exec.ExecuteSkillAction(medic, "battle-medicine", veteran.GridPosition);
                bool healed = veteran.Health.CurrentHP > hpBefore;
                bool immune = BattleMedicineAction.IsImmune(medic.UniqueId, veteran.UniqueId);

                // Repeat must be blocked by immunity.
                medic.Actions.RefillActions();
                bool secondBlocked = !await exec.ExecuteSkillAction(medic, "battle-medicine", veteran.GridPosition);

                if (healed && immune && secondBlocked) { ok = true; break; }
            }
            finally { session.Teardown(); }
        }
        Check("(f) Battle Medicine heals then blocks a repeat on the same target", ok);
    }

    // ─────────────────────────── (g) Slot exhaustion ───────────────────────────

    private async Task Scenario_G_SlotExhaustion(DataManager data)
    {
        var medic = PresetCharacters.BuildMedic(level: 2, teamId: 1);
        var veteran = PresetCharacters.BuildVeteran(level: 2, teamId: 1);
        var goblin = MakeGoblin(data);

        var (session, exec) = StartSession(data,
            party: new() { (medic, new PF2eVec(5, 5)), (veteran, new PF2eVec(5, 6)) },
            enemies: new() { (goblin, new PF2eVec(6, 5)) }, seed: 3);
        try
        {
            var heal = PresetSpells.Get(PresetSpells.HealId);
            Check("(g) rank-1 spell castable with slots remaining", heal.CanPerform(medic));

            // Medic prepared Heal, Heal, Fear = 3 rank-1 preparations. Spend all three.
            medic.Actions.RefillActions();
            await exec.ExecuteCast(medic, PresetSpells.HealId, 0, veteran.GridPosition);
            medic.Actions.RefillActions();
            await exec.ExecuteCast(medic, PresetSpells.HealId, 0, veteran.GridPosition);
            medic.Actions.RefillActions();
            await exec.ExecuteCast(medic, PresetSpells.FearId, -1, goblin.GridPosition);

            medic.Actions.RefillActions();
            Check("(g) Heal not castable after 3 rank-1 casts", !heal.CanPerform(medic));
            Check("(g) Fear not castable after slots exhausted",
                !PresetSpells.Get(PresetSpells.FearId).CanPerform(medic));
        }
        finally { session.Teardown(); }
    }

    // ─────────────────────────── Harness helpers ───────────────────────────

    private (CombatSession session, PlayerActionExecutor exec) StartSession(
        DataManager data,
        List<(ICharacter, PF2eVec)> party,
        List<(ICharacter, PF2eVec)> enemies,
        int seed)
    {
        var setup = new CombatSetup { GridWidth = 16, GridHeight = 14, RngSeed = seed };
        setup.Party.AddRange(party);
        setup.Enemies.AddRange(enemies);

        var session = new CombatSession();
        session.Setup(setup);
        session.SetPresenter(_ => Task.CompletedTask);

        foreach (var (c, _) in party) CombatantRegistry.Instance.Register(c);
        foreach (var (c, _) in enemies) CombatantRegistry.Instance.Register(c);

        return (session, session.PlayerActions);
    }

    private ICharacter MakeGoblin(DataManager data)
    {
        var def = data.FindCreature("Goblin Warrior")
            ?? data.LoadCreatureFile("pathfinder-monster-core", "goblin-warrior");
        return CreatureFactory.Create(def, teamId: 2);
    }

    /// <summary>Capture the resolved SpellContext of a single cast (mirrors the AI/executor seam).</summary>
    private static async Task<SpellContext?> CaptureCast(Func<Task<bool>> cast)
    {
        SpellContext? captured = null;
        void Capture(SpellCompletionEvent e) => captured = e.Context;
        SpellCastAction.OnSpellResolved += Capture;
        try { await cast(); }
        finally { SpellCastAction.OnSpellResolved -= Capture; }
        return captured;
    }

    private static bool DamageConsistent(SpellContext ctx)
    {
        foreach (var tr in ctx.TargetResults)
        {
            // Crit-success save = no damage result; otherwise a positive damage total must be present.
            if (tr.Degree == DegreeOfSuccess.CriticalSuccess) continue;
            if (tr.DamageResult == null || tr.DamageResult.TotalDamage <= 0) return false;
        }
        return true;
    }

    private static int PreparedCount(ICharacter c, string spellId)
        => c.Spellcasting?.GetPreparedCount(PresetSpells.Get(spellId)) ?? 0;

    private void Check(string label, bool ok)
    {
        if (!ok) _failures++;
        GD.Print($"  [{(ok ? "PASS" : "FAIL")}] {label}");
    }
}
