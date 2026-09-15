using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Combat;
using Delve.Data;
using Delve.Presets;
using Godot;
using PF2e;
using PF2e.Actions;
using PF2e.Actions.SkillActions;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Utilities;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Dev;

/// <summary>
/// Headless regression for the spell + skill-action layer. Each scenario builds a fresh
/// <see cref="CombatSession"/> (real wiring: grid, registry, spatial + reaction delegates), runs a
/// player-side cast/skill through <see cref="PlayerActionExecutor"/>, asserts the observable outcome,
/// and tears the session down (so pass-through reaction handlers never stack). Prints
/// "SPIKE RESULT: PASS/FAIL" and quits with the matching exit code.
/// </summary>
public partial class SpellCastSpike : SpikeBase
{
    protected override string Banner => "==================== SPELL CAST SPIKE ====================";

    protected override async Task RunSpikeAsync(DataManager data)
    {
        PresetSpells.EnsureRegistered();
        CheckTargetPreviews(data);

        await Scenario_A_HealTouch(data);
        await Scenario_B_ElectricArcMulti(data);
        await Scenario_TargetSelectionAndRemoval(data);
        Scenario_LargeRemoval(data);
        await Scenario_C_Fear(data);
        await Scenario_D_BreatheFireCone(data);
        await Scenario_E_Trip(data);
        await Scenario_F_BattleMedicine(data);
        await Scenario_G_SlotExhaustion(data);
    }

    // ─────────────────────────── (a) Heal (1-action touch) ───────────────────────────

    private void CheckTargetPreviews(DataManager data)
    {
        var caster = PresetCharacters.BuildFenwick(2);
        var fighter = PresetCharacters.BuildPlayer(2);
        var target = PresetCharacters.BuildPlayer(2, teamId: 2);
        var (session, exec) = StartSession(data,
            party: new() { (caster, new PF2eVec(5, 5)), (fighter, new PF2eVec(6, 4)) },
            enemies: new() { (target, new PF2eVec(6, 5)) }, seed: 17);
        try
        {
            int actions = caster.Actions.TotalActionsRemaining;
            int hp = target.Health.CurrentHP;
            var save = exec.GetSpellTargetPreview(caster, PresetSpells.ElectricArcId, -1, target.GridPosition);
            var expected = CombatPreviewCalculator.CalculateSavePreview(caster, target, PresetSpells.Get(PresetSpells.ElectricArcId));
            Check("preview: saving spells show target failure probability", save?.OutcomeText?.StartsWith($"{Math.Round(expected.TargetFailChance)}% target fails") == true);
            Check("preview: saving spells identify Reflex and caster DC", save?.DetailText?.Contains($"vs spell DC {expected.SpellDC}") == true);
            var attack = exec.GetSpellTargetPreview(caster, PresetSpells.IgnitionId, -1, target.GridPosition);
            Check("preview: spell attacks have hit and crit chances", attack?.OutcomeText?.Contains("% hit") == true && attack.OutcomeText.Contains("critical hit"));
            var trip = exec.GetAbilityTargetPreview(fighter, "trip", target.GridPosition);
            Check("preview: Trip shows success odds and Reflex DC", trip?.OutcomeText?.Contains("% success") == true && trip.DetailText!.Contains("Reflex DC"));
            fighter.Combat.IncrementAttackCount();
            var map = exec.GetAbilityTargetPreview(fighter, "trip", target.GridPosition);
            Check("preview: attack-trait skill forecast changes with MAP", map?.DetailText != trip?.DetailText);
            var controller = new PlayerTurnController(exec);
            AttackPreviewView? hovered = null;
            controller.AttackPreviewChanged += view => hovered = view;
            controller.BeginTurn(caster);
            controller.BeginSpell(PresetSpells.ElectricArcId, -1);
            controller.TileHovered(target.GridPosition);
            Check("preview: multi-target spell hover reaches the card", hovered?.OutcomeText == save?.OutcomeText && hovered != null);
            controller.TileHovered(new PF2eVec(0, 0));
            Check("preview: leaving legal targets clears the card", hovered == null);
            controller.EndControl();
            Check("preview: hovering spends no actions and deals no damage", actions == caster.Actions.TotalActionsRemaining && hp == target.Health.CurrentHP);
        }
        finally { session.Teardown(); }
    }

    private async Task Scenario_A_HealTouch(DataManager data)
    {
        var medic = PresetCharacters.BuildTharr(level: 2, teamId: 1);
        var veteran = PresetCharacters.BuildPlayer(level: 2, teamId: 1);

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
            int fontBefore = medic.Spellcasting!.DivineFont?.CurrentSlots ?? -1;
            var healPreview = exec.GetSpellTargetPreview(medic, PresetSpells.HealId, 1, veteran.GridPosition);
            Check("preview: healing identifies no roll and the chosen variant", healPreview?.OutcomeText == "No roll required"
                && healPreview.DetailText?.Contains("+8") == true);

            await exec.ExecuteCast(medic, PresetSpells.HealId, variantIndex: 0, veteran.GridPosition);

            Check("(a) Heal raises HP", veteran.Health.CurrentHP > hpBefore);
            Check("(a) 1-action variant consumes 1 action",
                actionsBefore - medic.Actions.TotalActionsRemaining == 1);
            // Warpriest Medic: Heal is Aveline's divine-font spell, so the cast is paid from the
            // font pool FIRST — preparations stay untouched until the font runs dry.
            Check("(a) Heal consumed a divine-font slot (font-first)",
                fontBefore == 4 && medic.Spellcasting!.DivineFont!.CurrentSlots == fontBefore - 1);
            Check("(a) rank-1 preparations untouched while font slots remain",
                PreparedCount(medic, PresetSpells.HealId) == preparedBefore);
        }
        finally { session.Teardown(); }
    }

    // ─────────────────────────── (b) Electric Arc (2 targets) ───────────────────────────

    private async Task Scenario_B_ElectricArcMulti(DataManager data)
    {
        var fenwick = PresetCharacters.BuildFenwick(level: 2, teamId: 1);
        var g1 = MakeGoblin(data);
        var g2 = MakeGoblin(data);

        var (session, exec) = StartSession(data,
            party: new() { (fenwick, new PF2eVec(5, 5)) },
            enemies: new() { (g1, new PF2eVec(6, 5)), (g2, new PF2eVec(7, 5)) },
            seed: 5);
        try
        {
            int leveledBefore = fenwick.Spellcasting.LeveledSpells.Count;

            var first = await CaptureCast(() =>
                exec.ExecuteCastTargets(fenwick, PresetSpells.ElectricArcId, -1, new[] { g1, g2 }));
            Check("(b) Electric Arc resolves against 2 targets",
                first != null && first.TargetResults != null && first.TargetResults.Count == 2);
            Check("(b) per-target damage is save-degree consistent", first != null && DamageConsistent(first));
            Check("(b) cantrip consumes no leveled slot",
                fenwick.Spellcasting.LeveledSpells.Count == leveledBefore);

            // Repeatable.
            fenwick.Actions.RefillActions();
            var second = await CaptureCast(() =>
                exec.ExecuteCastTargets(fenwick, PresetSpells.ElectricArcId, -1, new[] { g1, g2 }));
            Check("(b) Electric Arc is repeatable (still 2 targets)",
                second != null && second.TargetResults != null && second.TargetResults.Count == 2);
        }
        finally { session.Teardown(); }
    }

    // ─────────────────────────── (c) Fear (Frightened by degree) ───────────────────────────

    private async Task Scenario_TargetSelectionAndRemoval(DataManager data)
    {
        var caster = PresetCharacters.BuildFenwick(level: 2, teamId: 1);
        var a = MakeGoblin(data);
        var b = MakeGoblin(data);
        var c = MakeGoblin(data);
        var (session, exec) = StartSession(data,
            new() { (caster, new PF2eVec(5, 5)) },
            new() { (a, new PF2eVec(6, 5)), (b, new PF2eVec(7, 5)), (c, new PF2eVec(8, 5)) }, 5);
        try
        {
            caster.Actions.RefillActions();
            Check("target limit comes from spell", exec.GetSpellTargets(caster, PresetSpells.ElectricArcId, -1).MaxTargets == 2);
            Check("empty selection rejected", !await exec.ExecuteCastTargets(caster, PresetSpells.ElectricArcId, -1, Array.Empty<ICharacter>()));
            Check("over limit rejected", !await exec.ExecuteCastTargets(caster, PresetSpells.ElectricArcId, -1, new[] { a, b, c }));
            Check("duplicate target rejected", !await exec.ExecuteCastTargets(caster, PresetSpells.ElectricArcId, -1, new[] { a, a }));
            Check("invalid selections cost no actions", caster.Actions.TotalActionsRemaining == 3);
            var controller = new PlayerTurnController(exec);
            int count = -1;
            controller.SpellTargetsChanged += (n, _) => count = n;
            controller.BeginTurn(caster);
            controller.BeginSpell(PresetSpells.ElectricArcId, -1);
            controller.TileClicked(a.GridPosition);
            Check("partial selection waits without spending actions", count == 1 && caster.Actions.TotalActionsRemaining == 3);
            controller.TileClicked(a.GridPosition);
            Check("click selected target toggles it off", count == 0);
            controller.Cancel();
            controller.ConfirmSpellTargets();
            Check("cancel clears selection without casting", count == 0 && caster.Actions.TotalActionsRemaining == 3);
            var completed = new TaskCompletionSource<SpellContext>();
            int casts = 0;
            void CaptureAutomatic(SpellCompletionEvent e) { casts++; completed.TrySetResult(e.Context); }
            SpellCastAction.OnSpellResolved += CaptureAutomatic;
            try
            {
                controller.BeginSpell(PresetSpells.ElectricArcId, -1);
                controller.TileClicked(a.GridPosition);
                controller.TileClicked(b.GridPosition);
                controller.ConfirmSpellTargets();
                var automatic = await completed.Task.WaitAsync(TimeSpan.FromSeconds(5));
                Check("last target automatically casts exactly once", casts == 1 && automatic.TargetResults.Count == 2
                    && automatic.TargetResults.Exists(t => t.Target == a) && automatic.TargetResults.Exists(t => t.Target == b));
            }
            finally { SpellCastAction.OnSpellResolved -= CaptureAutomatic; }
            caster.Actions.RefillActions();
            int untouched = a.Health.CurrentHP;
            var result = await CaptureCast(() => exec.ExecuteCastTargets(caster, PresetSpells.ElectricArcId, -1, new[] { c }));
            Check("one chosen target never auto-fills another", result?.TargetResults?.Count == 1
                && result.TargetResults[0].Target == c && a.Health.CurrentHP == untouched);

            a.Health.TakeDamage(new DamageResult { TotalDamage = 999, DamageType = DamageType.Slashing });
            Check("death immediately releases occupancy", a.Health.IsDead && !session.Grid.IsTileOccupied(a.GridPosition));
            Check("death tile can be stepped onto", exec.StepBlockedReason(caster, a.GridPosition) == null);
            session.RemoveCombatant(b);
            Check("removed living enemy releases occupancy and registry", !session.Grid.IsTileOccupied(b.GridPosition)
                && !new List<ICharacter>(CombatantRegistry.Instance.All).Contains(b));
            caster.Actions.RefillActions();
            Check("stale removed selection rejected", !await exec.ExecuteCastTargets(caster, PresetSpells.ElectricArcId, -1, new[] { b }));
            session.Grid.PlaceCreature(caster, a.GridPosition);
            session.RemoveCombatant(a);
            Check("repeated cleanup preserves replacement occupant", session.Grid.GetGroundOccupant(a.GridPosition) == caster);
        }
        finally { session.Teardown(); }
    }

    private void Scenario_LargeRemoval(DataManager data)
    {
        var caster = PresetCharacters.BuildFenwick(level: 2, teamId: 1);
        var definition = data.ResolveCreature(new CreatureRef
        {
            DisplayName = "Giant Stag Beetle", Pack = "pathfinder-monster-core", Slug = "giant-stag-beetle",
        })!;
        var large = CreatureFactory.Create(definition, teamId: 2);
        var other = MakeGoblin(data);
        var (session, exec) = StartSession(data, new() { (caster, new PF2eVec(5, 5)) },
            new() { (large, new PF2eVec(6, 5)), (other, new PF2eVec(9, 5)) }, 5);
        try
        {
            var footprint = new List<PF2eVec>(CreatureTargetTiles.For(large));
            Check("large removal fixture has four occupied tiles", footprint.Count == 4
                && footprint.TrueForAll(t => session.Grid.IsTileOccupied(t)));
            caster.Actions.RefillActions();
            var controller = new PlayerTurnController(exec);
            int selected = 0;
            controller.SpellTargetsChanged += (n, _) => selected = n;
            controller.BeginTurn(caster);
            controller.BeginSpell(PresetSpells.ElectricArcId, -1);
            controller.TileClicked(footprint[0]);
            controller.TileClicked(footprint[1]);
            Check("different tiles of one creature toggle the same target", selected == 0);
            controller.Cancel();
            PF2e.TurnManagement.TurnManager.Instance.StartEncounter(new List<ICharacter> { caster, large, other });
            large.Health.TakeDamage(new DamageResult { TotalDamage = 999, DamageType = DamageType.Slashing });
            Check("large death frees every footprint tile during encounter", footprint.TrueForAll(t => !session.Grid.IsTileOccupied(t)));
            Check("dead creature leaves turn order", !new List<PF2e.TurnManagement.TurnEntry>(session.TurnOrder!).Exists(t => t.Character == large));
            CombatantRegistry.Instance.Unregister(other);
            session.ReconcileOccupancy();
            Check("external registry removal frees tile and initiative", !session.Grid.IsTileOccupied(other.GridPosition)
                && !new List<PF2e.TurnManagement.TurnEntry>(session.TurnOrder!).Exists(t => t.Character == other));
            caster.Health.TakeDamage(new DamageResult { TotalDamage = caster.Health.CurrentHP, DamageType = DamageType.Slashing });
            session.ReconcileOccupancy();
            Check("dying hero stays on grid for healing", !caster.Health.IsDead && session.Grid.GetGroundOccupant(caster.GridPosition) == caster);
        }
        finally { session.Teardown(); }
    }

    private async Task Scenario_C_Fear(DataManager data)
    {
        bool applied = false;
        foreach (int seed in new[] { 1, 2, 3, 7, 11, 42 })
        {
            var medic = PresetCharacters.BuildTharr(level: 2, teamId: 1);
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
        var fenwick = PresetCharacters.BuildFenwick(level: 2, teamId: 1);
        var g1 = MakeGoblin(data);
        var g2 = MakeGoblin(data);
        var g3 = MakeGoblin(data);

        var (session, exec) = StartSession(data,
            party: new() { (fenwick, new PF2eVec(5, 5)) },
            enemies: new()
            {
                (g1, new PF2eVec(6, 5)), (g2, new PF2eVec(7, 5)), (g3, new PF2eVec(6, 6)),
            }, seed: 9);
        try
        {
            fenwick.Actions.RefillActions();
            var preview = exec.GetSpellTargetPreview(fenwick, PresetSpells.BreatheFireId, -1, new PF2eVec(7, 5));
            int previewTargets = preview?.OutcomeText?.Split('\n').Length ?? 0;
            var previousKnowledge = CreatureKnowledgeLocator.Instance;
            try
            {
                CreatureKnowledgeLocator.Instance = new UnknownPreviewKnowledge();
                var hidden = exec.GetSpellTargetPreview(fenwick, PresetSpells.BreatheFireId, -1, new PF2eVec(7, 5));
                Check("preview: unknown saves mask every target's odds", previewTargets >= 2
                    && hidden?.OutcomeText?.Split("?% target fails").Length == previewTargets + 1);
            }
            finally { CreatureKnowledgeLocator.Instance = previousKnowledge; }
            var ctx = await CaptureCast(() =>
                exec.ExecuteCast(fenwick, PresetSpells.BreatheFireId, -1, new PF2eVec(7, 5)));
            Check("(d) Breathe Fire cone hits multiple goblins",
                ctx != null && ctx.TargetResults != null && ctx.TargetResults.Count >= 2);
            Check("preview: area forecast matches actual affected targets", previewTargets >= 2
                && ctx?.TargetResults?.Count == previewTargets);
        }
        finally { session.Teardown(); }
    }

    // ─────────────────────────── (e) Trip (Prone) ───────────────────────────

    private sealed class UnknownPreviewKnowledge : ICreatureKnowledgeProvider
    {
        public bool IsFieldRevealed(string id, CreatureKnowledgeField field) => false;
        public bool IsEncountered(string id) => true;
        public bool IsComplete(string id) => false;
    }

    private async Task Scenario_E_Trip(DataManager data)
    {
        bool prone = false;
        foreach (int seed in new[] { 1, 2, 3, 7, 11, 42, 100 })
        {
            var veteran = PresetCharacters.BuildPlayer(level: 2, teamId: 1);
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
            var medic = PresetCharacters.BuildTharr(level: 2, teamId: 1);
            var veteran = PresetCharacters.BuildPlayer(level: 2, teamId: 1);
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
        var medic = PresetCharacters.BuildTharr(level: 2, teamId: 1);
        var veteran = PresetCharacters.BuildPlayer(level: 2, teamId: 1);
        var goblin = MakeGoblin(data);

        var (session, exec) = StartSession(data,
            party: new() { (medic, new PF2eVec(5, 5)), (veteran, new PF2eVec(5, 6)) },
            enemies: new() { (goblin, new PF2eVec(6, 5)) }, seed: 3);
        try
        {
            var heal = PresetSpells.Get(PresetSpells.HealId)!;
            Check("(g) rank-1 spell castable with slots remaining", heal.CanPerform(medic));

            // Warpriest Medic heal budget: 4 divine-font slots + 2 prepared Heals = 6 casts.
            // The font pays first; only then do the preparations get consumed.
            int healCasts = 0;
            while (heal.CanPerform(medic) && healCasts < 10)
            {
                medic.Actions.RefillActions();
                await exec.ExecuteCast(medic, PresetSpells.HealId, 0, veteran.GridPosition);
                healCasts++;
            }
            Check("(g) Heal budget = 4 font slots + 2 preparations (6 casts)", healCasts == 6);
            Check("(g) font pool exhausted", medic.Spellcasting!.DivineFont!.CurrentSlots == 0);
            Check("(g) Heal not castable once font + preparations are spent", !heal.CanPerform(medic));

            // Fear was the third rank-1 preparation and is not a font spell — still castable once.
            var fear = PresetSpells.Get(PresetSpells.FearId)!;
            Check("(g) Fear still castable (its preparation is untouched)", fear.CanPerform(medic));
            medic.Actions.RefillActions();
            await exec.ExecuteCast(medic, PresetSpells.FearId, -1, goblin.GridPosition);
            Check("(g) Fear not castable after its preparation is spent", !fear.CanPerform(medic));
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
        var def = data.ResolveCreature(EncounterTables.GoblinWarrior)!;
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
        => c.Spellcasting?.GetPreparedCount(PresetSpells.Get(spellId)!) ?? 0;
}
